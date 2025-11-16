---
title: "Envoy Response Flag"
---

Organizes Envoy's Response Flag.

## 1. Envoy Response Flag

Envoy Response Flag refers to flags used to represent related information in Access Log when **specific Events or Errors** occur during Envoy's request processing. **Long Name** and **Short Name** exist, and Short Name is recorded in Envoy Access Log. Response Flags are divided into flags that are **used with HTTP and TCP** and flags that are **only applied to HTTP**.

### 1.1. HTTP, TCP Flag

{{< table caption="[Table 1] Envoy HTTP, TCP Flag" >}}
|| Long Name | Short Name | Description |
|---|---|---|
|| NoHealthyUpstream          | UH  | Envoy Server failed to connect to Upstream Server because there is no Healthy Upstream Server in Upstream Cluster, and responds with 503 Status Code to Downstream Client |
|| UpstreamConnectionFailure  | UF  | Envoy Server failed to connect to Upstream Server and responds with 503 Status Code to Downstream Client |
|| UpstreamOverflow           | UO  | Envoy Server did not attempt to connect to Upstream Server due to Circuit Breaking and responds with 503 Status Code to Downstream Client |
|| NoRouteFound               | NR  | Envoy Server could not attempt to connect to Upstream Server because appropriate Route Rule or Filter Chain does not exist, and responds with 404 Status Code to Downstream Client |
|| UpstreamRetryLimitExceeded | URX | Envoy Server temporarily does not connect to Upstream Server because the configured HTTP request retry or TCP reconnection attempt count has been exceeded |
|| NoClusterFound             | NC  | Envoy Server could not attempt to connect to Upstream Server because it could not find Upstream Cluster to forward the request to |
|| DurationTimeout            | DT  | Envoy Server forcibly terminates the connection when maintaining connection with Upstream Server for `max_connection_duration` time or longer, or maintaining connection with Downstream Client for `max_downstream_connection_duration` time or longer, and responds with 504 Status Code to Downstream Client |
{{</ table >}}

### 1.2. HTTP Only Flag

{{< table caption="[Table 2] Envoy HTTP Only Flag" >}}
|| Long Name | Short Name | Description |
|---|---|---|
|| DownstreamConnectionTermination  | DC    | Downstream Client first terminates connection with Envoy Server with TCP FIN |
|| FailedLocalHealthCheck           | LH    | Envoy Server performed Health Check before sending request to Upstream Server but failed, terminates the request, and responds with 503 Status Code to Downstream Client |
|| UpstreamRequestTimeout           | UT    | Envoy Server forcibly aborted the request sent to Upstream Cluster due to Timeout and responds with 504 Status Code to Downstream Client |
|| LocalReset                       | LR    | Envoy Server first forcibly terminates connection with Upstream Cluster with TCP RST and responds with 503 Status Code to Downstream Client |
|| UpstreamRemoteReset              | UR    | Upstream Server first forcibly terminates connection with Envoy Server with TCP RST, and Envoy Server responds with 503 Status Code to Downstream Client |
|| UpstreamConnectionTermination    | UC    | Upstream Server first terminates connection with Envoy Server with TCP FIN, and Envoy Server responds with 503 Status Code to Downstream Client |
|| DelayInjected                    | DI    | Envoy Server delays the request by the Fault Injection setting and delivers it to Upstream Server |
|| FaultInjected                    | FI    | Envoy Server does not deliver the request to Upstream Server due to Fault Injection setting |
|| RateLimited                      | RL    | Envoy Server limits the number of requests through HTTP Rate Limit Filter and responds with 429 Status Code to Downstream Client |
|| UnauthorizedExternalService      | UAEX  | Envoy Server rejects the request due to integrated external Authorization Service |
|| RateLimitServiceError            | RLSE  | Envoy Server does not deliver the request to Upstream Server due to HTTP Rate Limit Filter |
|| InvalidEnvoyRequestHeaders       | IH    | Envoy Server rejects the request because incorrect Header is set in the request and responds with 400 Status Code to Downstream Client |
|| StreamIdleTimeout                | SI    | Envoy Server terminates the connection if no requests are exchanged with Upstream Server or Downstream Client for a certain time, and if there were no requests between Envoy Server and Upstream Server, Envoy Server responds with 504 Status Code to Downstream Client, and if there were no requests between Envoy Server and Downstream Client, Envoy Server responds with 408 Status Code to Downstream Client |
|| DownstreamProtocolError          | DPE   | Envoy Server receives a request using incorrect HTTP Protocol from Downstream Client |
|| UpstreamProtocolError            | UPE   | Envoy Server receives a response using incorrect HTTP Protocol from Upstream Server |
|| UpstreamMaxStreamDurationReached | UMSDR | Envoy Server forcibly terminates the request when the duration of the request sent to Upstream Server exceeds the maximum value |
|| ResponseFromCacheFilter          | RFCF  | Envoy Server uses cached response through Cache Filter without delivering the request to Upstream Server |
|| NoFilterConfigFound              | NFCF  | Envoy Server cannot find Filter configuration to process requests during warm-up period |
|| OverloadManagerTerminated        | OM    | Envoy Server detects overload state through Overload Manager and forcibly terminates requests being processed |
|| DnsResolutionFailed              | DF    | Envoy Server fails DNS lookup when querying to send request to Upstream Server |
|| DropOverload                     | DO    | Envoy Server rejects some new requests due to overload and responds with 503 Status Code to Downstream Client |
|| DownstreamRemoteReset            | DR    | Downstream Client first terminates connection with Envoy Server with TCP RST |
|| UnconditionalDropOverload        | UDO   | Envoy Server rejects all new requests due to overload |
{{</ table >}}

## 2. References

* [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage)


