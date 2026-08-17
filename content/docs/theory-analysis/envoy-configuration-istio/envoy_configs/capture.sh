#!/usr/bin/env bash
# envoy_configs 캡처 스크립트.
# manifests/의 각 CR을 순서대로 적용/캡처/삭제하며, 정규화된 proxy-config dump를
# envoy_configs/<cr이름>/<pod>.yaml 로 저장한다.
# 실험 환경: manifests/base/의 server-a, server-b, server-c, client Pod가
# default Namespace(istio-injection=enabled)에 상주해야 한다.
set -euo pipefail

CTX=kind-kind
DOC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAN="$DOC_DIR/manifests"
OUT="$DOC_DIR/envoy_configs"
K="kubectl --context $CTX"
DRAIN_WAIT=45   # CR 삭제 후 구 Listener drain 대기 (CLAUDE.md 방법론 5번)
PUSH_WAIT=6     # CR 적용 후 istiod push 대기

log() { echo "[$(date +%H:%M:%S)] $*"; }

normalize() {
  awk '/envoy.admin.v3.EndpointsConfigDump/{skip=1;next} skip && /^- .@type.:/{skip=0} !skip' \
    | grep -v '^[[:space:]]*last_updated:' \
    | grep -vE '^[[:space:]]*-[[:space:]]+last_updated:' \
    | grep -v '^[[:space:]]*version_info:'
}

cap() { # <pod> <namespace> <outfile>
  mkdir -p "$(dirname "$3")"
  istioctl --context "$CTX" proxy-config all "$1" -n "$2" -o yaml | normalize > "$3"
  log "captured $3 ($(wc -l < "$3" | tr -d ' ') lines)"
}

GW_POD=$($K -n istio-system get pods -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
log "ingressgateway pod: $GW_POD"

# 1. baseline 캡처 + self-diff 검증
cap client default "$OUT/base/client.yaml"
cap client default /tmp/envoy-configs-selfcheck.yaml
if diff -q "$OUT/base/client.yaml" /tmp/envoy-configs-selfcheck.yaml > /dev/null; then
  log "self-diff OK (0 lines)"
else
  log "WARNING: self-diff not clean"
  diff "$OUT/base/client.yaml" /tmp/envoy-configs-selfcheck.yaml | head -20 || true
fi
cap server-a default "$OUT/base/server-a.yaml"
cap server-b default "$OUT/base/server-b.yaml"
cap server-c default "$OUT/base/server-c.yaml"
cap "$GW_POD" istio-system "$OUT/base/istio-ingressgateway.yaml"

# 2. client Pod 관찰 대상 CR (outbound)
for cr in virtualservice destinationrule serviceentry sidecar workloadentry workloadgroup proxyconfig; do
  f="$MAN/$cr/$cr.yaml"
  log "=== $cr (client) ==="
  $K apply -f "$f"
  sleep $PUSH_WAIT
  cap client default "$OUT/$cr/client.yaml"
  $K delete -f "$f"
  sleep $DRAIN_WAIT
done

# 3. server-a Pod 관찰 대상 CR (inbound)
for cr in envoyfilter peerauthentication requestauthentication authorizationpolicy; do
  f="$MAN/$cr/$cr.yaml"
  log "=== $cr (server-a) ==="
  $K apply -f "$f"
  sleep $PUSH_WAIT
  cap server-a default "$OUT/$cr/server-a.yaml"
  $K delete -f "$f"
  sleep $DRAIN_WAIT
done

# 3-1. telemetry: otel provider 대상 dummy Service 필요 (meshConfig extensionProviders 참조)
log "=== telemetry (server-a) ==="
$K create ns observability
$K -n observability create service clusterip opentelemetry-collector --tcp=4317:4317
sleep 5
$K apply -f "$MAN/telemetry/telemetry.yaml"
sleep $PUSH_WAIT
cap server-a default "$OUT/telemetry/server-a.yaml"
$K delete -f "$MAN/telemetry/telemetry.yaml"
$K delete ns observability
sleep $DRAIN_WAIT

# 3-2. wasmplugin: pilot-agent의 OCI 모듈 다운로드 시간 필요
log "=== wasmplugin (server-a) ==="
$K apply -f "$MAN/wasmplugin/wasmplugin.yaml"
sleep 20
cap server-a default "$OUT/wasmplugin/server-a.yaml"
$K delete -f "$MAN/wasmplugin/wasmplugin.yaml"
sleep $DRAIN_WAIT

# 4. Gateway 실험 (istio-ingressgateway Pod 관찰)
log "=== gateway (istio-ingressgateway) ==="
$K apply -f "$MAN/gateway/gateway.yaml"
sleep $PUSH_WAIT
cap "$GW_POD" istio-system "$OUT/gateway/istio-ingressgateway.yaml"

# 4-1. Gateway-bound VirtualService: Gateway 적용 상태 위에 캡처
log "=== virtualservice-gateway (istio-ingressgateway) ==="
$K apply -f "$MAN/virtualservice/virtualservice-gateway.yaml"
sleep $PUSH_WAIT
cap "$GW_POD" istio-system "$OUT/virtualservice/virtualservice-gateway_istio-ingressgateway.yaml"
$K delete -f "$MAN/virtualservice/virtualservice-gateway.yaml"
$K delete -f "$MAN/gateway/gateway.yaml"
sleep 10

log "done"
