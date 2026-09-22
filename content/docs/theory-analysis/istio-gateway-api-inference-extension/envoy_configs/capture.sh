#!/usr/bin/env bash
# envoy_configs 캡처 스크립트.
# Gateway Envoy의 config_dump(admin :15000)와 Inference Extension 관련 핵심 발췌,
# Model Server의 /metrics 출력을 envoy_configs/ 아래에 저장한다.
# 실험 환경: kind-istio-gateway-api Cluster에 manifests/가 전부 적용된 상태
# (gateway-namespace의 gateway-istio, llm-namespace의 vllm-llama3-8b + EPP + InferencePool + HTTPRoute).
# 주의: Shadow Service 이름의 Hash와 Pod 이름은 재생성 시 달라진다 (CLAUDE.md 참조).
set -euo pipefail

CTX=kind-istio-gateway-api
DOC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DOC_DIR/envoy_configs"
K="kubectl --context $CTX"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# 1. Gateway Envoy config_dump 전체
mkdir -p "$OUT/gateway-istio" "$OUT/model-server"
$K -n gateway-namespace exec deploy/gateway-istio -- curl -s localhost:15000/config_dump > /tmp/cfgdump.json
jq . /tmp/cfgdump.json > "$OUT/gateway-istio/config_dump.json"
log "captured config_dump.json ($(wc -c < "$OUT/gateway-istio/config_dump.json" | tr -d ' ') bytes)"

# 2. 핵심 발췌
# Listener의 ext_proc Filter (metadata_options로 envoy.lb Metadata 수신 — 기본은 dummy cluster + SKIP으로 비활성)
jq '[.. | objects | select((.name? // "")=="envoy.filters.http.ext_proc" and (.typed_config.metadata_options? != null))] | .[0]' \
  /tmp/cfgdump.json > "$OUT/gateway-istio/ext-proc-listener-filter.json"
# InferencePool을 참조하는 Route (per-route ext-proc override, 본문 [Shell 5] 원본)
jq '[.. | objects | select((.name? // "")=="llm-namespace.llm-route.0")] | .[0]' \
  /tmp/cfgdump.json > "$OUT/gateway-istio/route-llm-route.json"
# Shadow Service Cluster (override_host LB Policy, 본문 [Shell 8] 원본)
jq '[.. | objects | select(.cluster? and ((.cluster.name? // "") | contains("vllm-llama3-8b-ip")))] | .[0].cluster' \
  /tmp/cfgdump.json > "$OUT/gateway-istio/cluster-shadow-service.json"
# EPP Cluster (DestinationRule의 TLS 설정 반영)
jq '[.. | objects | select(.cluster? and ((.cluster.name? // "") | contains("vllm-llama3-8b-epp")))] | .[0].cluster' \
  /tmp/cfgdump.json > "$OUT/gateway-istio/cluster-epp.json"
log "captured excerpts (ext-proc filter, route, shadow/epp clusters)"

# 3. Model Server /metrics (본문 [Shell 7] 원본)
POD=$($K -n llm-namespace get pods -l app=vllm-llama3-8b -o jsonpath='{.items[0].metadata.name}')
$K -n llm-namespace port-forward "pod/$POD" 18000:8000 >/dev/null 2>&1 &
PF=$!
sleep 3
curl -s http://127.0.0.1:18000/metrics > "$OUT/model-server/metrics.txt"
kill $PF 2>/dev/null
log "captured model-server/metrics.txt from $POD"

log "done"
