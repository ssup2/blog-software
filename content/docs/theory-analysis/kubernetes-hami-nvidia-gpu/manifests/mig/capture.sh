#!/usr/bin/env bash
# HAMi Dynamic MIG Test의 단계별 상태·로그 수집 Script
#
# 사용법:
#   KUBE_CONTEXT=<alpha-kr-dev EKS context> ./capture.sh <step-label>
#   예) ./capture.sh step1-config8
#       ./capture.sh step2-config9
#
# 수집 결과는 글 폴더의 dumps/mig/<step-label>/ 아래에 저장된다.
set -euo pipefail

STEP=${1:?usage: ./capture.sh <step-label>}
CTX=${KUBE_CONTEXT:?"KUBE_CONTEXT 환경 변수에 kubectl context 이름을 지정하세요"}
NS=addon-hami
TEST_PODS="mig-2g-a mig-2g-b mig-3g mig-1g-a mig-1g-b"

DIR="$(cd "$(dirname "$0")/../.." && pwd)/dumps/mig/${STEP}"
mkdir -p "$DIR"
K="kubectl --context ${CTX}"

echo "# capture -> ${DIR}"

# HAMi Component 상태와 Log
$K get pods -n $NS -o wide > "$DIR/hami-pods.txt"
for p in $($K get pods -n $NS -l app.kubernetes.io/component=hami-device-plugin -o name); do
  name=$(basename "$p")
  $K logs -n $NS "$p" -c device-plugin > "$DIR/${name}-device-plugin.log" 2>&1 || true
  $K logs -n $NS "$p" -c vgpu-monitor  > "$DIR/${name}-vgpu-monitor.log"  2>&1 || true
done
for p in $($K get pods -n $NS -l app.kubernetes.io/component=hami-scheduler -o name); do
  name=$(basename "$p")
  $K logs -n $NS "$p" -c vgpu-scheduler-extender > "$DIR/${name}-extender.log"       2>&1 || true
  $K logs -n $NS "$p" -c kube-scheduler          > "$DIR/${name}-kube-scheduler.log" 2>&1 || true
done

# MIG Node 상태 (hami.io/node-nvidia-register Annotation 포함)
$K get nodes -l group=gpu-a100-hami -o yaml > "$DIR/nodes-gpu-a100-hami.yaml" 2>&1 || true

# Test Pod의 HAMi Annotation과 Container 안의 MIG Device 확인
for tp in $TEST_PODS; do
  $K get pod "$tp" -o yaml > "$DIR/pod-${tp}.yaml" 2>/dev/null || continue
  $K exec "$tp" -- nvidia-smi -L > "$DIR/nvidia-smi-L-${tp}.txt" 2>&1 || true
  $K exec "$tp" -- nvidia-smi    > "$DIR/nvidia-smi-${tp}.txt"   2>&1 || true
done

echo "# done"
ls -la "$DIR"
