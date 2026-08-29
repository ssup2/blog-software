---
title: Envoy Header
---

Organizes Envoy's own Headers used while Envoy processes HTTP and gRPC requests.

## 1. Envoy Header

Envoy uses its own Headers with the `x-envoy-` Prefix while processing HTTP requests. Envoy Headers can be classified by role into **Headers that Envoy sets to represent information in requests or responses** and **Headers that the Downstream Client sets in requests to control Envoy's behavior**. Since gRPC operates on top of HTTP/2, most Envoy Headers are applied to gRPC requests in the same way, and there are also Headers that are applied only to gRPC requests.

### 1.1. Request Header

These are Headers that Envoy sets while forwarding requests to the Upstream Server. The Upstream Server can obtain request-related information through these Headers.

* `x-request-id` : Represents a unique UUID value that Envoy generates for each request. Although it does not have the `x-envoy-` Prefix, it is a representative Header set by Envoy, and it is used to identify a single request in Access Logs and Tracing. If the request already has an `x-request-id` Header, Envoy either keeps the existing value or replaces it with a new value depending on the configuration.
* `x-envoy-internal` : Indicates whether the request originated from the internal network, and is set to `true` for Internal requests. Envoy determines whether a request is Internal based on the `x-forwarded-for` (XFF) Header and the `use_remote_address` setting as follows.
  * When `use_remote_address` is `true` : The request is considered Internal only when the **XFF Header does not exist** and the Source IP address of the Downstream directly connected to Envoy is an Internal address. The existence of the XFF Header means that the request has passed through at least one other Proxy, so it is not considered an Internal request.
  * When `use_remote_address` is `false` (default) : Envoy does not trust the IP address of the directly connected Downstream and makes the determination based only on the XFF Header. The request is considered Internal only when **exactly one address exists in the XFF Header** and that address is an Internal address. Therefore, both the case where the XFF Header does not exist and the case where multiple addresses exist in the XFF Header are not considered Internal requests.
  * Internal addresses by default mean the RFC1918 private IPv4 address ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) and the RFC4193 IPv6 ULA address range, and they can be changed through the `internal_address_config` setting. However, starting from Envoy Version `1.33`, the default behavior has changed for security hardening, and if the `internal_address_config` setting is not specified, all addresses are considered External addresses.
  * Even when two or more Internal addresses are accumulated in the XFF Header while passing through multiple Internal Proxies, the request is considered External. This is a known limitation of Envoy that arose from simplifying XFF Header parsing.
* `x-envoy-external-address` : Represents the trusted Client IP address (Trusted Client Address) when the request originated from the external network. Since intermediate Proxies can arbitrarily manipulate the XFF Header, Envoy provides the trusted Client IP address determined by the following criteria as a separate Header. It is not set for Internal requests.
  * When `use_remote_address` is `true` : The Source IP address of the Downstream directly connected to Envoy is considered the trusted Client IP address.
  * When `use_remote_address` is `false` (default) : If the XFF Header exists, the **rightmost (last) address** of the XFF Header is considered the trusted Client IP address. The rightmost address is set by the Proxy right in front of Envoy, so it is an address that the Client cannot arbitrarily manipulate. If the XFF Header does not exist, the Source IP address of the Downstream directly connected to Envoy is used.
  * When `xff_num_trusted_hops` is `N (> 0)` : This means that there are N trusted Proxies in front of Envoy, and the trusted Client IP address is determined as the Nth address from the right end of the XFF Header when `use_remote_address` is `true`, or the (N+1)th address from the right end when it is `false`. If the XFF Header contains fewer addresses than required, the Source IP address of the Downstream directly connected to Envoy is used.
* `x-envoy-original-path` : Represents the original Path before Rewrite when the request Path has been rewritten by Envoy's Route configuration.
* `x-envoy-attempt-count` : Represents the number of request attempts. The first request is `1`, and it increases by 1 each time a retry occurs. The Upstream Server can check whether the received request is a retry request through this Header. Depending on the configuration, it can also be set in the response, in which case it represents the number of attempts performed until the response was received.
* `x-envoy-expected-rq-timeout-ms` : Represents the Timeout value that Envoy applied to the request. Through this Header, the Upstream Server can determine the remaining time before the Timeout occurs and give up processing requests that have exceeded the Timeout.
* `x-envoy-force-trace` : If this Header is set in an Internal request, Envoy forcibly collects the Trace regardless of the Sampling policy. Envoy stores whether to collect the Trace not in a separate Header but **inside the UUID value of the `x-request-id` Header**. The 13th character of the UUID Version 4 format (`xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx`) is fixed to `4`, which represents the UUID Version, and Envoy takes advantage of the fact that the Version information is not actually used, overwriting this character with the following values to represent whether the Trace is collected.
  * `4` : Represents the state where the Trace is not collected. The default value of UUID Version 4 is kept as is.
  * `9` : Represents the state where the Trace is collected by the Sampling policy.
  * `a` : Represents the state where the Trace is forcibly collected by Server-side configuration.
  * `b` : Represents the state where the Trace is forcibly collected by the `x-envoy-force-trace` Header sent by the Client.

  Therefore, when Envoy receives a request with the `x-envoy-force-trace` Header set, it generates an `x-request-id` with the 13th character set to `b` and also sets the `x-request-id` Header in the response. Afterwards, when the App propagates the `x-request-id` Header to other Upstream Servers, the Envoys that receive it do not perform Sampling again on their own but check the 13th character value of the `x-request-id` and collect the Trace in the same way. Through this method, a consistent Trace for the entire request flow can be obtained.
* `x-envoy-decorator-operation` : Represents the Operation name of the Tracing Span. The Operation name of a Span is by default the Host name of the requested Service, but if a Decorator is specified in Envoy's Route configuration, Envoy sets the Operation name configured in the Decorator in this Header and propagates it. If this Header is set in a request, the Envoy that receives the request overwrites the Operation name of the **Server Span** (the Span of Span Kind `SERVER` that Envoy generates while receiving the request from the Downstream Client) with the value of this Header. A Header with the same name is also used in responses.

### 1.2. Timeout, Retry Control Request Header

These are Headers that the Downstream Client sets in requests to control Envoy's Timeout and Retry behavior on a per-request basis. These Headers work **only when Envoy determines the request to be an Internal request**, and if they are set in an External request, Envoy does not trust them and removes them. The criteria for determining an Internal request are the same as those described for the `x-envoy-internal` Header.

* `x-envoy-upstream-rq-timeout-ms` : Sets the Timeout of the entire request in Milliseconds. It takes precedence over the Timeout value specified in Envoy's Route configuration.
* `x-envoy-upstream-rq-per-try-timeout-ms` : Sets the Timeout for each attempt, including retries, in Milliseconds.
* `x-envoy-max-retries` : Sets the maximum number of retries.
* `x-envoy-retry-on` : Sets the retry conditions for HTTP requests. The main conditions are as follows.
  * `5xx` : Performs a retry when HTTP Status Code `5XX` occurs.
  * `gateway-error` : Performs a retry when HTTP Status Code `502`, `503`, or `504` occurs.
  * `reset` : Performs a retry when the Upstream Server becomes unable to send a response. This includes cases where the Connection is terminated, Reset, or a Read Timeout occurs.
  * `connect-failure` : Performs a retry when Connection establishment with the Upstream Server fails.
  * `retriable-4xx` : Performs a retry when a retriable HTTP Status Code `4XX` occurs. Currently, only the `409` Status Code is included.
  * `refused-stream` : Performs a retry when the Upstream Server returns the HTTP/2 `REFUSED_STREAM` Error Code.
  * `envoy-ratelimited` : Performs a retry when the response contains the `x-envoy-ratelimited` Header.
  * `retriable-status-codes` : Performs a retry when a Status Code specified in the `x-envoy-retriable-status-codes` Header occurs.
  * `retriable-headers` : Performs a retry when a Header specified in the `x-envoy-retriable-header-names` Header is included in the response.
* `x-envoy-retriable-status-codes` : Used together with the `retriable-status-codes` retry condition, and sets the list of HTTP Status Codes to retry, separated by `,`.
* `x-envoy-retriable-header-names` : Used together with the `retriable-headers` retry condition, and sets the list of Header names, separated by `,`, that trigger a retry when included in the response.
* `x-envoy-hedge-on-per-try-timeout` : Sets whether to perform Hedging, which performs a retry simultaneously while keeping the existing request alive without terminating it when a per-attempt Timeout occurs. The response that arrives first is delivered to the Downstream Client.

### 1.3. Response Header

These are Headers that Envoy sets while delivering responses to the Downstream Client. The Downstream Client can obtain response-related information through these Headers.

* `x-envoy-upstream-service-time` : Represents the time in Milliseconds taken from when Envoy sent the request to the Upstream Server until the response was received. The Downstream Client can compare the total response time with the value of this Header to distinguish between Network Latency and the Upstream Server's processing time.
* `x-envoy-overloaded` : Set when Envoy could not forward the request to the Upstream Server due to Circuit Breaking.
* `x-envoy-ratelimited` : Set when Envoy could not forward the request to the Upstream Server due to Rate Limiting.
* `x-envoy-immediate-health-check-fail` : A Header set by the Upstream Server in the response. When Envoy receives a response containing this Header, it immediately treats the Upstream Server as having failed the Health Check. It can be used when the Upstream Server performs a Graceful Shutdown.
* `x-envoy-decorator-operation` : Like the request Header, it represents the Operation name of the Tracing Span, and the Server-side Envoy sets the Operation name of the Decorator specified in its own Route configuration in the response and returns it. If this Header is set in a response, the Envoy that receives the response overwrites the Operation name of the **Client Span** (the Span of Span Kind `CLIENT` that Envoy generates while sending the request to the Upstream Server) with the value of this Header. Since the Client-side Envoy sending the request cannot know which Route on the Server side the request was actually matched to and processed by, this Header is used for the Server-side Envoy to inform the Client-side Envoy of the accurate Operation name determined based on its own Route information through the response.

### 1.4. gRPC Header

Since gRPC operates on top of HTTP/2, most of the Envoy Headers described above are applied to gRPC requests in the same way. Since a single gRPC request (RPC) is processed by being allocated a new Stream on the HTTP/2 Connection, all Headers are set on a **per-RPC (Stream) basis**, not per-Connection. Request Headers are set in the first HEADERS Frame that starts the Stream, and the `grpc-status` and `grpc-message` Headers, which represent the final processing result of the RPC, are set in the last HEADERS Frame (Trailer) that terminates the Stream. The Headers applied only to gRPC requests are as follows.

* `grpc-timeout` : Represents the Deadline of the request set by the gRPC Client. Depending on the configuration, Envoy can use the `grpc-timeout` Header value as the Route's Timeout.
* `x-envoy-retry-grpc-on` : Sets the retry conditions for gRPC requests. Like the `x-envoy-retry-on` Header, it works only for Internal requests.
  * `cancelled` : Performs a retry when gRPC Status Code `CANCELLED (1)` occurs.
  * `deadline-exceeded` : Performs a retry when gRPC Status Code `DEADLINE_EXCEEDED (4)` occurs.
  * `internal` : Performs a retry when gRPC Status Code `INTERNAL (13)` occurs.
  * `resource-exhausted` : Performs a retry when gRPC Status Code `RESOURCE_EXHAUSTED (8)` occurs.
  * `unavailable` : Performs a retry when gRPC Status Code `UNAVAILABLE (14)` occurs.
* `grpc-status`, `grpc-message` : Headers that represent the processing result of gRPC, and are generally set by the gRPC Server in the Trailer of the response. They are also set when Envoy fails to receive a normal response from the Upstream Server and generates an Error response on its own, and the detailed process is described in 1.4.1.

#### 1.4.1. gRPC Status Code Conversion for Error Responses

When Envoy receives a response normally from the gRPC Server, the `grpc-status` set by the gRPC Server in the Trailer is delivered to the Downstream Client as is, and Envoy does not perform any conversion. On the other hand, when Envoy fails to receive a normal response from the Upstream Server, the `grpc-status` generated by the gRPC Server does not exist, so Envoy generates an Error response on its own and responds to the Downstream Client. The cases where Envoy fails to receive a normal response from the Upstream Server can be divided into the following two categories.

* Cases where the request could not be forwarded to the Upstream Server : When no Route matches the request, when no Healthy Upstream Server exists in the Upstream Cluster, when the connection to the Upstream Server fails, or when the request is rejected due to Circuit Breaking
* Cases where the request was forwarded but a normal response was not received : When a Timeout occurs, or when the Upstream Server terminates or Resets the connection in the middle of the response

{{< table caption="[Table 1] Envoy HTTP Status Code, gRPC Status Code Mapping" >}}
| HTTP Status Code | gRPC Status Code |
|---|---|
| 400 | INTERNAL (13) |
| 401 | UNAUTHENTICATED (16) |
| 403 | PERMISSION_DENIED (7) |
| 404 | UNIMPLEMENTED (12) |
| 429 | UNAVAILABLE (14) |
| 502 | UNAVAILABLE (14) |
| 503 | UNAVAILABLE (14) |
| 504 | UNAVAILABLE (14) |
| Others | UNKNOWN (2) |
{{</ table >}}

In these cases, Envoy generates a gRPC-format Error response through the following process using the Mapping in [Table 1]. It proceeds in the following order.

1. Envoy first determines the HTTP Status Code internally according to the Error situation. (`503` when the connection to the Upstream Server fails, `404` when no Route exists, etc.) For HTTP requests, the determined HTTP Status Code is set in the response as is.
2. For gRPC requests, the determined HTTP Status Code is converted to a gRPC Status Code according to the Mapping in [Table 1].
3. The converted gRPC Status Code is set in the `grpc-status` Header, and the response is sent in Trailers-Only form with HTTP Status Code `200`. In other words, the HTTP Status Code in [Table 1] does not mean the value set in the actual response of a gRPC request but the HTTP Status Code determined internally by Envoy, and the HTTP Status Code set in the actual response of a gRPC request is always `200`.

Exceptionally, when a Timeout occurs, the `DEADLINE_EXCEEDED (4)` gRPC Status Code is set directly without using the Mapping in [Table 1]. (In the same situation, HTTP requests are responded with the `504` Status Code.)

## 2. References

* Envoy HTTP Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Envoy Router Filter Header : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter)
* gRPC HTTP Status Mapping : [https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md](https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md)
* Istio Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/istio-envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/istio-envoy-header/)
