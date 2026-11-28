---
title: Python OpenSandbox SDK
draft: true
---

Python OpenSandbox SDK의 이용 방법을 정리한다. API Reference의 나열보다는 Sandbox를 실제 서비스에서 이용할 때 반복되는 패턴을 중심으로 정리한다. 예제는 SDK의 기본 표면인 Async API를 기준으로 한다. 분석 기준 Version은 v1.2.1이다.

## 1. Lifecycle 및 연결 관리

SDK는 단독으로 동작하지 않으며, 모든 요청을 **OpenSandbox Server**의 REST API로 전달하는 Client로 동작한다. 따라서 SDK를 이용하려면 먼저 `ConnectionConfig`를 통해서 OpenSandbox Server의 주소와 **API Key**를 설정해야 한다. **Single-Tenant** 구성에서는 Server 전체가 하나의 API Key를 공유하기 때문에 모든 호출자가 동일한 공간에 Sandbox를 생성한다. 반면 **Multi-Tenant** 구성에서는 Tenant마다 별도의 API Key가 발급되며, 이용하는 Key에 따라서 Sandbox가 생성되는 Namespace와 소유자가 분리되기 때문에 하나의 Server를 다수의 팀이나 서비스가 격리된 채 공유할 수 있다.

```python {caption="[Code 1] 기본 Lifecycle과 연결 관리"}
import asyncio
from datetime import timedelta
from opensandbox.sandbox import Sandbox
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

[Code 1]은 Sandbox를 생성하고 Shell 명령을 실행한 후 종료하는 기본 Lifecycle을 나타내고 있다. 모든 Sandbox는 생성 시점에 수명(`timeout`)을 가지며, 생략하면 기본 10분 TTL이 적용되고 `None`을 명시하면 만료되지 않는다. 종료 방식은 원격 Sandbox까지 함께 종료하는 `destroy()`와 Client 측 Session만 정리하는 `close()` 두 가지가 있으며, 구분해서 이용해야 한다. 여기서 Session은 `Sandbox` 객체가 Cluster에서 동작하는 원격 Sandbox와 별개로, Server 및 Sandbox와 통신하기 위해서 Client Process 안에 유지하는 HTTP Connection Pool을 의미한다.

* **`destroy()`** : 원격 Sandbox를 종료(`kill()`)한 후 Client 측 Session까지 함께 정리한다. Sandbox를 생성하고 사용한 후 바로 폐기하는 Workflow에 적합하다.
* **`close()`** : Client 측 Session만 닫을 뿐 원격 Sandbox에는 종료 요청이 전달되지 않는다. 따라서 Sandbox는 TTL이 만료될 때까지 Cluster에서 계속 동작하며 Resource를 점유한다.

```python {caption="[Code 2] 기존 Sandbox 재접속과 수명 연장"}
sandbox = await Sandbox.create("python:3.11", connection_config=config)
sandbox_id = sandbox.sandbox_id

# Close only the client-side session — the remote sandbox keeps running
await sandbox.close()

# Reattach to the running sandbox by sandboxId (not resume)
sandbox = await Sandbox.connect(sandbox_id, connection_config=config)

# Extend lifetime: resets expiration to (now + duration)
await sandbox.renew(timedelta(minutes=30))

info = await sandbox.get_info()
print(info.status.state, info.expires_at)
```

[Code 2]는 Client 측 Session만 닫은 후 동작 중인 Sandbox에 다시 접속하여 수명을 연장하는 과정을 나타내고 있다. `close()` 이후에도 원격 Sandbox는 계속 동작하기 때문에, `sandboxId`만 보관하고 있으면 동일 Process는 물론 분리된 다른 Process에서도 `Sandbox.connect()`로 다시 접속할 수 있다. `Sandbox.connect()`는 Resume이 아니라 실행 중인 Sandbox에 Attach하는 동작이며, `renew()`는 만료 시각을 현재 시각 기준으로 재설정한다.

```python {caption="[Code 3] Renew-on-Access 선언"}
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

[Code 3]은 **Renew-on-Access**를 선언하는 과정을 나타내고 있다. 매 요청마다 명시적으로 `renew()`를 호출하는 대신 생성 시점에 Renewal Policy를 선언하면, Gateway/Proxy가 관측한 접근마다 만료 시각이 자동으로 연장된다. Platform 운영자가 OpenSandbox Server 설정(config.toml)에 `[renew_intent]`를 활성화해둔 경우에만 동작한다.

## 2. Code 실행과 File 송수신

```python {caption="[Code 4] Code 실행과 File 송수신"}
from opensandbox.models.filesystem import WriteEntry

# Upload files
await sandbox.files.write_files([
    WriteEntry(path="/workspace/main.py", data="print('hello')", mode=644),
])

# Run shell
execution = await sandbox.commands.run("cd /workspace && python main.py")

# Run a code snippet directly without uploading a file
execution = await sandbox.codes.run("print('inline snippet')")

# Download a file
content = await sandbox.files.read_file("/workspace/result.json")
```

[Code 4]는 File을 업로드하고 Shell로 실행한 후 결과 File을 다운로드하는 과정과, File 업로드 없이 Code Snippet을 직접 실행하는 과정을 나타내고 있다. Code 실행과 File 송수신은 Sandbox Pod에 Init으로 주입된 `execd`가 처리하며, SDK에서는 `Sandbox` 객체의 `commands`(Shell), `codes`(Code Snippet), `files` 하위 객체를 통해서 이용한다.

## 3. Volume 이용

OpenSandbox는 Kubernetes PVC(PersistentVolumeClaim)를 기반으로 하는 Volume 기능을 제공한다. Sandbox의 수명을 넘어서 상태를 보존하는 **Persistent PVC**와, Sandbox 종료와 함께 정리되는 실행 단위 임시 공간인 **Ephemeral PVC** 두 가지 Mode로 이용할 수 있다.

### 3.1. Persistent PVC 이용

```python {caption="[Code 5] Volume 기반 상태 보존"}
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

[Code 5]는 Session 식별자 기반의 고정된 `claimName`으로 PVC를 선언하고, 유휴 진입시 Sandbox만 종료한 후 다음 Session에서 재생성하는 과정을 나타내고 있다. AI Agent Session처럼 유휴 구간이 긴 Workload에서 Sandbox를 Session 내내 유지하면 유휴 시간만큼 Compute 비용이 낭비된다. **Persistent PVC**를 이용하면 상태는 PVC에 남겨둔 채 유휴 시점에 Sandbox를 종료하여 Compute를 반납하고, 다시 필요할 때 Sandbox를 재생성하여 상태를 복원할 수 있다.

최초 Session에서 Server가 PVC를 자동으로 생성하며, 이후 Session에서 동일한 `claimName`으로 Sandbox를 다시 생성하면 새 Sandbox가 기존 PVC를 Mount하기 때문에 이전 상태가 `/workspace`에 그대로 복원된다. 즉 별도의 재개 API 없이 종료와 재생성만으로 Compute 반납과 상태 복원이 이루어진다.

Volume을 이용할 경우 유의할 점은 두 가지이다. 첫째, **Mount 경로 밖의 상태는 보존되지 않는다.** `pip install`로 System 경로에 설치한 Package는 재생성시 사라지기 때문에, venv와 작업물을 PVC 경로(`/workspace`) 아래에 두도록 Sandbox 내부 작업을 설계해야 한다. 둘째, **`sandboxId`는 재생성시 변경된다.** Session과 Sandbox의 매핑은 호출 측(Platform Backend)이 `user_id ↔ claimName` 기준으로 관리해야 한다. `sandboxId`를 유지한 채 보존이 필요하면 Snapshot 기반 Pause/Resume이 필요하며, 이는 Container Image Registry 구성을 전제로 한다.

### 3.2. Ephemeral PVC 이용

```python {caption="[Code 6] Ephemeral Scratch 공간"}
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

[Code 6]은 일회성 Scratch 공간을 **Ephemeral PVC**로 선언하는 과정을 나타내고 있다. Sandbox의 기본 쓰기 공간은 Container Layer이기 때문에 용량이 보장되지 않으며, 대용량 데이터를 쓰면 Node의 Disk를 압박하여 Eviction의 원인이 된다. 따라서 대용량 Dataset 가공이나 Build처럼 보존할 필요는 없지만 큰 중간 산출물이 생기는 작업에서는, Ephemeral PVC를 선언하여 실행 단위로 크기가 보장된 독립 Volume을 할당받는 것이 안전하다. 여기서 Ephemeral은 저장 매체가 아니라 PVC의 수명을 의미한다. Kubernetes의 Node-Local Ephemeral Storage(emptyDir)를 이용하는 것이 아니라, Sandbox 종료와 함께 삭제되는 일반 PVC이다.

Sandbox가 종료되면 Server가 PVC까지 정리하기 때문에 별도의 뒷정리도 필요 없다. Ephemeral PVC는 생성한 Sandbox가 배타적으로 소유하기 때문에 `claimName`을 실행 단위로 고유하게 생성해야 하며, 다른 Sandbox가 동일한 이름을 Mount하려고 하면 `409 CONFLICT`로 거부된다.

## 4. Egress 제한

```python {caption="[Code 7] Egress Allowlist"}
from opensandbox.api.egress.models import NetworkPolicy, NetworkRule

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

[Code 7]은 Package 설치 경로와 내부 DB만 허용하는 Allowlist 선언을 나타내고 있다. Prompt Injection으로 생성된 유출 Code처럼 Sandbox에서 실행되는 Code는 신뢰할 수 없기 때문에, Sandbox 생성시 **모든 Egress를 기본적으로 거부(Default-Deny)하고 필요한 목적지만 Allowlist로 허용**하는 것을 기본 패턴으로 선언한다.

Rule은 `target` 값에 따라서 **Domain 기반**(FQDN, Wildcard Domain)과 **IP 기반**(IP, CIDR)으로 나뉘며, 두 종류는 Rule을 수행하는 주체와 방식이 다르기 때문에 제약도 다르다. Domain Rule은 Egress Sidecar의 DNS Proxy가 Domain 조회 시점에 평가하기 때문에 Port라는 차원이 존재하지 않으며, `ports`와 조합하면 Validation Error로 거부된다. 반면 IP/CIDR Rule은 nftables가 Packet 수준에서 수행하기 때문에 `ports`로 TCP 목적지 Port까지 제한할 수 있지만, nftables가 함께 활성화되는 `[egress] mode = "dns+nft"` 설정에서만 실제로 적용된다. 기본값인 `[egress] mode = "dns"` 설정에서는 IP/CIDR Rule이 거부되지 않고 조용히 무시되기 때문에 주의가 필요하다.

## 5. Pause/Resume 이용시 주의

SDK의 `pause()` / `resume()`은 모든 실행 경로에서 동일한 API로 제공되지만, 동작과 가용성은 Server의 실행 경로 구성에 따라서 달라진다.

```python {caption="[Code 8] Pause 요청과 상태 확인"}
await sandbox.pause()     # Asynchronous request — does not become Paused immediately

while True:
    info = await sandbox.get_info()
    if info.status.state == "Paused":
        break
    await asyncio.sleep(2)
```

[Code 8]은 Pause를 요청하고 상태 전환을 확인하는 과정을 나타내고 있다. `pause()`는 비동기 요청이기 때문에 즉시 Paused 상태가 되지 않으며, `get_info()`를 통해서 상태 전환을 확인해야 한다. 실행 경로별 동작 차이는 다음과 같다.

* **BatchSandbox + runc** : Rootfs가 Registry에 Commit된다. Controller에 Snapshot Registry가 설정되어 있지 않으면 실패한다.
* **BatchSandbox + gVisor** : Server가 `HTTP 409`로 거부한다. gVisor 격리와 Snapshot은 양립하지 않는다.
* **agent-sandbox Provider** : Pod만 제거되고 PVC 데이터만 보존된다. Registry가 필요없다.
* **Fast Sandbox** : Memory까지 보존되며, `IdlePolicy`를 선언하면 호출 없이 자동 Pause/Wake가 동작한다 (Fast Sandbox 전용).

따라서 `pause()`를 이용하는 Client Code는 실행 경로별 의미 차이를 알고 있어야 하며, Snapshot 인프라가 구성되지 않은 환경에서는 Volume 기반 상태 보존이 현실적인 대안이다.

## 6. Sync API

Script, Jupyter Notebook, 또는 Async Runtime이 없는 환경에서는 Sync API를 이용한다. Async API와 Method 구성이 동일하며, `Sandbox` 대신 `SandboxSync`를, `ConnectionConfig` 대신 `ConnectionConfigSync`를 이용하고 `await`/`async` 키워드만 제거하면 된다.

```python {caption="[Code 9] Sync API 기본 Lifecycle"}
from opensandbox.sandbox import SandboxSync
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

[Code 9]는 [Code 1]과 동일한 기본 Lifecycle을 Sync API로 이용하는 과정을 나타내고 있다.

```python {caption="[Code 10] Sync API Volume 기반 상태 보존"}
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

[Code 10]은 Volume 기반 상태 보존을 Sync API로 이용하는 과정을 나타내고 있다. Volume 선언은 [Code 5]와 동일하게 재사용할 수 있다.

## 7. 참조

* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/sdks/python.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/sdks/python.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md)
