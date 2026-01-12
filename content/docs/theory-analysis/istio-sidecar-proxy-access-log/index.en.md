---
title: Istio Sidecar Proxy Access Log
---

## 1. Istio Sidecar Proxy Access Log

This document examines the Sidecar Proxy Access Logs in various cases within an Istio environment.

### 1.1. Test Environment Setup

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="800px" >}}

[Figure 1] shows the Istio Sidecar Proxy Access Log test environment. It consists of 2 Worker Nodes, each containing a `shell` Pod acting as a Client and a `mock-server` Pod acting as a Server. The `shell` Pod accesses the `mock-server` Pod through the configured Service, Destination Rule, and Virtual Service. For HTTP Protocol access, the `curl` command is used inside the `shell` Pod, and for gRPC Protocol access, the `grpcurl` command is used inside the `shell` Pod.

#### 1.1.1. Kubernetes, Istio Environment Setup

```shell {caption="[Shell 1] Kubernetes, Istio Environment Setup"}
# Create kubernetes cluster with kind
$ kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Install istio
$ istioctl install --set profile=demo -y

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled
```

[Shell 1] shows the script for setting up the Kubernetes and Istio environment. A Kubernetes Cluster is created using `kind`, and Istio is installed. Then, Sidecar Injection is enabled for the default Namespace.

```yaml {caption="[Text 1] Set Mesh Config", linenos=table}
apiVersion: v1
data:
  mesh: |-
    accessLogFile: /dev/stdout
    accessLogEncoding: TEXT
    accessLogFormat: |
      {
        "start_time": "%START_TIME%",
        "method": "%REQ(:METHOD)%",
        "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
        "protocol": "%PROTOCOL%",
        "response_code": "%RESPONSE_CODE%",
        "response_flags": "%RESPONSE_FLAGS%",
        "response_code_details": "%RESPONSE_CODE_DETAILS%",
        "connection_termination_details": "%CONNECTION_TERMINATION_DETAILS%",
        "upstream_transport_failure_reason": "%UPSTREAM_TRANSPORT_FAILURE_REASON%",
        "bytes_received": "%BYTES_RECEIVED%",
        "bytes_sent": "%BYTES_SENT%",
        "duration": "%DURATION%",
        "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
        "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",
        "user_agent": "%REQ(USER-AGENT)%",
        "request_id": "%REQ(X-REQUEST-ID)%",
        "authority": "%REQ(:AUTHORITY)%",
        "upstream_host": "%UPSTREAM_HOST%",
        "upstream_cluster": "%UPSTREAM_CLUSTER_RAW%",
        "upstream_local_address": "%UPSTREAM_LOCAL_ADDRESS%",
        "downstream_local_address": "%DOWNSTREAM_LOCAL_ADDRESS%",
        "downstream_remote_address": "%DOWNSTREAM_REMOTE_ADDRESS%",
        "requested_server_name": "%REQUESTED_SERVER_NAME%",
        "route_name": "%ROUTE_NAME%",
        "grpc_status": "%GRPC_STATUS%",
        "upstream_request_attempt_count": "%UPSTREAM_REQUEST_ATTEMPT_COUNT%",
        "request_duration": "%REQUEST_DURATION%",
        "response_duration": "%RESPONSE_DURATION%"
      }
```

[Text 1] shows the Istio Mesh Config for changing the format of Istio Sidecar Proxy Access Log. The default format of Access Log is in plain text format which has poor readability, so the `accessLogFormat` field is used to change it to JSON format.

#### 1.1.2. Workload Setup

```yaml {caption="[File 1] mock-server Pod Manifest", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: mock-server
  labels:
    app: mock-server
spec:
  containers:
  - name: mock-server
    image: ghcr.io/ssup2/mock-go-server:0.1.6
    ports:
    - containerPort: 8080
    - containerPort: 9090
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: grpc
    port: 9090
    targetPort: 9090
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server
  http:
  - timeout: 60s # default is disabled
    retries:
      attempts: 2                                                     # default value
      retryOn: "connect-failure,refused-stream,unavailable,cancelled" # default value
    route:
    - destination:
        host: mock-server
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1 # default value is 2^31-1
      http:
        http1MaxPendingRequests: 1   # default value is 2^31-1 (unlimited)
        maxConcurrentStreams: 1      # default value is 2^31-1 (unlimited)
    outlierDetection:
      consecutive5xxErrors: 5 # default value
      interval: 10s           # default value
      baseEjectionTime: 30s   # default value
      maxEjectionPercent: 100 # default value
```

[File 1] shows the Manifest for the `mock-server` Workload. The `mock-server` Pod is created using the `mock-server` Image, opening port `8080` for HTTP service and port `9090` for gRPC service. In the Virtual Service, Timeout is set to `60s`, and retry is configured with 2 retries (same as default) for a maximum of 3 request attempts. Also, the default setting is configured to retry when any of the 4 errors occur: `connect-failure`, `refused-stream`, `unavailable`, `cancelled`.

Circuit Breaking is configured in the Destination Rule for testing. The `outlierDetection` field defines the criteria for determining abnormal status and is configured with default values. Circuit Breaking activates when 5 consecutive 5xx errors occur at 10-second intervals, with the Circuit Breaking duration set to 30 seconds. The `connectionPool` field specifies settings to limit the concurrent processing count of HTTP/GRPC requests, configured to allow only one request to be processed at a time.

There are two main methods to limit concurrent processing count: limiting based on maximum TCP Connections and limiting based on maximum concurrent HTTP/GRPC request processing count. The TCP Connection-based method uses the `tcp.maxConnections` field to limit the maximum number of TCP Connections. In [File 1], `tcp.maxConnections` is set to `1` to limit the maximum TCP Connections to 1, and `http.http1MaxPendingRequests` is set to `1` to limit the maximum pending requests to 1 before the TCP Connection becomes Ready.

For GRPC, multiple requests can be processed simultaneously on a single TCP Connection using HTTP/2's Stream feature. Therefore, `http.maxConcurrentStreams` is set to `1` to force a maximum of 1 Stream per TCP Connection, easily triggering GRPC request Pending. If `http.maxConcurrentStreams` is not specified, unlimited Streams can be processed on a single TCP Connection, so GRPC request Pending does not occur.

```yaml {caption="[File 2] mock-server Destination Rule", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  trafficPolicy:
    connectionPool:
      http:
        http2MaxRequests: 1   # default value is 2^31-1 (unlimited)
    outlierDetection:
      consecutive5xxErrors: 5 # default value
      interval: 10s           # default value
      baseEjectionTime: 30s   # default value
      maxEjectionPercent: 100 # default value
```

The method to limit maximum concurrent HTTP/GRPC request processing count uses the `http.http2MaxRequests` field. In [File 2], `http.http2MaxRequests` is set to `1` to limit the maximum HTTP/GRPC request processing count to 1. Also, the remaining `connectionPool` fields are not set to prevent Request from being Pending. The Destination Rule set in [File 1] is used for most Cases, while [File 2]'s Destination Rule is used in some Circuit Breaking Cases.

{{< table caption="[Table 1] mock-server HTTP Endpoints" >}}
| Endpoint | Description |
|---|---|
| /status/{code} | Return specific HTTP status code |
| /delay/{ms} | Delay response by milliseconds |
| /reset-before-response/{ms} | Server sends TCP RST before response after delay |
| /reset-after-response/{ms} | Server sends dummy data, then TCP RST after delay |
| /close-before-response/{ms} | Server closes connection before response after delay |
| /close-after-response/{ms} | Server sends dummy data, then closes connection after delay |
{{< /table >}}

{{< table caption="[Table 2] mock-server gRPC Endpoints" >}}
| Function | Description |
|---|---|
| /mock.MockService/Status | Return specific gRPC status code |
| /mock.MockService/Delay | Delay response by milliseconds |
| /mock.MockService/ResetBeforeResponse | Server sends TCP RST before response after delay |
| /mock.MockService/ResetAfterResponse | Server sends dummy data, then TCP RST after delay |
| /mock.MockService/CloseBeforeResponse | Server closes connection before response after delay |
| /mock.MockService/CloseAfterResponse | Server sends dummy data, then closes connection after delay |
{{< /table >}}

[Table 1] and [Table 2] show the behavior of the `mock-server` Workload's HTTP Endpoints and gRPC Functions. The endpoints provided by `mock-server` are used to reproduce various cases.

```yaml {caption="[File 3] shell Pod Manifest", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: shell
  labels:
    app: shell
spec:
  containers:
  - name: shell
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
```

```proto {caption="[File 4] mock-server gRPC Service Definition", linenos=table}
syntax = "proto3";

package mock;

option go_package = "mock-go-server/proto";

service MockService {
  // Return specific status code
  rpc Status(StatusRequest) returns (StatusResponse);

  // Delay response
  rpc Delay(DelayRequest) returns (DelayResponse);

  // Server closes connection before response after delay
  rpc CloseBeforeResponse(CloseRequest) returns (Empty);

  // Server sends dummy data, then closes connection
  rpc CloseAfterResponse(CloseRequest) returns (stream CloseStreamResponse);

  // Server sends wrong protocol data after delay
  rpc WrongProtocol(WrongProtocolRequest) returns (Empty);

  // Server sends RST before response after delay
  rpc ResetBeforeResponse(ResetRequest) returns (Empty);

  // Server sends dummy data, then RST
  rpc ResetAfterResponse(ResetRequest) returns (stream ResetStreamResponse);
}

message CloseRequest {
  int32 milliseconds = 1;
}

message CloseStreamResponse {
  int32 sequence = 1;
  bytes data = 2;
}

message WrongProtocolRequest {
  int32 milliseconds = 1;
}

message ResetRequest {
  int32 milliseconds = 1;
}

message ResetStreamResponse {
  int32 sequence = 1;        // Message sequence number
  bytes data = 2;            // Payload data
}

message Empty {}

message StatusRequest {
  int32 code = 1;
}

message StatusResponse {
  int32 status_code = 1;
  string service = 2;
  string message = 3;
}

message DelayRequest {
  int32 milliseconds = 1;
}

message DelayResponse {
  string service = 1;
  int32 delayed_ms = 2;
  string message = 3;
}
```

```shell {caption="[Shell 2] Copy mock.proto to shell Pod", linenos=table}
$ kubectl cp mock.proto shell:mock.proto
```

[File 3] shows the Manifest for the `shell` Pod. The `shell` Pod is created using the netshoot Image, with Network Admin privileges to enable the use of the `iptables` command. [File 4] shows the Proto file for calling the `mock-server` gRPC Service using the `grpcurl` command. [Shell 2] shows an example of copying the Proto file to the `shell` Pod.

### 1.2. HTTP Cases

#### 1.2.1. OK Case

{{< figure caption="[Figure 2] HTTP OK Case" src="images/http-ok-case.png" width="1000px" >}}

```shell {caption="[Shell 3] HTTP OK Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
{"message":"OK","service":"mock-server","status_code":200}
```

[Figure 2] shows the HTTP OK Case where a `GET` request is sent to the `mock-server`'s `/status/200` Endpoint using the `curl` command from the `shell` Pod, and a `200 OK` response is received. [Shell 3] shows an example of executing [Figure 2].

```json {caption="[Text 2] HTTP OK Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-14T15:04:12.558Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "59",
  "duration": "10",
  "upstream_service_time": "6",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "0432d33a-0ffb-94fc-98fc-b9b322d5eaa3",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.3:45178",
  "downstream_local_address": "10.96.191.168:8080",
  "downstream_remote_address": "10.244.2.3:34226",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "10"
}
```

```json {caption="[Text 3] HTTP OK Case / mock-server Access Log", linenos=table}
{
  "start_time": "2025-12-14T15:04:12.563Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "59",
  "duration": "4",
  "upstream_service_time": "3",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "0432d33a-0ffb-94fc-98fc-b9b322d5eaa3",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:46243",
  "downstream_local_address": "10.244.1.4:8080",
  "downstream_remote_address": "10.244.2.3:45178",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "4"
}
```

[Text 2] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 3] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/status/200` Endpoint and the `200 OK` response.

#### 1.2.2. Service Unavailable Case

{{< figure caption="[Figure 3] HTTP Service Unavailable Case" src="images/http-service-unavailable-case.png" width="1000px" >}}

```shell {caption="[Shell 4] HTTP Service Unavailable Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
```

[Figure 3] shows the HTTP Service Unavailable Case where a `GET` request is sent to the `mock-server`'s `/status/503` Endpoint using the `curl` command from the `shell` Pod, and a `503 Service Unavailable` response is received. [Shell 4] shows an example of executing [Figure 3].

```json {caption="[Text 4] HTTP Service Unavailable Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-28T12:47:37.317Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "56",
  "upstream_service_time": "52",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "af4ab845-948b-9669-8bae-384dc22cf9f7",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.11:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.6:39692",
  "downstream_local_address": "10.96.95.31:8080",
  "downstream_remote_address": "10.244.1.6:52850",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "56"
}
```

```json {caption="[Text 5] HTTP Service Unavailable Case / mock-server Access Log", linenos=table}
{
  "start_time": "2025-12-28T12:47:37.325Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "37",
  "upstream_service_time": "25",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "af4ab845-948b-9669-8bae-384dc22cf9f7",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.11:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:36269",
  "downstream_local_address": "10.244.2.11:8080",
  "downstream_remote_address": "10.244.1.6:39692",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "2",
  "response_duration": "36"
}
```

[Text 4] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 5] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/status/503` Endpoint and the `503 Service Unavailable` response.

#### 1.2.3. Downstream TCP RST Case

{{< figure caption="[Figure 4] Downstream TCP RST Case" src="images/http-downstream-tcp-rst-case.png" width="1000px" >}}

```shell {caption="[Shell 5] Downstream TCP RST Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/5000
^C
```

[Figure 4] shows the Downstream TCP RST Case where a `GET` request is sent to the `mock-server`'s `/delay/10000` Endpoint using the `curl` command from the `shell` Pod, and the request is forcefully terminated using `Ctrl+C` before 5000ms passes. [Shell 5] shows an example of executing [Figure 4].

When the `curl` command is forcefully terminated during execution, the `curl` command internally terminates the Connection and sends a TCP FIN Flag to the `curl` Pod's `istio-proxy`. The `curl` Pod's `istio-proxy` that received the TCP FIN Flag sends a TCP RST Flag to the `mock-server` Pod, which is ultimately delivered to the `mock-server` Container. Afterward, the `mock-server` Pod's `istio-proxy` sends a TCP RST Flag after the TCP FIN Flag because it was an unexpected client Connection termination.

```json {caption="[Text 6] Downstream TCP RST Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T11:29:33.615Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "0",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "2966",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "dfa53579-b29c-9787-9719-10e42ca2cf98",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.7:47142",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:40350",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 7] Downstream TCP RST Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T11:29:33.616Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "0",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "2972",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "dfa53579-b29c-9787-9719-10e42ca2cf98",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:34691",
  "downstream_local_address": "10.244.2.17:8080",
  "downstream_remote_address": "10.244.1.7:47142",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 6] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 7] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/delay/5000` Endpoint and `response_code` showing as `0`. Also, `response_flags` showing as `DC (DownstreamConnectionTermination)` can be confirmed.

#### 1.2.4. Upstream TCP RST before Response Case

{{< figure caption="[Figure 5] Upstream TCP RST before Response Case" src="images/http-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 6] Upstream TCP RST before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 5] shows the Upstream TCP RST before Response Case where a `GET` request is sent to the `mock-server`'s `/reset-before-response/1000` Endpoint using the `curl` command from the `shell` Pod, and after `1000ms`, the `mock-server` Pod sends a TCP RST Flag to forcefully terminate the Connection. [Shell 6] shows an example of executing [Figure 5].

When the `mock-server` Pod's `istio-proxy` receives a TCP RST Flag from the `mock-server` Container, it does not send a TCP RST Flag to the `shell` Pod but sends a `503 Service Unavailable` response. Therefore, the `shell` Pod's `istio-proxy` Access Log does not have `response_flags` and only shows the `503 Service Unavailable` response.

```json {caption="[Text 8] Upstream TCP RST before Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T11:58:47.152Z",
  "method": "GET",
  "path": "/reset-before-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1077",
  "upstream_service_time": "1063",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "65cb201d-5b20-9321-8550-8749675883ee",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.7:49326",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:55326",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1075"
}
```

```json {caption="[Text 9] Upstream TCP RST before Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T11:58:47.167Z",
  "method": "GET",
  "path": "/reset-before-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1047",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "65cb201d-5b20-9321-8550-8749675883ee",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:33619",
  "downstream_local_address": "10.244.2.17:8080",
  "downstream_remote_address": "10.244.1.7:49326",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "1",
  "response_duration": "-"
}
```

[Text 8] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 9] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/reset-before-response/1000` Endpoint and the `503 Service Unavailable` response. Also, `response_flags` showing as `UC (UpstreamConnectionTermination)` can be confirmed, and `response_code_details` shows `upstream_reset_before_response_started{connection_termination}`, indicating that a TCP RST Flag was sent from the Upstream before the response started.

#### 1.2.5. Upstream TCP RST after Response Case

{{< figure caption="[Figure 6] Upstream TCP RST after Response Case" src="images/http-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 7] Upstream TCP RST after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-after-response/1000
curl: (18) transfer closed with outstanding read data remaining
dummy datacommand terminated with exit code 18
```

[Figure 6] shows the Upstream TCP RST after Response Case where a `GET` request is sent to the `mock-server`'s `/reset-after-response/1000` Endpoint using the `curl` command from the `shell` Pod, and after `1000ms`, the `mock-server` Pod sends a partial response and then sends a TCP RST Flag to forcefully terminate the Connection. [Shell 7] shows an example of executing [Figure 6].

When the `mock-server` Pod's `istio-proxy` receives a TCP RST Flag, it sends a TCP FIN Flag to the `shell` Pod to terminate the TCP Connection. Also, since it was an unexpected Connection termination, a TCP RST Flag is sent after the TCP RST Flag.

```json {caption="[Text 10] Upstream TCP RST after Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T12:47:45.064Z",
  "method": "GET",
  "path": "/reset-after-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "UPE",
  "response_code_details": "upstream_reset_after_response_started{protocol_error}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "10",
  "duration": "2023",
  "upstream_service_time": "1006",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "4b388e57-8df0-9198-b9a8-3f72f0865739",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.7:52250",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:59530",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1007"
}
```

```json {caption="[Text 11] Upstream TCP RST after Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-01T12:47:45.066Z",
  "method": "GET",
  "path": "/reset-after-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "UPE",
  "response_code_details": "upstream_reset_after_response_started{protocol_error}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "10",
  "duration": "1017",
  "upstream_service_time": "1003",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "4b388e57-8df0-9198-b9a8-3f72f0865739",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.17:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:44401",
  "downstream_local_address": "10.244.2.17:8080",
  "downstream_remote_address": "10.244.1.7:52250",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1004"
}
```

[Text 10] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 11] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/reset-after-response/1000` Endpoint and the `200 OK` response. Also, `response_flags` showing as `UPE (UpstreamProtocolError)` can be confirmed.

`response_code_details` shows `upstream_reset_after_response_started{protocol_error}`, indicating that a TCP RST Flag was sent from the Upstream after partial response transmission. The Protocol Error occurs because the TCP RST Flag was sent from the Upstream before the complete HTTP response was transmitted.

#### 1.2.6. Upstream TCP Close before Response Case

{{< figure caption="[Figure 7] Upstream TCP Close before Response Case" src="images/http-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 8] Upstream TCP Close before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 7] shows the Upstream TCP Close before Response Case where a `GET` request is sent to the `mock-server`'s `/close-before-response/1000` Endpoint using the `curl` command from the `shell` Pod, and after `1000ms`, the `mock-server` Pod forcefully terminates the Connection. [Shell 8] shows an example of executing [Figure 7].

When the `mock-server` Pod's `istio-proxy` receives a TCP FIN Flag from the `mock-server` Container, it sends a 503 Service Unavailable response to the `shell` Pod to indicate that the request was abnormally terminated.

```json {caption="[Text 12] Upstream TCP Connection Close Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T08:00:51.487Z",
  "method": "GET",
  "path": "/close-before-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1004",
  "upstream_service_time": "1003",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "4fa56d4c-a9ce-9fa3-b938-9c99162e5b74",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.22:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:45602",
  "downstream_local_address": "10.96.211.131:8080",
  "downstream_remote_address": "10.244.1.8:55556",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1004"
}
```

```json {caption="[Text 13] Upstream TCP Connection Close Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T08:00:51.488Z",
  "method": "GET",
  "path": "/close-before-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1002",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "4fa56d4c-a9ce-9fa3-b938-9c99162e5b74",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.22:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:48343",
  "downstream_local_address": "10.244.2.22:8080",
  "downstream_remote_address": "10.244.1.8:45602",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 12] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 13] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/disconnect/1000` Endpoint and the `503 Service Unavailable` response. Also, `response_flags` showing as `UC (UpstreamConnectionTermination)` can be confirmed.

`response_code_details` shows `upstream_reset_before_response_started{connection_termination}`, indicating that a TCP FIN Flag was sent from the Upstream before the response started. This is the same detail as when receiving a TCP RST Flag in [Figure 5], confirming that the `mock-server` Pod's `istio-proxy` logs the same `response_code_details` when receiving either a TCP FIN Flag or TCP RST Flag before the response is sent.

#### 1.2.7. Upstream TCP Close after Response Case

{{< figure caption="[Figure 8] Upstream TCP Close after Response Case" src="images/http-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 9] Upstream TCP Close after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-after-response/1000
dummy datacommand terminated with exit code 18
```

[Figure 8] shows the Upstream TCP Close after Response Case where a `GET` request is sent to the `mock-server`'s `/close-after-response/1000` Endpoint using the `curl` command from the `shell` Pod, and after `1000ms`, the `mock-server` Pod sends a response and then forcefully terminates the Connection. [Shell 9] shows an example of executing [Figure 8].

When the `mock-server` Pod's `istio-proxy` receives a TCP FIN Flag from the `mock-server` Container, it sends a 503 Service Unavailable response to the `shell` Pod to indicate that the request was abnormally terminated.

```json {caption="[Text 14] Upstream TCP Close after Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T08:01:36.305Z",
  "method": "GET",
  "path": "/close-after-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "UPE",
  "response_code_details": "upstream_reset_after_response_started{protocol_error}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "10",
  "duration": "2110",
  "upstream_service_time": "1008",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "feab8e89-b2ac-9992-add8-0c67d8624427",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.22:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:52206",
  "downstream_local_address": "10.96.211.131:8080",
  "downstream_remote_address": "10.244.1.8:33028",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1009"
}
```

```json {caption="[Text 15] Upstream TCP Close after Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T08:01:36.307Z",
  "method": "GET",
  "path": "/close-after-response/1000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "UPE",
  "response_code_details": "upstream_reset_after_response_started{protocol_error}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "10",
  "duration": "1109",
  "upstream_service_time": "1002",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "feab8e89-b2ac-9992-add8-0c67d8624427",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.22:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58855",
  "downstream_local_address": "10.244.2.22:8080",
  "downstream_remote_address": "10.244.1.8:52206",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1007"
}
```

[Text 14] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 15] shows the Access Log of the `mock-server`'s `istio-proxy`. Both Access Logs confirm the access to the `/close-after-response/1000` Endpoint and the `200 OK` response. Also, `response_flags` showing as `UPE (UpstreamProtocolError)` can be confirmed.

`response_code_details` shows `upstream_reset_after_response_started{protocol_error}`, indicating that a Protocol Error occurred and the Connection was forcefully terminated after the response started. This is the same detail as when receiving a TCP RST Flag in [Figure 6], confirming that the `mock-server` Pod's `istio-proxy` logs the same `response_code_details` when receiving either a TCP FIN Flag or TCP RST Flag after partial response transmission.

#### 1.2.8. Circuit Breaking with Upstream Connection Pool Overflow Case

{{< figure caption="[Figure 9] Circuit Breaking with Upstream Connection Pool Overflow Case" src="images/http-circuit-breaking-with-upstream-connection-pool-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 10] Circuit Breaking with Upstream Connection Pool Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
```

[Figure 9] shows the Case where 3 consecutive `GET` requests are sent to the `mock-server`'s `/delay/5000` Endpoint using the `curl` command from the `shell` Pod, causing Upstream Overflow and triggering Circuit Breaking. [Shell 10] shows an example of executing [Figure 9].

Due to the Destination Rule in [File 1], the first request is immediately forwarded to the `mock-server` Pod and completes with a `200 OK` response after waiting 5000ms. The second request is Pending because the first request is being processed and waits until the first request finishes before being forwarded to the `mock-server` Pod. Therefore, the time for the second request to be processed is 5000ms + 5000ms = 10000ms. The third request cannot even be Pending, so `istio-proxy` considers it Upstream Overflow and triggers Circuit Breaking, sending a `503 Service Unavailable` response.

```json {caption="[Text 16] Circuit Breaking with Upstream Connection Pool Overflow Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-22T16:08:03.507Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "81",
  "duration": "2",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "4c299e03-e57f-9613-8817-6682e9deb675",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:55486",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-22T16:08:02.442Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "5011",
  "upstream_service_time": "5010",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "8d667b79-534b-9d95-a3a7-4b2fa17263e6",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:58132",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:55470",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5011"
}
{
  "start_time": "2025-12-22T16:08:02.847Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "9615",
  "upstream_service_time": "9615",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "afe67ad1-54bd-9a82-b947-6fe65a1dfe69",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:58134",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:55472",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "9615"
}
```

```json {caption="[Text 17] Circuit Breaking with Upstream Connection Pool Overflow Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2025-12-22T16:08:02.443Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "5008",
  "upstream_service_time": "5008",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "8d667b79-534b-9d95-a3a7-4b2fa17263e6",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:52515",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:58132",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5008"
}
{
  "start_time": "2025-12-22T16:08:07.456Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "5004",
  "upstream_service_time": "5003",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "afe67ad1-54bd-9a82-b947-6fe65a1dfe69",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:49425",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:58134",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5004"
}
```

[Text 16] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 17] shows the Access Log of the `mock-server`'s `istio-proxy`. In the `shell` Pod's `istio-proxy` Access Log, the first log recorded is for the third request which failed immediately due to Upstream Connection Pool Overflow. `response_flags` showing as `UO (UpstreamOverflow)` can be confirmed, and comparing `start_time` with other logs confirms it started last. The second log is for the first request, and the third log is for the second request. `response_duration` can be confirmed as 5000ms and 10000ms respectively.

In the `mock-server` Pod's `istio-proxy` Access Log, only logs for the first and second requests exist, and `response_duration` can be confirmed as 5000ms for both. The third request was not forwarded to the `mock-server` Pod due to Upstream Connection Pool Overflow at the `shell` Pod's `istio-proxy`, so there is no log for the third request in the `mock-server` Pod's `istio-proxy`.

#### 1.2.9. Circuit Breaking with Upstream Request Limit Overflow Case

{{< figure caption="[Figure 9] Circuit Breaking with Upstream Request Limit Overflow Case" src="images/http-circuit-breaking-with-upstream-request-limit-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 11] Circuit Breaking with Upstream Request Limit Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
```

[Figure 9] shows the Case where 3 consecutive `GET` requests are sent to the `mock-server`'s `/delay/5000` Endpoint using the `curl` command from the `shell` Pod, causing Upstream Request Limit Overflow. To reproduce this Case, the Destination Rule set in [File 2] must be applied. [Shell 11] shows an example of executing [Figure 9].

Due to the Destination Rule settings in [File 2], the maximum concurrent requests that can be processed is one and request Pending is not possible, so the second and third requests are not forwarded to the `mock-server` Pod due to Upstream Overflow.

```json {caption="[Text 18] Circuit Breaking with Request Limit Upstream Overflow Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-03T15:23:06.371Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "81",
  "duration": "4",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "1f7ca280-0458-94b0-b520-f62a4d7655f7",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:47206",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-03T15:23:06.694Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "81",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "e844139f-1dd6-91f4-9acd-f3511058cc52",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:47210",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-03T15:23:06.118Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "5017",
  "upstream_service_time": "5016",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "99a50488-a899-9a8c-ab1b-07867b2ba1fd",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.7:56360",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:47198",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5017"
}
```

```json {caption="[Text 19] Circuit Breaking with Request Limit Upstream Overflow Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-03T15:23:06.121Z",
  "method": "GET",
  "path": "/delay/5000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "83",
  "duration": "5008",
  "upstream_service_time": "5007",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "99a50488-a899-9a8c-ab1b-07867b2ba1fd",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:51333",
  "downstream_local_address": "10.244.2.18:8080",
  "downstream_remote_address": "10.244.1.7:56360",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5007"
}
```

[Text 18] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 19] shows the Access Log of the `mock-server` Pod's `istio-proxy`. In the `shell` Pod's `istio-proxy` Access Log, the first logs recorded are for the second and third requests which failed immediately due to Upstream Request Limit Overflow. The first log is for the second request, and the second log is for the third request. Both show `response_flags` as `UO (UpstreamOverflow)`. The last log is for the first request, which was successfully forwarded to the `mock-server` Pod and processed.

#### 1.2.10. Circuit Breaking with No Healthy Upstream Case

{{< figure caption="[Figure 10] Circuit Breaking with No Healthy Upstream Case" src="images/http-circuit-breaking-with-no-healthy-upstream-case.png" width="1000px" >}}

```shell {caption="[Shell 12] Circuit Breaking with No Healthy Upstream Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
no healthy upstream
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
no healthy upstream
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
no healthy upstream
```

[Figure 10] shows the Case where 8 consecutive `GET` requests are sent to the `mock-server`'s `/status/503` Endpoint using the `curl` command from the `shell` Pod, causing Circuit Breaking through No Healthy Upstream. [Shell 12] shows an example of executing [Figure 10].

Due to the Destination Rule in [File 1], Circuit Breaking activates when 5 consecutive 5XX Errors occur. Therefore, the first 5 requests from the `shell` Pod are all forwarded to the `mock-server` Pod, but the subsequent 3 requests are not forwarded to the `mock-server` Pod due to Circuit Breaking.

```json {caption="[Text 20] Circuit Breaking with No Healthy Upstream Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-22T12:23:20.109Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "42",
  "upstream_service_time": "37",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "464940f1-963a-90e4-8deb-172245eac437",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:48362",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:60748",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "42"
}
{
  "start_time": "2025-12-22T12:23:24.234Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "2",
  "upstream_service_time": "2",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "75817232-e306-94d0-89f7-095718dbe70d",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:48372",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:60750",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "2"
}
{
  "start_time": "2025-12-22T12:23:25.743Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "1",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "9de7cc1c-f93b-9cf3-9db8-53f29de86d1b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:48372",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:60756",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:26.981Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "80ee43d3-af9a-9aa3-bfc1-a288fb7d64a1",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:48362",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:41660",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:28.384Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "1",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "411cedbf-1f1c-9d16-8ea1-6a10678fdd6d",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.3:48372",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:41676",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:29.590Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "f8dc8df5-a957-93d1-92aa-226110d9dd10",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:41690",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-22T12:23:31.367Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "0ff441a9-9bfd-9c10-8911-5b6c079dd31a",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:41702",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-22T12:23:40.187Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "c1becf45-cf49-9262-9df1-a74f63190b6b",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:37202",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 21] Circuit Breaking with No Healthy Upstream Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2025-12-22T12:23:20.129Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "6",
  "upstream_service_time": "4",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "464940f1-963a-90e4-8deb-172245eac437",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58085",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:48362",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "6"
}
{
  "start_time": "2025-12-22T12:23:24.236Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "75817232-e306-94d0-89f7-095718dbe70d",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58085",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:48372",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:25.743Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "9de7cc1c-f93b-9cf3-9db8-53f29de86d1b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58085",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:48372",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:26.981Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "80ee43d3-af9a-9aa3-bfc1-a288fb7d64a1",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58085",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:48362",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-22T12:23:28.384Z",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "76",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "411cedbf-1f1c-9d16-8ea1-6a10678fdd6d",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:58085",
  "downstream_local_address": "10.244.2.4:8080",
  "downstream_remote_address": "10.244.1.3:48372",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
```

[Text 20] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 21] shows the Access Log of the `mock-server` Pod's `istio-proxy`. In the `shell` Pod's `istio-proxy` Access Log, only the last 3 requests show `response_flags` as `UH (NoHealthyUpstream)` and were not forwarded to the `mock-server` Pod. Also, in the `mock-server` Pod's `istio-proxy` Access Log, only logs for the first 5 requests exist.

#### 1.2.11. Upstream Connection Failure with Timeout

{{< figure caption="[Figure 11] Upstream Connection Failure with Timeout" src="images/http-upstream-connection-failure-case-with-timeout.png" width="1000px" >}}

```shell {caption="[Shell 13] Upstream Connection Failure with Timeout / iptables & curl Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables -A INPUT -s ${SHELL_IP} -j DROP
# $ kubectl exec mock-server -c mock-server -- iptables -D INPUT 1 remove rule after case execution

$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
no healthy upstream
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
no healthy upstream
```

[Figure 11] shows the Upstream Connection Failure with Timeout Case where a connection to the `mock-server`'s `/status/200` Endpoint from the `shell` Pod using the `curl` command fails due to Timeout and is Retried. [Shell 13] shows an example of executing [Figure 11]. To trigger the Timeout, a rule is added using the `iptables` command to `DROP` traffic from the `shell` Pod's IP Address, and then a request is sent using the `curl` command.

Due to the Virtual Service's `connect-failure` setting in [File 1], 2 retries occur for a total of 3 requests. Therefore, the first request from the `shell` Pod performs 3 retries and then outputs a `connection timeout` error. The second request from the `shell` Pod triggers only 1 retry for a total of 2 requests, because Circuit Breaking activates when 5 consecutive 5XX Errors occur due to the Destination Rule in [File 1].

The first request's 3 requests and the second request's 2nd request, a total of 5 requests occurred and all failed due to Timeout, so it determines there is no Healthy Upstream and Circuit Breaking activates. Therefore, the second request's 2nd retry is not sent to the `mock-server` Pod due to Circuit Breaking, and the second request outputs a `no healthy upstream` error. The third request immediately outputs a `no healthy upstream` error due to Circuit Breaking.

```json {caption="[Text 22] Upstream Connection Failure with Timeout / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-21T07:17:42.331Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "URX,UF",
  "response_code_details": "upstream_reset_before_response_started{connection_timeout}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "114",
  "duration": "30066",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "78343cc2-d6f2-9a5d-8dff-84c7ea3596c3",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.12:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.225.216:8080",
  "downstream_remote_address": "10.244.2.5:35248",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-21T07:18:15.580Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "20062",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "575b956c-0e96-9471-a21f-0555763492ab",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.12:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.225.216:8080",
  "downstream_remote_address": "10.244.2.5:46700",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-21T07:18:38.162Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "24be226c-274c-9948-bb96-88df90492bdf",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.225.216:8080",
  "downstream_remote_address": "10.244.2.5:33536",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 22] shows the Access Log of the `shell` Pod's `istio-proxy`. Since requests from the `shell` Pod are not forwarded to the `mock-server` Pod by `istio-proxy`, nothing is logged in the `mock-server` Pod's `istio-proxy` Access Log. The first request shows `response_flags` as `URX (UpstreamRetryLimitExceeded)` and `UF (UpstreamConnectionFailure)`, and `response_code_details` shows `upstream_reset_before_response_started{connection_timeout}`, confirming a Connection Timeout occurred. `upstream_request_attempt_count` shows as `3`.

The second and third requests show `response_flags` as `UH (NoHealthyUpstream)` due to Circuit Breaking, and `response_code_details` shows `no_healthy_upstream`. The second request shows `upstream_request_attempt_count` as `3`. The third request shows `upstream_request_attempt_count` as `1`.

#### 1.2.12. Upstream Connection Failure with TCP Reset

{{< figure caption="[Figure 12] Upstream Connection Failure with TCP Reset" src="images/http-upstream-connection-failure-case-with-tcp-reset.png" width="1000px" >}}

```shell {caption="[Shell 14] Upstream Connection Failure with TCP Reset / iptables & curl Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables-legacy -A INPUT -p tcp -s ${SHELL_IP} -j REJECT --reject-with tcp-reset
# $ kubectl exec mock-server -c mock-server -- iptables-legacy -D INPUT 1 remove rule after case execution

$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
no healthy upstream
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
no healthy upstream
```

[Figure 12] shows the Upstream Connection Failure with TCP Reset Case where a connection to the `mock-server`'s `/status/200` Endpoint from the `shell` Pod using the `curl` command fails due to TCP Reset and is Retried. [Shell 14] shows an example of executing [Figure 12]. To trigger TCP Reset, a rule is added using the `iptables` command to `REJECT` traffic from the `shell` Pod's IP Address, and then a request is sent using the `curl` command. Except for the `Connection Refused` error message, it shows the same results as the Case where Retry is performed due to Timeout.

```json {caption="[Text 23] Upstream Connection Failure with TCP Reset / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-22T17:09:54.276Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "URX,UF",
  "response_code_details": "upstream_reset_before_response_started{remote_connection_failure|delayed_connect_error:_Connection_refused}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "delayed_connect_error:_Connection_refused",
  "bytes_received": "0",
  "bytes_sent": "190",
  "duration": "63",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "6e0d7462-2323-9e73-8dcf-43701a368edb",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:36360",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-22T17:09:56.768Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "delayed_connect_error:_Connection_refused",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "17",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "af1888dc-b298-9c53-8d44-ed21a0da304f",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:36368",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2025-12-22T17:10:00.420Z",
  "method": "GET",
  "path": "/status/200",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "19",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "9b901845-b436-95f3-89d1-868d9acd05ac",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.90.250:8080",
  "downstream_remote_address": "10.244.1.3:36370",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 23] shows the Access Log of the `shell` Pod's `istio-proxy`. Since requests from the `shell` Pod are not forwarded to the `mock-server` Pod by `istio-proxy`, nothing is logged in the `mock-server` Pod's `istio-proxy` Access Log. `response_code_details` shows `upstream_reset_before_response_started{remote_connection_failure|delayed_connect_error:_Connection_refused}`, confirming that Remote Connection Failure and Delayed Connect Error occurred. Except for this part, it shows the same results as the Case where Retry is performed due to Timeout.

#### 1.2.13. Upstream Request Timeout Case

{{< figure caption="[Figure 13] Upstream Request Timeout Case" src="images/http-upstream-request-timeout-case.png" width="1000px" >}}

```shell {caption="[Shell 15] Upstream Request Timeout Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/70000
```

[Figure 13] shows the Upstream Request Timeout Case where a `GET` request is sent to the `mock-server`'s `/delay/70000` Endpoint from the `shell` Pod using the `curl` command, but the `mock-server` Pod's `istio-proxy` does not receive a response after waiting 60000ms and processes the Request as Timeout. [Shell 15] shows an example of executing [Figure 13].

Due to the Virtual Service in [File 1], requests sent to the `mock-server` Pod can wait up to 60000ms. However, the request sent to the `mock-server` Pod's `/delay/70000` Endpoint requires 70000ms, so a Timeout occurs. When a Timeout occurs, the `mock-server` Pod's `istio-proxy` sends TCP FIN Flag and TCP RST Flag sequentially to terminate the connection with the `mock-server` Pod. It also sends a `504 Gateway Timeout` response to the `shell` Container.

```json {caption="[Text 24] Upstream Timeout Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T16:07:19.812Z",
  "method": "GET",
  "path": "/delay/70000",
  "protocol": "HTTP/1.1",
  "response_code": "504",
  "response_flags": "UT",
  "response_code_details": "response_timeout",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "24",
  "duration": "60022",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "da28cc83-9055-9ed5-8c0e-104bf3337a0c",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.23:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:37022",
  "downstream_local_address": "10.96.1.12:8080",
  "downstream_remote_address": "10.244.1.8:37910",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 25] Upstream Timeout Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T16:07:19.851Z",
  "method": "GET",
  "path": "/delay/70000",
  "protocol": "HTTP/1.1",
  "response_code": "0",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "59989",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "da28cc83-9055-9ed5-8c0e-104bf3337a0c",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.23:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:52563",
  "downstream_local_address": "10.244.2.23:8080",
  "downstream_remote_address": "10.244.1.8:37022",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 24] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 25] shows the Access Log of the `mock-server` Pod's `istio-proxy`. The `shell` Pod's `istio-proxy` shows `response_flags` as `UT (UpstreamTimeout)`. The `mock-server` Pod's `istio-proxy` shows `response_flags` as `DC (DownstreamConnectionTermination)`.

### 1.3. GRPC Cases

#### 1.3.1. OK Case

{{< figure caption="[Figure 14] OK Case" src="images/grpc-ok-case.png" width="1000px" >}}

```shell {caption="[Shell 16] OK Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
{
  "service": "mock-server",
  "message": "OK"
}
```

[Figure 14] shows the OK Case where the `grpcurl` command is used from the `shell` Pod to send a `code: 0` request to the `mock-server`'s `/mock.MockService/Status` function and receive an `OK` response. [Shell 16] shows an example of executing [Figure 14].

```json {caption="[Text 26] OK Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T11:18:51.880Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "5",
  "bytes_sent": "22",
  "duration": "2",
  "upstream_service_time": "1",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "7eb9994b-2491-9e41-9094-7664914a3692",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:58590",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:53152",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "2"
}
```

```json {caption="[Text 27] OK Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T11:18:51.881Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "5",
  "bytes_sent": "22",
  "duration": "1",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "7eb9994b-2491-9e41-9094-7664914a3692",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:43691",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:58590",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
```

[Text 26] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 27] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/Status` function and `grpc_status` as `OK`.

#### 1.3.2. Unavailable Case

{{< figure caption="[Figure 15] Unavailable Case" src="images/grpc-unavailable-case.png" width="1000px" >}}

```shell {caption="[Shell 17] Unavailable Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 14}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: Simulated error with gRPC code 14 (Unavailable)
command terminated with exit code 78
```

[Figure 15] shows the Unavailable Case where the `grpcurl` command is used from the `shell` Pod to send a `code: 14` request to the `mock-server`'s `/mock.MockService/Status` function and receive an `Unavailable` response. [Shell 17] shows an example of executing [Figure 15].

```json {caption="[Text 28] Unavailable Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T14:38:10.298Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "347",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "36a44aa4-990b-9db5-8c98-d00d5b7acbf8",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:46440",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:33238",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "46",
  "response_duration": "304"
}
```

```json {caption="[Text 29] Unavailable Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T14:38:10.601Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "1",
  "upstream_service_time": "1",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "36a44aa4-990b-9db5-8c98-d00d5b7acbf8",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42649",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:46440",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
```

[Text 28] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 29] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/Status` function and `grpc_status` as `Unavailable`. Also, `response_code` shows `200 OK`, and when using gRPC, `response_code` always shows `200 OK` regardless of the gRPC result.

#### 1.3.3. Downstream HTTP/2 RST_STREAM Case

{{< figure caption="[Figure 16] Downstream HTTP/2 RST_STREAM Case" src="images/grpc-downstream-http2-rst-stream-case.png" width="1000px" >}}

```shell {caption="[Shell 18] Downstream HTTP/2 RST_STREAM Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay
^C
```

[Figure 16] shows the Downstream HTTP/2 RST_STREAM Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 5000` request to the `mock-server`'s `/mock.MockService/Delay` function, and forcefully terminates the request using `Ctrl+C` before 5000ms passes. [Shell 18] shows an example of executing [Figure 16].

When the `grpcurl` command is forcefully terminated during execution, the `grpcurl` command sends a TCP FIN Flag to the `shell` Pod's `istio-proxy`, and the `shell` Pod's `istio-proxy` sends an HTTP/2 RST_STREAM Frame instead of TCP FIN Flag to the `mock-server` Pod, which is ultimately delivered to the `mock-server` Container to terminate the connection.

```json {caption="[Text 30] Downstream Reset Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-05T14:41:20.286Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "0",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "778",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b62ed186-f4a0-9f38-b6a9-e5d351c626c9",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.19:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:58320",
  "downstream_local_address": "10.96.212.50:9090",
  "downstream_remote_address": "10.244.1.8:53602",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "8",
  "response_duration": "-"
}
```

```json {caption="[Text 31] Downstream Remote Disconnect Case / mock-server Pod Access Log", linenos=table} 
{
  "start_time": "2026-01-05T14:41:20.300Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "0",
  "response_flags": "DR",
  "response_code_details": "http2.remote_reset",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "778",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b62ed186-f4a0-9f38-b6a9-e5d351c626c9",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.19:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:52919",
  "downstream_local_address": "10.244.2.19:9090",
  "downstream_remote_address": "10.244.1.8:58320",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "8",
  "response_duration": "-"
}
```

[Text 30] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 31] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/Delay` function with `response_code` as `0` and `grpc_status` as `-`.

Also, the `shell` Pod's `istio-proxy` shows `response_flags` as `DC (DownstreamConnectionTermination)` because it receives TCP FIN Flag from the `grpcurl` command, and the `mock-server` Pod's `istio-proxy` shows `response_flags` as `DR (DownstreamRemoteReset)` because it receives HTTP/2 RST_STREAM Frame.

#### 1.3.4. Upstream TCP RST before Response Case

{{< figure caption="[Figure 17] Upstream TCP RST before Response Case" src="images/grpc-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 19] Upstream TCP RST before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/ResetBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 17] shows the Upstream TCP RST before Response Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 1000` request to the `mock-server`'s `/mock.MockService/ResetBeforeResponse` function, and after waiting 1000ms, a TCP RST Flag is sent to forcefully terminate the Connection. [Shell 19] shows an example of executing [Figure 17].

The `mock-server` Pod's `istio-proxy` that receives the TCP RST Flag returns an `Unavailable` status code to notify the `shell` Pod's `istio-proxy` that the request was abnormally terminated. Due to the `unavailable` setting in the Virtual Service in [File 1], the `shell` Pod's `istio-proxy` performs 2 retries for a total of 3 requests.

```json {caption="[Text 32] Upstream TCP RST before Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-10T15:25:19.861Z",
  "method": "POST",
  "path": "/mock.MockService/ResetBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "3066",
  "upstream_service_time": "3064",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b195727a-1004-9084-931d-ba8c01f7b1e3",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:55012",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:59464",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "1",
  "response_duration": "3065"
}
```

```json {caption="[Text 33] Upstream TCP RST before Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-10T15:25:19.863Z",
  "method": "POST",
  "path": "/mock.MockService/ResetBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1005",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b195727a-1004-9084-931d-ba8c01f7b1e3",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:35179",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:55012",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-10T15:25:20.888Z",
  "method": "POST",
  "path": "/mock.MockService/ResetBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1002",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b195727a-1004-9084-931d-ba8c01f7b1e3",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:53123",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:55012",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-10T15:25:21.922Z",
  "method": "POST",
  "path": "/mock.MockService/ResetBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1003",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b195727a-1004-9084-931d-ba8c01f7b1e3",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:48095",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:55012",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 32] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 33] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/ResetBeforeResponse` function with `response_code` as `200` and `grpc_status` as `Unavailable`. Also, both Access Logs show `response_flags` as `UC (UpstreamConnectionTermination)`.

Since the `shell` Pod's `istio-proxy` sends 3 requests, `upstream_request_attempt_count` shows `3` in the `shell Pod`'s `istio-proxy` Access Log. Also, 3 Access Logs are left in the `mock-server` Pod's `istio-proxy`.

#### 1.3.5. Upstream TCP RST after Response Case

{{< figure caption="[Figure 18] Upstream TCP RST after Response Case" src="images/grpc-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 20] Upstream TCP RST after Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/ResetAfterResponse
kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/ResetAfterResponse
{
  "data": "ZHVtbXkgZGF0YQ=="
}
ERROR:
  Code: Internal
  Message: stream terminated by RST_STREAM with error code: NO_ERROR
command terminated with exit code 77
```

[Figure 18] shows the Upstream TCP RST after Response Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 1000` request to the `mock-server`'s `/mock.MockService/ResetAfterResponse` function, and after `1000ms`, the `mock-server` Pod sends a partial response and then sends a TCP RST Flag to forcefully terminate the Connection. [Shell 20] shows an example of executing [Figure 18].

```json {caption="[Text 34] Upstream TCP RST after Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T06:37:13.914Z",
  "method": "POST",
  "path": "/mock.MockService/ResetAfterResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UR",
  "response_code_details": "upstream_reset_after_response_started{remote_reset}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "17",
  "duration": "1216",
  "upstream_service_time": "1092",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "4d986174-88b0-97b1-88fb-46f493a880e5",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:35336",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:36028",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unknown",
  "upstream_request_attempt_count": "1",
  "request_duration": "9",
  "response_duration": "1101"
}
```

```json {caption="[Text 35] Upstream TCP RST after Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T06:37:13.949Z",
  "method": "POST",
  "path": "/mock.MockService/ResetAfterResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_after_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "17",
  "duration": "1167",
  "upstream_service_time": "1010",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "4d986174-88b0-97b1-88fb-46f493a880e5",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42975",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:35336",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unknown",
  "upstream_request_attempt_count": "1",
  "request_duration": "55",
  "response_duration": "1065"
}
```

[Text 34] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 35] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/ResetAfterResponse` function with `response_code` as `200` and `grpc_status` as `Unknown`. The `shell` Pod's `istio-proxy` Access Log shows `response_flags` as `UR (UpstreamRemoteReset)`, and the `mock-server` Pod's `istio-proxy` Access Log shows `response_flags` as `UC (UpstreamConnectionTermination)`.

#### 1.3.6. Upstream TCP Close before Response Case

{{< figure caption="[Figure 19] Upstream TCP Close before Response Case" src="images/grpc-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 21] Upstream TCP Close before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 19] shows the Upstream TCP Close before Response Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 1000` request to the `mock-server`'s `/mock.MockService/CloseBeforeResponse` function, and after `1000ms`, the `mock-server` Pod forcefully terminates the Connection. [Shell 21] shows an example of executing [Figure 19].

Except for the fact that the `mock-server` Container sends TCP FIN Flag, the same process as [Figure 17] which receives TCP RST Flag is performed.

```json {caption="[Text 36] Upstream TCP Close before Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T11:55:39.852Z",
  "method": "POST",
  "path": "/mock.MockService/CloseBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "3086",
  "upstream_service_time": "3071",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "196a9ef4-4383-9d02-9dbb-9752f082fba6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:45386",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:38082",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "1",
  "response_duration": "3073"
}
```

```json {caption="[Text 37] Upstream TCP Close before Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T11:55:39.855Z",
  "method": "POST",
  "path": "/mock.MockService/CloseBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1006",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "196a9ef4-4383-9d02-9dbb-9752f082fba6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:60797",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:45386",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-11T11:55:40.874Z",
  "method": "POST",
  "path": "/mock.MockService/CloseBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1003",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "196a9ef4-4383-9d02-9dbb-9752f082fba6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:45085",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:45386",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-11T11:55:41.921Z",
  "method": "POST",
  "path": "/mock.MockService/CloseBeforeResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1003",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "196a9ef4-4383-9d02-9dbb-9752f082fba6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:58531",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:45386",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 36] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 37] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/CloseBeforeResponse` function with `response_code` as `200` and `grpc_status` as `Unavailable`. The same process as [Figure 17] which receives TCP RST Flag is performed.

#### 1.3.7. Upstream TCP Close after Response Case

{{< figure caption="[Figure 20] Upstream TCP Close after Response Case" src="images/grpc-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 22] Upstream TCP Close after Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseAfterResponse
ERROR:
  Code: Internal
  Message: stream terminated by RST_STREAM with error code: NO_ERROR
command terminated with exit code 77
```

[Figure 20] shows the Upstream TCP Close after Response Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 1000` request to the `mock-server`'s `/mock.MockService/CloseAfterResponse` function, and after `1000ms`, the `mock-server` Pod sends a partial response and then forcefully terminates the Connection. [Shell 22] shows an example of executing [Figure 20].

Except for the fact that the `mock-server` Container sends TCP FIN Flag, the same process as [Figure 18] which receives TCP RST Flag is performed.

```json {caption="[Text 38] Upstream TCP Close after Response Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T12:12:56.184Z",
  "method": "POST",
  "path": "/mock.MockService/CloseAfterResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UR",
  "response_code_details": "upstream_reset_after_response_started{remote_reset}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "17",
  "duration": "1221",
  "upstream_service_time": "1091",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "5352fc42-1f26-953b-8934-54be55aac934",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:55444",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:45082",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unknown",
  "upstream_request_attempt_count": "1",
  "request_duration": "15",
  "response_duration": "1106"
}
```

```json {caption="[Text 39] Upstream TCP Close before Response Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T12:12:56.215Z",
  "method": "POST",
  "path": "/mock.MockService/CloseAfterResponse",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_after_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "17",
  "duration": "1175",
  "upstream_service_time": "1013",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "5352fc42-1f26-953b-8934-54be55aac934",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:47473",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:55444",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Unknown",
  "upstream_request_attempt_count": "1",
  "request_duration": "61",
  "response_duration": "1074"
}
```

[Text 38] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 39] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Both Access Logs show the access to the `/mock.MockService/CloseAfterResponse` function with `response_code` as `200` and `grpc_status` as `Unknown`. The same process as [Figure 18] which receives TCP RST Flag is performed.

#### 1.3.8. Circuit Breaking with Upstream Connection Pool Overflow Case

{{< figure caption="[Figure 21] Circuit Breaking with Upstream Connection Pool Overflow Case" src="images/grpc-circuit-breaking-with-upstream-connection-pool-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 23] Circuit Breaking with Upstream Connection Pool Overflow Case / grpcurl Command", linenos=table}
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: overflow
command terminated with exit code 78
{
  "service": "mock-server",
  "delayedMs": 5000,
  "message": "Response delayed by 5000ms"
}
{
  "service": "mock-server",
  "delayedMs": 5000,
  "message": "Response delayed by 5000ms"
}
```

[Figure 21] shows the Case where `grpcurl` command is used from the `shell` Pod to send 3 consecutive `milliseconds: 5000` requests to the `mock-server`'s `/mock.MockService/Delay` function, causing Upstream Connection Pool Overflow. [Shell 23] shows an example of executing [Figure 21]. Except for the fact that requests and responses occur via GRPC, the same process as described in [Figure 9] is performed.

```json {caption="[Text 40] Circuit Breaking with Upstream Connection Pool Overflow Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T16:00:42.913Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b3f85437-be22-9083-8193-972ac2f9d0bb",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:52054",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2026-01-11T16:00:42.393Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "5018",
  "upstream_service_time": "5015",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "ab76aaaf-ab05-900c-8c45-162dff809b27",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:53896",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:52044",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5017"
}
{
  "start_time": "2026-01-11T16:00:42.636Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "9784",
  "upstream_service_time": "9783",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "66defa5b-ae78-9fe0-8529-af5dbec52725",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:53896",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:52052",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "9783"
}
```

```json {caption="[Text 41] Circuit Breaking with Upstream Connection Pool Overflow Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-11T16:00:42.395Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "5014",
  "upstream_service_time": "5012",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "ab76aaaf-ab05-900c-8c45-162dff809b27",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:49515",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:53896",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "1",
  "response_duration": "5013"
}
{
  "start_time": "2026-01-11T16:00:47.412Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "5006",
  "upstream_service_time": "5004",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "66defa5b-ae78-9fe0-8529-af5dbec52725",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:49515",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:53896",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "5005"
}
```

[Text 40] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 41] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Except for the fact that requests and responses occur via GRPC, the same process as [Text 16] and [Text 17] is performed.

#### 1.3.9. Circuit Breaking with Upstream Overflow Case

{{< figure caption="[Figure 22] Circuit Breaking with Upstream Overflow Case" src="images/grpc-circuit-breaking-with-upstream-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 24] Circuit Breaking with Upstream Overflow Case / grpcurl Command", linenos=table}
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: overflow
command terminated with exit code 78
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay &
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: overflow
command terminated with exit code 78
```

[Figure 22] shows the Case where `grpcurl` command is used from the `shell` Pod to send 3 consecutive `milliseconds: 5000` requests to the `mock-server`'s `/mock.MockService/Delay` function, causing Upstream Overflow. To reproduce this Case, the Destination Rule configured in [File 2] must be applied. [Shell 24] shows an example of executing [Figure 22]. Except for the fact that requests and responses occur via GRPC, the same process as described in [Figure 9] is performed.

```json {caption="[Text 42] Circuit Breaking with Upstream Overflow Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T14:45:01.595Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "82f56865-fa1b-9fbe-8367-205fcae1dafd",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:42196",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2025-12-25T14:45:01.927Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UO",
  "response_code_details": "upstream_reset_before_response_started{overflow}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "0277cd35-3680-914d-9b1b-e402076d3838",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:42212",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2025-12-25T14:45:01.235Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "5032",
  "upstream_service_time": "5027",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "69957e0b-65a5-97fa-baba-dcc3943f6b67",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:46834",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:42190",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "3",
  "response_duration": "5030"
}
```

```json {caption="[Text 43] Circuit Breaking with Upstream Overflow Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T14:45:01.241Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "49",
  "duration": "5020",
  "upstream_service_time": "5013",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "69957e0b-65a5-97fa-baba-dcc3943f6b67",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:60721",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:46834",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "OK",
  "upstream_request_attempt_count": "1",
  "request_duration": "4",
  "response_duration": "5018"
}
```

[Text 42] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 43] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Except for the fact that requests and responses occur via GRPC, the same process as [Text 18] and [Text 19] is performed.

#### 1.3.10. Circuit Breaking with No Healthy Upstream Case

{{< figure caption="[Figure 23] Circuit Breaking with No Healthy Upstream Case" src="images/grpc-circuit-breaking-with-no-healthy-upstream-case.png" width="1000px" >}}

```shell {caption="[Shell 23] Circuit Breaking with No Healthy Upstream Case / grpcurl Command", linenos=table}
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
```

[Figure 23] shows the Case where `grpcurl` command is used from the `shell` Pod to send 8 consecutive `code: 13` requests to the `mock-server`'s `/mock.MockService/Status` function, causing Circuit Breaking via No Healthy Upstream. [Shell 23] shows an example of executing [Figure 23].

According to the Destination Rule in [File 1], Circuit Breaking is activated when 5 consecutive 5XX Errors occur. Therefore, the first 5 requests from the `shell` Pod are all delivered to the `mock-server` Pod, but the subsequent 3 requests are not delivered to the `mock-server` Pod due to Circuit Breaking. Therefore, the response to the first 5 requests shows `Internal`, and the response to the subsequent 3 requests shows `Unavailable`.

```json {caption="[Text 40] Circuit Breaking Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T15:02:58.363Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "177",
  "upstream_service_time": "138",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "63a34f0f-2ba7-96fe-bf09-a9b557de9e7c",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:42296",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55756",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "38",
  "response_duration": "176"
}
{
  "start_time": "2026-01-12T15:02:59.115Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "1",
  "upstream_service_time": "1",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "dfa5d9a4-205f-9ed0-b8f9-a57503eef534",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:42296",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55772",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2026-01-12T15:03:00.019Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "2",
  "upstream_service_time": "1",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "3ccce983-77fe-901b-8cde-9015d2f04224",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:42310",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55782",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "2"
}
{
  "start_time": "2026-01-12T15:03:00.783Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "1",
  "upstream_service_time": "1",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "542a7709-ee30-91b3-8f94-5d98d38d7979",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:42296",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55784",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2026-01-12T15:03:01.586Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "1",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "fffa72a1-d8ec-97fa-adb7-8ac84397d5ef",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:42296",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55792",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2026-01-12T15:03:02.459Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "df1b083c-e98c-93dd-90b6-153fc4017e1e",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55794",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T15:03:03.131Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "6593b359-3b58-9dd2-bdb8-9b5024bd25fb",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55804",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T15:03:03.863Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "d73c7aa7-e2af-90fb-91db-c205335a979b",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.211.131:9090",
  "downstream_remote_address": "10.244.1.8:55812",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
```

```json {caption="[Text 41] Circuit Breaking Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T15:02:58.454Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "65",
  "upstream_service_time": "26",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "63a34f0f-2ba7-96fe-bf09-a9b557de9e7c",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42649",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:42296",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "22",
  "response_duration": "49"
}
{
  "start_time": "2026-01-12T15:02:59.115Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "1",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "dfa5d9a4-205f-9ed0-b8f9-a57503eef534",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42649",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:42296",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2026-01-12T15:03:00.020Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "3ccce983-77fe-901b-8cde-9015d2f04224",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:45955",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:42310",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2026-01-12T15:03:00.783Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "542a7709-ee30-91b3-8f94-5d98d38d7979",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42649",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:42296",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2026-01-12T15:03:01.586Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "fffa72a1-d8ec-97fa-adb7-8ac84397d5ef",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.22:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:42649",
  "downstream_local_address": "10.244.2.22:9090",
  "downstream_remote_address": "10.244.1.8:42296",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
```

[Text 40] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 41] shows the Access Log of the `mock-server` Pod's `istio-proxy`. In the `shell` Pod's `istio-proxy` Access Log, only the last 3 requests show `response_flags` as `UH (NoHealthyUpstream)` along with confirmation that requests were not delivered to the `mock-server` Pod. Also, only the first 5 request logs are present in the `mock-server` Pod's `istio-proxy` Access Log.

#### 1.3.11. Upstream Request Retry Case with Timeout

{{< figure caption="[Figure 24] Upstream Request Retry Case with Timeout" src="images/grpc-upstream-request-retry-case-with-timeout.png" width="1000px" >}}

```shell {caption="[Shell 24] Upstream Request Retry Case with Timeout / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables -A INPUT -s ${SHELL_IP} -j DROP
# $ kubectl exec mock-server -c mock-server -- iptables -D INPUT 1 remove rule after case execution

$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
command terminated with exit code 78
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
```

[Figure 24] shows the Upstream Request Retry Case with Timeout where `grpcurl` command is used from the `shell` Pod to send 3 consecutive `code: 0` requests to the `mock-server`'s `/mock.MockService/Status` function, causing Retry due to Timeout. [Shell 24] shows an example of executing [Figure 24]. Except for the fact that requests and responses occur via GRPC, the same process as described in [Figure 11] is performed.

```json {caption="[Text 42] Upstream Request Retry Case with Timeout / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T16:03:05.367Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX,UF",
  "response_code_details": "upstream_reset_before_response_started{connection_timeout}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "5",
  "bytes_sent": "0",
  "duration": "30022",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "d0bfefd5-7d33-91e5-99b9-20be930cb454",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:38130",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "1",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T16:03:36.696Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "5",
  "bytes_sent": "0",
  "duration": "20027",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "298c1ca4-1d65-96fe-b954-e9940ad05219",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:33064",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T16:03:57.696Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "024b3626-a1a7-9a48-a0ce-7b51fb0cb045",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:56904",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
```

[Text 42] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 43] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Except for the fact that requests and responses occur via GRPC, the same process as [Text 22] is performed.

#### 1.3.12. Upstream Request Retry Case with TCP Reset

{{< figure caption="[Figure 25] Upstream Request Retry Case with TCP Reset" src="images/grpc-upstream-request-retry-case-with-tcp-reset.png" width="1000px" >}}

```shell {caption="[Shell 26] Upstream Request Retry Case with TCP Reset / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables-legacy -A INPUT -p tcp -s ${SHELL_IP} -j REJECT --reject-with tcp-reset
# $ kubectl exec mock-server -c mock-server -- iptables-legacy -D INPUT 1 remove rule after case execution

$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused
command terminated with exit code 78
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
```

[Figure 25] shows the Upstream Request Retry Case with TCP Reset where `grpcurl` command is used from the `shell` Pod to send 3 consecutive `code: 0` requests to the `mock-server`'s `/mock.MockService/Status` function, causing Retry due to TCP Reset. [Shell 26] shows an example of executing [Figure 25]. Except for the fact that requests and responses occur via GRPC, the same process as described in [Figure 12] is performed.

```json {caption="[Text 43] Upstream Request Retry Case with TCP Reset / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T15:38:06.556Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX,UF",
  "response_code_details": "upstream_reset_before_response_started{remote_connection_failure|delayed_connect_error:_Connection_refused}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "delayed_connect_error:_Connection_refused",
  "bytes_received": "5",
  "bytes_sent": "0",
  "duration": "47",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "33dbdad0-498c-946a-9cca-4011993ab77d",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:35730",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T15:38:07.473Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "delayed_connect_error:_Connection_refused",
  "bytes_received": "5",
  "bytes_sent": "0",
  "duration": "37",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "febde591-cafd-9ad9-b567-85f31bdee0ce",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:35734",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "-"
}
{
  "start_time": "2026-01-12T15:38:08.939Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UH",
  "response_code_details": "no_healthy_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "0",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "3965c57d-d452-9572-b1f2-22f39c36c446",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:35738",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
```

[Text 43] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 44] shows the Access Log of the `mock-server` Pod's `istio-proxy`. Except for the fact that requests and responses occur via GRPC, the same process as [Text 23] is performed.

#### 1.3.13. Upstream Request Timeout Case

{{< figure caption="[Figure 26] Upstream Request Timeout Case" src="images/grpc-upstream-request-timeout-case.png" width="1000px" >}}

```shell {caption="[Shell 27] Upstream Request Timeout Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 70000}' mock-server:9090 mock.MockService/Delay
```

[Figure 26] shows the Upstream Request Timeout Case where the `grpcurl` command is used from the `shell` Pod to send a `milliseconds: 70000` request to the `mock-server`'s `/mock.MockService/Delay` function, but the `mock-server` Pod's `istio-proxy` does not receive a response after waiting 60000ms and processes the Request as Timeout.

Due to the Virtual Service in [File 1], requests sent to the `mock-server` Pod can wait up to 60000ms. However, the request sent to the `mock-server` Pod's `/mock.MockService/Delay` function with `milliseconds: 70000` requires 70000ms, so a Timeout occurs. The `mock-server` Pod's `istio-proxy` sends an HTTP/2 RST_STREAM Frame to terminate the connection with the `mock-server` Pod when a Timeout occurs. It also returns an `Unavailable` status code to notify the `shell` Pod's `istio-proxy` that the request was abnormally terminated.

```json {caption="[Text 44] Upstream Request Timeout Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T16:10:41.589Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "UT",
  "response_code_details": "response_timeout",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "9",
  "bytes_sent": "0",
  "duration": "60015",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "1dfff112-112f-90e4-a6fe-c247011b9d94",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.8:33502",
  "downstream_local_address": "10.96.1.12:9090",
  "downstream_remote_address": "10.244.1.8:48540",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "16",
  "response_duration": "-"
}
```

```json {caption="[Text 45] Upstream Request Timeout Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-01-12T16:10:41.644Z",
  "method": "POST",
  "path": "/mock.MockService/Delay",
  "protocol": "HTTP/2",
  "response_code": "0",
  "response_flags": "DR",
  "response_code_details": "http2.remote_reset",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "9",
  "bytes_sent": "0",
  "duration": "59975",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "1dfff112-112f-90e4-a6fe-c247011b9d94",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.23:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:35027",
  "downstream_local_address": "10.244.2.23:9090",
  "downstream_remote_address": "10.244.1.8:33502",
  "requested_server_name": "-",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "19",
  "response_duration": "-"
}
```

[Text 44] shows the Access Log of the `shell` Pod's `istio-proxy`, and [Text 45] shows the Access Log of the `mock-server` Pod's `istio-proxy`. The `shell` Pod's `istio-proxy` shows `response_flags` as `UT (UpstreamTimeout)`. The `mock-server` Pod's `istio-proxy` shows `response_flags` as `DR (DownstreamRemoteReset)`.

## 2. References

* Istio Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)
* Enovy Access Log : [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string)
