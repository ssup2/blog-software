---
title: Istio Sidecar Proxy Access Log
draft: true
---

## 1. Istio Sidecar Proxy Access Log

Istio 환경에서 다양한 Case에 따른 Sidecar Proxy의 Access Log를 살펴본다.

### 1.1. Test 환경 구성

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="700px" >}}

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
    image: ghcr.io/ssup2/mock-go-server:0.1.4
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
  - retries:
      attempts: 2
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
        maxConnections: 1   # default value is 2^31-1
      http:
        http1MaxPendingRequests: 1   # default value is 2^31-1 (unlimited)
        http2MaxRequests: 1          # default value is 2^31-1 (unlimited)
    outlierDetection:
      consecutive5xxErrors: 5   # default value is 5
      interval: 10s             # default value is 10s
      baseEjectionTime: 30s     # default value is 30s
      maxEjectionPercent: 100   # default value is 100
```

{{< table caption="[Table 1] mock-server HTTP Endpoints" >}}
| Endpoint | Description |
|---|---|
| /status/{code} | Return specific HTTP status code |
| /delay/{ms} | Delay response by milliseconds |
| /disconnect/{ms} | Server closes connection after milliseconds |
{{< /table >}}

{{< table caption="[Table 2] mock-server gRPC Endpoints" >}}
| Endpoint | Description |
|---|---|
| /mock.MockService.Status | Return specific gRPC status code |
| /mock.MockService.Delay | Delay response by milliseconds |
| /mock.MockService.Disconnect | Server closes connection after milliseconds |
{{< /table >}}

[File 1]은 mock-server Workload의 Manifest를 나타내고 있다. mock-server Image를 이용하여 mock-server Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공하고, `9090` Port를 열어서 gRPC 서비스를 제공한다. [Table 1]과 [Table 2]는 `mock-server` Workload의 HTTP, gRPC Endpoint별 동작을 나타내고 있다. `mock-server`에서 제공하는 Endpoint들을 다양한 Case를 재현하기 위해서 사용한다.

```yaml {caption="[File 2] shell Pod Manifest", linenos=table}
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

```shell {caption="[Shell 2] Copy mock.proto to shell Pod", linenos=table}
$ kubectl cp proto/mock.proto shell:mock.proto
```

[File 2]는 `shell` Pod의 Manifest를 나타내고 있다. netshoot Image를 이용하여 `shell` Pod을 생성하며, Network Admin 권한을 부여하여 `iptables` 명령어를 이용할 수 있도록 한다. [Shell 2]는  mock.proto 파일을 shell Pod에 복사하는 Script를 나타내고 있다.

## 2. Istio Sidecar Proxy Access Log

### 2.1. HTTP Cases

#### 2.1.1. Success Case

```shell {caption="[Shell 2] Success Case / curl Command", linenos=table}
$ curl -s mock-server:8080/status/200
```

```json {caption="[Text 2] Success Case / curl Client", linenos=table}
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

```json {caption="[Text 3] 200 OK Success Case / Mock Server", linenos=table}
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

#### 2.1.2. Downstream Remote Disconnect Case

```shell {caption="[Shell 5] Timeout Case / curl Command", linenos=table}
$ curl -s mock-server:8080/delay/10000
^C
```

```json {caption="[Text 6] Timeout Case / curl Client", linenos=table}
{
  "start_time": "2025-12-14T15:31:56.209Z",
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
  "duration": "1870",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "c9b2decb-ebc7-9ab4-99d6-69712772ef41",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.3:34506",
  "downstream_local_address": "10.96.191.168:8080",
  "downstream_remote_address": "10.244.2.3:54024",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 7] Timeout Case / Mock Server", linenos=table}
{
  "start_time": "2025-12-14T15:31:56.210Z",
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
  "duration": "1877",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "c9b2decb-ebc7-9ab4-99d6-69712772ef41",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:53009",
  "downstream_local_address": "10.244.1.4:8080",
  "downstream_remote_address": "10.244.2.3:34506",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

#### 2.1.3. Upstream Remote Disconnect Case

```shell {caption="[Shell 8] Upstream Remote Disconnect Case / curl Command", linenos=table}
$ curl mock-server:8080/disconnect/1000
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

```json {caption="[Text 9] Upstream Remote Disconnect Case / curl Client", linenos=table}
{
  "start_time": "2025-12-15T16:19:32.636Z",
  "method": "GET",
  "path": "/disconnect/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1085",
  "upstream_service_time": "1077",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "d4f9a535-98b1-962f-a739-c9ceb8f4b6a9",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.2.3:48284",
  "downstream_local_address": "10.96.191.168:8080",
  "downstream_remote_address": "10.244.2.3:37140",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1085"
}
```

```json {caption="[Text 10] Upstream Remote Disconnect Case / Mock Server", linenos=table}
{
  "start_time": "2025-12-15T16:19:32.654Z",
  "method": "GET",
  "path": "/disconnect/1000",
  "protocol": "HTTP/1.1",
  "response_code": "503",
  "response_flags": "UC",
  "response_code_details": "upstream_reset_before_response_started{connection_termination}",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "0",
  "bytes_sent": "95",
  "duration": "1052",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "curl/8.14.1",
  "request_id": "d4f9a535-98b1-962f-a739-c9ceb8f4b6a9",
  "authority": "mock-server:8080",
  "upstream_host": "10.244.1.4:8080",
  "upstream_cluster": "inbound|8080||",
  "upstream_local_address": "127.0.0.6:60795",
  "downstream_local_address": "10.244.1.4:8080",
  "downstream_remote_address": "10.244.2.3:48284",
  "requested_server_name": "outbound_.8080_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "6",
  "response_duration": "-"
}
```

#### 2.1.4. Upstream Overflow Case

```shell {caption="[Shell 14] Upstream Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
```

```json {caption="[Shell 15] Upstream Overflow Case / istioctl Command", linenos=table}
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

```json {caption="[Text 16] Upstream Overflow Case / Mock Server", linenos=table}
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

#### 2.1.5. Circuit Breaking Case

```shell {caption="[Shell 12] No Healthy Upstream Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl mock-server:8080/status/503
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
{"message":"Service Unavailable","service":"mock-server","status_code":503}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/503 
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/200
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}
```

```json {caption="[Shell 13] Circuit Breaking Case / istioctl Command", linenos=table}
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

```json {caption="[Text 15] Circuit Breaking Case / Mock Server", linenos=table}
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

#### 2.1.6. Upstream Request Retry Case with Timeout

```shell {caption="[Shell 9] Upstream Request Retry Case / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables -A INPUT -s ${SHELL_IP} -j DROP
```

```shell {caption="[Shell 10] Upstream Request Retry Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl mock-server:8080/status/200
upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/200
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/200
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}
```

```json {caption="[Text 12] Upstream Request Retry Case / curl Client", linenos=table}
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

```shell {caption="[Shell 11] Upstream Request Retry Case / istioctl Command", linenos=table}
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}
```

`consecutive5xxErrors` : 5이기 때문에

#### 2.1.7. Upstream Request Retry Case with TCP Reset

```shell {caption="[Shell 9] Upstream Request Retry Case / iptables Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables-legacy -A INPUT -p tcp -s ${SHELL_IP} -j REJECT --reject-with tcp-reset
```

```shell {caption="[Shell 10] Upstream Request Retry Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl mock-server:8080/status/200
upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/200
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}

$ kubectl exec -it shell -- curl mock-server:8080/status/200
no healthy upstream
$ istioctl proxy-config endpoint shell -o json | jq '.[] | select(.name | contains("8080||mock-server")) | .hostStatuses[].healthStatus'
{
  "failedOutlierCheck": true,
  "edsHealthStatus": "HEALTHY"
}
```

```json {caption="[Text 12] Upstream Request Retry Case / curl Client", linenos=table}
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

#### 2.1.8. No Healthy Upstream Case

```shell {caption="[Shell 12] No Healthy Upstream Case / curl Command", linenos=table}
$ kubectl exec -it shell -- curl mock-server:8080/status/200          
no healthy upstream
```

```json {caption="[Text 14] No Healthy Upstream Case / curl Client", linenos=table}
{
  "start_time": "2025-12-21T08:20:10.288Z",
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
  "request_id": "3860e4b1-1bd2-908b-8673-af357e4296d6",
  "authority": "mock-server:8080",
  "upstream_host": "-",
  "upstream_cluster": "outbound|8080||mock-server.default.svc.cluster.local",
  "upstream_local_address": "-",
  "downstream_local_address": "10.96.225.216:8080",
  "downstream_remote_address": "10.244.2.5:37982",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

### 2.2. GRPC Cases

#### 2.2.1. Success Case

```shell {caption="[Shell 16] Success Case / curl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService.Status
{
  "service": "mock-server",
  "message": "OK"
}
```

```json {caption="[Text 15] Success Case / curl Client", linenos=table}
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

```json {caption="[Text 16] Success Case / istioctl Command", linenos=table}
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

#### 2.2.2. Internal Server Error Case

```shell {caption="[Shell 17] Internal Server Error Case / curl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 13}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)
command terminated with exit code 77
```

```json {caption="[Text 17] Internal Server Error Case / curl Client", linenos=table}
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

```json {caption="[Text 18] Internal Server Error Case / istioctl Command", linenos=table}
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

#### 2.2.3. Downstream Disconnect Case

```shell {caption="[Shell 17] Downstream Remote Disconnect Case / curl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 10000}' mock-server:9090 mock.MockService.Delay
^C
```

```json {caption="[Text 17] Downstream Remote Disconnect Case / curl Client", linenos=table}
{
  "start_time": "2025-12-25T11:26:57.849Z",
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
  "duration": "6627",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "6604fb4f-9d82-9617-bbd9-a7a849695692",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:58590",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:40966",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

```json {caption="[Text 18] Downstream Remote Disconnect Case / istioctl Command", linenos=table} 
{
  "start_time": "2025-12-25T11:26:57.850Z",
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
  "duration": "6634",
  "upstream_service_time": "-",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "6604fb4f-9d82-9617-bbd9-a7a849695692",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:43691",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:58590",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "-",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "-"
}
```

#### 2.2.4. Upstream Disconnect Case

```shell {caption="[Shell 18] Upstream Disconnect Case / curl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 1000}' mock-server:9090 mock.MockService.Disconnect
RROR:
  Code: Unavailable
  Message: connection closed by server
command terminated with exit code 78
```

```json {caption="[Text 19] Upstream Disconnect Case / curl Client", linenos=table}
{
  "start_time": "2025-12-25T11:47:17.883Z",
  "method": "POST",
  "path": "/mock.MockService/Disconnect",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "URX",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "3136",
  "upstream_service_time": "3131",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "3f9b6820-408e-9e38-a7f6-8eed233a9457",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "outbound|9090||mock-server.default.svc.cluster.local",
  "upstream_local_address": "10.244.1.5:58590",
  "downstream_local_address": "10.96.186.69:9090",
  "downstream_remote_address": "10.244.1.5:46598",
  "requested_server_name": "-",
  "route_name": "-",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "3",
  "request_duration": "4",
  "response_duration": "3135"
}
```

```json {caption="[Text 20] Upstream Disconnect Case / istioctl Command", linenos=table}
{
  "start_time": "2025-12-25T11:47:20.014Z",
  "method": "POST",
  "path": "/mock.MockService/Disconnect",
  "protocol": "HTTP/2",
  "response_code": "200",
  "response_flags": "-",
  "response_code_details": "via_upstream",
  "connection_termination_details": "-",
  "upstream_transport_failure_reason": "-",
  "bytes_received": "8",
  "bytes_sent": "0",
  "duration": "1004",
  "upstream_service_time": "1003",
  "x_forwarded_for": "-",
  "user_agent": "grpcurl/v1.9.3 grpc-go/1.61.0",
  "request_id": "3f9b6820-408e-9e38-a7f6-8eed233a9457",
  "authority": "mock-server:9090",
  "upstream_host": "10.244.2.8:9090",
  "upstream_cluster": "inbound|9090||",
  "upstream_local_address": "127.0.0.6:43691",
  "downstream_local_address": "10.244.2.8:9090",
  "downstream_remote_address": "10.244.1.5:58590",
  "requested_server_name": "outbound_.9090_._.mock-server.default.svc.cluster.local",
  "route_name": "default",
  "grpc_status": "Unavailable",
  "upstream_request_attempt_count": "1",
  "request_duration": "0",
  "response_duration": "1004"
}
```

#### 2.2.5. Upstream Overflow Case

```shell {caption="[Shell 21] Upstream Overflow Case / curl Command", linenos=table}
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService.Delay &
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService.Delay &
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: overflow
command terminated with exit code 78
$ kubectl exec shell -- grpcurl -plaintext -proto mock.proto -d '{"milliseconds": 5000}' mock-server:9090 mock.MockService.Delay &
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. reset reason: overflow
command terminated with exit code 78
```

```json {caption="[Text 21] Upstream Overflow Case / curl Client", linenos=table}
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

```json {caption="[Text 22] Upstream Overflow Case / istioctl Command", linenos=table}
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

```shell {caption="[Shell 23] Circuit Breaking Case / curl Command", linenos=table}
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

```json {caption="[Text 23] Circuit Breaking Case / curl Client", linenos=table}
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

```json {caption="[Text 24] Circuit Breaking Case / istioctl Command", linenos=table}
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

```shell {caption="[Shell 13] Upstream Request Retry Case with Timeout / curl Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables -A INPUT -s ${SHELL_IP} -j DROP
$ kubectl exec mock-server -c mock-server -- iptables -D INPUT 1
```

```shell {caption="[Shell 13] Upstream Request Retry Case with Timeout / istioctl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto  -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
command terminated with exit code 78
```

```json {caption="[Text 24] Upstream Request Retry Case with Timeout / curl Client", linenos=table}
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

```shell {caption="[Shell 13] Upstream Request Retry Case with TCP Reset / curl Command", linenos=table}
$ SHELL_IP=$(kubectl get pod shell -o jsonpath='{.status.podIP}')
$ kubectl exec mock-server -c mock-server -- iptables-legacy -A INPUT -p tcp -s ${SHELL_IP} -j REJECT --reject-with tcp-reset
$ kubectl exec mock-server -c mock-server -- iptables-legacy -D INPUT 1
```

```shell {caption="[Shell 13] Upstream Request Retry Case with TCP Reset / istioctl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused
command terminated with exit code 78
```

```json {caption="[Text 24] Upstream Request Retry Case with TCP Reset / curl Client", linenos=table}
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

```shell {caption="[Shell 13] No Healthy Upstream Case / curl Command", linenos=table}
$ kubectl exec -it shell -- grpcurl -plaintext -proto mock.proto -d '{"code": 0}' mock-server:9090 mock.MockService.Status
ERROR:
  Code: Unavailable
  Message: no healthy upstream
command terminated with exit code 78
```

```json {caption="[Text 24] No Healthy Upstream Case / curl Client", linenos=table}
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

## 3. 참조

* Istio Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)
* Enovy Access Log : [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string)