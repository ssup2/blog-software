---
title: "Envoy Response Flag"
draft: true
---

## 1. HTTP, TCP Flag

| Long Name | Short Name | Description |
|---|---|---|
| NoHealthyUpstream          | UH  | Upstream Cluster에 Health 상태의 Upstream Server가 존재하지 않으며, Client는 503 Status Code를 받음 |
| UpstreamConnectionFailure  | UF  | Upstream Server 연결에 실패하였으며, Client는 503 Status Code를 받음 |
| UpstreamOverflow           | UO  | Circuit Breaker로 인해서 Upstream Server 연결에 실패하였으며, Client는 503 Status Code를 받음 |
| NoRouteFound               | NR  | 요청을 처리할 Route Rule 또는 Filter Chain이 존재하지 않으며, Client는 404 Status Code를 받음 |
| UpstreamRetryLimitExceeded | URX | HTTP 요청 재시도 또는 TCP 재접속 시도 횟수가 초과하여 Upstream Server 연결에 실패 |
| NoClusterFound             | NC  | Upstream Cluster가 존재하지 않음 |
| DurationTimeout            | DT  | `max_connection_duration` 또는 `max_downstream_connection_duration` 시간을 초과하는 경우 |

## 2. HTTP Only Flag

| Long Name | Short Name | Description |
|---|---|---|
| DownstreamConnectionTermination  | DC    | Downstream Client가 연결을 종료 |
| FailedLocalHealthCheck           | LH    | Local service failed health check request in addition to 503 response code. |
| UpstreamRequestTimeout           | UT    | Upstream Server로 전송한 요청이 Timeout에 의해서 종료 되었으며, Client는 504 Status Code를 받음 |
| LocalReset                       | LR    | Connection local reset in addition to 503 response code. |
| UpstreamRemoteReset              | UR    | Upstream remote reset in addition to 503 response code. |
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

