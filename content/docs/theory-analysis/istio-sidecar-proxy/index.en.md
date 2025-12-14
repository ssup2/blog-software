---
title: Istio Sidecar Proxy
---

Analyze Istio's Sidecar Proxy.

## 1. Istio Sidecar Proxy

{{< figure caption="[Figure 1] Istio Sidecar" src="images/istio-sidecar.png" width="600px" >}}

Istio's Sidecar Proxy technique refers to a method of launching a dedicated Proxy Server for each Pod. [Figure 1] shows the Architecture of Istio Sidecar Proxy. The Sidecar Proxy receives all Inbound Packets destined for the Pod, processes them, and then forwards them to the App Container in the Pod. Additionally, the Sidecar Proxy receives all Packets sent from the App Container, processes them, and then forwards them outside the Pod.

The Sidecar Proxy must know all the information necessary for packet transmission. The Sidecar Proxy receives this information necessary for packet transmission from a central Controller called Istiod. The information that Istiod sends to the Sidecar Proxy includes Service information provided by the App running in the Pod, Policy information that determines whether packet transmission/reception is allowed, and certificate information for packet encryption. Here, Service refers to Kubernetes Service Objects or Istio Virtual Service Objects. Based on the information received from Istiod, the Sidecar Proxy performs various roles such as Packet Load Balancing, Packet Encap/Decap, Rate Limit, and Circuit Breaker.

The Sidecar Proxy actually runs as a separate Container inside the App Pod, and the Sidecar Proxy Container consists of **Envoy**, which performs the actual Sidecar Proxy role, and **pilot-agent**, which receives information from Istiod and configures Envoy. Envoy supports various protocols such as HTTP, gRPC, and TCP, so Apps can exchange packets based on various protocols. pilot-agent and Envoy collect Metric information themselves, and the collected Metric information is collected by external Components such as Prometheus and Jaeger.

### 1.1. Sidecar Proxy Injection

The Sidecar Proxy runs as a Container inside the Pod. Therefore, it must be configured so that the Sidecar Proxy can be injected and run as a Container inside the Pod. Sidecar Proxy configuration can be set manually for each Pod, or it can be set at the Namespace level so that the Sidecar Proxy runs in all Pods created within the Namespace.

#### 1.1.1. Manual Configuration

```yaml {caption="[File 1] nginx Deployment Manifest before applying istioctl kube-inject", linenos=table}
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

```yaml {caption="[File 2] nginx Deployment Manifest after applying istioctl kube-inject", linenos=table}
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

The `istioctl kube-inject` command modifies the Manifest of Objects that manage Pods such as Deployment, StatefulSet, and DaemonSet so that Sidecar Proxy is created in the Pod. [File 1] shows the nginx Deployment Manifest file before applying the `istioctl kube-inject` command, and [File 2] shows the nginx Deployment Manifest file after applying the `istioctl kube-inject` command. You can see that the `istio-proxy` Container, which is the Sidecar Proxy, has been added, and the `istio-init` Init Container, which is responsible for the Network configuration of the Sidecar Proxy, has been added.

```shell {caption="[Shell 1] Using istioctl kube-inject", linenos=table}
$ istioctl kube-inject -f nginx-deployment.yaml | kubectl apply -f -
```

When you execute the `istioctl kube-inject` command as shown in [Shell 1], the Sidecar Proxy is injected when the Pod is newly created.

#### 1.1.2. Namespace Configuration

When a Pod is created in a Namespace with the label `istio-injection=enabled`, Istio performs Sidecar Proxy Injection to forcibly create a Sidecar Proxy in the Pod without intervention from Kubernetes users. The reason why Sidecar Proxy Injection can be forcibly performed without intervention from Kubernetes users is because it uses the Admission Controller function provided by Kubernetes.

When a Pod-related Object creation request is sent to the Kubernetes API Server through the Mutating Webhook function of the Admission Controller, the Kubernetes API Server sends the Pod creation request to Istiod. Istiod adds (Mutating) Sidecar Proxy and Init Container settings to the Pod creation request and then delivers it to the Kubernetes API server so that Sidecar Proxy and Init Container are created.

### 1.2. Packet Capture

```shell {caption="[Shell 2] Pod iptables NAT Table with Istio Sidecar", linenos=table}
# iptables -t nat -nvL
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

The reason why all Inbound Packets sent to a Pod with Sidecar Proxy injected are sent to the Sidecar Proxy, or why all Outbound Packets sent from a Pod with Sidecar Proxy injected are sent to the Sidecar Proxy, is because of the **Init Container** that is configured together with the Sidecar Proxy. The Init Container sets Rules in the Pod's Network Namespace using `iptables` to redirect the Pod's Inbound/Outbound Packets to the Sidecar.

[Shell 2] is the result of querying the `iptables` NAT Table inside a Pod with Sidecar Proxy injected. Pod's Inbound Packets are sent to the Sidecar Proxy through Port `15006`, and Pod's Outbound Packets are sent to the Sidecar Proxy through Port `15001`. Ports `15020` and `15090` are used as Prometheus Ports for the Sidecar Proxy, and Port `15020` is used as the Health Check Port for the Sidecar Proxy. Therefore, related Ports are configured not to be redirected in the `ISTIO-INBOUND` Chain. Looking at [File 2], you can see that the Sidecar Proxy is configured to run with UID/GID `1337`. Therefore, Packets sent by the Sidecar Proxy running with UID/GID `1337` are configured in the `ISTIO-OUTPUT` Chain not to be redirected from the Pod.

Since the Init Container must set `iptables` Rules, you can see in [File 2] that it is configured to run with `NET-ADMIN` and `NET-RAW` Capabilities. Init Containers running with `NET-ADMIN` and `NET-RAW` Capabilities can be a security vulnerability. To solve this problem, Istio provides the Istio CNI Plugin. Through the Istio CNI Plugin, `iptables`-based NAT Rules can be set in the Pod's Network Namespace from the Host.

### 1.3. Traffic Load Balancing

The Sidecar Proxy does not perform Load Balancing using iptables/IPVS Rules set by kube-proxy when sending Traffic to Services. The Sidecar Proxy receives information about Services and Pods (Endpoints) connected to Services through Istiod and directly performs L7 Level Load Balancing. Therefore, various Load Balancing techniques that cannot be used in kube-proxy, which performs L3/L4 Level Load Balancing, can be applied through Istio's Sidecar Proxy. Starting with basic Load Balancing techniques such as Round Robin, Least Connection, and Random, L7-based techniques such as Consistent Hash and Locality Base can also be used.

However, kube-proxy is still an essential element in Istio environments. Pods without Sidecar Proxy still use kube-proxy when sending Traffic to Services, and Sidecar Proxy also accesses Istiod through kube-proxy when communicating with Istiod.

### 1.4. Access Log

The Sidecar Proxy does not leave Access Logs by default, but it can be configured to leave Access Logs by activating them through separate settings. When Access Logs are activated, a large amount of Logs are generated, so it is good to disable Access Logs during normal times, but Access Logs can be temporarily activated and utilized during Network-related Troubleshooting. Methods to activate Access Logs include setting them in **Mesh Config** and using the **Telemetry** Object.

```yaml {caption="[File 3] Set Sidecar Access Log within Mesh Config", linenos=table}
mesh: |-
  accessLogFile: /dev/stdout
...
```

[File 3] is a method to configure Access Logs to be output to stdout in Istio's Mesh Config. When Access Logs are configured to be output to stdout, you can check the Sidecar's Access Logs through the `kubectl logs` command, and they can also be collected by Log Aggregators such as fluentd. The Mesh Config method only supports **Global methods that apply to all Sidecar Proxies**, so it is impossible to configure only specific Pod's Sidecar Proxy Access Logs, and in this case, you must use the Telemetry Object to configure it.

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

[File 4] shows an example of activating Access Logs using the Telemetry Object. Access Logs can be configured at Global, Namespace, and Pod levels, and the [File 4] example is an example configured to activate Access Logs only for Sidecar Proxies of Pods with the `app: productpage` Label existing in the `default` Namespace. Pods can be selected through `matchLabels`, and if `matchLabels` does not exist, Access Logs of Sidecar Proxies of all Pods in the Namespace where the Telemetry Object exists are activated. If the Namespace where the Telemetry Object exists is `istio-system`, which is Istio's Root Configuration Namespace, the Telemetry Object applies Global settings regardless of Namespace.

```console {caption="[Shell 3] istio-proxy Access Log", linenos=table}
[2025-05-04T17:22:18.230Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 151 124 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "23a37732-e001-9302-b72f-284faaf8f7cc" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:39068 - default
[2025-05-04T17:22:18.402Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 358 649 648 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "0157ddc1-8fd0-9d95-b3cd-4b5d0c9001bb" "reviews:9080" "10.244.2.20:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:40188 10.96.81.152:9080 10.244.2.19:40142 - default
[2025-05-04T17:22:24.163Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 35 27 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "5c82d8bc-2a15-9a25-81bf-c567fe990e6d" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:39764 - default
[2025-05-04T17:22:24.209Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 437 994 991 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "121ac9af-1ee6-93c6-b973-8dc808723603" "reviews:9080" "10.244.1.15:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:60236 10.96.81.152:9080 10.244.2.19:45090 - default
[2025-05-04T17:22:58.962Z] "GET /details/0 HTTP/1.1" 200 - via_upstream - "-" 0 178 78 54 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "1215fb69-21c7-9b8d-98d7-b90ea053a76c" "details:9080" "10.244.1.14:9080" outbound|9080||details.default.svc.cluster.local 10.244.2.19:38918 10.96.94.35:9080 10.244.2.19:46332 - default
[2025-05-04T17:22:59.046Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 437 142 141 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" "4e43168a-01e6-907c-ba17-2f72fad816a8" "reviews:9080" "10.244.1.15:9080" outbound|9080||reviews.default.svc.cluster.local 10.244.2.19:60236 10.96.81.152:9080 10.244.2.19:55058 - default
```

[Shell 3] shows an example of the Sidecar's Access Log. By default, it outputs in the format `[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% %RESPONSE_CODE_DETAILS% %CONNECTION_TERMINATION_DETAILS%
\"%UPSTREAM_TRANSPORT_FAILURE_REASON%\" %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" \"%REQ(USER-AGENT)%\" \"%REQ(X-REQUEST-ID)%\"
\"%REQ(:AUTHORITY)%\" \"%UPSTREAM_HOST%\" %UPSTREAM_CLUSTER_RAW% %UPSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_REMOTE_ADDRESS% %REQUESTED_SERVER_NAME% %ROUTE_NAME%\n`.

```yaml {caption="[File 5] Set Sidecar Access Log within Mesh Config (Global)", linenos=table}
mesh: |-
  accessLogFile: /dev/stdout
  accessLogEncoding: TEXT
  accessLogFormat: |
    [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%" %RESPONSE_CODE% retry_attempts=%UPSTREAM_REQUEST_ATTEMPT_COUNT% flags=%RESPONSE_FLAGS% details=%RESPONSE_CODE_DETAILS%
...
```

If you want to change the format of Access Logs, you can set `accessLogFormat` in Mesh Config as shown in [File 5]. [File 5] is an example configured to output Retry counts by adding the `UPSTREAM_REQUEST_ATTEMPT_COUNT` field.

## 2. References

* [https://istio.io/latest/docs/reference/config/networking/virtual-service/](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
* [https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
* [https://istio.io/latest/docs/ops/deployment/requirements/](https://istio.io/latest/docs/ops/deployment/requirements/)
* [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LoadBalancerSettings](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LoadBalancerSettings)
* [http://itnp.kr/post/istio-routing-api](http://itnp.kr/post/istio-routing-api)
* Access Log : [https://istio.io/latest/docs/tasks/observability/logs/access-log/](https://istio.io/latest/docs/tasks/observability/logs/access-log/)

