---
title: Istio Sidecar Proxy
---

Istio의 Sidecar Proxy를 분석한다.

## 1. Istio Sidecar Proxy

{{< figure caption="[Figure 1] Istio Sidecar" src="images/istio-sidecar.png" width="600px" >}}

Istio의 Sidecar Proxy 기법은 각 Pod 마다 전용 Proxy Server를 띄우는 기법을 의미한다. [Figure 1]은 Istio Sidecar Proxy의 Architecture를 나타내고 있다. Sidecar Proxy는 Pod으로 전달되는 모든 Inbound Packet을 대신 수신한 다음, 처리 후 Pod의 App Container에게 대신 전송하는 역할을 수행한다. 또한 Sidecar Proxy는 App Container에서 밖으로 전송되는 모든 Packet을 대신 수신한 다음, 처리 후 Pod의 외부로 대신 전송하는 역할을 수행한다.

Sidecar Proxy는 Packet 전송에 필요한 모든 정보를 알고 있어야 한다. Sidecar Proxy는 이러한 Packet 전송에 필요한 정보를 Istiod라고 불리는 중앙 Controller로 부터 받는다. Istiod가 Sidecar Proxy에게 전송하는 정보에는 Pod에서 동작하는 App이 제공하는 Service 정보, Packet 송수신 허용 여부를 결정하는 Policy 정보, Packet 암호화를 위한 인증서 정보등이 포함되어 있다. 여기서 Service는 Kubernetes의 Service Object 또는 Istio의 Virtual Service Object를 의미한다. Sidecar Proxy는 Istiod로 부터 받은 정보들을 바탕으로 Packet Load Balancing, Packet Encap/Decap, Rate Limit, Circuit Breaker 등의 다양한 역할을 수행한다.

Sidecar Proxy는 실제로 App Pod안에서 별도의 Container로 동작하며, Sidecar Proxy Container안에는 실제 Sidecar Proxy 역할을 수행하는 **Envoy**와 Istiod로부터 정보를 받아 Envoy를 설정하는 **pilot-agent**로 구성되어 있다. Envoy는 HTTP, gRPC, TCP등 다양한 Protocol을 지원하며 따라서 App에서도 다양한 Protocol을 기반으로 Packet을 주고받을 수 있다. pilot-agent 및 Envoy는 자체적으로 Metric 정보를 수집하며, 수집된 Metric 정보는 Prometheus, Jaeger와 같은 외부 Component에 의해서 수집된다.

### 1.1. Sidecar Proxy Injection

Sidecar Proxy는 Pod안에서 Container로 동작한다. 따라서 Sidecar Proxy가 Pod안에서 Container로 Injection되어 동작할 수 있도록 설정해주어야 한다. Sidecar Proxy 설정은 각 Pod마다 수동으로 설정할 수도 있고, Namespace 단위로 설정하여 Namespace안에서 생성되는 모든 Pod에서 Sidecar Proxy가 동작하도록 설정할 수 있다.

#### 1.1.1. Manual 설정

```yaml {caption="[File 1] istioctl kube-inject 적용 전 nginx Deployment Manifest", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

```yaml {caption="[File 2] istioctl kube-inject 적용 후 nginx Deployment Manifest", linenos=table}
apiVersion: apps/v1
kind: Deployment
...
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
      - args:
        - proxy
        - sidecar
        - --domain
        - $(POD-NAMESPACE).svc.cluster.local
        - --serviceCluster
        - nginx.$(POD-NAMESPACE)
        - --proxyLogLevel=warning
        - --proxyComponentLogLevel=misc:error
        - --concurrency
        - "2"
        env:
        - name: JWT-POLICY
          value: first-party-jwt
        - name: PILOT-CERT-PROVIDER
          value: istiod
        - name: CA-ADDR
          value: istiod.istio-system.svc:15012
        - name: POD-NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD-NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: INSTANCE-IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: SERVICE-ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: HOST-IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: CANONICAL-SERVICE
          valueFrom:
            fieldRef:
              fieldPath: metadata.labels['service.istio.io/canonical-name']
        - name: CANONICAL-REVISION
          valueFrom:
            fieldRef:
              fieldPath: metadata.labels['service.istio.io/canonical-revision']
        - name: PROXY-CONFIG
          value: |
            {"proxyMetadata":{"DNS-AGENT":""}}
        - name: ISTIO-META-POD-PORTS
          value: |-
            [
                {"containerPort":80}
            ]
        - name: ISTIO-META-APP-CONTAINERS
          value: nginx
        - name: ISTIO-META-CLUSTER-ID
          value: Kubernetes
        - name: ISTIO-META-INTERCEPTION-MODE
          value: REDIRECT
        - name: ISTIO-META-WORKLOAD-NAME
          value: nginx-deployment
        - name: ISTIO-META-OWNER
          value: kubernetes://apis/apps/v1/namespaces/default/deployments/nginx-deployment
        - name: ISTIO-META-MESH-ID
          value: cluster.local
        - name: TRUST-DOMAIN
          value: cluster.local
        - name: DNS-AGENT
        image: docker.io/istio/proxyv2:1.8.1
        imagePullPolicy: Always
        name: istio-proxy
        ports:
        - containerPort: 15090
          name: http-envoy-prom
          protocol: TCP
        readinessProbe:
          failureThreshold: 30
          httpGet:
            path: /healthz/ready
            port: 15021
          initialDelaySeconds: 1
          periodSeconds: 2
          timeoutSeconds: 3
        resources:
          limits:
            cpu: "2"
            memory: 1Gi
          requests:
            cpu: 10m
            memory: 40Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: true
          runAsGroup: 1337
          runAsNonRoot: true
          runAsUser: 1337
        volumeMounts:
        - mountPath: /var/run/secrets/istio
          name: istiod-ca-cert
        - mountPath: /var/lib/istio/data
          name: istio-data
        - mountPath: /etc/istio/proxy
          name: istio-envoy
        - mountPath: /etc/istio/pod
          name: istio-podinfo
      initContainers:
      - args:
        - istio-iptables
        - -p
        - "15001"
        - -z
        - "15006"
        - -u
        - "1337"
        - -m
        - REDIRECT
        - -i
        - '*'
        - -x
        - ""
        - -b
        - '*'
        - -d
        - 15090,15021,15020
        env:
        - name: DNS-AGENT
        image: docker.io/istio/proxyv2:1.8.1
        imagePullPolicy: Always
        name: istio-init
        resources:
          limits:
            cpu: "2"
            memory: 1Gi
          requests:
            cpu: 10m
            memory: 40Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET-ADMIN
            - NET-RAW
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: false
          runAsGroup: 0
          runAsNonRoot: false
          runAsUser: 0
      securityContext:
        fsGroup: 1337
      volumes:
      - emptyDir:
          medium: Memory
        name: istio-envoy
      - emptyDir: {}
        name: istio-data
      - downwardAPI:
          items:
          - fieldRef:
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              fieldPath: metadata.annotations
            path: annotations
        name: istio-podinfo
      - configMap:
          name: istio-ca-root-cert
        name: istiod-ca-cert
...
```

`istioctl kube-inject` 명령어를 통해서 Deployment, StatefulSet, DaemonSet등의 Pod를 관리하는 Object의 Manifest를 변경하여 Pod에 Sidecar Proxy가 생성되도록 만든다. [File 1]은 `istioctl kube-inject` 명령어 적용 전 nginx Deployment Manifest 파일을 나타내고 있고, [File 2]는 `istioctl kube-inject` 명령어 적용 후 nginx Deployment Manifest 파일을 나타내고 있다. Sidecar Proxy인 `istio-proxy` Container가 추가되었고, Sidecar Proxy의 Network 설정을 담당하는 `istio-init` Init Container가 추가된 것을 확인할 수 있다.

```shell {caption="[Shell 1] istioctl kube-inject 이용", linenos=table}
$ istioctl kube-inject -f nginx-deployment.yaml | kubectl apply -f -
```

[Shell 1]과 같이 `istioctl kube-inject` 명령어를 수행하면 Pod이 새로 생성되면서 Sidecar Proxy가 Injection 된다.

#### 1.1.2. Namespace 설정

Label에 `istio-injection=enabled`이 붙어있는 Namespace안에 Pod이 생성될 경우에는 Istio는 Sidecar Proxy Injection을 수행하여 Kubernetes의 사용자의 개입없이 Pod안에 Sidecar Proxy를 강제로 생성한다. Kubernetes 사용자의 개입없이 Sidecar Proxy Injection을 강제로 수행할 수 있는 이유는 Kubernetes에서 제공하는 Admission Controller 기능을 이용하기 때문이다.

Admission Controller의 Mutating Webhook 기능을 통해서 Pod 관련 Object 생성 요청이 Kubernetes API Server에게 전달되면, Kubernetes API Server는 해당 Pod 생성 요청을 Istiod에게 전송한다. Istiod는 Pod 생성 요청에 Sidecar Proxy 및 Init Container 설정을 추가(Mutating)한 다음에 Kubernetes API 서버에 전달하여 Sidecar Proxy와 Init Container가 생성되도록 한다.

### 1.2. Packet Capture

```shell {caption="[Shell 2] Pod iptables NAT Table with Istio Sidecar", linenos=table}
$ iptables -t nat -nvL
Chain PREROUTING (policy ACCEPT 11729 packets, 704K bytes)
 pkts bytes target     prot opt in     out     source               destination
11729  704K ISTIO-INBOUND  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain INPUT (policy ACCEPT 11729 packets, 704K bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 1074 packets, 95511 bytes)
 pkts bytes target     prot opt in     out     source               destination
   54  3240 ISTIO-OUTPUT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain POSTROUTING (policy ACCEPT 1077 packets, 95691 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain ISTIO-INBOUND (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15008
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:22
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15090
11727  704K RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15021
    2   120 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15020
    0     0 ISTIO-IN-REDIRECT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain ISTIO-IN-REDIRECT (3 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15006

Chain ISTIO-OUTPUT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     all  --  *      lo      127.0.0.6            0.0.0.0/0
    0     0 ISTIO-IN-REDIRECT  all  --  *      lo      0.0.0.0/0           !127.0.0.1            owner UID match 1337
    0     0 RETURN     all  --  *      lo      0.0.0.0/0            0.0.0.0/0            ! owner UID match 1337
   51  3060 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1337
    0     0 ISTIO-IN-REDIRECT  all  --  *      lo      0.0.0.0/0           !127.0.0.1            owner GID match 1337
    0     0 RETURN     all  --  *      lo      0.0.0.0/0            0.0.0.0/0            ! owner GID match 1337
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner GID match 1337
    0     0 RETURN     all  --  *      *       0.0.0.0/0            127.0.0.1
    3   180 ISTIO-REDIRECT  all  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain ISTIO-REDIRECT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    3   180 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15001
```

Sidecar Proxy가 Injection된 Pod로 전송되는 모든 Inbound Packet이 Sidecar Proxy로 전송되는 이유, 또는 Sidecar Proxy가 Injection된 Pod에서 전송되는 모든 Outbound Packet이 Sidecar Proxy로 전송되는 이유는 Pod에 Sidecar Proxy와 같이 설정되는 **Init Container** 때문이다. Init Container는 Pod의 Network Namespace에 `iptables`를 이용하여 Pod의 Inbound/Outbound Packet이 Sidecar로 전송되도록 Redirect하는 Rule을 설정한다.

[Shell 2]는 Sidecar Proxy가 Injection된 Pod안에서 `iptables` DNAT Table을 조회한 결과이다. Pod의 Inbound Packet은 `15006` Port를 통해서 Sidecar Proxy로 전송되고, Pod의 Outbound Packet은 `15001` Port를 통해서 Sidecar Proxy로 전송된다. `15020`, `15090` Port는 Sidecar Proxy의 Prometheus Port로 이용하고 있고, `15020` Port는 Sidecar Proxy의 Health Check Port로 이용하고 있다. 따라서 관련된 Port들은 `ISTIO-INBOUND` Chain에서 Redirect되지 않도록 설정되어 있다. [File 2]를 보면 Sidecar Proxy는 UID/GID `1337`로 동작하도록 설정되어 있는것을 확인할 수 있다. 따라서 UID/GID가 `1337`로 동작하는 Sidecar Proxy가 전송하는 Packet은 Pod에서 Redirect되지 않도록 `ISTIO-OUTPUT` Chain에 설정되어 있다.

Init Container는 `iptables` Rule을 설정해야하기 때문에 [File 2]에서 `NET-ADMIN`, `NET-RAW` Capability를 갖고 동작되도록 설정되어 있는것을 확인할 수 있다. `NET-ADMIN`, `NET-RAW` Capability를 갖고 동작하는 Init Container는 보안상 취약점이 될 수 있다. 이러한 문제를 해결하기 위해서 Istio는 Istio CNI Plugin을 제공한다. Istio CNI Plugin을 통해서 Pod의 Network Namespace에 `iptables` 기반 DNAT Rule을 Host에서 설정할 수 있다.

### 1.3. Traffic Load Balancing

Sidecar Proxy는 Service에게 Traffic 전송시 kube-proxy가 설정하는 iptables/IPVS Rule을 이용하여 Load Balancing을 수행하지 않는다. Sidecar Proxy는 Istiod를 통해서 받는 Service 및 Service와 연결되어 있는 Pod(Endpoint)의 정보를 받아서 직접 L7 Level의 Load Balancing을 수행한다. 따라서 L3/L4 Level의 Load Balancing을 수행하는 kube-proxy에서는 이용할 수 없는 다양한 Load Balancing 기법을 Istio의 Sidecar Proxy를 통해서 적용할 수 있다. Round Robin, Least Connection, Random과 같은 기본적인 Load Balancing 기법부터 시작하여, L7 기반의 Consistent Hash, Locality Base 기법들도 이용할 수 있다.

다만 Istio 환경에서도 여전히 kube-proxy는 필수적인 요소이다. Sidecar Proxy가 존재하지 않는 Pod는 여전히 Service에게 Traffic 전송시에 kube-proxy를 이용하며, Sidecar Proxy가 Istiod와 통신시에도 kube-proxy를 통해서 Istiod에 접근하기 때문이다.

### 1.4. Access Log

Sidecar Proxy는 기본적으로 Access Log를 남기지 않지만, 별도의 설정을 통해서 Access Log 활성화하여 남기도록 설정할 수 있다. Access Log를 활성화하면 많은양의 Log가 발생하기 때문에 평상시에는 Access Log를 비활성화 하는게 좋지만, Network 관련 Trouble Shooting 시에는 Access Log를 일시적으로 활성화하여 활용할 수 있다. Access Log를 활성화 할 수 있는 방법은 **Mesh Config**에 설정하는 방법과, **Telemetry** Object를 이용하는 방법이 있다.

```yaml {caption="[File 3] Set Sidecar Access Log within Mesh Config", linenos=table}
mesh: |-
  accessLogFile: /dev/stdout
...
```

[File 3]은 Istio의 Mesh Config에서 Access Log를 stdout에 출력하도록 설정하는 방법이다. Access Log를 stdout에 출력하도록 설정하면 `kubectl logs` 명령어를 통해서 Sidecar의 Access Log를 확인할 수 있으며, fluentd와 같은 Log Aggregator에서도 수집할 수 있게된다. Mesh Config 방식은 **모든 Sidecar Proxy에 적용되는 Global 방식**만 지원하기 때문에, 특정 Pod의 Sidecar Proxy의 Access Log만을 남기는 설정은 불가능하며 이 경우에는 Telemetry Object를 이용하여 설정해야 한다.

```yaml {caption="[File 4] Set Sidecar Access Log within Telemetry Object", linenos=table}
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  namespace: default
  name: mesh-default
spec:
  selector:
    matchLabels:
      app: productpage
  accessLogging:
    - providers:
      - name: envoy
```

[File 4]는 Telemetry Object를 이용하여 Access Log를 활성한 예제를 나타내고 있다. Global, Namespace, Pod 단위로 Access Log를 설정할 수 있으며, [File 4] 예제는 `default` Namespace에 존재하는 `app: productpage` Label을 갖는 Pod의 Sidecar Proxy의 Access Log만 활성화하도록 설정한 예제이다. `matchLabels`를 통해서 Pod를 선택할 수 있으며, `matchLabels`가 존재하지 않으면 Telemetry Object가 존재하는 Namespace안에 있는 모든 Pod의 Sidecar Proxy의 Access Log가 활성화된다. 만약 Telemetry Object가 존재하는 Namespace가 Istio의 Root Configuration Namespace인 `istio-system`이라면, 해당 Telemetry Object는 Namespace에 관계없이 Global 설정이 적용된다.

```console {caption="[Shell 3] istio-proxy Access Log", linenos=table}
[2025-05-04T17:22:18.230Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 151 124 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "23a37732-e001-9302-b72f-284faaf8f7cc" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:39068 - default
[2025-05-04T17:22:18.402Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 358 649 648 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "0157ddc1-8fd0-9d95-b3cd-4b5d0c9001bb" "reviews:9080" "10.244.2.20:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:40188 10.96.81.152:9080 10.244.2.19:40142 - default
[2025-05-04T17:22:24.163Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 35 27 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "5c82d8bc-2a15-9a25-81bf-c567fe990e6d" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:39764 - default
[2025-05-04T17:22:24.209Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 437 994 991 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "121ac9af-1ee6-93c6-b973-8dc808723603" "reviews:9080" "10.244.1.15:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:60236 10.96.81.152:9080 10.244.2.19:45090 - default
[2025-05-04T17:22:58.962Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 78 54 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "1215fb69-21c7-9b8d-98d7-b90ea053a76c" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:46332 - default
[2025-05-04T17:22:59.046Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 437 142 141 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "4e43168a-01e6-907c-ba17-2f72fad816a8" "reviews:9080" "10.244.1.15:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:60236 10.96.81.152:9080 10.244.2.19:55058 - default
```

[Shell 3]은 Sidecar의 Access Log의 예제를 나타낸다. 기본적으로 `[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% %RESPONSE_CODE_DETAILS% %CONNECTION_TERMINATION_DETAILS%
\"%UPSTREAM_TRANSPORT_FAILURE_REASON%\" %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" \"%REQ(USER-AGENT)%\" \"%REQ(X-REQUEST-ID)%\"
\"%REQ(:AUTHORITY)%\" \"%UPSTREAM_HOST%\" %UPSTREAM_CLUSTER_RAW% %UPSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_REMOTE_ADDRESS% %REQUESTED_SERVER_NAME% %ROUTE_NAME%\n` 형태로 출력한다.

```yaml {caption="[File 5] Set Sidecar Access Log within Mesh Config (Global)", linenos=table}
mesh: |-
  accessLogFile: /dev/stdout
  accessLogEncoding: TEXT
  accessLogFormat: |
    [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%" %RESPONSE_CODE% retry_attempts=%UPSTREAM_REQUEST_ATTEMPT_COUNT% flags=%RESPONSE_FLAGS% details=%RESPONSE_CODE_DETAILS%
...
```

만약 Access Log의 포맷을 변경하고 싶다면 [File 5]와 같이 Mesh Config에서 `accessLogFormat`을 설정하면 된다. [File 5]는 `UPSTREAM_REQUEST_ATTEMPT_COUNT` 필드를 추가하여 Retry 횟수를 출력하도록 설정한 예제이다.

## 2. 참조

* [https://istio.io/latest/docs/reference/config/networking/virtual-service/](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
* [https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
* [https://istio.io/latest/docs/ops/deployment/requirements/](https://istio.io/latest/docs/ops/deployment/requirements/)
* [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LoadBalancerSettings](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LoadBalancerSettings)
* [http://itnp.kr/post/istio-routing-api](http://itnp.kr/post/istio-routing-api)
* Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)