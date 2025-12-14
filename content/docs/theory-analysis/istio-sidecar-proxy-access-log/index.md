---
title: Istio Sidecar Proxy Access Log
draft: true
---

## 1. Test 환경 구성

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

| Field | Description |
|-------|-------------|
| `start_time` | The time the request started. |
| `method` | The HTTP method of the request. |
| `path` | The path of the request. |
| `protocol` | The protocol of the request. |
| `response_code` | The HTTP status code of the response. |
| `response_flags` | The flags of the response. |
| `response_code_details` | The details of the response code. |
| `connection_termination_details` | The details of the connection termination. |
| `upstream_transport_failure_reason` | The reason for the upstream transport failure. |
| `bytes_received` | The number of bytes received from the upstream. |
| `bytes_sent` | The number of bytes sent to the downstream. |
| `duration` | The duration of the request. |
| `upstream_service_time` | The time it took for the upstream service to process the request. |
| `x_forwarded_for` | The X-Forwarded-For header of the request. |
| `user_agent` | The User-Agent header of the request. |
| `request_id` | The request ID of the request. |
| `authority` | The authority of the request. |
| `upstream_host` | The upstream host of the request. |
| `upstream_cluster` | The upstream cluster of the request. |
| `upstream_local_address` | The upstream local address of the request. |
| `downstream_local_address` | The downstream local address of the request. |
| `downstream_remote_address` | The downstream remote address of the request. |
| `requested_server_name` | The requested server name of the request. |
| `route_name` | The route name of the request. |
| `grpc_status` | The gRPC status of the request. |
| `upstream_request_attempt_count` | The number of upstream request attempts. |
| `request_duration` | The duration of the request. |
| `response_duration` | The duration of the response. |

## 2. Istio Sidecar Proxy Access Log

### 2.1. HTTP Cases

#### 2.1.1. 200 OK Success Case

```shell {caption="[Shell 2] 200 OK Success Case / curl Command", linenos=table}
$ curl -s mock-server:8080/status/200
```

```json {caption="[Text 2] 200 OK Success Case / curl Client", linenos=table}
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
$ curl -s mock-server:8080/delay/10000
^C
```

### 2.2. GRPC Cases

## 3. 참조

* Istio Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)
* Enovy Access Log : [https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#default-format-string)