---
title: Python OpenSandbox SDK
---

Summarizes how to use the Python OpenSandbox SDK. Rather than enumerating the API reference, this article focuses on patterns that recur when using sandboxes in real services. Examples use the async API, which is the SDK's primary surface. Based on v1.2.1.

## 1. Lifecycle and Connection Management

The SDK does not operate on its own — it acts as a client that forwards every request to the REST API of the **OpenSandbox Server**. Therefore, to use the SDK, the OpenSandbox Server address and the **API Key** must first be configured through `ConnectionConfig`. In a **single-tenant** setup, the entire server shares one API key, so every caller creates sandboxes in the same space. In a **multi-tenant** setup, each tenant is issued its own API key, and the namespace and ownership of created sandboxes are separated by the key in use, allowing multiple teams or services to share one server in isolation.

```python {caption="[Code 1] Basic Lifecycle and Connection Management"}
import asyncio
from datetime import timedelta
from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig

config = ConnectionConfig(
    domain="opensandbox.example.com",   # OpenSandbox Server address
    api_key="tenant-a-api-key",         # Per-tenant API key
)

async def main():
    sandbox = await Sandbox.create(
        "python:3.11",
        connection_config=config,
        timeout=timedelta(minutes=30),  # Default 10-minute TTL when omitted; None = no expiration
    )
    try:
        execution = await sandbox.commands.run("python -V")
        print(execution.logs.stdout[0].text)
    finally:
        await sandbox.destroy()         # kill() + close()

asyncio.run(main())
```

[Code 1] shows the basic lifecycle of creating a sandbox, running a shell command, and terminating it. Every sandbox has a lifetime (`timeout`) at creation time; omitting it applies the default 10-minute TTL, and passing `None` disables expiration. There are two termination methods that must be distinguished: `destroy()`, which terminates the remote sandbox as well, and `close()`, which only cleans up the client-side session. Here, the session means the HTTP connection pool that the `Sandbox` object maintains inside the client process — separately from the remote sandbox running in the cluster — for communicating with the server and the sandbox.

* **`destroy()`** : Terminates the remote sandbox (`kill()`) and then cleans up the client-side session as well. Suitable for workflows that create a sandbox, use it, and discard it right away.
* **`close()`** : Only closes the client-side session without sending any termination request to the remote sandbox. The sandbox therefore keeps running in the cluster and holding resources until its TTL expires.

```python {caption="[Code 2] Reattaching and Renewing"}
sandbox = await Sandbox.create("python:3.11", connection_config=config)
sandbox_id = sandbox.id

# Close only the client-side session — the remote sandbox keeps running
await sandbox.close()

# Reattach to the running sandbox by sandboxId (not resume)
sandbox = await Sandbox.connect(sandbox_id, connection_config=config)

# Extend lifetime: resets expiration to (now + duration)
await sandbox.renew(timedelta(minutes=30))

info = await sandbox.get_info()
print(info.status.state, info.expires_at)
```

[Code 2] shows closing only the client-side session and then reattaching to the still-running sandbox to extend its lifetime. Since the remote sandbox keeps running after `close()`, keeping just the `sandboxId` allows reattaching with `Sandbox.connect()` — from the same process or from a separate one. `Sandbox.connect()` is not a resume — it attaches to a running sandbox — and `renew()` resets the expiration relative to the current time.

```python {caption="[Code 3] Declaring Renew-on-Access"}
from opensandbox.models.sandboxes import SandboxLifecycle, RenewalPolicy

sandbox = await Sandbox.create(
    "python:3.11",
    connection_config=config,
    timeout=timedelta(hours=1),
    lifecycle=SandboxLifecycle(
        # Each observed access extends the expiration by 1 hour (now + 3600s)
        renewal_policy=RenewalPolicy(extend_seconds=3600),
    ),
)
```

[Code 3] shows declaring **Renew-on-Access**. Instead of calling `renew()` explicitly on every request, declaring a renewal policy at creation time automatically extends the expiration on every access observed by the gateway/proxy. This works only if the platform operator has enabled `[renew_intent]` in the OpenSandbox Server configuration (config.toml).

## 2. Code Execution and File Transfer

```python {caption="[Code 4] Code Execution and File Transfer"}
from opensandbox.models.filesystem import WriteEntry

# Upload files
await sandbox.files.write_files([
    WriteEntry(path="/workspace/main.py", data="print('hello')", mode=644),
])

# Run shell
execution = await sandbox.commands.run("cd /workspace && python main.py")

# Download a file
content = await sandbox.files.read_file("/workspace/result.json")
```

[Code 4] shows uploading a file, executing it through the shell, and downloading the resulting file. Code execution and file transfer are handled by `execd` injected into the sandbox pod as init, and are used in the SDK through the `commands` (shell) and `files` sub-objects of the `Sandbox` object. The `codes` feature, which runs code snippets directly through an interpreter without uploading a file, is provided by the separate Code Interpreter SDK that extends the Sandbox SDK.

## 3. Using Volumes

OpenSandbox provides a volume feature built on Kubernetes PVCs (PersistentVolumeClaims). It can be used in two modes: **persistent PVCs**, which preserve state beyond the sandbox's lifetime, and **ephemeral PVCs**, per-run temporary space cleaned up along with the sandbox.

### 3.1. Using Persistent PVCs

```python {caption="[Code 5] Volume-Based State Preservation"}
from opensandbox.models.sandboxes import Volume, PVC

def workspace_volume(user_id: str) -> Volume:
    return Volume(
        pvc=PVC(
            claimName=f"ws-{user_id}",          # Fixed name derived from the session
            createIfNotExists=True,             # Server provisions the PVC on first use
            deleteOnSandboxTermination=False,   # PVC survives the sandbox
            storage="20Gi",
        ),
        mountPath="/workspace",
    )

# First session: the server provisions the PVC on first use
sandbox = await Sandbox.create(
    "python:3.11",
    connection_config=config,
    volumes=[workspace_volume(user_id)],
)

# Going idle: terminate only the sandbox — the PVC remains
await sandbox.destroy()

# Next session: recreate with the same claimName — prior state is restored at /workspace
sandbox = await Sandbox.create(
    "python:3.11",
    connection_config=config,
    volumes=[workspace_volume(user_id)],
)
```

[Code 5] shows declaring a PVC with a fixed `claimName` derived from the session, terminating only the sandbox when going idle, and recreating it in the next session. For workloads with long idle periods, such as AI agent sessions, keeping a sandbox alive for the entire session wastes compute for the idle time. With a **persistent PVC**, you can terminate the sandbox when it goes idle while leaving the state in the PVC, releasing compute, and restore the state by recreating the sandbox when it is needed again.

The server provisions the PVC automatically in the first session, and recreating a sandbox with the same `claimName` in later sessions mounts the existing PVC, so the prior state is restored at `/workspace`. In other words, releasing compute and restoring state are achieved with just termination and recreation, without any dedicated resume API.

Two things deserve attention when using volumes. First, **state outside the mount path is not preserved.** Packages installed into system paths by `pip install` disappear on recreation, so in-sandbox work should be designed to keep venvs and artifacts under the PVC path (`/workspace`). Second, **the `sandboxId` changes on recreation.** The mapping between sessions and sandboxes must be managed by the caller (platform backend) keyed by `user_id ↔ claimName`. If preservation with a stable `sandboxId` is required, snapshot-based pause/resume is needed, which presumes a container image registry setup.

### 3.2. Using Ephemeral PVCs

```python {caption="[Code 6] Ephemeral Scratch Space"}
Volume(
    pvc=PVC(
        claimName=f"scratch-{run_id}",     # Unique per run (duplicate → 409)
        createIfNotExists=True,
        deleteOnSandboxTermination=True,   # Server deletes it on sandbox termination
        storage="5Gi",
    ),
    mountPath="/tmp/scratch",
)
```

[Code 6] shows declaring one-off scratch space as an **ephemeral PVC**. A sandbox's default writable space is the container layer, which has no capacity guarantee, and writing large amounts of data there pressures the node's disk and can cause evictions. So for work that produces large intermediate artifacts that do not need preservation — processing large datasets, builds — it is safer to declare an ephemeral PVC and get an independent volume with a guaranteed size per run. Here, ephemeral refers to the PVC's lifetime, not the storage medium — it does not use Kubernetes node-local ephemeral storage (emptyDir), but is a regular PVC that is deleted along with the sandbox's termination.

When the sandbox terminates, the server cleans up the PVC as well, so no separate cleanup is needed. An ephemeral PVC is exclusively owned by the sandbox that created it, so generate a unique `claimName` per run; another sandbox attempting to mount the same name is rejected with `409 CONFLICT`.

## 4. Egress Restriction

```python {caption="[Code 7] Egress Allowlist"}
from opensandbox.models.sandboxes import NetworkPolicy, NetworkRule

sandbox = await Sandbox.create(
    "python:3.11",
    connection_config=config,
    network_policy=NetworkPolicy(
        default_action="deny",
        egress=[
            # Allow only package installation paths
            NetworkRule(action="allow", target="pypi.org"),
            NetworkRule(action="allow", target="*.pythonhosted.org"),
            # Internal DB by IP/CIDR + port (requires dns+nft mode)
            NetworkRule(action="allow", target="10.0.20.0/24", ports=[5432]),
        ],
    ),
)
```

[Code 7] shows an allowlist declaration permitting only package installation paths and an internal database. Since code running in a sandbox cannot be trusted — such as exfiltration code produced by prompt injection — declare the baseline pattern at creation time: **deny all egress by default (default-deny) and allow only the required destinations through an allowlist**.

Rules are divided by the `target` value into **domain-based** (FQDNs, wildcard domains) and **IP-based** (IPs, CIDRs) rules, and since the two kinds are enforced by different components in different ways, their constraints differ as well. Domain rules are evaluated by the egress sidecar's DNS proxy at domain lookup time, where no port dimension exists, so combining them with `ports` is rejected with a validation error. IP/CIDR rules, on the other hand, are enforced by nftables at the packet level, so `ports` can restrict TCP destination ports — but they are actually applied only with the `[egress] mode = "dns+nft"` setting, which activates nftables alongside the DNS proxy. Beware that with the default `[egress] mode = "dns"` setting, IP/CIDR rules are not rejected but silently ignored.

## 5. Pause/Resume

```python {caption="[Code 8] Requesting Pause/Resume and Checking State"}
# Asynchronous request — does not become Paused immediately
await sandbox.pause()

while True:
    info = await sandbox.get_info()
    if info.status.state == "PAUSED":
        break
    await asyncio.sleep(2)

# Resume the paused sandbox (classmethod) — returns a new instance with the same sandboxId
sandbox = await Sandbox.resume(sandbox.id, connection_config=config)
```

[Code 8] shows requesting a pause, checking the state transition, and then resuming. Pause transitions a sandbox into an idle state to release its compute resources, and resume brings the paused sandbox back with the same `sandboxId`. Since `pause()` is an asynchronous request, the sandbox does not become Paused immediately, and the transition must be checked through `get_info()`.

The SDK's `pause()` / `resume()` are provided as the same API, but the actual behavior and availability depend on how the server is configured to run sandboxes. How a sandbox runs is determined by server configuration — the workload provider (batchsandbox, agent-sandbox), the container runtime (runc, gVisor), and whether Fast Sandbox is used — and the client cannot tell the difference from the API call alone. Client code using `pause()` must therefore be aware of the semantic differences per server configuration. The behavior per server configuration is as follows.

| Workload Provider | Container Runtime | Pause/Resume Behavior | Notes |
|---|---|---|---|
| batchsandbox | runc | Commits the rootfs to a registry, then removes the pod | Fails if no snapshot registry is configured on the controller |
| batchsandbox | gVisor | Rejected with `HTTP 409` | gVisor isolation and snapshots are incompatible |
| agent-sandbox | runc | Removes only the pod, preserving only PVC data | No registry required |
| Fast Sandbox | Firecracker MicroVM | Preserves memory as well | Automatic pause/wake without explicit calls via `IdlePolicy` (Fast Sandbox only) |

## 6. Sync API

```python {caption="[Code 9] Sync API Basic Lifecycle"}
from opensandbox import SandboxSync
from opensandbox.config import ConnectionConfigSync

config = ConnectionConfigSync(
    domain="opensandbox.example.com",
    api_key="tenant-a-api-key",
)

sandbox = SandboxSync.create("python:3.11", connection_config=config)
try:
    execution = sandbox.commands.run("python -V")
    print(execution.logs.stdout[0].text)
finally:
    sandbox.destroy()
```

```python {caption="[Code 10] Volume-Based State Preservation with the Sync API"}
sandbox = SandboxSync.create(
    "python:3.11",
    connection_config=config,
    volumes=[workspace_volume(user_id)],   # Same volume declaration as [Code 5]
)
try:
    sandbox.files.write_files([
        WriteEntry(path="/workspace/note.md", data="session state", mode=644),
    ])
finally:
    sandbox.destroy()                       # The PVC remains for the next session

# Reattaching to an existing sandbox works the same
sandbox = SandboxSync.connect(sandbox_id, connection_config=config)
```

[Code 9] shows the same basic lifecycle as [Code 1], and [Code 10] shows volume-based state preservation, both using the sync API. In scripts, Jupyter notebooks, or environments without an async runtime, use the sync API. The method surface is identical to the async API — use `SandboxSync` instead of `Sandbox` and `ConnectionConfigSync` instead of `ConnectionConfig`, and remove the `await`/`async` keywords. The volume declaration can be reused as-is from [Code 5].

## 7. References

* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/sdks/python.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/sdks/python.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md)
