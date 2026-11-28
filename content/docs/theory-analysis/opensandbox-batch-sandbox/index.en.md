---
title: OpenSandbox BatchSandbox
draft: true
---

Analyzes the behavior of BatchSandbox, OpenSandbox's default sandbox execution model. BatchSandbox is OpenSandbox's first-class workload provider that runs sandboxes as Kubernetes pods, and most OpenSandbox features, including volume lifecycle management, egress restriction, and snapshot-based pause/resume, are provided based on BatchSandbox. The overall OpenSandbox architecture is analyzed in the [OpenSandbox Architecture](../opensandbox-architecture/) article, and this article focuses on the detailed behavior of the BatchSandbox path. The analysis is based on v1.2.1.

## 1. BatchSandbox Mechanics

{{< figure caption="[Figure 1] BatchSandbox Creation Flow and Sandbox Pod Structure" src="images/batchsandbox-flow.png" width="1000px" >}}

[Figure 1] shows the process by which a sandbox creation request materializes into a pod. When the server receives a creation request, it creates a **BatchSandbox** custom resource in the `sandbox.opensandbox.io/v1alpha1` group in the sandbox workload namespace, and the controller reconciles the BatchSandbox to create the sandbox pod. The skeleton of the pod is determined by the BatchSandbox template (`batchsandbox_template_file`) mounted on the server, and the content of the creation request is merged on top of the template. Therefore, platform-owned settings such as scheduling and securityContext are enforced by the template, and only per-sandbox settings such as image and env are determined by the request.

In addition to the user container, the sandbox pod includes components injected by OpenSandbox.

* **execd** : The process responsible for in-sandbox bootstrap. According to OSEP-0018, it runs as the sandbox's init (PID 1) and is responsible for child process reaping and signal forwarding. Both the code execution (exec) API and the file transfer API are handled through execd.
* **Egress Sidecar / egress-init** : Egress enforcement components injected when the creation request includes a `networkPolicy`. The detailed behavior is analyzed in the Egress NetworkPolicy section.

Created workloads are given reserved labels such as `opensandbox.io/id`, `opensandbox.io/tenant`, and `opensandbox.io/expires-at`, and the server tracks sandbox lifetime and ownership through these labels.

## 2. Egress NetworkPolicy

Per-sandbox egress restriction is declared with the `networkPolicy` field of the creation request.

```python {caption="[Text 1] Egress NetworkPolicy Declaration Example"}
sandbox = await Sandbox.create(
    image="python:3.11",
    network_policy=NetworkPolicy(
        default_action="deny",                  # deny is the default even when omitted
        egress=[
            NetworkRule(action="allow", target="pypi.org"),
            NetworkRule(action="allow", target="*.pythonhosted.org"),
            NetworkRule(action="allow", target="10.0.0.0/8", ports=[5432]),
            NetworkRule(action="deny",  target="*.internal.example.com"),
        ],
    ),
)
```

[Text 1] shows a NetworkPolicy declaration example using the Python SDK. A NetworkPolicy consists of a default action (`defaultAction`, defaults to deny) and a list of rules evaluated in order (`egress`). Each rule's `target` supports FQDNs, wildcard domains, IPs, and CIDRs, and `ports` can restrict TCP destination ports. However, since domain rules are evaluated at the DNS layer where no port dimension exists, combining a domain with `ports` is rejected with a validation error. UDP port restriction is also not supported.

Enforcement happens in two stages. At pod startup, the `egress-init` init container installs a default-deny nftables fence before the workload container starts, and once the egress sidecar initializes, the fence is atomically replaced with the declared policy. After that, domain rules are enforced by the sidecar's DNS proxy and IP/CIDR rules by nftables (based on `dns+nft` mode). Because of this bootstrap order, sandbox code cannot exploit the time gap before sidecar initialization.

Note that the NetworkPolicy is a mechanism by which the platform creating the sandbox defends itself from code inside the sandbox. Since policy authority lies with the requester, in multi-tenant environments where the requester itself cannot be trusted, an additional non-bypassable boundary is needed: installing a baseline Kubernetes NetworkPolicy in the sandbox workload namespace (blocking IMDS and internal networks).

## 3. Volume

BatchSandbox can mount PVCs through the `volumes` field of the creation request, and is divided into three modes depending on the owner of the PVC lifecycle.

| Mode | `createIfNotExists` | `deleteOnSandboxTermination` | PVC Lifecycle Owner | Use Case |
|---|---|---|---|---|
| Bring Your Own | `false` | Ignored | Platform (pre-provisioned) | Shared cache, model storage |
| Server-Managed Persistent | `true` | `false` (default) | User after first creation | State preservation beyond sandbox lifetime |
| Server-Managed Ephemeral | `true` | `true` | Server | Per-sandbox scratch space |

```python {caption="[Text 2] Server-Managed PVC Declaration Example"}
sandbox = await Sandbox.create(
    image="python:3.11",
    volumes=[Volume(
        pvc=PVC(
            claimName="agent-cache",
            createIfNotExists=True,            # server creates it if missing
            deleteOnSandboxTermination=False,  # retained after sandbox termination
            storage="20Gi",
        ),
        mountPath="/mnt/cache",
    )],
)
```

[Text 2] shows a PVC declaration example in server-managed persistent mode. In server-managed mode, PVC creation and cleanup are handled by the API without the client accessing Kubernetes. An ephemeral PVC is exclusively owned by the sandbox that created it, and another sandbox attempting to mount the same `claimName` is rejected with 409 CONFLICT. Also, the server only deletes PVCs it created via `createIfNotExists` and never deletes pre-existing PVCs, so a shared pre-provisioned PVC is never swept away by ephemeral cleanup.

In addition to PVCs, host bind mounts are supported only for paths declared in `[storage].allowed_host_paths`. If the allowlist is empty, all host binds are rejected — a secure-by-default behavior.

Volumes are also meaningful as an alternative to snapshot-based pause/resume. By placing state that needs preservation in a persistent PVC, you can achieve state preservation and compute release without a registry by terminating the sandbox and recreating it with the same `claimName`. However, this approach differs from snapshots in that the `sandboxId` changes and rootfs changes outside the mount path are not preserved.

## 4. Secure Runtime

Sandbox pods of BatchSandbox run with runc by default, but a more strongly isolated runtime can be used through the `[secure_runtime]` configuration.

```toml {caption="[Text 3] Secure Runtime Configuration"}
[secure_runtime]
type = "gvisor"               # "", gvisor, kata, firecracker
k8s_runtime_class = "gvisor"  # Kubernetes RuntimeClass name
```

[Text 3] shows a secure runtime configuration using gVisor. The server injects the specified RuntimeClass when creating sandbox pods. If a nodeSelector and tolerations are defined in the RuntimeClass's `scheduling` field, sandbox pods are automatically placed on nodes where the runtime is installed, so it works without server configuration changes even in clusters where gVisor or Kata is installed only on specific node groups.

There is one secure runtime profile per server process, and API requests cannot select a runtime. To serve runc sandboxes and gVisor sandboxes simultaneously, separate servers must be deployed. The runtime choice also directly affects the availability of the snapshot-based pause/resume feature.

## 5. Pause/Resume and Snapshot

{{< figure caption="[Figure 2] BatchSandbox Pause/Resume Flow" src="images/batchsandbox-snapshot.png" width="1000px" >}}

[Figure 2] shows the pause/resume flow of BatchSandbox. Pause in BatchSandbox preserves the sandbox's rootfs as an OCI image and then removes the pod to release compute resources. When a pause request arrives, the controller creates an internal custom resource called **SandboxSnapshot** and creates a short-lived **commit Job** in the same namespace as the sandbox. The commit Job's image-committer uses nerdctl to commit the container rootfs as an OCI image and pushes it to the configured registry. On resume, the BatchSandbox template is rewritten to the snapshot image and the pod is recreated, so the filesystem state is restored while the `sandboxId` is retained. Processes that were running before the pause are not preserved and are restarted.

Snapshot configuration belongs to the controller, not the server. The registry address, push/pull secrets (`kubernetes.io/dockerconfigjson` type), and image naming template are specified on the controller, and clients just call the pause/resume APIs without configuration. If pause is requested without a configured registry, the failure is reported as a status condition on the SandboxSnapshot.

### 5.1. Snapshot Compatibility per Runtime

Snapshot behavior differs in availability and preservation scope depending on the sandbox's container runtime.

| Runtime | Pause/Snapshot | Preservation Scope |
|---|---|---|
| runc (default) | Supported (rootfs-v1 committer) | Rootfs only, processes restarted |
| gVisor (runsc) | **Rejected (HTTP 409)** | - |
| Kata (QEMU) | Supported (QEMU checkpoint) | Rootfs + **entire VM memory** |

The default rootfs-v1 committer presumes containerd's task pause/resume and writable snapshot APIs, and gVisor (runsc) does not satisfy this contract. For this reason, the server rejects pause requests for BatchSandboxes running with a runsc-handler RuntimeClass with HTTP 409 before creating a snapshot record, leaving the running sandbox unaffected. In other words, **gVisor isolation and snapshot-based pause/resume are a mutually exclusive trade-off**.

On the other hand, a separate QEMU checkpoint path is provided for the QEMU-based Kata runtime. The image-committer checkpoints the entire VM memory state through the QEMU checkpoint helper, compresses it, and packages it as a registry image, and on resume the VM state loader restores it. In this case, not only the filesystem but also running processes and memory are preserved, providing a preservation scope similar to Fast Sandbox's live snapshot in a pod-based execution model. However, since the memory state makes a round trip through the registry, pause/resume takes significantly longer compared to Fast Sandbox, which keeps checkpoints node-local. Fast Sandbox's live snapshot and automatic idle-pause/wake are analyzed in the [OpenSandbox Fast Sandbox](../opensandbox-fast-sandbox/) article.

## 6. References

* [https://github.com/opensandbox-group/OpenSandbox](https://github.com/opensandbox-group/OpenSandbox)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md)
