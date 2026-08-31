---
title: Istio Sidecar Proxy Access Log
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
    image: ghcr.io/ssup2/mock-go-server:0.1.7
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
      attempts: 2                                                         # default value
      retryOn: "502,connect-failure,refused-stream,unavailable,cancelled" # add 502 to default value
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

[File 1]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공하고, `9090` Port를 열어서 gRPC 서비스를 제공한다. Virtual Service에는 Timeout은 `60s`로 설정되어 있고, 재시도는 기본값과 동일하게 2번 재시도를 설정하여 최대 3번 요청을 시도하도록 설정되어 있다. 또한 재시도 조건은 기본값인 `connect-failure`, `refused-stream`, `unavailable`, `cancelled` 4가지 Error 조건에 `502` Status Code를 추가하여 설정되어 있다.

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
| /bytes/{bytes} | Return specified number of bytes |
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

#### 1.2.1. OK Case

{{< figure caption="[Figure 2] HTTP OK Case" src="images/http-ok-case.png" width="1000px" >}}

```shell {caption="[Shell 3] HTTP OK Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
{"message":"OK","service":"mock-server","status_code":200}
```

[Figure 2]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 `GET` 요청을 전달하고, `200 OK` 응답을 받는 HTTP OK Case를 나타내고 있다. [Shell 3]은 [Figure 2]의 내용을 실행하는 예시를 나타내고 있다.

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

[Text 2]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 3]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/status/200` Endpoint에 접근하는 내역와 `200 OK` 응답도 확인이 가능하다.

#### 1.2.2. Service Unavailable Case

{{< figure caption="[Figure 3] HTTP Service Unavailable Case" src="images/http-service-unavailable-case.png" width="1000px" >}}

```shell {caption="[Shell 4] HTTP Service Unavailable Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
```

[Figure 3]은 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/503` Endpoint에 `GET` 요청을 전달하고, `503 Service Unavailable` 응답을 받는 HTTP Service Unavailable Case를 나타내고 있다. [Shell 4]은 [Figure 3]의 내용을 실행하는 예시를 나타내고 있다.

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

[Text 4]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 5]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/status/503` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다.

#### 1.2.3. Downstream TCP Close Case

{{< figure caption="[Figure 4] Downstream TCP Close Case" src="images/http-downstream-tcp-close-case.png" width="1000px" >}}

```shell {caption="[Shell 5] Downstream TCP Close Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/5000
^C
```

[Figure 4]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 전달하고, 5000ms가 지나기 전에 `Ctrl+C` 명령어를 이용하여 요청을 강제로 종료하는 Downstream TCP Close Case를 나타내고 있다. [Shell 5]은 [Figure 4]의 내용을 실행하는 예시를 나타내고 있다.

`curl` 명령어 실행 중 강제로 종료하면 `curl` 명령어는 내부적으로 Connection을 종료하면서 TCP FIN Flag를 `shell` Pod의 `istio-proxy`에게 전송하며, TCP FIN Flag를 받은 `shell` Pod의 `istio-proxy`는 처리중인 요청을 중단하고 TCP FIN Flag를 `mock-server` Pod에게 전송하여 최종적으로 `mock-server` Container에게 전달된다. 이후에 `mock-server` Container가 5000ms 뒤에 응답을 전송하면 Connection이 이미 종료된 상태이기 때문에 `mock-server` Pod의 `istio-proxy`는 TCP RST Flag를 `mock-server` Container에게 전송한다.

```json {caption="[Text 6] Downstream TCP Close Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 7] Downstream TCP Close Case / mock-server Pod Access Log", linenos=table}
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

#### 1.2.4. Downstream TCP RST Case

{{< figure caption="[Figure 5] Downstream TCP RST Case" src="images/http-downstream-tcp-rst-case.png" width="1000px" >}}

```shell {caption="[Shell 6] Downstream TCP RST Case / python3 Command", linenos=table}
$ kubectl exec -it shell -- python3 -c '
import socket, struct, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("mock-server", 8080))
s.sendall(b"GET /delay/5000 HTTP/1.1\r\nHost: mock-server:8080\r\nUser-Agent: python-rst-client\r\n\r\n")
time.sleep(1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()'
```

[Shell 6]은 `shell` Pod에서 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 전달하고, 5000ms가 지나기 전에 TCP FIN Flag가 아닌 TCP RST Flag를 전송하여 요청을 강제로 종료하는 Downstream TCP RST Case를 나타내고 있다. `curl` 명령어는 Socket의 `SO_LINGER` Option을 제어할 수 없어 TCP RST Flag를 전송할 수 없기 때문에, `python3` 명령어를 이용하여 요청 전송 1000ms 이후에 `SO_LINGER` Option을 `0`으로 설정하고 Socket을 닫아 TCP RST Flag를 전송한다.

TCP RST Flag를 수신한 `shell` Pod의 `istio-proxy`는 TCP RST Flag를 `mock-server` Pod에게 그대로 전달하지 않고, Downstream TCP Close Case와 동일하게 TCP FIN Flag를 전송하여 Connection을 종료한다. `istio-proxy`는 Downstream Connection과 Upstream Connection을 별도의 TCP Connection으로 관리하기 때문에, Downstream Connection이 TCP RST Flag를 통해서 비정상적으로 종료되어도 Upstream Connection은 TCP FIN Flag를 통해서 정상적으로 종료한다. TCP FIN Flag를 수신한 `mock-server` Pod의 `istio-proxy`도 TCP FIN Flag를 `mock-server` Container에게 전송한다. 이후에 `mock-server` Container는 5000ms 뒤에 응답을 전송하지만 Connection이 이미 종료된 상태이기 때문에 `mock-server` Pod의 `istio-proxy`로부터 TCP RST Flag를 수신한다.

```json {caption="[Text 8] Downstream TCP RST Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-26T14:44:50.149Z",
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
  "duration": "992",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "python-rst-client",
  "request_id": "6829f238-8938-964e-b075-5acc45deea89",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:48142",
  "downstream_local_address": "10.96.221.63:8080",
  "downstream_remote_address": "10.244.2.7:52548",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 9] Downstream TCP RST Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-26T14:44:50.192Z",
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
  "duration": "958",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "python-rst-client",
  "request_id": "6829f238-8938-964e-b075-5acc45deea89",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:55605",
  "downstream_local_address": "10.244.1.9:8080",
  "downstream_remote_address": "10.244.2.7:48142",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

[Text 8]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 9]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 Downstream TCP Close Case와 동일하게 `response_code`가 `0`, `response_flags`가 `DC (DownstreamConnectionTermination)`, `response_code_details`가 `downstream_remote_disconnect`로 나타나는 것을 확인할 수 있다. 즉 `istio-proxy`는 Downstream으로부터 TCP FIN Flag를 수신하는 경우와 TCP RST Flag를 수신하는 경우를 Access Log에서 구분하지 않는것을 확인할 수 있다.

#### 1.2.5. Downstream TCP RST with Backpressure Case

{{< figure caption="[Figure 6] Downstream TCP RST with Backpressure Case" src="images/http-downstream-tcp-rst-with-backpressure-case.png" width="1000px" >}}

```shell {caption="[Shell 7] Downstream TCP RST with Backpressure Case / python3 Command", linenos=table}
$ kubectl exec -i shell -- python3 - <<'EOF'
import socket, struct, time, subprocess

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("mock-server", 8080))
s.sendall(b"GET /bytes/50000000 HTTP/1.1\r\nHost: mock-server:8080\r\nUser-Agent: python-backpressure-rst\r\n\r\n")
time.sleep(4)   # do not read the response so the buffers on the path fill up
# show unread bytes stacked in istio-proxy's upstream socket
print(subprocess.run(["ss", "-tn", "dport", "=", ":8080"], capture_output=True, text=True).stdout)
# Close with SO_LINGER(on, 0) so the kernel sends TCP RST instead of FIN
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
EOF
State Recv-Q  Send-Q Local Address:Port  Peer Address:Port
ESTAB 124312  0         10.244.2.7:38012 10.96.221.63:8080
ESTAB 1868933 0         10.244.2.7:50072  10.244.1.10:8080
```

[Shell 7]은 `shell` Pod에서 `mock-server`의 `/bytes/50000000` Endpoint에 `GET` 요청을 전달하여 50MB 응답을 수신하는 도중에, 응답을 읽지 않고 4000ms 대기한 이후에 TCP RST Flag를 전송하여 요청을 강제로 종료하는 Downstream TCP RST with Backpressure Case를 나타내고 있다.

Client가 응답을 읽지 않으면 `shell` Pod의 `istio-proxy`는 Client에게 전달하지 못한 데이터를 내부 Buffer에 보관하며, Buffer가 가득 차면(High Watermark) Upstream 데이터 읽기를 중단하는 Backpressure가 동작한다. 이후 `mock-server` Pod에서 전송된 데이터는 `istio-proxy`가 읽어가지 않기 때문에 Upstream Socket의 Kernel Receive Buffer에 쌓인다. [Shell 7]의 `ss` 명령어 출력에서 `istio-proxy`의 Upstream Socket(`10.244.1.10:8080`)의 Recv-Q에 약 1.8MB의 읽지 않은 데이터가 쌓여있는 것을 확인할 수 있다.

이 상태에서 TCP RST Flag를 수신한 `shell` Pod의 `istio-proxy`는 Upstream Connection을 종료하는데, Downstream TCP RST Case와 다르게 Kernel Receive Buffer에 읽지 않은 데이터가 남아있는 Socket을 닫기 때문에 TCP 규칙에 따라 TCP FIN Flag가 아닌 TCP RST Flag가 `mock-server` Pod에게 전송된다. 즉 `istio-proxy`가 Upstream Connection을 종료할 때 전송하는 Flag는 종료 시점에 Kernel Receive Buffer에 읽지 않은 데이터가 존재하는지 여부에 따라서 결정된다.

```json {caption="[Text 10] Downstream TCP RST with Backpressure Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-27T02:24:12.605Z",
  "method": "GET",
  "path": "/bytes/50000000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "1818624",
  "duration": "3982",
  "upstream_service_time": "60",
  "x_forwarded_for": "-",
  "user_agent": "python-backpressure-rst",
  "request_id": "ab01ee94-eacc-96f2-a3f1-291a830f1036",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.10:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:50072",
  "downstream_local_address": "10.96.221.63:8080",
  "downstream_remote_address": "10.244.2.7:38012",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "72"
}
```

```json {caption="[Text 11] Downstream TCP RST with Backpressure Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-27T02:24:12.633Z",
  "method": "GET",
  "path": "/bytes/50000000",
  "protocol": "HTTP/1.1",
  "response_code": "200",
  "response_flags": "DC",
  "response_code_details": "downstream_remote_disconnect",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "8752321",
  "duration": "3967",
  "upstream_service_time": "23",
  "x_forwarded_for": "-",
  "user_agent": "python-backpressure-rst",
  "request_id": "ab01ee94-eacc-96f2-a3f1-291a830f1036",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.10:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:49821",
  "downstream_local_address": "10.244.1.10:8080",
  "downstream_remote_address": "10.244.2.7:50072",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "43"
}
```

[Text 10]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 11]은 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log 모두 Downstream TCP RST Case와 동일하게 `response_flags`가 `DC (DownstreamConnectionTermination)`, `response_code_details`가 `downstream_remote_disconnect`로 기록되며, 응답 전송 도중에 중단되었기 때문에 `response_code`는 `200`으로 기록된다. `bytes_sent`를 통해서 중단 전까지 각 `istio-proxy`가 Downstream에게 전송한 데이터의 크기도 확인할 수 있다.

즉 Access Log에서는 Downstream TCP RST Case와 Downstream TCP RST with Backpressure Case가 구분되지 않으며, `istio-proxy`가 Upstream에게 TCP FIN Flag 대신 TCP RST Flag를 전송하는 차이는 Packet Dump를 통해서만 확인이 가능하다.

#### 1.2.6. Upstream Request Retry Case

{{< figure caption="[Figure 7] Upstream Request Retry Case" src="images/http-upstream-request-retry-case.png" width="1000px" >}}

[File 1]의 Virtual Service에는 `retryOn` Field에 `502` Status Code가 포함되어 있기 때문에, `502` Status Code 응답을 받는 경우 최대 2번의 재시도를 수행하여 최대 3번의 요청이 전송된다.

```shell {caption="[Shell 8] Upstream Request Retry Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/502
{"message":"Bad Gateway","service":"mock-server","status_code":502}
```

[Shell 8]은 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/502` Endpoint에 `GET` 요청을 전달하는 Upstream Request Retry Case를 나타내고 있다. `mock-server`는 모든 요청에 `502 Bad Gateway` 응답을 반환하기 때문에, `shell` Pod의 `istio-proxy`는 2번의 재시도를 모두 수행한 이후에 마지막으로 받은 `502 Bad Gateway` 응답을 `curl` 명령어에게 전달한다.

```json {caption="[Text 12] Upstream Request Retry Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T00:19:18.701Z",
  "method": "GET",
  "path": "/status/502",
  "protocol": "HTTP/1.1",
  "response_code": "502",
  "response_flags": "URX",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "68",
  "duration": "118",
  "upstream_service_time": "91",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.21.0",
  "request_id": "c0ace0c7-fe4b-9244-81cd-72cda95dee0b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:41160",
  "downstream_local_address": "10.96.221.63:8080",
  "downstream_remote_address": "10.244.2.7:48340",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "118"
}
```

```json {caption="[Text 13] Upstream Request Retry Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T00:19:18.761Z",
  "method": "GET",
  "path": "/status/502",
  "protocol": "HTTP/1.1",
  "response_code": "502",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "68",
  "duration": "13",
  "upstream_service_time": "7",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.21.0",
  "request_id": "c0ace0c7-fe4b-9244-81cd-72cda95dee0b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:51459",
  "downstream_local_address": "10.244.1.9:8080",
  "downstream_remote_address": "10.244.2.7:41132",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "13"
}
{
  "start_time": "2026-08-25T00:19:18.802Z",
  "method": "GET",
  "path": "/status/502",
  "protocol": "HTTP/1.1",
  "response_code": "502",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "68",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.21.0",
  "request_id": "c0ace0c7-fe4b-9244-81cd-72cda95dee0b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:51459",
  "downstream_local_address": "10.244.1.9:8080",
  "downstream_remote_address": "10.244.2.7:41148",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2026-08-25T00:19:18.819Z",
  "method": "GET",
  "path": "/status/502",
  "protocol": "HTTP/1.1",
  "response_code": "502",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "68",
  "duration": "0",
  "upstream_service_time": "0",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.21.0",
  "request_id": "c0ace0c7-fe4b-9244-81cd-72cda95dee0b",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.9:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:51459",
  "downstream_local_address": "10.244.1.9:8080",
  "downstream_remote_address": "10.244.2.7:41160",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
```

[Text 12]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 13]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. [Text 12]에서는 `upstream_request_attempt_count`가 첫번째 시도와 2번의 재시도를 모두 포함한 `3`으로 기록된 것을 확인할 수 있으며, `response_flags`도 재시도 한도를 모두 소진했음을 나타내는 `URX (UpstreamRetryLimitExceeded)`로 기록된 것을 확인할 수 있다.

[Text 13]에서는 동일한 `request_id`를 갖는 3개의 Log가 기록된 것을 확인할 수 있다. 재시도는 Client 역할을 수행하는 `shell` Pod의 `istio-proxy`에서 수행되기 때문에, `mock-server` Pod의 `istio-proxy`는 각 재시도를 별개의 요청으로 처리하여 모든 Log에 `upstream_request_attempt_count`가 `1`로 기록된다.

#### 1.2.7. Upstream TCP RST before Response Case

{{< figure caption="[Figure 8] Upstream TCP RST before Response Case" src="images/http-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 9] Upstream TCP RST before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 8]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/reset-before-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST before Response Case를 나타내고 있다. [Shell 9]은 [Figure 8]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP RST Flag를 수신하면 TCP RST Flag를 `shell` Pod에게 전송하지 않고, `503 Service Unavailable` 응답을 전송하기 때문에 `shell` Pod의 `istio-proxy`의 Access Log에는 `response_flags`가 존재하지 않고 `503 Service Unavailable` 응답만 확인이 가능하다.

```json {caption="[Text 14] Upstream TCP RST before Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 15] Upstream TCP RST before Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 14]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 15]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/reset-before-response/1000` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다. 또한 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있으며, `response_code_details`에 `upstream_reset_before_response_started{connection_termination}`, 즉 응답을 시작하기전에 TCP RST Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다.

#### 1.2.8. Upstream TCP RST after Response Case

{{< figure caption="[Figure 9] Upstream TCP RST after Response Case" src="images/http-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 10] Upstream TCP RST after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/reset-after-response/1000
curl: (18) transfer closed with outstanding read data remaining
dummy datacommand terminated with exit code 18
```

[Figure 9]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/reset-after-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST after Response Case를 나타내고 있다. [Shell 10]은 [Figure 9]의 내용을 실행하는 예시를 나타내고 있다.

TCP RST Flag를 받은 `mock-server` Pod의 `istio-proxy`는 TCP FIN Flag를 `shell` Pod에게 전송하여 TCP Connection을 종료한다. 또한 예상치 못한 Connection 종료였기 때문에 TCP RST Flag도 TCP RST Flag 이후에 전송한다.

```json {caption="[Text 16] Upstream TCP RST after Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 17] Upstream TCP RST after Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 16]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 17]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/reset-after-response/1000` Endpoint에 접근하는 내역와 `200 OK` 응답도 확인이 가능하다. 또한 `response_flags`가 `UPE (UpstreamProtocolError)`로 나타나는 것을 확인할 수 있있다. 

`response_code_details`에 `upstream_reset_after_response_started{protocol_error}`, 즉 일부 응답 전송후에 TCP RST Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다. Protocol Error가 발생하는 이유는 완전한 HTTP 응답을 전송하기 전에 TCP RST Flag가 Upstream에서 전송되었기 때문이다.

#### 1.2.9. Upstream TCP Close before Response Case

{{< figure caption="[Figure 10] Upstream TCP Close before Response Case" src="images/http-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 11] Upstream TCP Close before Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-before-response/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

[Figure 10]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/close-before-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 Connection을 강제로 종료하는 Upstream TCP Close before Response Case를 나타내고 있다. [Shell 11]은 [Figure 10]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP FIN Flag를 수신하면 503 Service Unavailable 응답을 `shell` Pod에게 전송하여 요청이 비정상적으로 종료된것을 알린다.

```json {caption="[Text 18] Upstream TCP Connection Close Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 19] Upstream TCP Connection Close Case / mock-server Pod Access Log", linenos=table}
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

[Text 18]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 19]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/disconnect/1000` Endpoint에 접근하는 내역와 `503 Service Unavailable` 응답도 확인이 가능하다. 또한 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

`response_code_details`에 `upstream_reset_before_response_started {connection_termination}`, 즉 응답을 시작하기전에 TCP FIN Flag가 Upstream에서 전송되었음을 나타내는 상세 내역도 확인할 수 있다. 이는 [Figure 8]에서 TCP RST Flag를 받을때와 동일한 상세 내역이며, `mock-server` Pod의 `istio-proxy`는 응답이 전송되기 전에 TCP FIN Flag 또는 TCP RST Flag를 수신하면 동일한 `response_code_details`를 남기는것을 확인할 수 있다.

#### 1.2.10. Upstream TCP Close after Response Case

{{< figure caption="[Figure 11] Upstream TCP Close after Response Case" src="images/http-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 12] Upstream TCP Close after Response Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/close-after-response/1000
dummy datacommand terminated with exit code 18
```

[Figure 11]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/close-after-response/1000` Endpoint에 `GET` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 전송한 후에 Connection을 강제로 종료하는 Upstream TCP Close after Response Case를 나타내고 있다. [Shell 12]은 [Figure 11]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Pod의 `istio-proxy`는 `mock-server` Container로부터 TCP FIN Flag를 수신하면 503 Service Unavailable 응답을 `shell` Pod에게 전송하여 요청이 비정상적으로 종료된것을 알린다.

```json {caption="[Text 20] Upstream TCP Close after Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 21] Upstream TCP Close after Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 20]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 21]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/close-after-response/1000` Endpoint에 접근하는 내역과 `200 OK` 응답도 확인이 가능하다. 또한 `response_flags`가 `UPE (UpstreamProtocolError)`로 나타나는 것을 확인할 수 있다.

`response_code_details`에 `upstream_reset_after_response_started {protocol_error}`, 즉 응답을 시작한 후에 Protocol Error가 발생하여 Connection을 강제로 종료한 것을 나타내는 상세 내역도 확인할 수 있다. 이는 [Figure 9]에서 TCP RST Flag를 받을때와 동일한 상세 내역이며, `mock-server` Pod의 `istio-proxy`는 응답을 일부 전송한 상태에서 TCP FIN Flag 또는 TCP RST Flag를 수신하면 동일한 `response_code_details`를 남기는것을 확인할 수 있다.

#### 1.2.11. Circuit Breaking with Upstream Connection Pool Overflow Case

{{< figure caption="[Figure 12] Circuit Breaking with Upstream Connection Pool Overflow Case" src="images/http-circuit-breaking-with-upstream-connection-pool-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 13] Circuit Breaking with Upstream Connection Pool Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
```

[Figure 12]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 3번 연속으로 전달하여 Upstream Connection Pool Overflow를 발생시켜 Circuit Breaking을 동작시키는 Case를 나타내고 있다. [Shell 13]은 [Figure 12]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Destination Rule에 의해서 첫번째 요청은 바로 `mock-server` Pod로 전달되며, 5000ms 동안 대기 이후에 `200 OK` 응답과 함께 종료된다. 두번째 요청은 첫번째 요청이 처리중이기 때문에 Pending되어 첫번째 요청이 끝나기 전까지 대기 이후에 `mock-server` Pod에 전달된다. 따라서 두번째 요청이 처리되는데 걸리는 시간은 5000ms + 5000ms = 10000ms가 된다. 세번째 요청은 Pending도 불가능하기 때문에 `istio-proxy`는 Upstream Overflow라 간주하고 Circuit Breaking을 동작시키고, `503 Service Unavailable` 응답을 전송한다.

```json {caption="[Text 22] Circuit Breaking with Upstream Connection Pool Overflow Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 23] Circuit Breaking with Upstream Connection Pool Overflow Case / mock-server Pod Access Log", linenos=table}
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

[Text 22]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 23]는 `mock-server`의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 가장 먼저 남는 Log는 Upstream Connection Pool Overflow로 인해서 요청과 동시에 처리에 실패한 세번째 요청에 대한 Log이다. `response_flags`가 `UO (UpstreamOverflow)`로 나타나는 것을 확인할 수 있으며, `start_time`도 나머지 Log와 비교하면 가장 나중에 시작된 것도 확인할 수 있다. 두번째로 남는 Log는 첫번째 요청에 대한 Log이며, 세번째로 남는 Log는 두번째 요청에 대한 Log이다. `response_duration`이 각각 5000ms, 10000ms인걸 확인할 수 있다.

`mock-server` Pod의 `istio-proxy`의 Access Log에는 첫번째 요청과 두번째 요청에 대한 Log만 남아 있는것을 확인할 수 있으며, `response_duration`이 모두 5000ms인걸 확인할 수 있다. 세번째 요청은 `shell` Pod의 `istio-proxy`에서 Upstream Connection Pool Overflow로 인해서 `mock-server` Pod로 전달되지 않았기 때문에 `mock-server` Pod의 `istio-proxy`에도 세번째 요청에 대한 Log가 존재하지 않는다.

#### 1.2.12. Circuit Breaking with Upstream Request Limit Overflow Case

{{< figure caption="[Figure 13] Circuit Breaking with Upstream Request Limit Overflow Case" src="images/http-circuit-breaking-with-upstream-request-limit-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 14] Circuit Breaking with Upstream Request Limit Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}
```

[Figure 13]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/5000` Endpoint에 `GET` 요청을 3번 연속으로 전달하여 Upstream Request Limit Overflow를 발생시키는 Case를 나타내고 있다. 이 Case를 재현하기 위해서는 [File 2]에서 설정한 Destination Rule을 적용해야한다. [Shell 14]은 [Figure 13]의 내용을 실행하는 예시를 나타내고 있다.

[File 2]의 Destination Rule의 설정에 의해서 최대 동시에 처리할 수 있는 요청이 하나이고 요청 Pending도 불가능하기 때문에, 두번째와 세번째 요청은 Upstream Overflow로 인해서 `mock-server` Pod에 전달되지 않는다.

```json {caption="[Text 24] Circuit Breaking with Request Limit Upstream Overflow Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 25] Circuit Breaking with Request Limit Upstream Overflow Case / mock-server Pod Access Log", linenos=table}
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

[Text 24]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 25]은 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 먼저 남는 Log는 Upstream Request Limit Overflow로 인해서 요청과 동시에 처리에 실패한 두번째, 세번째 요청에 대한 Log이다. 첫번째 Log가 두번째 요청에 대한 Log이고, 두번째 Log가 세번째 요청에 대한 Log이다. 둘다 `response_flags`가 `UO (UpstreamOverflow)`로 나타나는 것을 확인할 수 있다. 마지막 Log는 첫번째 요청에 대한 Log이며, 정상적으로 `mock-server` Pod에 전달되어 처리된 것을 확인할 수 있다.

#### 1.2.13. Circuit Breaking with No Healthy Upstream Case

{{< figure caption="[Figure 14] Circuit Breaking with No Healthy Upstream Case" src="images/http-circuit-breaking-with-no-healthy-upstream-case.png" width="1000px" >}}

```shell {caption="[Shell 15] Circuit Breaking with No Healthy Upstream Case / curl Command", linenos=table}
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

[Figure 14]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/503` Endpoint에 `GET` 요청을 8번 연속으로 전달하여 No Healthy Upstream을 통한 Circuit Breaking을 발생시키는 Case를 나타내고 있다. [Shell 15]는 [Figure 14]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Destination Rule에 의해서 5번의 연속적인 5XX Error가 발생하면 Circuit Breaking이 동작한다. 따라서 `shell` Pod의 첫 5번의 요청은 모두 `mock-server` Pod에게 전달되지만, 이후에 3번의 요청은 Circuit Breaking으로 인해서 `mock-server` Pod에 전달되지 않는다.

```json {caption="[Text 26] Circuit Breaking with No Healthy Upstream Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 27] Circuit Breaking with No Healthy Upstream Case / mock-server Pod Access Log", linenos=table}
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

[Text 26]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 27]은 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 마지막 3개의 요청에만 `response_flags`가 `UH (NoHealthyUpstream)`와 함께 요청이 `mock-server` Pod에 전달되지 않은 것을 확인할 수 있다. 또한 `mock-server` Pod의 `istio-proxy`의 Access Log에는 처음 5개의 요청에 대한 Log만 남아있는것도 확인할 수 있다.

#### 1.2.14. Upstream Connection Failure with Timeout Case

{{< figure caption="[Figure 15] Upstream Connection Failure with Timeout Case" src="images/http-upstream-connection-failure-case-with-timeout.png" width="1000px" >}}

```shell {caption="[Shell 16] Upstream Connection Failure with Timeout Case / iptables & curl Command", linenos=table}
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

[Figure 15]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 접속시 Timeout에 의해서 연결에 실패하여 Retry되는 Upstream Connection Failure with Timeout Case를 나타내고 있다. [Shell 16]은 [Figure 15]의 내용을 실행하는 예시를 나타내고 있다. Timeout을 발생시키기 위해서 `iptables` 명령어를 이용하여 `shell` Pod의 IP Address로부터 들어오는 트래픽을 `DROP`하는 Rule을 추가한 다음, `curl` 명령어를 이용하여 요청을 전송한다.

[File 1]의 Virtual Service의 `connect-failure` 의해서 2번의 재시도가 발생하여 총 3번의 요청이 전송된다. 따라서 `shell` Pod의 첫번째 요청은 `shell` Pod의 `istio-proxy`에 의해서 3번의 재시도를 수행한 다음 `connection timeout` 오류가 출력된다. `shell` Pod의 두번째 요청은 1번의 재시도가 발생하여 총 2번의 요청이 전송되는데, 이유는 [File 1]의 Destination Rule에 의해서 5번 연속적인 5XX Error가 발생하면 Circuit Breaking이 동작하기 때문이다.

첫번째 요청의 3번의 요청과 두번째 요청의 2번째 요청, 총 5번의 요청이 발생했고 모두 Timeout에 의해서 실패하였기 때문에 Healthy Upstream이 없다고 판단하고 Circuit Breaking이 동작한다. 따라서 두번째 요청의 2번째 재시도는 Circuit Breaking에 의해서 `mock-server` Pod에 전송되지 않으며, 두번째 요청의 결과로 `no healthy upstream` 오류가 출력된다. 세번째 요청은 Circuit Breaking에 의해서 즉시 `no healthy upstream` 오류 출력과 함께 종료된다.

```json {caption="[Text 28] Upstream Connection Failure with Timeout Case / shell Pod Access Log", linenos=table}
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

[Text 28]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 요청이 `istio-proxy`에 의해서 `mock-server` Pod에 전달되지 않기 때문에 `mock-server` Pod의 `istio-proxy`의 Access Log에는 아무것도 남지 않는다. 첫번째 요청에는 `response_flags`에 `URX (UpstreamRetryLimitExceeded)`와 `UF (UpstreamConnectionFailure)`가 함께 나타나는 것을 확인할 수 있으며, `response_code_details`에 `upstream_reset_before_response_started {connection_timeout}`, 즉 Connection Timeout이 발생한 사실을 확인할 수 있다. `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다.

두번째, 세번째 요청에는 Circuit Breaking에 의해서 `response_flags`에 `UH (NoHealthyUpstream)`가 나타나는 것을 확인할 수 있으며, `response_code_details`에 `no_healthy_upstream`가 나타나는 것을 확인할 수 있다. 두번째 요청에는 `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다. 세번째 요청에는 `upstream_request_attempt_count`가 `1`으로 나타나는 것을 확인할 수 있다.

#### 1.2.15. Upstream Connection Failure with TCP Reset Case

{{< figure caption="[Figure 16] Upstream Connection Failure with TCP Reset Case" src="images/http-upstream-connection-failure-case-with-tcp-reset.png" width="1000px" >}}

```shell {caption="[Shell 17] Upstream Connection Failure with TCP Reset Case / iptables & curl Command", linenos=table}
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

[Figure 16]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/status/200` Endpoint에 접속시 TCP Reset에 의해서 연결에 실패하여 Retry되는 Upstream Connection Failure with TCP Reset Case를 나타내고 있다. [Shell 17]은 [Figure 16]의 내용을 실행하는 예시를 나타내고 있다. TCP Reset을 발생시키기 위해서 `iptables` 명령어를 이용하여 `shell` Pod의 IP Address로부터 들어오는 트래픽을 `REJECT`하는 Rule을 추가한 다음, `curl` 명령어를 이용하여 요청을 전송한다. `Connection Refused` 오류 내용을 제외하고는 Timeout에 의해서 Retry를 수행하는 Case와 동일한 결과를 보여준다.

```json {caption="[Text 29] Upstream Connection Failure with TCP Reset Case / shell Pod Access Log", linenos=table}
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

[Text 29]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 요청이 `istio-proxy`에 의해서 `mock-server` Pod에 전달되지 않기 때문에 `mock-server` Pod의 `istio-proxy`의 Access Log에는 아무것도 남지 않는다. `response_code_details`에 `upstream_reset_before_response_started{remote_connection_failure|delayed_connect_error:_Connection_refused}`, 즉 Remote Connection Failure와 Delayed Connect Error가 발생한 사실을 확인할 수 있다. 이 부분을 제외하고는 Timeout에 의해서 Retry를 수행하는 Case와 동일한 결과를 보여준다.

#### 1.2.16. Upstream Request Timeout Case

{{< figure caption="[Figure 17] Upstream Request Timeout Case" src="images/http-upstream-request-timeout-case.png" width="1000px" >}}

```shell {caption="[Shell 18] Upstream Request Timeout Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl -s mock-server:8080/delay/70000
```

[Figure 17]는 `shell` Pod에서 `curl` 명령어를 이용하여 `mock-server`의 `/delay/70000` Endpoint에 `GET` 요청을 전달하였지만, `mock-server` Pod의 `istio-proxy`에서 60000ms 대기후에 응답이 오지 않아 Request를 Timeout 처리하는 Upstream Request Timeout Case를 나타내고 있다. [Shell 18]은 [Figure 17]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Virtual Service에 의해서 `mock-server` Pod로 전송된 요청은 최대 60000ms 대기할 수 있다. 하지만 `mock-server` Pod의 `/delay/70000` Endpoint에 전송한 요청은 70000ms가 필요하기 때문에 Timeout이 발생한다. `mock-server` Pod의 `istio-proxy`는 Timeout 발생시 TCP FIN Flag와 TCP RST Flag를 차례로 전송하여, `mock-server` Pod와의 연결을 종료한다. 또한 `504 Gateway Timeout` 응답을 `shell` Container에게 전송한다.

```json {caption="[Text 30] Upstream Timeout Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 31] Upstream Timeout Case / mock-server Pod Access Log", linenos=table}
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

[Text 30]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 31]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`에는 `response_flags`에 `UT (UpstreamTimeout)`를 확인할 수 있다. `mock-server` Pod의 `istio-proxy`에는 `response_flags`에 `DC (DownstreamConnectionTermination)`를 확인할 수 있다.

### 1.3. GRPC Cases

#### 1.3.1. OK Case

{{< figure caption="[Figure 18] OK Case" src="images/grpc-ok-case.png" width="1000px" >}}

```shell {caption="[Shell 19] OK Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService/Status
{
  "service": "mock-server",
  "message": "OK"
}
```

[Figure 18]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 0` 요청을 전달하고, `OK` 응답을 받는 OK Case를 나타내고 있다. [Shell 19]은 [Figure 18]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 32] OK Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 33] OK Case / mock-server Pod Access Log", linenos=table}
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

[Text 32]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 33]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Status` 함수에 접근하는 내역과 `grpc_status`가 `OK`로 나타나는 것을 확인할 수 있다.

#### 1.3.2. Internal Case

{{< figure caption="[Figure 19] Internal Case" src="images/grpc-internal-case.png" width="1000px" >}}

```shell {caption="[Shell 20] Internal Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
```

[Figure 19]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 13` 요청을 전달하고, `Internal` 응답을 받는 Internal Case를 나타내고 있다. [Shell 20]은 [Figure 19]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 34] Internal Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T02:32:08.271Z",
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
  "duration": "150",
  "upstream_service_time": "135",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "0ea3e5b2-6c30-9f3b-8c06-bc056c442043",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:42196",
  "downstream_local_address": "10.96.221.63:9090",
  "downstream_remote_address": "10.244.2.7:49548",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "13",
  "response_duration": "149"
}
```

```json {caption="[Text 35] Internal Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T02:32:08.341Z",
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
  "duration": "57",
  "upstream_service_time": "36",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "0ea3e5b2-6c30-9f3b-8c06-bc056c442043",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:53621",
  "downstream_local_address": "10.244.1.9:9090",
  "downstream_remote_address": "10.244.2.7:42196",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Internal",
  "upstream_request_attempt_count": "1",
  "request_duration": "20",
  "response_duration": "57"
}
```

[Text 34]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 35]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Status` 함수에 접근하는 내역과 `grpc_status`가 `Internal`로 나타나는 것을 확인할 수 있다. 또한 `response_code`가 `200 OK`로 나타나는 것을 확인할 수 있으며, gRPC 이용시 gRPC의 결과와 상관없이 `response_code`는 항상 `200 OK`로 나타난다. `INTERNAL (13)` Status Code는 [File 1]의 Virtual Service의 `retryOn` Field에 포함되어 있지 않기 때문에 재시도가 발생하지 않으며, `upstream_request_attempt_count`도 `1`로 기록된다.

#### 1.3.3. Downstream TCP Close Case

{{< figure caption="[Figure 20] Downstream TCP Close Case" src="images/grpc-downstream-tcp-close-case.png" width="1000px" >}}

```shell {caption="[Shell 21] Downstream TCP Close Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService/Delay
^C
```

[Figure 20]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 5000` 요청을 전달하고, 5000ms가 지나기 전에 `Ctrl+C` 명령어를 이용하여 요청을 강제로 종료하는 Downstream TCP Close Case를 나타내고 있다. [Shell 21]은 [Figure 20]의 내용을 실행하는 예시를 나타내고 있다.

`grpcurl` 명령어 실행 중 강제로 종료하면 `grpcurl` 명령어는 내부적으로 Connection을 종료하면서 TCP FIN Flag를 `shell` Pod의 `istio-proxy`에게 전송하며, TCP FIN Flag를 받은 `shell` Pod의 `istio-proxy`는 HTTP/2 RST_STREAM Frame을 `mock-server` Pod에게 전송하여 최종적으로 `mock-server` Container에게 전달하여 요청을 종료한다. HTTP/1.1 Protocol과 다르게 HTTP/2 Protocol을 이용하는 Pod 사이의 TCP Connection은 Stream 다중화를 통해서 다수의 요청이 공유하기 때문에, `shell` Pod의 `istio-proxy`는 Pod 사이의 TCP Connection을 종료하지 않고 HTTP/2 RST_STREAM Frame을 통해서 해당 요청의 Stream만 종료한다.

```json {caption="[Text 36] Downstream TCP Close Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 37] Downstream TCP Close Case / mock-server Pod Access Log", linenos=table}
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

[Text 36]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 37]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/Delay` 함수에 접근하는 내역과 `response_code`가 `0`, `grpc_status`가 `-`로 나타나는 것을 확인할 수 있다.

또한 `shell` Pod의 `istio-proxy`에서는 `grpcurl` 명령어로부터 TCP FIN Flag를 수신하기 때문에 `response_flags`가 `DC (DownstreamConnectionTermination)`로 나타나는 것을 확인할 수 있으며, `mock-server` Pod의 `istio-proxy`에서는 HTTP/2 RST_STREAM Frame을 수신하기 때문에 `response_flags`가 `DR (DownstreamRemoteReset)`로 나타나는 것을 확인할 수 있다.

#### 1.3.4. Downstream TCP RST Case

{{< figure caption="[Figure 21] Downstream TCP RST Case" src="images/grpc-downstream-tcp-rst-case.png" width="1000px" >}}

```shell {caption="[Shell 22] Downstream TCP RST Case / python3 Command", linenos=table}
$ kubectl exec -i shell -- python3 - <<'EOF'
import socket, struct, time

def hdr(name, value):
    # HPACK literal header field without indexing, new name
    return b"\x00" + bytes([len(name)]) + name + bytes([len(value)]) + value

def frame(ftype, flags, stream_id, payload):
    return struct.pack(">I", len(payload))[1:] + bytes([ftype, flags]) + struct.pack(">I", stream_id) + payload

headers = b"".join([
    hdr(b":method", b"POST"),
    hdr(b":scheme", b"http"),
    hdr(b":path", b"/mock.MockService/Delay"),
    hdr(b":authority", b"mock-server:9090"),
    hdr(b"content-type", b"application/grpc"),
    hdr(b"te", b"trailers"),
    hdr(b"user-agent", b"python-rst-client"),
])
# DelayRequest{milliseconds: 5000} protobuf + gRPC length prefix
grpc_msg = b"\x00" + struct.pack(">I", 3) + b"\x08\x88\x27"

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("mock-server", 9090))
s.sendall(b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")            # HTTP/2 preface
s.sendall(frame(0x4, 0x0, 0, b""))                        # empty SETTINGS
s.sendall(frame(0x1, 0x4, 1, headers))                    # HEADERS (END_HEADERS)
s.sendall(frame(0x0, 0x1, 1, grpc_msg))                   # DATA (END_STREAM)
time.sleep(1)
# Close with SO_LINGER(on, 0) so the kernel sends TCP RST instead of FIN
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
EOF
```

[Shell 22]은 `shell` Pod에서 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 5000` 요청을 전달하고, 5000ms가 지나기 전에 TCP FIN Flag가 아닌 TCP RST Flag를 전송하여 요청을 강제로 종료하는 Downstream TCP RST Case를 나타내고 있다. `grpcurl` 명령어는 Socket의 `SO_LINGER` Option을 제어할 수 없어 TCP RST Flag를 전송할 수 없기 때문에, `python3` 명령어를 이용하여 HTTP/2 Frame과 gRPC Message를 직접 구성하여 요청을 전송하고, 요청 전송 1000ms 이후에 `SO_LINGER` Option을 `0`으로 설정하고 Socket을 닫아 TCP RST Flag를 전송한다.

TCP RST Flag를 수신한 `shell` Pod의 `istio-proxy`는 Downstream TCP Close Case와 동일하게 TCP RST Flag를 `mock-server` Pod에게 그대로 전달하지 않고, HTTP/2 RST_STREAM Frame을 전송하여 해당 요청의 Stream만 종료한다. 즉 Downstream Connection이 TCP FIN Flag를 통해서 정상적으로 종료되거나 TCP RST Flag를 통해서 비정상적으로 종료되는 것과 무관하게, Pod 사이의 TCP Connection은 그대로 유지되며 HTTP/2 RST_STREAM Frame만 전송된다.

```json {caption="[Text 38] Downstream TCP RST Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-26T15:16:13.003Z",
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
  "duration": "988",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "python-rst-client",
  "request_id": "7ccbd0bb-976a-904f-bd45-349ba1dce793",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:34766",
  "downstream_local_address": "10.96.221.63:9090",
  "downstream_remote_address": "10.244.2.7:33084",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "14",
  "response_duration": "-"
}
```

```json {caption="[Text 39] Downstream TCP RST Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-26T15:16:13.026Z",
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
  "duration": "979",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "python-rst-client",
  "request_id": "7ccbd0bb-976a-904f-bd45-349ba1dce793",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:34371",
  "downstream_local_address": "10.244.1.9:9090",
  "downstream_remote_address": "10.244.2.7:34766",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "13",
  "response_duration": "-"
}
```

[Text 38]은 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 39]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 Downstream TCP Close Case와 동일하게 `shell` Pod에서는 `response_flags`가 `DC (DownstreamConnectionTermination)`, `response_code_details`가 `downstream_remote_disconnect`로 나타나며, `mock-server` Pod에서는 `response_flags`가 `DR (DownstreamRemoteReset)`, `response_code_details`가 `http2.remote_reset`으로 나타나는 것을 확인할 수 있다. 즉 HTTP/1.1 Protocol의 경우와 동일하게 gRPC Protocol의 경우에도 `istio-proxy`는 Downstream으로부터 TCP FIN Flag를 수신하는 경우와 TCP RST Flag를 수신하는 경우를 Access Log에서 구분하지 않는것을 확인할 수 있다.

#### 1.3.5. Upstream Request Retry Case

{{< figure caption="[Figure 22] Upstream Request Retry Case" src="images/grpc-upstream-request-retry-case.png" width="1000px" >}}

[File 1]의 Virtual Service의 `retryOn` Field에는 gRPC의 재시도 조건인 `unavailable`, `cancelled`가 포함되어 있다. 따라서 `UNAVAILABLE (14)` Status Code 응답을 받는 경우 최대 2번의 재시도를 수행하여 최대 3번의 요청이 전송된다.

```shell {caption="[Shell 23] Upstream Request Retry Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 14}' mock-server:9090 mock.MockService/Status
ERROR:
  Code: Unavailable
  Message: Simulated error with gRPC code 14 (Unavailable)
```

[Shell 23]은 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 14` (Unavailable) 요청을 전달하는 Upstream Request Retry Case를 나타내고 있다.

```json {caption="[Text 40] Upstream Request Retry Case / shell Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T02:32:08.437Z",
  "method": "POST",
  "path": "/mock.MockService/Status",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "7",
  "bytes_sent": "0",
  "duration": "56",
  "upstream_service_time": "56",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "01f901a0-01e7-978a-aecc-a81094ae5ed6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.7:42196",
  "downstream_local_address": "10.96.221.63:9090",
  "downstream_remote_address": "10.244.2.7:49562",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "0",
  "response_duration": "56"
}
```

```json {caption="[Text 41] Upstream Request Retry Case / mock-server Pod Access Log", linenos=table}
{
  "start_time": "2026-08-25T02:32:08.437Z",
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
  "request_id": "01f901a0-01e7-978a-aecc-a81094ae5ed6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:53621",
  "downstream_local_address": "10.244.1.9:9090",
  "downstream_remote_address": "10.244.2.7:42196",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1"
}
{
  "start_time": "2026-08-25T02:32:08.455Z",
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
  "request_id": "01f901a0-01e7-978a-aecc-a81094ae5ed6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:53621",
  "downstream_local_address": "10.244.1.9:9090",
  "downstream_remote_address": "10.244.2.7:42196",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
{
  "start_time": "2026-08-25T02:32:08.493Z",
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
  "request_id": "01f901a0-01e7-978a-aecc-a81094ae5ed6",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.1.9:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:53621",
  "downstream_local_address": "10.244.1.9:9090",
  "downstream_remote_address": "10.244.2.7:42196",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "0"
}
```

[Text 40]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `upstream_request_attempt_count`가 첫번째 시도와 2번의 재시도를 모두 포함한 `3`으로 기록된 것을 확인할 수 있으며, `response_flags`도 재시도 한도를 모두 소진했음을 나타내는 `URX (UpstreamRetryLimitExceeded)`로 기록된 것을 확인할 수 있다.

[Text 41]에서는 동일한 `request_id`를 갖는 3개의 Log가 기록된 것을 확인할 수 있다. 재시도는 Client 역할을 수행하는 `shell` Pod의 `istio-proxy`에서 수행되기 때문에, `mock-server` Pod의 `istio-proxy`는 각 재시도를 별개의 요청으로 처리하여 모든 Log에 `upstream_request_attempt_count`가 `1`로 기록된다.

#### 1.3.6. Upstream TCP RST before Response Case

{{< figure caption="[Figure 23] Upstream TCP RST before Response Case" src="images/grpc-upstream-tcp-rst-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 24] Upstream TCP RST before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/ResetBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 23]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/ResetBeforeResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, 1000ms 대기후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST before Response Case를 나타내고 있다. [Shell 24]은 [Figure 23]의 내용을 실행하는 예시를 나타내고 있다.

TCP RST Flag를 받은 `mock-server` Pod의 `istio-proxy`는 `Unavailable` 상태 코드를 반환하여 요청이 비정상적으로 종료된것을 `shell` Pod의 `istio-proxy`에게 알린다. [File 1]의 Virtual Service에 `unavailable` 설정에 의해서 `shell` Pod의 `istio-proxy`는 2번의 재시도를 수행하여 총 3번의 요청을 전송한다.

```json {caption="[Text 42] Upstream TCP RST before Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 43] Upstream TCP RST before Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 42]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 43]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/ResetBeforeResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unavailable`로 나타나는 것을 확인할 수 있다. 또한 두 Access Log에서 모두 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

`shell` Pod의 `istio-proxy`가 3번의 요청을 전송하기 때문에 `shell Pod`의 `istio-proxy`의 Access Log에서 `upstream_request_attempt_count`가 `3`으로 나타나는 것을 확인할 수 있다. 또한 `mock-server` Pod의 `istio-proxy`의 Access Log가 3번이 남아있는것을 확인할 수 있다.

#### 1.3.7. Upstream TCP RST after Response Case

{{< figure caption="[Figure 24] Upstream TCP RST after Response Case" src="images/grpc-upstream-tcp-rst-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 25] Upstream TCP RST after Response Case / grpcurl Command", linenos=table}
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

[Figure 24]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/ResetAfterResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 TCP RST Flag를 전송하여 Connection을 강제로 종료하는 Upstream TCP RST after Response Case를 나타내고 있다. [Shell 25]은 [Figure 24]의 내용을 실행하는 예시를 나타내고 있다.

```json {caption="[Text 44] Upstream TCP RST after Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 45] Upstream TCP RST after Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 44]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 45]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/ResetAfterResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unknown`로 나타나는 것을 확인할 수 있다. `shell` Pod의 `istio-proxy`의 Access Log에서 `response_flags`가 `UR (UpstreamRemoteReset)`로 나타나는 것을 확인할 수 있으며, `mock-server` Pod의 `istio-proxy`의 Access Log에서 `response_flags`가 `UC (UpstreamConnectionTermination)`로 나타나는 것을 확인할 수 있다.

#### 1.3.8. Upstream TCP Close before Response Case

{{< figure caption="[Figure 25] Upstream TCP Close before Response Case" src="images/grpc-upstream-tcp-close-before-response-case.png" width="1000px" >}}

```shell {caption="[Shell 26] Upstream TCP Close before Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseBeforeResponse
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: connection termination
command terminated with exit code 78
```

[Figure 25]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/CloseBeforeResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 Connection을 강제로 종료하는 Upstream TCP Close before Response Case를 나타내고 있다. [Shell 26]은 [Figure 25]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Container에서 TCP FIN Flag를 전송한다는 부분만 제외하고 TCP RST Flag를 받는 [Figure 23]과 동일한 과정을 수행한다는 것을 알 수 있다.

```json {caption="[Text 46] Upstream TCP Close before Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 47] Upstream TCP Close before Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 46]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 47]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/CloseBeforeResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unavailable`로 나타나는 것을 확인할 수 있다. TCP RST Flag를 받는 [Figure 23]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.9. Upstream TCP Close after Response Case

{{< figure caption="[Figure 26] Upstream TCP Close after Response Case" src="images/grpc-upstream-tcp-close-after-response-case.png" width="1000px" >}}

```shell {caption="[Shell 27] Upstream TCP Close after Response Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService/CloseAfterResponse
ERROR:
  Code: Internal
  Message: stream terminated by RST_STREAM with error code: NO_ERROR
command terminated with exit code 77
```

[Figure 26]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/CloseAfterResponse` 함수에 `milliseconds: 1000` 요청을 전달하고, `1000ms` 후에 `mock-server` Pod가 응답을 일부 전송한 후에 Connection을 강제로 종료하는 Upstream TCP Close after Response Case를 나타내고 있다. [Shell 27]은 [Figure 26]의 내용을 실행하는 예시를 나타내고 있다.

`mock-server` Container에서 TCP FIN Flag를 전송한다는 부분만 제외하고 TCP RST Flag를 받는 [Figure 24]과 동일한 과정을 수행한다는 것을 알 수 있다.

```json {caption="[Text 48] Upstream TCP Close after Response Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 49] Upstream TCP Close before Response Case / mock-server Pod Access Log", linenos=table}
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

[Text 48]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 49]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. 두 Access Log에서 모두 `/mock.MockService/CloseAfterResponse` 함수에 접근하는 내역과 `response_code`가 `200`, `grpc_status`가 `Unknown`로 나타나는 것을 확인할 수 있다. TCP RST Flag를 받는 [Figure 24]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.10. Circuit Breaking with Upstream Connection Pool Overflow Case

{{< figure caption="[Figure 27] Circuit Breaking with Upstream Connection Pool Overflow Case" src="images/grpc-circuit-breaking-with-upstream-connection-pool-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 28] Circuit Breaking with Upstream Connection Pool Overflow Case / grpcurl Command", linenos=table}
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

[Figure 27]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 5000` 요청을 3번 연속으로 전달하여 Upstream Connection Pool Overflow를 발생시키는 Case를 나타내고 있다. [Shell 28]은 [Figure 27]의 내용을 실행하는 예시를 나타내고 있다. GRPC로 요청과 응답이 온다는 부분을 제외하고는 [Figure 12]에서 설명한 것과 동일한 과정을 수행한다.

```json {caption="[Text 50] Circuit Breaking with Upstream Connection Pool Overflow Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 51] Circuit Breaking with Upstream Connection Pool Overflow Case / mock-server Pod Access Log", linenos=table}
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

[Text 50]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 51]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고 [Text 22], [Text 23]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.11. Circuit Breaking with Upstream Request Limit Overflow Case

{{< figure caption="[Figure 28] Circuit Breaking with Upstream Request Limit Overflow Case" src="images/grpc-circuit-breaking-with-upstream-request-limit-overflow-case.png" width="1000px" >}}

```shell {caption="[Shell 29] Circuit Breaking with Upstream Request Limit Overflow Case / grpcurl Command", linenos=table}
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

[Figure 28]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 5000` 요청을 3번 연속으로 전달하여 Upstream Request Limit Overflow를 발생시키는 Case를 나타내고 있다. 이 Case를 재현하기 위해서는 [File 2]에서 설정한 Destination Rule을 적용해야한다. [Shell 29]은 [Figure 28]의 내용을 실행하는 예시를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고는 [Figure 13]에서 설명한 것과 동일한 과정을 수행한다.

```json {caption="[Text 52] Circuit Breaking with Upstream Request Limit Overflow Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 53] Circuit Breaking with Upstream Request Limit Overflow Case / mock-server Pod Access Log", linenos=table}
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

[Text 52]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 53]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고 [Text 24], [Text 25]과 동일한 과정을 수행한다는 것을 알 수 있다.

#### 1.3.12. Circuit Breaking with No Healthy Upstream Case

{{< figure caption="[Figure 29] Circuit Breaking with No Healthy Upstream Case" src="images/grpc-circuit-breaking-with-no-healthy-upstream-case.png" width="1000px" >}}

```shell {caption="[Shell 30] Circuit Breaking with No Healthy Upstream Case / grpcurl Command", linenos=table}
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

[Figure 29]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 13` 요청을 8번 연속으로 전달하여 No Healthy Upstream을 통한 Circuit Breaking을 발생시키는 Case를 나타내고 있다. [Shell 30]은 [Figure 29]의 내용을 실행하는 예시를 나타내고 있다.

[File 1]의 Destination Rule에 의해서 5번의 연속적인 5XX Error가 발생하면 Circuit Breaking이 동작한다. 따라서 `shell` Pod의 첫 5번의 요청은 모두 `mock-server` Pod에게 전달되지만, 이후에 3번의 요청은 Circuit Breaking으로 인해서 `mock-server` Pod에 전달되지 않는다. 따라서 첫번째 5번의 요청에 대한 응답은 `Internal`로 나타나고, 이후에 3번의 요청에 대한 응답은 `Unavailable`로 나타난다.

```json {caption="[Text 54] Circuit Breaking Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 55] Circuit Breaking Case / mock-server Pod Access Log", linenos=table}
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

[Text 54]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 55]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`의 Access Log에는 마지막 3개의 요청에만 `response_flags`가 `UH (NoHealthyUpstream)`와 함께 요청이 `mock-server` Pod에 전달되지 않은 것을 확인할 수 있다. 또한 `mock-server` Pod의 `istio-proxy`의 Access Log에는 처음 5개의 요청에 대한 Log만 남아있는것도 확인할 수 있다.

#### 1.3.13. Upstream Connection Failure with Timeout Case

{{< figure caption="[Figure 30] Upstream Connection Failure with Timeout Case" src="images/grpc-upstream-connection-failure-case-with-timeout.png" width="1000px" >}}

```shell {caption="[Shell 31] Upstream Connection Failure with Timeout Case / iptables Command", linenos=table}
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

[Figure 30]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 0` 요청을 3번 연속으로 전달하여 Timeout에 의해서 Retry되는 Upstream Connection Failure with Timeout Case를 나타내고 있다. [Shell 31]은 [Figure 30]의 내용을 실행하는 예시를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고는 [Figure 15]에서 설명한 것과 동일한 과정을 수행한다.

```json {caption="[Text 56] Upstream Connection Failure with Timeout Case / shell Pod Access Log", linenos=table}
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

[Text 56]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고는 [Text 28]와 동일한 과정을 수행한다.

#### 1.3.14. Upstream Connection Failure with TCP Reset Case

{{< figure caption="[Figure 31] Upstream Connection Failure with TCP Reset Case" src="images/grpc-upstream-connection-failure-case-with-tcp-reset.png" width="1000px" >}}

```shell {caption="[Shell 32] Upstream Connection Failure with TCP Reset Case / iptables Command", linenos=table}
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

[Figure 31]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Status` 함수에 `code: 0` 요청을 3번 연속으로 전달하여 TCP Reset에 의해서 Retry되는 Upstream Connection Failure with TCP Reset Case를 나타내고 있다. [Shell 32]은 [Figure 31]의 내용을 실행하는 예시를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고는 [Figure 16]에서 설명한 것과 동일한 과정을 수행한다.

```json {caption="[Text 57] Upstream Connection Failure with TCP Reset Case / shell Pod Access Log", linenos=table}
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

[Text 57]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. GRPC로 요청과 응답이 발생한다는 부분을 제외하고는 [Text 29]와 동일한 과정을 수행한다.

#### 1.3.15. Upstream Request Timeout Case

{{< figure caption="[Figure 32] Upstream Request Timeout Case" src="images/grpc-upstream-request-timeout-case.png" width="1000px" >}}

```shell {caption="[Shell 33] Upstream Request Timeout Case / grpcurl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 70000}' mock-server:9090 mock.MockService/Delay
```

[Figure 32]는 `shell` Pod에서 `grpcurl` 명령어를 이용하여 `mock-server`의 `/mock.MockService/Delay` 함수에 `milliseconds: 70000` 요청을 전달하였지만 `mock-server` Pod의 `istio-proxy`에서 60000ms 대기후에 응답이 오지 않아 Request를 Timeout 처리하는 Upstream Request Timeout Case를 나타내고 있다. 

[File 1]의 Virtual Service에 의해서 `mock-server` Pod로 전송된 요청은 최대 60000ms 대기할 수 있다. 하지만 `mock-server` Pod의 `/mock.MockService/Delay` 함수에 `milliseconds: 70000`과 함께 전달할 요청은 70000ms가 필요하기 때문에 Timeout이 발생한다. `mock-server` Pod의 `istio-proxy`는 Timeout 발생시 HTTP/2 RST_STREAM Frame을 전송하여, `mock-server` Pod와의 연결을 종료한다. 또한 `Unavailable` 상태 코드를 반환하여 요청이 비정상적으로 종료된것을 `shell` Pod의 `istio-proxy`에게 알린다.

```json {caption="[Text 58] Upstream Request Timeout Case / shell Pod Access Log", linenos=table}
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

```json {caption="[Text 59] Upstream Request Timeout Case / mock-server Pod Access Log", linenos=table}
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

[Text 58]는 `shell` Pod의 `istio-proxy`의 Access Log를 나타내고 있으며, [Text 59]는 `mock-server` Pod의 `istio-proxy`의 Access Log를 나타내고 있다. `shell` Pod의 `istio-proxy`에는 `response_flags`에 `UT (UpstreamTimeout)`를 확인할 수 있다. `mock-server` Pod의 `istio-proxy`에는 `response_flags`에 `DR (DownstreamRemoteReset)`를 확인할 수 있다.

## 2. 참조

* Istio Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)
* Enovy Access Log : [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string)