# kubernetes-nvidia-device-plugin 문서 작업 컨텍스트

NVIDIA Device Plugin의 GPU 등록, 할당, Health Check와 Time-slicing, MPS, MIG 기반 GPU Sharing을 설명하는 문서.

## 문서 구성 및 상태

- **2026-11-07 1.4.3 `MIG_STRATEGY` 서술 수정** (사용자 요청): Resource 이름을 `nvidia.com/gpu-[Profile]`에서 `nvidia.com/mig-[Profile]`로 수정. 본문은 `mixed`만 설명하고 `none`, `single`은 언급하지 않음 (사용자 결정, 글 흐름 때문).
  참고: `none`(기본값)은 물리 GPU를 `nvidia.com/gpu`로 등록하고 Instance는 등록하지 않음. `single`은 Instance를 `nvidia.com/gpu`로 등록하며 Profile이 섞인 Node에서는 오류. 근거는 `internal/rm/device_map.go`의 `buildDeviceMapFromConfigResources`, `assertAllMigDevicesAreValid`, NVIDIA MIG Support in Kubernetes 문서, GPU Operator MIG 문서.
- **2026-11-07 Container당 Compute Instance 서술 수정** (사용자 요청, 문서 기반, 실측 없음): "반드시 동일 GPU Instance에서 동작해야 한다"는 근거를 찾지 못해 CUDA 제약으로 교체. R570 이상은 CUDA Process가 GPU Instance당 Compute Instance 1개, R570 미만은 MIG Device 1개 (NVIDIA MIG Device Names 문서). Device Plugin 할당 코드에는 GPU Instance 비교가 없음.
- **`nvidia.com/mig-2g.10gb` 2개 서술 유지** (사용자 결정): [Figure 7]과 본문은 사용자의 테스트 결과 기준으로 유지. 아래 버전별 동작 참고.

## MIG `1c.2g.10gb` 구성의 버전별 동작

[Figure 7]의 `2g.10gb` GPU Instance + `1c.2g.10gb` Compute Instance 2개 (1:2 구성)를 `mixed`로 등록할 때의 동작. 소스 기반이며 Device Plugin 실측 출력은 Repo에 없음.

| Device Plugin | 패턴 매칭 | `2g.10gb` 규칙과 `1c.2g.10gb` | 예상 결과 |
|---|---|---|---|
| v0.19.3 이하 | Anchor 없음, 문자열 일부 일치 | 일치 | `nvidia.com/mig-2g.10gb: 2` |
| v0.20.0 이상 (2026-08-19) | `^...$`, 전체 일치 | 불일치 | `does not match any resource patterns` 오류로 Device Map 생성 실패 |

- 패턴 매칭 확인 Tag: v0.14.5, v0.17.4, v0.18.2, v0.19.0, v0.19.3은 Anchor 없음, v0.20.0, v0.20.1은 Anchor 있음.
- 변경 원인: PR #1807 (Issue #1462). `1g.24gb`와 `1g.24gb-me`가 합쳐지는 문제를 고치기 위한 수정이며 PR 설명과 테스트에 `1c.` Profile은 없음. `1c.` 구성에 미친 영향은 의도하지 않은 부작용으로 추정.
- 공통 코드: `internal/rm/rm.go`의 `info.C != info.G` 조건으로 `1c.` Profile의 규칙은 만들어지지 않음 (v0.14.5 ~ v0.20.1). 패턴 매칭은 `api/config/v1/resources.go`의 `wildCardToRegexp`, 오류는 `internal/rm/device_map.go`의 `buildMigDeviceMap`.
- `resources` 설정은 `DisableResourceNamingInConfig`로 무시되어 사용자 설정으로 규칙을 추가할 수 없음 (현재 소스 기준).
- 설계 배경: NVIDIA 설계 문서는 Compute Instance끼리 Memory와 GPU Engine을 공유하므로 Container에 나눠 주는 것이 맞지 않다고 판단해 GPU Instance와 Compute Instance를 1:1로 정의하고, Container당 MIG Device 1개 요청을 전제함. [Figure 7]의 Container B (2개 요청)도 이 전제와 다름.
  - Challenges Supporting MIG in Kubernetes : https://drive.google.com/open?id=1Dxx5MwG_GiBeKOuMNwv4QbO8OqA7XFdzn7fzzI7AQDg
  - Supporting Multi-Instance GPUs (MIG) in Kubernetes : https://docs.google.com/document/d/1mdgMQ8g7WmaI_XVVRrCvHPFPOMCm5LQD5JefgAh6N8g

## Test 수행 상태

- A100 `nvidia-smi` 수준의 MIG 구성 실측은 `nvidia-gpu-sharing` 글의 [Shell 4], [Shell 5], [Shell 7]에 있음 ([Figure 7]의 Host 구성, `nvidia-cap` 번호와 일치).
- Device Plugin 등록 테스트는 사용자 기억 기준으로 수행했으나 사용 버전과 출력 기록은 없음. 글 작성 시기(2026-03)의 Release는 v0.19.x 이하.
- v0.20.0 이상의 1:2 구성 동작은 미실측. Device Plugin 버전을 올려 재테스트하면 본문과 [Figure 7]의 수정 여부를 다시 판단할 것.
