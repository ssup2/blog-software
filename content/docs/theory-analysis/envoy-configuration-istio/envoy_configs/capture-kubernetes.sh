#!/usr/bin/env bash
# 1.2 (Kubernetes Resources) 실험 캡처 스크립트.
# manifests/kubernetes/의 각 실험 리소스를 순서대로 적용/캡처/삭제하며,
# 정규화된 proxy-config dump를 envoy_configs/kubernetes/<실험이름>/client.yaml 로 저장한다.
# EDS 관찰이 필요한 실험은 raw dump의 EndpointsConfigDump 섹션을 client-eds*.yaml 로 함께 저장한다.
# 주의:
# - service-new-port와 service-protocol-tcp는 같은 Service 인스턴스에서 연속 캡처해야
#   ClusterIP/Pod IP가 일치한다 (재생성하면 IP가 달라져 diff에 IP 노이즈가 섞인다).
# - 2026-09-24 기준 클러스터에는 문서 환경 외 잉여 Workload(httpbin, mock-server, shell 등)가
#   상주하므로, diff는 구 base/가 아니라 같은 시점의 kubernetes/base/와 떠야 한다.
set -euo pipefail

CTX=kind-kind
DOC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAN="$DOC_DIR/manifests/kubernetes"
OUT="$DOC_DIR/envoy_configs/kubernetes"
K="kubectl --context $CTX"
PUSH_WAIT=6
DRAIN_WAIT=75   # Listener 교체/삭제 실험은 구 Listener의 drain이 끝난 뒤 캡처/복귀 확인

log() { echo "[$(date +%H:%M:%S)] $*"; }

normalize() {
  awk '/envoy.admin.v3.EndpointsConfigDump/{skip=1;next} skip && /^- .@type.:/{skip=0} !skip' \
    | grep -v '^[[:space:]]*last_updated:' \
    | grep -vE '^[[:space:]]*-[[:space:]]+last_updated:' \
    | grep -v '^[[:space:]]*version_info:'
}

eds_section() { # raw dump에서 EndpointsConfigDump 섹션만 추출
  awk '/envoy.admin.v3.EndpointsConfigDump/{f=1} f && /^- .@type.:/ && $0 !~ /EndpointsConfigDump/{f=0} f'
}

cap() { # <outfile>
  mkdir -p "$(dirname "$1")"
  istioctl --context "$CTX" proxy-config all client -n default -o yaml | normalize > "$1"
  log "captured $1 ($(wc -l < "$1" | tr -d ' ') lines)"
}

cap_eds() { # <outfile>
  mkdir -p "$(dirname "$1")"
  istioctl --context "$CTX" proxy-config all client -n default -o yaml | eds_section > "$1"
  log "captured $1 ($(wc -l < "$1" | tr -d ' ') lines)"
}

verify_clean() { # 실험 사이에서 client 설정이 baseline으로 복귀했는지 확인
  for i in 1 2 3; do
    istioctl --context "$CTX" proxy-config all client -n default -o yaml | normalize > /tmp/k8s-exp-check.yaml
    if diff -q "$OUT/base/client.yaml" /tmp/k8s-exp-check.yaml > /dev/null; then
      log "baseline restored (self-diff 0)"
      return 0
    fi
    log "baseline not restored yet, waiting 30s (try $i)"
    sleep 30
  done
  log "WARNING: baseline not restored, continuing anyway"
  diff "$OUT/base/client.yaml" /tmp/k8s-exp-check.yaml | head -20 || true
}

# 1. baseline 캡처 + self-diff 검증
log "=== baseline ==="
cap "$OUT/base/client.yaml"
istioctl --context "$CTX" proxy-config all client -n default -o yaml | normalize > /tmp/k8s-exp-selfcheck.yaml
if diff -q "$OUT/base/client.yaml" /tmp/k8s-exp-selfcheck.yaml > /dev/null; then
  log "self-diff OK (0 lines)"
else
  log "WARNING: self-diff not clean"
  diff "$OUT/base/client.yaml" /tmp/k8s-exp-selfcheck.yaml | head -20 || true
fi

# 2. service-new-port: server-d Pod + 7070 Port Service (dump + EDS)
log "=== service-new-port (client) ==="
$K apply -f "$MAN/service-new-port/service-new-port.yaml"
$K wait --for=condition=Ready pod/server-d --timeout=120s
sleep $PUSH_WAIT
RAW=$(mktemp)
istioctl --context "$CTX" proxy-config all client -n default -o yaml > "$RAW"
normalize < "$RAW" > "$OUT/service-new-port/client.yaml"
eds_section < "$RAW" > "$OUT/service-new-port/client-eds.yaml"
rm -f "$RAW"
log "captured service-new-port dump + eds"

# 3. service-protocol-tcp: 같은 Service의 Port 이름만 http -> tcp (2번 상태 위에 적용,
#    구 0.0.0.0_7070 Listener의 drain이 끝난 뒤 캡처)
log "=== service-protocol-tcp (client) ==="
$K apply -f "$MAN/service-protocol-tcp/service-protocol-tcp.yaml"
sleep $DRAIN_WAIT
cap "$OUT/service-protocol-tcp/client.yaml"
$K delete -f "$MAN/service-new-port/service-new-port.yaml"
sleep $DRAIN_WAIT
verify_clean

# 4. service-shared-port: server-d Pod + 기존 8080 Port를 공유하는 Service
log "=== service-shared-port (client) ==="
$K apply -f "$MAN/service-shared-port/service-shared-port.yaml"
$K wait --for=condition=Ready pod/server-d --timeout=120s
sleep $PUSH_WAIT
cap "$OUT/service-shared-port/client.yaml"
$K delete -f "$MAN/service-shared-port/service-shared-port.yaml"
sleep $DRAIN_WAIT
verify_clean

# 5. pod-endpoint: server-a-2 Pod 추가 -> EDS만 변화 (before/after EDS + 무변화 검증)
log "=== pod-endpoint (client) ==="
cap_eds "$OUT/pod-endpoint/client-eds-before.yaml"
$K apply -f "$MAN/pod-endpoint/pod-endpoint.yaml"
$K wait --for=condition=Ready pod/server-a-2 --timeout=120s
sleep $PUSH_WAIT
cap_eds "$OUT/pod-endpoint/client-eds-after.yaml"
cap "$OUT/pod-endpoint/client.yaml"   # LDS/RDS/CDS 무변화 검증용
if diff -q "$OUT/base/client.yaml" "$OUT/pod-endpoint/client.yaml" > /dev/null; then
  log "pod-endpoint: LDS/RDS/CDS diff 0 confirmed"
else
  log "WARNING: pod-endpoint has non-EDS changes"
  diff "$OUT/base/client.yaml" "$OUT/pod-endpoint/client.yaml" | head -20 || true
fi
$K delete -f "$MAN/pod-endpoint/pod-endpoint.yaml"
sleep 15

# 6. service-headless: server-d Pod + Headless Service (8080 Port)
log "=== service-headless (client) ==="
$K apply -f "$MAN/service-headless/service-headless.yaml"
$K wait --for=condition=Ready pod/server-d --timeout=120s
sleep $PUSH_WAIT
cap "$OUT/service-headless/client.yaml"
$K delete -f "$MAN/service-headless/service-headless.yaml"
sleep $DRAIN_WAIT
verify_clean

log "done"
