---
title: Istio Sidecar Proxy Access Log
draft: true
---

## 1. Istio Sidecar Proxy Access Log

Istio 환경에서 다양한 Case에 따른 Sidecar Proxy의 Access Log를 살펴본다.

### 1.1. Test 환경 구성

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="800px" >}}

[Figure 1]은 Istio Sidecar Proxy Access Log Test 환경을 나타내고 있다. 2개의 Worker Node로 구성되어 있고 각각의 Node에 Client 역할을 수행하는 `shell` Pod와 Server 역할을 수행하는 `mock-server` Pod가 위치한다. `shell` Pod는 `mock-server` Pod와 같이 설정된 Service, Destination Rule, Virtual Service를 통해서 접근한다. HTTP Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `curl` 명령어를 이용하여 접근하고, gRPC Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `grpcurl` 명령어를 이용하여 접근한다.

#### 1.1.1. Kubernetes, Istio 환경 구성

```shell {caption="[Shell 1] Kubernetes, Istio 환경 구성"}
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

[Shell 1]은 Kubernetes, Istio 환경을 구성하는 Script를 나타내고 있다. `kind`를 활용하여 Kubernetes Cluster를 구성하고 Istio를 설치한다. 그리고 default Namespace에 Sidecar Injection을 활성화한다.

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

[Text 1]은 Istio Sidecar Proxy Access Log의 Format을 변경하기 위한 Istio의 Mesh Config를 나타내고 있다. Access Log의 기본 Format은 Plain Text 형식으로 되어 있어 가독성이 좋지 않으며, JSON 형식으로 변경하기 위해서 `accessLogFormat` Field를 이용하여 설정한다.

#### 1.1.2. Workload 구성

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
  - timeout: 10s # default is disabled
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

[File 1]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공하고, `9090` Port를 열어서 gRPC 서비스를 제공한다. Virtual Service에는 Timeout은 `5s`로 설정되어 있고, 재시도는 기본값과 동일하게 2번 재시도를 설정하여 최대 3번 요청을 시도하도록 설정되어 있다. 또한 기본값과 동일하게 `connect-failure`, `refused-stream`, `unavailable`, `cancelled` 4가지 Error가 발생하면 재시도를 수행하도록 설정되어 있다.

Circuit Breaking을 Test를 위해서 Destination Rule이 설정되어 있다. `outlierDetection` Field는 비정상 상태를 판단하는 기준을 정의하며 기본값으로 구성되어 있다. 5번 연속으로 10초 간격으로 5xx 에러가 발생하면 Circuit Breaking이 동작하며, Circuit Breaking 적용 시간은 30초로 설정되어 있다. `connectionPool` Field는 HTTP/GRPC 요청의 동시 처리 개수를 제한하는 설정을 명시하며, 동시에 한개의 요청만 처리할 수 있도록 설정되어 있다.

동시 처리 개수를 제한하는 방법은 크게 최대 TCP Connection을 기반으로 제한하는 방법과 최대 동시 HTTP/GRPC 요청 처리의 개수를 제한하는 방법이 있다. TCP Connection 기반의 방법은 `tcp.maxConnections` Field를 이용하여 최대 TCP Connection의 개수를 제한하는 방법이다. [File 1]에서는 `tcp.maxConnections` Field를 `1`로 설정하여 최대 TCP Connection의 개수를 1개로 제한하고 있으며, `http.http1MaxPendingRequests` Field를 `1`로 설정하여 TCP Connection이 Ready 상태가 되기전까지 Pending 할 수 있는 요청의 개수도 최대 1개까지로 제한하고 있다.

GRPC의 경우에는 하나의 TCP Connection에서 HTTP/2의 Stream 기능을 활용하여 다수의 요청을 동시에 처리할 수 있다. 따라서 `http.maxConcurrentStreams` Field를 `1`로 설정하여 하나의 TCP Connection에서 최대 1개의 Stream만 처리할 대 있도록 강제하여 손쉽게 GRPC 요청 Pending을 발생시킬 수 있도록 설정되어 있다. 만약에 `http.maxConcurrentStreams` Field가 명시되어 있지 않으면 하나의 TCP Connection에서 무제한으로 Stream 처리가 가능하기 때문에 GRPC 요청 Pending이 발생하지 않는다.

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

HTTP/GRPC 요청의 최대 동시 처리 개수를 제한하는 방법은 `http.http2MaxRequests` Field를 이용하면 된다. [File 2]에서는 `http.http2MaxRequests` Field를 `1`로 설정하여 최대 HTTP/GRPC 요청 처리의 개수를 1개로 제한하고 있다. 또한 나머지 `connectionPool` Field는 설정하지 않아 Request가 Pending 되지 않도록 설정되어 있다. 대부분의 Case에서는 [File 1]에서 설정한 Destination Rule을 이용하며, [File 2]의 Destination Rule은 일부 Circuit Breaking Case에서 이용한다.

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
| /mock.MockService.Status | Return specific gRPC status code |
| /mock.MockService.Delay | Delay response by milliseconds |
| /mock.MockService.ResetBeforeResponse | Server sends TCP RST before response after delay |
| /mock.MockService.ResetAfterResponse | Server sends dummy data, then TCP RST after delay |
| /mock.MockService.CloseBeforeResponse | Server closes connection before response after delay |
| /mock.MockService.CloseAfterResponse | Server sends dummy data, then closes connection after delay |
{{< /table >}}

[Table 1]과 [Table 2]는 `mock-server` Workload의 HTTP Endpoint, gRPC Function별 동작을 나타내고 있다. `mock-server`에서 제공하는 Endpoint들을 다양한 Case를 재현하기 위해서 사용한다.

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

[File 3]은 `shell` Pod의 Manifest를 나타내고 있다. netshoot Image를 이용하여 `shell` Pod을 생성하며, Network Admin 권한을 부여하여 `iptables` 명령어를 이용할 수 있도록 한다. [File 4]는 `grpcurl` 명령어를 이용하여 `mock-server` gRPC Service를 호출하기 위한 Proto 파일을 나타내고 있다. [Shell 2]은 Proto 파일을 `shell` Pod에 복사하는 예시를 나타내고 있다.

### 1.2. HTTP Cases

#### 1.2.1. Success Case

{{< figure caption="[Figure 2] HTTP Success Case" src="images/http-success-case.png" width="1000px" >}}

```shell {caption="[Shell 3] HTTP Success Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
{"message":"OK","service":"mock-server","status_code":200}
```

[Figure 2]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 `GET` 요청을 전달하고, `200 OK` 응답을 받는 HTTP Success Case를 나타내고 있다. [Shell 3]은 [Figure 2]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 2] HTTP Success Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 3] HTTP Success Case / mock-server Access Log", linenos=table}
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

[Text 2]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 3]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/status/200` Endpoint에 접근하는 내역와 `200 OK` 응답도 확인이 가능하다.

#### 1.2.2. Failure Case

{{< figure caption="[Figure 3] HTTP Failure Case" src="images/http-failure-case.png" width="1000px" >}}

```shell {caption="[Shell 4] HTTP Failure Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
```

[Figure 3]은 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/503` Endpoint에 `GET` 요청을 전달하고, `503 Service Unavailable` 응답을 받는 HTTP Failure Case를 나타내고 있다. [Shell 4]은 [Figure 3]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 4] HTTP Failure Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 5] HTTP Failure Case / mock-server Access Log", linenos=table}
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

[Text 4]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 5]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/status/503` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다.

#### 1.2.3. Downstream TCP RST Case

{{< figure caption="[Figure 4] Downstream TCP RST Case" src="images/http-downstream-tcp-rst-case.png" width="1000px" >}}

```shell {caption="[Shell 5] Downstream TCP RST Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/5000
^C
```

[Figure 4]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/10000` Endpoint에 `GET` 요청을 전달하고, 5000ms가 지나기 전에 `Ctrl+C` 명령어를 이용하여 요청을 강제로 종료하는 Downstream TCP RST Case를 나타내고 있다. [Shell 5]은 [Figure 4]의 내용을 실행하는 예시를 나타내고 있다.

`curl` 명령어 실행 중 강제로 종료하면 `curl` 명령어는 내부적으로 Connection을 종료하면서 TCP FIN Flag를 `curl` Pod의 `istio-proxy`에게 전송한며, TCP FIN Flag를 받은 `curl` Pod의 `istio-proxy`는 TCP RST Flag를 `mock-server` Pod에게 전송하여 최종적으로 `mock-server` Container에게 전달된다. 이후에 `mock-server` Pod의 `istio-proxy`는 예상치 못한 Client의  Connection 종료였기 때문에 TCP RST Flag를 TCP FIN Flag 이후에 전송한다.

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

[Text 6]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 7]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/delay/5000` Endpoint에 접근하는 내역와 `response_code`가 `0`으로 나타나는 것을 확인할 수 있다. 또한 `response_flags`가 `DC (DownstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

#### 1.2.4. Upstream TCP RST before Response Case

{{< figure caption="[Figure 5] Upstream TCP RST before Response Case" src="images/http-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 6] Upstream TCP RST before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 5]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/reset-before-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST before Response Case를 나타내고 있다. [Shell 6]은 [Figure 5]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP RST Flag를 수신하면 TCP RST Flag를 `shell` Pod에게 전송하지 않고, `503 Service Unavailable` 응답을 전송하기 때문에 `shell` Pod의 `istio-proxy`의 Access Log에는 `response_flags`가 존재하지 않고 `503 Service Unavailable` 응답만 확인이 가능하다.

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

[Text 8]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 9]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/reset-before-response/1000` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다. 또한 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있으며, `response_code_details`에 `upstream_reset_before_response_started{connection_termination}`, 즉 응답을 시작하기전에 TCP RST Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다.

#### 1.2.5. Upstream TCP RST after Response Case

{{< figure caption="[Figure 6] Upstream TCP RST after Response Case" src="images/http-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 7] Upstream TCP RST after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-after-response/1000
curl: (18) transfer closed with outstanding read data remaining
dummy datacommand terminated with exit code 18
```

[Figure 6]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/reset-after-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST after Response Case를 나타내고 있다. [Shell 7]은 [Figure 6]의 내용을 실행하는 예시를 나타내고 있다.

TCP RST Flag를 받은 `mock-server` Pod의 `istio-proxy`는 TCP FIN Flag를 `shell` Pod에게 전송하여 TCP Connection을 종료한다. 또한 예상치 못한 Connection 종료였기 때문에 TCP RST Flag도 TCP RST Flag 이후에 전송한다.

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
  "request_duration": "0"한
  "response_duration": "1004"
}
```

[Text 10]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 11]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/reset-after-response/1000` Endpoint에 접근하는 내역와 `200 OK` 응답도 확인이 가능하다. 또한 `response_flags`가 `UPE (UpstreamProtocolError)`로 나타나는 것을 확인할 수 있있다. 

`response_code_details`에 `upstream_reset_after_response_started{protocol_error}`, 즉 일부 응답 전송후에 TCP RST Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다. Protocol Error가 발생하는 이유는 완전한 HTTP 응답을 전송하기 전에 TCP RST Flag가 Upstream에서 전송되었기 때문이다.

#### 1.2.6. Upstream TCP Close before Response Case

{{< figure caption="[Figure 7] Upstream TCP Close before Response Case" src="images/http-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 8] Upstream TCP Close before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 7]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/close-before-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 Connection을 강제로 종료하는 Upstream TCP Close before Response Case를 나타내고 있다. [Shell 8]은 [Figure 7]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP FIN Flag를 수신하면 503 Service Unavailable 응답을 `shell` Pod에게 전송하여 요청이 비정상적으로 종료된것을 알린다.

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

[Text 12]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 13]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/disconnect/1000` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다. 또한 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

`response_code_details`에 `upstream_reset_before_response_started {connection_termination}`, 즉 응답을 시작하기전에 TCP FIN Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다. 이는 [Figure 5]에서 TCP RST Flag를 받을때와 동일한 상세 내역이며, `mock-server` Pod의 `istio-proxy`는 응답이 전송되기 전에 TCP FIN Flag 또는 TCP RST Flag를 수신하면 동일한 `response_code_details`를 남기는것을 확인할 수 있다.

#### 1.2.7. Upstream TCP Close after Response Case

{{< figure caption="[Figure 8] Upstream TCP Close after Response Case" src="images/http-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 9] Upstream TCP Close after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-after-response/1000
dummy datacommand terminated with exit code 18
```

[Figure 8]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/close-after-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 전송한 후에 Connection을 강제로 종료하는 Upstream TCP Close after Response Case를 나타내고 있다. [Shell 9]은 [Figure 8]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP FIN Flag를 수신하면 503 Service Unavailable 응답을 `shell` Pod에게 전송하여 요청이 비정상적으로 종료된것을 알린다.

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

[Text 14]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 15]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/close-after-response/1000` Endpoint에 접근하는 내역과 `200 OK` 응답도 확인이 가능하다. 또한 `response_flags`가 `UPE (UpstreamProtocolError)`로 나타나는 것을 확인할 수 있다.

`response_code_details`에 `upstream_reset_after_response_started {protocol_error}`, 즉 응답을 시작한 후에 Protocol Error가 발생하여 Connection을 강제로 종료한 것을 나타내는 상세 내역도 확인할 수 있다. 이는 [Figure 6]에서 TCP RST Flag를 받을때와 동일한 상세 내역이며, `mock-server` Pod의 `istio-proxy`는 응답을 일부 전송한 상태에서 TCP FIN Flag 또는 TCP RST Flag를 수신하면 동일한 `response_code_details`를 남기는것을 확인할 수 있다.

#### 1.2.8. Circuit Breaking with Upstream Connection PoolOverflow Case

{{< figure caption="[Figure 9] Circuit Breaking with Upstream Connection Pool Overflow Case" src="images/http-circuit-breaking-with-upstream-connection-pool-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 10] Circuit Breaking with Upstream Connection Pool Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
```

[Figure 9]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 3번 연속으로 전달하여 Upstream Overflow를 발생시켜 Circuit Breaking을 동작시키는 Case를 나타내고 있다. [Shell 10]은 [Figure 9]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Destination Rule에 의해서 첫번째 요청은 바로 `mock-server` Pod로 전달되며, 5000ms 동안 대기 이후에 `200 OK` 응답과 함께 종료된다. 두번째 요청은 첫번째 요청이 처리중이기 때문에 Pending되어 첫번째 요청이 끝나기 전까지 대기 이후에 `mock-server` Pod에 전달된다. 따라서 두번째 요청이 처리되는데 걸리는 시간은 5000ms + 5000ms = 10000ms가 된다. 세번째 요청은 Pending도 불가능하기 때문에 `istio-proxy`는 Upstream Overflow라 간주하고 Circuit Breaking을 동작시키고, `503 Service Unavailable` 응답을 전송한다.

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

[Text 16]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 17]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 가장 먼저 남는 Log는 Upstream Connection Pool Overflow로 인해서 요청과 동시에 처리에 실패한 세번째 요청에 대한 Log이다. `response_flags`가 `UO (UpstreamOverflow)`로 나타나는 것을 확인할 수 있으며, `start_time`도 나머지 Log와 비교하면 가장 나중에 시작된 것도 확인할 수 있다. 두번째로 남는 Log는 첫번째 요청에 대한 Log이며, 세번째로 남는 Log는 두번째 요청에 대한 Log이다. `response_duration`이 각각 5000ms, 10000ms인걸 확인할 수 있다.

`mock-server` Pod의 `istio-proxy`의 Access Log에는 첫번째 요청과 두번째 요청에 대한 Log만 남아 있는것을 확인할 수 있으며, `response_duration`이 모두 5000ms인걸 확인할 수 있다. 세번째 요청은 `shell` Pod의 `istio-proxy`에서 Upstream Connection Pool Overflow로 인해서 `mock-server` Pod로 전달되지 않았기 때문에 `mock-server` Pod의 `istio-proxy`에도 세번째 요청에 대한 Log가 존재하지 않는다.

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

[Figure 9]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 3번 연속으로 전달하여 Upstream Request Limit Overflow를 발생시키는 Case를 나타내고 있다. 이 Case를 재현하기 위해서는 [File 2]에서 설정한 Destination Rule을 적용해야한다. [Shell 11]은 [Figure 9]의 내용을 실행하는 예시를 나타내고 있다.

[File 2]의 Destination Rule의 설정에 의해서 최대 동시에 처리할 수 있는 요청이 하나이고 요청 Pending도 불가능하기 때문에, 두번째와 세번째 요청은 Upstream Overflow로 인해서 `mock-server` Pod에 전달되지 않는다.

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

[Text 18]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 19]은 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 먼저 남는 Log는 Upstream Request Limit Overflow로 인해서 요청과 동시에 처리에 실패한 두번째, 세번째 요청에 대한 Log이다. 첫번째 Log가 두번째 요청에 대한 Log이고, 두번째 Log가 세번째 요청에 대한 Log이다. 둘다 `response_flags`가 `UO (UpstreamOverflow)`로 나타나는 것을 확인할 수 있다. 마지막 Log는 첫번째 요청에 대한 Log이며, 정상적으로 `mock-server` Pod에 전달되어 처리된 것을 확인할 수 있다.

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

[Figure 10]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/503` Endpoint에 `GET` 요청을 8번 연속으로 전달하여 No Healthy Upstream을 통한 Circuit Breaking을 발생시키는 Case를 나타내고 있다. [Shell 12]는 [Figure 10]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Destination Rule에 의해서 5번의 연속적인 5XX Error가 발생하면 Circuit Breaking이 동작한다. 따라서 `shell` Pod의 첫 5번의 요청은 모두 `mock-server` Pod에게 전달되지만, 이후에 3번의 요청은 Circuit Breaking으로 인해서 `mock-server` Pod에 전달되지 않는다.

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

[Text 20]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 21]은 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 마지막 3개의 요청에만 `response_flags`가 `UH (No Healthy Upstream)`와 함께 요청이 `mock-server` Pod에 전달되지 않은 것을 확인할 수 있다. 또한 `mock-server` Pod의 `istio-proxy`의 Access Log에는 처음 5개의 요청에 대한 Log만 남아있는것도 확인할 수 있다.

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

[Figure 11]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 접속시 Timeout에 의해서 연결에 실패하여 Retry되는 Upstream Connection Failure with Timeout Case를 나타내고 있다. [Shell 13]은 [Figure 11]의 내용을 실행하는 예시를 나타내고 있다. Timeout을 발생시키기 위해서 `iptables` 명령어를 이용하여 `shell` Pod의 IP Address로부터 들어오는 트래픽을 `DROP`하는 Rule을 추가한 다음, `curl` 명령어를 이용하여 요청을 전송한다.

[File 1]의 Virtual Service의 `connect-failure` 의해서 2번의 재시도가 발생하여 총 3번의 요청이 전송된다. 따라서 `shell` Pod의 첫번째 요청은 `shell` Pod의 `istio-proxy`에 의해서 3번의 재시도를 수행한 다음 `connection timeout` 오류가 출력된다. `shell` Pod의 두번째 요청은 1번의 재시도가 발생하여 총 2번의 요청이 전송되는데, 이유는 [File 1]의 Destination Rule에 의해서 5번 연속적인 5XX Error가 발생하면 Circuit Breaking이 동작하기 때문이다.

첫번째 요청의 3번의 요청과 두번째 요청의 2번째 요청, 총 5번의 요청이 발생했고 모두 Timeout에 의해서 실패하였기 때문에 Healthy Upstream이 없다고 판단하고 Circuit Breaking이 동작한다. 따라서 두번째 요청의 2번째 재시도는 Circuit Breaking에 의해서 `mock-server` Pod에 전송되지 않으며, 두번째 요청의 결과로 `no healthy upstream` 오류가 출력된다. 세번째 요청은 Circuit Breaking에 의해서 즉시 `no healthy upstream` 오류 출력과 함께 종료된다.

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

[Text 22]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 요청이 `istio-proxy`에 의해서 `mock-server` Pod에 전달되지 않기 때문에 `mock-server` Pod의 `istio-proxy`의 Access Log에는 아무것도 남지 않는다. 첫번째 요청에는 `response_flags`에 `URX (UpstreamRetryLimitExceeded)`와 `UF (UpstreamConnectionFailure)`가 함께 나타나는 것을 확인할 수 있으며, `response_code_details`에 `upstream_reset_before_response_started {connection_timeout}`, 즉 Connection Timeout이 발생한 사실을 확인할 수 있다. `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다.

두번째, 세번째 요청에는 Circuit Breaking에 의해서 `response_flags`에 `UH (No Healthy Upstream)`가 나타나는 것을 확인할 수 있으며, `response_code_details`에 `no_healthy_upstream`가 나타나는 것을 확인할 수 있다. 두번째 요청에는 `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다. 세번째 요청에는 `upstream_request_attempt_count`가 `1`으로 나타나는 것을 확인할 수 있다.

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

[Figure 12]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 접속시 TCP Reset에 의해서 연결에 실패하여 Retry되는 Upstream Connection Failure with TCP Reset Case를 나타내고 있다. [Shell 14]은 [Figure 12]의 내용을 실행하는 예시를 나타내고 있다. TCP Reset을 발생시키기 위해서 `iptables` 명령어를 이용하여 `shell` Pod의 IP Address로부터 들어오는 트래픽을 `REJECT`하는 Rule을 추가한 다음, `curl` 명령어를 이용하여 요청을 전송한다. `Connection Refused` 오류 내용을 제외하고는 Timeout에 의해서 Retry를 수행하는 Case와 동일한 결과를 보여준다.

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

[Text 23]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 요청이 `istio-proxy`에 의해서 `mock-server` Pod에 전달되지 않기 때문에 `mock-server` Pod의 `istio-proxy`의 Access Log에는 아무것도 남지 않는다. `response_code_details`에 `upstream_reset_before_response_started{remote_connection_failure|delayed_connect_error:_Connection_refused}`, 즉 Remote Connection Failure와 Delayed Connect Error가 발생한 사실을 확인할 수 있다. 이 부분을 제외하고는 Timeout에 의해서 Retry를 수행하는 Case와 동일한 결과를 보여준다.

#### 1.2.13. Upstream Request Timeout Case

{{< figure caption="[Figure 13] Upstream Request Timeout Case" src="images/http-upstream-request-timeout-case.png" width="1000px" >}}

```shell {caption="[Shell 15] Upstream Request Timeout Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/10000
```

[Figure 13]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/10000` Endpoint에 `GET` 요청을 전달하였지만, `mock-server` Pod의 `istio-proxy`에서 5000ms 대기후에 응답이 오지 않아 Request를 Timeout 처리하는 Upstream Request Timeout Case를 나타내고 있다. [Shell 15]은 [Figure 13]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Virtual Service에 의해서 `mock-server` Pod로 전송된 요청은 최대 5000ms 대기할 수 있다. 하지만 `mock-server` Pod의 `/delay/10000` Endpoint에 전송한 요청은 10000ms가 필요하기 때문에 Timeout이 발생한다. `mock-server` Pod의 `istio-proxy`는 Timeout 발생시 TCP FIN Flag와 TCP RST Flag를 차례로 전송하여, `mock-server` Pod와의 연결을 종료한다. 또한 `504 Gateway Timeout` 응답을 `shell` Container에게 전송한다.

```json {caption="[Text 24] Upstream Timeout Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-01-04T12:28:44.275Z",
  "method": "GET",
  "path": "/delay/10000",
  "protocol": "HTTP/1.1",
  "response_code": "504",
  "response_flags": "UT",
  "response_code_details": "response_timeout",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "24",
  "duration": "10016",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "87a77d0f-480d-9961-b4de-e508b4814eff",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.7:60908",
  "downstream_local_address": "10.96.188.135:8080",
  "downstream_remote_address": "10.244.1.7:37610",
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
  "start_time": "2026-01-04T12:28:44.371Z",
  "method": "GET",
  "path": "/delay/10000",
  "protocol": "HTTP/1.1",
  "response_code": "0",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "0",
  "duration": "9920",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "87a77d0f-480d-9961-b4de-e508b4814eff",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.2.18:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:41337",
  "downstream_local_address": "10.244.2.18:8080",
  "downstream_remote_address": "10.244.1.7:60908",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 24]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 25]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`에는 `response_flags`에 `UT (UpstreamTimeout)`를 확인할 수 있다. `mock-server` Pod의 `istio-proxy`에는 `response_flags`에 `DC (DownstreamConnectionTermination)`를 확인할 수 있다.

### 1.3. GRPC Cases

#### 1.3.1. Success Case

{{< figure caption="[Figure 14] Success Case" src="images/grpc-success-case.png" width="1000px" >}}

```shell {caption="[Shell 16] Success Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
{
  "service": "mock-server",
  "message": "OK"
}
```

[Figure 14]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService.Status` 함수에 `code: 0` 요청을 전달하고, `OK` 응답을 받는 Success Case를 나타내고 있다. [Shell 16]은 [Figure 14]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 26] Success Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 27] Success Case / mock-server Pod Access Log", linenos=table}
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

[Text 26]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 27]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Status` 함수에 접근하는 내역과 `grpc_status`가 `OK`로 나타나는 것을 확인할 수 있다.

#### 1.3.2. Internal Error Case

{{< figure caption="[Figure 15] Internal Server Error Case" src="images/grpc-internal-server-error-case.png" width="1000px" >}}

```shell {caption="[Shell 17] Internal Server Error Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
```

[Figure 15]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 13` 요청을 전달하고, `Internal` 응답을 받는 Internal Error Case를 나타내고 있다. [Shell 17]은 [Figure 15]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 28] Internal Server Error Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T11:35:39.358Z",
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
  "duration": "50",
  "upstream_service_time": "27",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "796e0dd3-a85f-9d2b-8350-53c022d0880d",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:36738",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:58154",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "14",
  "response_duration": "42"
}
```

```json {caption="[Text 29] Internal Server Error Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T11:35:39.378Z",
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
  "duration": "16",
  "upstream_service_time": "5",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "796e0dd3-a85f-9d2b-8350-53c022d0880d",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:43023",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:36738",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "7",
  "response_duration": "12"
}
```

[Text 28]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 29]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Status` 함수에 접근하는 내역과 `grpc_status`가 `Internal`로 나타나는 것을 확인할 수 있다. 또한 `response_code`가 `200 OK`로 나타나는 것을 확인할 수 있으며, gRPC 이용시 gRPC의 결과와 상관없이 `response_code`는 항상 `200 OK`로 나타난다.

#### 1.3.3. Downstream HTTP/2 RST_STREAM Case

{{< figure caption="[Figure 16] Downstream HTTP/2 RST_STREAM Case" src="images/grpc-downstream-http2-rst-stream-case.png" width="1000px" >}}

```shell {caption="[Shell 18] Downstream HTTP/2 RST_STREAM Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay
^C
```

[Figure 16]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 5000` 요청을 전달하고, 5000ms가 지나가 전에 `Ctrl+C` 명령어를 이용하여 요청을 강제로 종료하는 Downstream HTTP/2 RST_STREAM Case를 나타내고 있다. [Shell 18]은 [Figure 16]의 내용을 실행하는 예시를 나타내고 있다.

`grpcurl` 명령어 실행 중 강제로 종료하면 `grpcurl` 명령어는 TCP FIN Flag를 `shell` Pod의 `istio-proxy`에게 전송하며, `shell` Pod의 `istio-proxy`는 TCP FIN Flag 대신 HTTP/2 RST_STREAM Frame을 `mock-server` Pod에게 전송하여 최종적으로 `mock-server` Container에게 전달하여 연결을 종료한다.

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

[Text 30]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 31]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Delay` 함수에 접근하는 내역과 `response_code`가 `0`, `grpc_status`가 `-`로 나타나는 것을 확인할 수 있다.

또한 `shell` Pod의 `istio-proxy`에서는 `grpcurl` 명령어로부터 TCP FIN Flag를 수신하기 때문에 `response_flags`가 `DC (DownstreamConnectionTermination)`로 나타나는 것을 확인할 수 있으며, `mock-server` Pod의 `istio-proxy`에서는 HTTP/2 RST_STREAM Frame을 수신하기 때문에 `response_flags`가 `DR (DownstreamRemoteReset)`로 나타나는 것을 확인할 수 있다.

#### 1.3.4. Upstream TCP RST before Response Case

{{< figure caption="[Figure 17] Upstream TCP RST before Response Case" src="images/grpc-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 19] Upstream TCP RST before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/ResetBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 17]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/ResetBeforeResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, 1000ms 대기후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST before Response Case를 나타내고 있다. [Shell 19]은 [Figure 17]의 내용을 실행하는 예시를 나타내고 있다.

TCP RST Flag를 받은 `mock-server` Pod의 `istio-proxy`는 `Unavailable` 상태 코드를 반환하여 요청이 비정상적으로 종료된것을 `shell` Pod의 `istio-proxy`에게 알린다. [File 1]의 Virtual Service에 `unavailable` 설정에 의해서 `shell` Pod의 `istio-proxy`는 2번의 재시도를 수행하여 총 3번의 요청을 전송한다.

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

[Text 32]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 33]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/ResetBeforeResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unavailable`로 나타나는 것을 확인할 수 있다. 또한 두 Access Log에서 모두 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

`shell` Pod의 `istio-proxy`가 3번의 요청을 전송하기 때문에 `shell Pod`의 `istio-proxy`의 Access Log에서 `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다. 또한 `mock-server` Pod의 `istio-proxy`의 Access Log가 3번이 남아있는것을 확인할 수 있다.

#### 1.3.5. Upstream TCP RST after Response Case

{{< figure caption="[Figure 18] Upstream TCP RST after Response Case" src="images/grpc-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 20] Upstream TCP RST after Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService.ResetAfterResponse
kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService.ResetAfterResponse
{
  "data": "ZHVtbXkgZGF0YQ=="
}
ERROR:
  Code: Internal
  Message: stream terminated by RST_STREAM with error code: NO_ERROR
command terminated with exit code 77
```

[Figure 18]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/ResetAfterResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST after Response Case를 나타내고 있다. [Shell 20]은 [Figure 18]의 내용을 실행하는 예시를 나타내고 있다.

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

[Text 34]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 35]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/ResetAfterResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unknown`로 나타나는 것을 확인할 수 있다. `shell` Pod의 `istio-proxy`의 Access Log에서 `response_flags`가 `UR (UpstreamRemoteReset)`로 나타나는 것을 확인할 수 있으며, `mock-server` Pod의 `istio-proxy`의 Access Log에서 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

#### 1.3.6. Upstream TCP Close before Response Case

{{< figure caption="[Figure 19] Upstream TCP Close before Response Case" src="images/grpc-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 21] Upstream TCP Close before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 19]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/CloseBeforeResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 Connection을 강제로 종료하는 Upstream TCP Close before Response Case를 나타내고 있다. [Shell 21]은 [Figure 19]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Container에서 TCP FIN Flag를 전송한다는 부분만 제외하고 TCP RST Flag를 받는 [Figure 17]과 동일한 과정을 수행한다는 것을 알 수 있다.

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

[Text 36]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 37]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/CloseBeforeResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unavailable`로 나타나는 것을 확인할 수 있다. TCP RST Flag를 받는 [Figure 17]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.7. Upstream TCP Close after Response Case

{{< figure caption="[Figure 20] Upstream TCP Close after Response Case" src="images/grpc-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 22] Upstream TCP Close after Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseAfterResponse
ERROR:
  Code: Internal
  Message: stream terminated by RST_STREAM with error code: NO_ERROR
command terminated with exit code 77
```

[Figure 20]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/CloseAfterResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 Connection을 강제로 종료하는 Upstream TCP Close after Response Case를 나타내고 있다. [Shell 22]은 [Figure 20]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Container에서 TCP FIN Flag를 전송한다는 부분만 제외하고 TCP RST Flag를 받는 [Figure 18]과 동일한 과정을 수행한다는 것을 알 수 있다.

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

[Text 38]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 39]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/CloseAfterResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unknown`로 나타나는 것을 확인할 수 있다. TCP RST Flag를 받는 [Figure 18]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.8. Circuit Breaking with Upstream Connection Pool Overflow Case

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

#### 1.3.9. Circuit Breaking with Upstream Overflow Case

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

#### 2.2.6. Circuit Breaking Case

```shell {caption="[Shell 23] Circuit Breaking Case / grpcurl Command", linenos=table}
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("9090||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}
```

```json {caption="[Text 40] Circuit Breaking Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T15:37:14.685Z",
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
  "duration": "41",
  "upstream_service_time": "22",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b218f327-fc35-9b50-bbb6-5852f71f8d71",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:33370",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:51102",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "19",
  "response_duration": "41"
}
{
  "start_time": "2025-12-25T15:37:15.505Z",
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
  "request_id": "9286020f-bdec-917d-b5e5-39c14fba1c16",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:55516",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:51110",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2025-12-25T15:37:16.355Z",
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
  "request_id": "67e5cd39-27d9-9619-abcf-16be12daeb47",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:33370",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:51120",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2025-12-25T15:37:17.237Z",
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
  "request_id": "579df252-3830-985e-8af4-00cf68e88d03",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:33370",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:51132",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2025-12-25T15:37:18.048Z",
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
  "request_id": "b9e570c0-e5b3-9258-a381-d8c1879c1d34",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:55516",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:55648",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2025-12-25T15:37:18.879Z",
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
  "request_id": "1cba5671-b265-994b-aef3-2c1f00b25a86",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:55654",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2025-12-25T15:37:19.572Z",
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
  "request_id": "b937b48e-0823-9759-8499-5ba6b70aab6d",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:55656",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
{
  "start_time": "2025-12-25T15:37:20.465Z",
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
  "request_id": "d5b22aac-eb55-9c1e-969d-f2fa3c953447",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:55670",
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
  "start_time": "2025-12-25T15:37:14.715Z",
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
  "duration": "9",
  "upstream_service_time": "6",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "b218f327-fc35-9b50-bbb6-5852f71f8d71",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:60721",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:33370",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "2",
  "response_duration": "8"
}
{
  "start_time": "2025-12-25T15:37:15.505Z",
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
  "request_id": "9286020f-bdec-917d-b5e5-39c14fba1c16",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:40643",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:55516",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2025-12-25T15:37:16.355Z",
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
  "request_id": "67e5cd39-27d9-9619-abcf-16be12daeb47",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:60721",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:33370",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-25T15:37:17.238Z",
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
  "request_id": "579df252-3830-985e-8af4-00cf68e88d03",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:60721",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:33370",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2025-12-25T15:37:18.048Z",
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
  "request_id": "b9e570c0-e5b3-9258-a381-d8c1879c1d34",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:40643",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:55516",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
```

#### 2.2.7. Upstream Request Retry Case with Timeout

```shell {caption="[Shell 24] Upstream Request Retry Case with Timeout / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables -A INPUT -s ${SHELL_IP} -j DROP
$ kubectl exec mock-server -c mock-server -- iptables -D INPUT 1
```

```shell {caption="[Shell 25] Upstream Request Retry Case with Timeout / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto  -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
command terminated with exit code 78
```

```json {caption="[Text 42] Upstream Request Retry Case with Timeout / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T16:35:14.398Z",
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
  "duration": "30020",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "46114f69-2363-9551-8c57-23ede0c5d5ba",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.10:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.208.157:9090",
  "downstream_remote_address": "10.244.1.6:46706",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "2",
  "response_duration": "-"
}
```

#### 2.2.8. Upstream Request Retry Case with TCP Reset

```shell {caption="[Shell 26] Upstream Request Retry Case with TCP Reset / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables-legacy -A INPUT -p tcp -s ${SHELL_IP} -j REJECT --reject-with tcp-reset
$ kubectl exec mock-server -c mock-server -- iptables-legacy -D INPUT 1
```

```shell {caption="[Shell 27] Upstream Request Retry Case with TCP Reset / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused
command terminated with exit code 78
```

```json {caption="[Text 43] Upstream Request Retry Case with TCP Reset / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T17:04:21.454Z",
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
  "duration": "65",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "4dff590e-6373-932c-b380-d4316d1deabb",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.10:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.208.157:9090",
  "downstream_remote_address": "10.244.1.6:33962",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "2",
  "response_duration": "-"
}
```

#### 2.2.9. No Healthy Upstream Case

```shell {caption="[Shell 28] No Healthy Upstream Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
```

```json {caption="[Text 44] No Healthy Upstream Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2025-12-25T15:52:08.991Z",
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
  "duration": "7",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "8a3edf54-2988-9bd2-8014-b36b23c84796",
  "authority": "mock-server:9090",
  "upstream_host": "-",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:47090",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "-",
  "response_duration": "-"
}
```

## 2. 참조

* Istio Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)
* Enovy Access Log : [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string)