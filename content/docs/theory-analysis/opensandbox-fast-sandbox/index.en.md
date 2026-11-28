---
title: OpenSandbox Fast Sandbox
draft: true
---

Analyzes the behavior of Fast Sandbox, OpenSandbox's fast sandbox execution path. The pod-based execution model analyzed in the [OpenSandbox BatchSandbox](../opensandbox-batch-sandbox/) article takes seconds to start due to pod creation and container cold boot, and pause/resume takes tens of seconds or more because snapshots make a round trip through a registry. Fast Sandbox is a separate execution path that provides millisecond-level startup time by restoring pre-built golden image snapshots as Firecracker microVMs, and supports live snapshots that preserve memory state as well as automatic idle-pause/wake. The analysis is based on v1.2.1.

## 1. Architecture

{{< figure caption="[Figure 1] Fast Sandbox Architecture" src="images/fast-sandbox-architecture.png" width="1000px" >}}

[Figure 1] shows the architecture of Fast Sandbox. Fast Sandbox consists of a control plane and node runtime separate from the OpenSandbox server, and when a sandbox creation request includes a `templateId`, the server routes the request to the Fast Sandbox path instead of the workload provider.

* **Controller (FastPath)** : The control plane of Fast Sandbox. The reconcilers for the SandboxPool, SandboxTemplate, and Sandbox custom resources in the `sandbox.fast.io` group, and **FastPath**, the gRPC API through which the server requests sandbox create/delete/pause/resume, run as a single process.
* **Firecracker Runtime** : A DaemonSet running on each KVM node. It provides the UDS management API (artifact pull, lease state) that the fastlet's Firecracker driver talks to, and includes a node readiness loop that performs host suitability checks and installs Firecracker assets. A node-local **DART** child for P2P artifact delivery and a **Janitor** sidecar that cleans up orphaned resources also run alongside.
* **Fastlet** : The worker pod where sandboxes actually run. A single fastlet hosts multiple Firecracker microVMs concurrently, and sandboxes run as microVMs inside the fastlet, not as Kubernetes pods.

What is notable in node preparation is the **runtime's self-labeling**. The Firecracker runtime performs host checks on the node, including KVM availability, and itself applies the `fast-sandbox.io/kvm` and `fast-sandbox.io/firecracker-node` labels and the `FirecrackerReady` node condition to nodes that pass. Operators do not need to manually label KVM nodes, and fastlets and golden image builder pods are scheduled based on these labels. Since Firecracker requires `/dev/kvm`, bare metal nodes or nodes with nested virtualization enabled are required.

## 2. Fastlet and SandboxPool

The quantity and shape of fastlets are determined by the **SandboxPool** custom resource. SandboxPool adopts a **fixed pool model** that pins the runtime type, the sandbox CPU/memory/PID limits, and the fastlet template, and all sandboxes in a pool have the same shape. The server selects the pool through the request's `extensions.poolRef` or the configured default pool (`fastpath_resource_pool`).

```yaml {caption="[Text 1] Key SandboxPool Spec"}
apiVersion: sandbox.fast.io/v1alpha2
kind: SandboxPool
spec:
  runtime: firecracker
  capacity:
    poolMin: 2                  # Number of fastlets kept resident
    poolMax: 4
  maxSandboxesPerPod: 5         # MicroVMs accommodated per fastlet
  sandboxResources:             # Fixed shape of every sandbox in the pool
    cpu: "1"
    memory: 512Mi
    pids: 128
  warmImages:                   # Golden images pre-pulled at fastlet startup
    - python-agent:v1
```

[Text 1] shows the key spec of a SandboxPool. Unlike BatchSandbox, which creates a pod per sandbox, Fast Sandbox is a model that **places microVMs into already-running fastlets**, so pod scheduling and image pulls do not exist in the sandbox creation path. Placement is done through a node-local scheduling registry and the fastlet's atomic admission, and when every fastlet is full, the request is rejected with ResourceExhausted before a Sandbox custom resource is created — a bounded capacity error semantic. The structure where one fastlet hosts multiple microVMs is also advantageous in density compared to a pod-per-sandbox model.

## 3. Golden Image Pipeline

{{< figure caption="[Figure 2] Golden Image Build and Distribution Path" src="images/fast-sandbox-golden-image.png" width="1000px" >}}

[Figure 2] shows the build and distribution path of golden images. Fast Sandbox's startup time comes from the golden image strategy of "performing the boot in advance and saving that point in time".

When a **SandboxTemplate** custom resource is created, the controller creates a one-shot **builder pod**. The builder actually boots a Firecracker VM from the base container image on a KVM node, bakes execd into the guest, creates a memory and rootfs snapshot (snapfiles) of the VM, and publishes it to the **artifact store**. The artifact store is S3-compatible object storage, and subsequent sandbox creation is replaced by restoring this snapshot. In other words, cold boot is performed only once at template build time.

The reason the creation path is fast even though the artifact store is remote storage is that **the restore source is node local**.

* **Warm Images** : Golden images declared in the SandboxPool's `warmImages` are pre-pulled into the node-local cache (StateRoot) while the fastlet starts up. Warm image lookups are byte-exact based on the hash of the image name, so they must exactly match the template's image.
* **Cache-aware Scheduling** : Sandbox placement prefers fastlets where the artifact is already cached. Caches such as warm images, infra components, and active runtime content are protected from GC.
* **DART P2P** : Even when a node is added with an empty cache, blocks are fetched from neighboring nodes' DART peers instead of the artifact store. Peer discovery is done through DNS seeding of a headless Service.

Therefore, the cost of round trips to the artifact store is paid only at template build and initial warm-up time, and steady-state sandbox creation completes with only a node-local snapshot restore.

## 4. Live Snapshot and Idle-Pause/Wake

### 4.1. Live Snapshot

Unlike BatchSandbox's rootfs commit, pause in Fast Sandbox **checkpoints the entire memory state of the microVM**. The checkpoint is first written to a memory-backed spill area and then moved to the node-local StateRoot, without a round trip through a registry or the artifact store. Because of this, a paused sandbox can be restored in milliseconds to seconds with its running processes and memory preserved intact. This contrasts with the Kata QEMU snapshot, which provides a similar preservation scope in the BatchSandbox path but round-trips memory state through a registry.

### 4.2. Idle-Pause/Wake-on-Access

{{< figure caption="[Figure 3] OSEP-0024 Idle-Pause/Wake-on-Access Loop" src="images/fast-sandbox-idle-pause-wake.png" width="1000px" >}}

[Figure 3] shows the loop structure of OSEP-0024 idle-pause/wake-on-access. The fast and lossless live snapshot is the premise of the automatic idle-pause/wake feature, and the ingress gateway, the server, and the sandbox form a loop of three components.

```text {caption="[Text 2] Idle-Pause/Wake Loop"}
Active : Every request passing through the ingress gateway records per-sandbox
         activity in Redis
Idle   : The server's sweeper periodically checks activity and calls FastPath
         PauseSandbox for sandboxes past their idle timeout → checkpoint, then Paused
Wake   : When a request arrives for a paused sandbox, the gateway triggers resume,
         parks the request within the parking budget, then forwards it to the
         restored sandbox
```

[Text 2] shows the actions performed at each stage of the loop. The automation operates only by agreement of three parties: the server's `[automation.idle_pause]` configuration (sweeper), the gateway's activity/wake flags, and the sandbox's own opt-in. A sandbox opts in through `lifecycle.idlePolicy` (idle timeout, wake enablement) in the creation request, and this policy is preserved as the `sandbox.opensandbox.io/idle-policy` annotation on the Sandbox custom resource. Sandboxes that do not opt in are never paused automatically.

Request parking for wake is bounded by a budget (default 5 seconds), and if restoration does not complete within the budget, 503 with Retry-After is returned while restoration continues in the background. This parking budget explains why automation exists only for Fast Sandbox. **Pausing behind the user's back is safe only if the premise holds that restoration can complete within a few seconds of parking when the next request arrives** — and BatchSandbox's resume, which requires pod recreation and image pulls, cannot satisfy this premise. For the same reason, automatic pause in execution models that do not preserve memory carries the risk of arbitrarily interrupting running work.

One caveat is that the only recording point for activity is the ingress gateway. Traffic that does not pass through the gateway is not recorded as activity, so opting such workloads into an idle policy may cause them to be judged idle and paused even while actually in use.

## 5. References

* [https://github.com/opensandbox-group/OpenSandbox](https://github.com/opensandbox-group/OpenSandbox)
* [https://github.com/opensandbox-group/fast-sandbox](https://github.com/opensandbox-group/fast-sandbox)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/auto-pause-wake.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/auto-pause-wake.md)
* [https://github.com/opensandbox-group/fast-sandbox/blob/main/docs/concepts/scheduling-and-capacity.md](https://github.com/opensandbox-group/fast-sandbox/blob/main/docs/concepts/scheduling-and-capacity.md)
