---
title: "Envoy Response Flag"
draft: true
---

## 1. HTTP, TCP Flag

| Long Name | Short Name | Description |
|---|---|---|
| NoHealthyUpstream          | UH  | Envoy Server는 Upstream Cluster에 Healthy 상태의 Upstream Server가 존재하지 않아 Upstream Server와 연결에 실패하였으며, Downstream Client에게 503 Status Code를 응답 |
| UpstreamConnectionFailure  | UF  | Envoy Server는 Upstream Server와 연결에 실패하였으며, Downstream Client에게 503 Status Code를 응답 |
| UpstreamOverflow           | UO  | Envoy Server는 Circuit Breaking으로 인해서 Upstream Server로 연결을 시도하지 않았으며, Downstream Client에게 503 Status Code를 응답 |
| NoRouteFound               | NR  | Envoy Server는 적절한 Route Rule 또는 Filter Chain이 존재하지 않아 Upstream Server로 연결을 시도하지 못했으며, Downstream Client에게 404 Status Code를 응답 |
| UpstreamRetryLimitExceeded | URX | Envoy Server는 설정된 HTTP 요청 재시도 또는 TCP 재접속 시도 횟수가 초과하여 잠시동안 Upstream Server로 연결을 시도하지 않음 |
| NoClusterFound             | NC  | Envoy Server는 요청을 처리할 Upstream Cluster를 찾지 못해 Upstream Server로 연결을 시도하지 못함 |
| DurationTimeout            | DT  | Envoy Server는 Upstream Server와 `max_connection_duration` 시간 이상으로 Connection을 유지하거나, Downstream Client와 `max_downstream_connection_duration` 시간 이상으로 Connection을 유지할 경우 Connection을 강제로 종료하며, Downstream Client에게 504 Status Code를 응답 |

## 2. HTTP Only Flag

| Long Name | Short Name | Description |
|---|---|---|
| DownstreamConnectionTermination  | DC    | Downstream Client가 연결을 종료 |
| FailedLocalHealthCheck           | LH    | Local service failed health check request in addition to 503 response code. |
| UpstreamRequestTimeout           | UT    | Upstream Cluster로 전송한 요청이 Timeout에 의해서 종료 되었으며, Client는 504 Status Code를 받음 |
| LocalReset                       | LR    | Envoy Server가 Connection을 Reset을 통해서 먼져 끊었으며, Client는 503 Status Code를 받음 |
| UpstreamRemoteReset              | UR    | Upstream Server가 Connection을 Reset을 통해 먼져 끊었으며, Client는 504 Status Code를 받음 |
| UpstreamConnectionTermination    | UC    | Upstream connection termination in addition to 503 response code. |
| DelayInjected                    | DI    | The request processing was delayed for a period specified via fault injection. |
| FaultInjected                    | FI    | The request was aborted with a response code specified via fault injection. |
| RateLimited                      | RL    | The request was rate-limited locally by the HTTP rate limit filter in addition to 429 response code. |
| UnauthorizedExternalService      | UAEX  | The request was denied by the external authorization service. |
| RateLimitServiceError            | RLSE  | The request was rejected because there was an error in rate limit service. |
| InvalidEnvoyRequestHeaders       | IH    | The request was rejected because it set an invalid value for a strictly-checked header in addition to 400. |
| StreamIdleTimeout                | SI    | Stream idle timeout in addition to 408 or 504 response code. |
| DownstreamProtocolError          | DPE   | The downstream request had an HTTP protocol error. |
| UpstreamProtocolError            | UPE   | The upstream response had an HTTP protocol error. |
| UpstreamMaxStreamDurationReached | UMSDR | The upstream request reached max stream duration. |
| ResponseFromCacheFilter          | RFCF  | The response was served from an Envoy cache filter. |
| NoFilterConfigFound              | NFCF  | The request is terminated because filter configuration was not received within the permitted warming deadline. |
| OverloadManagerTerminated        | OM    | Overload Manager terminated the request. |
| DnsResolutionFailed              | DF    | The request was terminated due to DNS resolution failure. |
| DropOverload                     | DO    | The request was terminated in addition to 503 response code due to drop_overloads. |
| DownstreamRemoteReset            | DR    | The response details are http2.remote_reset or http2.remote_refuse. |
| UnconditionalDropOverload        | UDO   | The request was terminated in addition to 503 response code due to drop_overloads is set to 100%. |

## 3. 참조

* [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage)

