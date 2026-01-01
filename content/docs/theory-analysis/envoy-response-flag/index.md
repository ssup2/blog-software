---
title: "Envoy Response Flag"
---

Enovy의 Response Flag를 정리한다.

## 1. Envoy Response Flag

Envoy Response Flag는 Envoy가 요청을 처리하는 과정에서 **특정 Event 또는 Error**가 발생했을때 Access Log에 관련 정보를 나타내기 위해서 사용되는 Flag를 의미한다. **Long Name**과 **Short Name**이 존재하며, Envoy Access Log에는 Short Name이 기록된다. Response Flag는 **HTTP, TCP와 혼용**되는 Flag와, **HTTP에서만 적용**되는 Flag로 구분된다.

### 1.1. HTTP, TCP Flag

{{< table caption="[Table 1] Envoy HTTP, TCP Flag" >}}
| Long Name | Short Name | Description |
|---|---|---|
| NoHealthyUpstream          | UH  | Envoy Server는 Upstream Cluster에 Healthy 상태의 Upstream Server가 존재하지 않아 Upstream Server와 연결에 실패하였으며, Downstream Client에게 503 Status Code를 응답 |
| UpstreamConnectionFailure  | UF  | Envoy Server는 Upstream Server와 연결에 실패하였으며, Downstream Client에게 503 Status Code를 응답 |
| UpstreamOverflow           | UO  | Envoy Server는 Circuit Breaking으로 인해서 Upstream Server로 연결을 시도하지 않았으며, Downstream Client에게 503 Status Code를 응답 |
| NoRouteFound               | NR  | Envoy Server는 적절한 Route Rule 또는 Filter Chain이 존재하지 않아 Upstream Server로 연결을 시도하지 못했으며, Downstream Client에게 404 Status Code를 응답 |
| UpstreamRetryLimitExceeded | URX | Envoy Server는 설정된 HTTP 요청 재시도 또는 TCP 재접속 시도 횟수가 초과하여 잠시동안 Upstream Server로 연결을 시결하지 않음 |
| NoClusterFound             | NC  | Envoy Server는 요청을 전달할 Upstream Cluster를 찾지 못해 Upstream Server로 연결을 시도하지 못함 |
| DurationTimeout            | DT  | Envoy Server는 Upstream Server와 `max_connection_duration` 시간 이상으로 연결을 유지하거나, Downstream Client와 `max_downstream_connection_duration` 시간 이상으로 연결을 유지할 경우 연결을 강제로 종료하며, Downstream Client에게 504 Status Code를 응답 |
{{</ table >}}

### 1.2. HTTP Only Flag

{{< table caption="[Table 2] Envoy HTTP Only Flag" >}}
| Long Name | Short Name | Description |
|---|---|---|
| DownstreamConnectionTermination  | DC    | Downstream Client가 Envoy Server와의 연결을 먼저 TCP RST과 함께 종료 |
| FailedLocalHealthCheck           | LH    | Envoy Server는 Upstream Server로 요청을 보내기전 Health Check를 수행하였지만 실패하여 요청은 종료하고, Downstream Client에게 503 Status Code를 응답 |
| UpstreamRequestTimeout           | UT    | Envoy Server는 Upstream Cluster로 전송한 요청을 Timeout에 의해서 강제로 중단하였으며, Downstream Client에게 504 Status Code를 응답 |
| LocalReset                       | LR    | Envoy Server는 Upstream Cluster와의 연결을 TCP RST과 함께 먼저 강제로 종료하였으며, Downstream Client에게 503 Status Code를 응답 |
| UpstreamRemoteReset              | UR    | Upstream Server는 Envoy Server와의 연결을 TCP RST과 함께 먼저 강제로 종료하였으며, Envoy Server는 Downstream Client에게 503 Status Code를 응답 |
| UpstreamConnectionTermination    | UC    | Upstream Server는 Envoy Server와의 연결을 TCP FIN과 함께 먼저 종료하였으며, Envoy Server는 Downstream Client에게 503 Status Code를 응답 |
| DelayInjected                    | DI    | Envoy Server는 Fault Injection 설정만큼 요청을 지연하여 Upstream Server에게 전달 |
| FaultInjected                    | FI    | Envoy Server는 Fault Injection 설정으로 인해서 요청을 Upstream Server에게 전달하지 않음 |
| RateLimited                      | RL    | Envoy Server는 HTTP Rate Limit Filter를 통해서 요청 횟수를 제한하며, Downstream Client에게 429 Status Code를 응답 |
| UnauthorizedExternalService      | UAEX  | Envoy Server는 연동된 외부의 Authorization Service로 인해서 요청을 거부 |
| RateLimitServiceError            | RLSE  | Envoy Server는 HTTP Rate Limit Filter로 인해서 요청을 Upstream Server에게 전달하지 않음 |
| InvalidEnvoyRequestHeaders       | IH    | Envoy Server는 요청에 잘못된 Header가 설정되어 있어 요청을 거부하였으며, Downstream Client에게 400 Status Code를 응답 |
| StreamIdleTimeout                | SI    | Envoy Server는 Upstream Server 또는 Downstream Client와 특정 시간 요청을 주고 받지 않으면 연결을 종료하며, Envoy Server와 Upstream Server 사이의 요청이 없었으면 Envoy Server는 Downstream Client에게 504 Status Code를 응답하고 Envoy Server와 Downstream Client 사이의 요청이 없었으면 Envoy Server는 Downstream Client에게 408 Status Code를 응답 |
| DownstreamProtocolError          | DPE   | Envoy Server는 Downstream Client로부터 잘못된 HTTP Protocol을 이용하는 요청을 받음 |
| UpstreamProtocolError            | UPE   | Envoy Server는 Upstream Server로부터 잘못된 HTTP Protocol을 이용하는 응답을 받음 |
| UpstreamMaxStreamDurationReached | UMSDR | Envoy Server는 Upstream Server에 전송한 요청의  지속시간이 최대값을 초과하면 요청을 강제로 종료 |
| ResponseFromCacheFilter          | RFCF  | Envoy Server는 요청을 Upstream Server에게 전달하지 않고 Cache Filter를 통해서 Caching된 응답을 활용 |
| NoFilterConfigFound              | NFCF  | Envoy Server는 예열 기간동안 요청을 처리할 Filter 설정을 찾지 못함 |
| OverloadManagerTerminated        | OM    | Envoy Server의 Overload Manager에 의해서 과부하 상태를 감지하고 강제로 처리중인 요청을 종료 |
| DnsResolutionFailed              | DF    | Envoy Server는 요청을 Upstream Server로 전송하기 위해서 DNS 조회시 조회에 실패 |
| DropOverload                     | DO    | Envoy Server는 과부화로 인해서 일부 신규 요청을 거절하며, Downstream Client에게 503 Status Code를 응답 |
| DownstreamRemoteReset            | DR    | Downstream Client가 Envoy Server와의 연결을 먼저 TCP RST과 함께 종료 |
| UnconditionalDropOverload        | UDO   | Envoy Server는 과부화로 인해서 모든 신규 요청을 거절 |
{{</ table >}}

## 2. 참조

* [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage)

