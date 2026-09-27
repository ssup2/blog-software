---
title: Kubernetes Nginx Ingress Controller
---

This post analyzes the Nginx Ingress Controller, which controls Nginx Ingress in Kubernetes. The analyzed Nginx Ingress Controller Version is `0.26.1`.

## 1. Kubernetes Nginx Ingress Controller

{{< figure caption="[Figure 1] Nginx Ingress Controller" src="images/nginx-ingress-controller.png" width="900px" >}}

**Nginx Ingress Controller** controls Nginx according to the Ingress and related Objects of Kubernetes, and collects Nginx-related Metric information and delivers it to the outside. [Figure 1] shows the Nginx Ingress Controller. The Nginx Ingress Controller resides in the Nginx Ingress Controller Pod together with Nginx. The Nginx Ingress Controller operates in a Leader (Active)/Non-leader (Standby) manner, but both the Leader and Non-leader identically control the Nginx running inside the same Pod as themselves and collect the related Metric information.

```text linenos {caption="[File 1] nginx.conf of Nginx Using Lua Modules", linenos=table}
...
http {
        lua-shared-dict certificate-data 20M;
        lua-shared-dict certificate-servers 5M;
        lua-shared-dict configuration-data 20M;  
...
        upstream upstream-balancer {
                balancer-by-lua-block {
                        balancer.balance()
                }
        }
...
        server {
                ssl-certificate-by-lua-block {
                        certificate.call()
                }                     
...
                location /app {
                        log-by-lua-block {
                                balancer.log()
                                monitor.call()
                                plugins.run()
                        }
...                       
```

Nginx is implemented to minimize Packet loss by minimizing Nginx Config Reloads through Lua Modules. Metric information is also collected through Lua Modules. [File 1] shows the `nginx.conf` file of Nginx using Lua Modules. Lines 3 ~ 5 of [File 1] show the Dictionary-based Shared Memory, also depicted in [Figure 1], where Nginx's Backend information and Certificates are stored. The `upstream` part of `nginx.conf` generally stores the information of the Servers targeted by Load Balancing, but lines 8~10 of [File 1] show that the `balancer` Lua Module is called instead of the Server information.

The `server` part of `nginx.conf` generally stores the Certificate Path information, but lines 14~16 of [File 1] show that the `certificate` Lua Module is called instead of the Certificate Path information. Lines 18 ~ 23 of [File 1] show the part that, when the `/app` URL is called, leaves a Log of which Pod the Packet is delivered to through `balancer` and leaves the related Metric information through `monitor`.

### 1.1. Configuration

The Store of the Nginx Ingress Controller **Watch**es Ingress Objects and the Endpoint, Secret, ConfigMap, and Service Objects related to Ingress using `client-go`, the Kubernetes Client. When a watched Object is updated, the Store receives the updated Object and delivers it to Ingress Sync. Ingress Sync composes the Nginx Config based on the updated Object and compares the newly composed Nginx Config with the previously applied Nginx Config. If the two Nginx Configs are identical, the Nginx Config is not changed, but if they differ, the changed Nginx Config is applied to Nginx.

If the Backend part of the Nginx Config is changed, the changed content is stored in Nginx's Shared Memory through the `nginx.conf` file and Nginx's `/configuration/backends` URL. If a Certificate in the Nginx Config is changed, the changed content is stored in Nginx's Shared Memory through the `/configuration/servers` URL. When Nginx's Backend is changed due to a change of an Ingress Object in the Kubernetes Cluster, the content of the `nginx.conf` file must also be changed, so Nginx must Reload `nginx.conf`. However, when only the number of Pods of the Service mapped to the Ingress Object changes, `nginx.conf` does not need to be changed and only the Backend Endpoints stored in the Shared Memory need to be changed, so Nginx does not perform a `nginx.conf` Reload.

Similarly, even when only Nginx's Certificate needs to be changed due to a change of an Ingress Object, only the Certificate stored in the Shared Memory needs to be changed, so Nginx does not perform a `nginx.conf` Reload. In this way, Nginx is implemented to minimize `nginx.conf` Reloads using Lua Modules. The `Configuration changes detected, backend reload required.` Log of the Nginx Ingress Controller means that Ingress Sync compared the previously applied Nginx Config with the newly composed Nginx Config and determined that a Reload is required, and the `Backend successfully reloaded.` Log indicates that the Nginx Reload succeeded.

### 1.2. Metric Collector

The Metric Collector of the Nginx Ingress Controller collects Metric information and sends it to Prometheus. [Figure 1] also includes the paths of the Metrics sent to the Metric Collector. The Metric Collector collects Metric information through three paths. First, it obtains the Metric information provided by the HTTP Stub Status Module inside Nginx through Nginx's `/nginx-status` URL. Second, it obtains Metric information through Nginx's Monitor Lua Module. Whenever a Client sends a Packet to an App through Nginx, the related Metric information is sent to the Monitor Lua Module. The Monitor Lua Module gathers the received Metric information and periodically sends it all at once to the Metric Collector using a Domain Socket.

Finally, it obtains the Metric information of the Nginx Processes through the procfs of the Nginx Ingress Controller Pod. The obtained Metric information is delivered to Prometheus through the Nginx Ingress Controller's `/metrics` URL. Therefore, each Nginx Ingress Controller acts as an Exporter for Prometheus.

### 1.3. Load Balancing, TLS

```yaml {caption="[File 2] Ingress, Service, Deployment", linenos=table}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - secretName: tls-secret
  rules:
  - host: ssup2.com
    http:
      paths:
      - path: /app
        backend:
          serviceName: app
          servicePort: 443
---
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  ports:
  - port: 443
    targetPort: 443
    protocol: TCP
    name: http
  selector:
    app: app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: ssup2/demo:latest
        ports:
        - containerPort: 443
```

Nginx uses Lua Modules to Load Balance Client Packets and, if necessary, also performs TLS encryption/decryption. [File 2] shows an example of a Kubernetes Ingress, Service, and Deployment. As shown in [File 2], the Ingress is mapped to the Service, and the Service is mapped to the Pods (Deployment). Therefore, looking at the contents of [File 2], it appears as if the Client's Packet is DNATed at Nginx to the Service IP and then DNATed again from the Service IP to a Pod IP, being DNATed twice and Load Balanced before being transmitted. In reality, however, Nginx **performs DNAT only once** on the Packet sent by the Client, based on the Backend Service and Endpoint (Pod IP/Port) information stored in the Shared Memory by the Configuration Lua Module, performing Load Balancing and sending the Packet directly to the Pod.

The Load Balancing algorithm uses Round Robin by default and can be configured through a ConfigMap. Not only HTTP/HTTPS but also TCP/UDP Protocols are supported. If the Ingress is configured to use TLS, TLS encryption/decryption is performed based on the Certificate information stored in the Shared Memory by the Configuration Lua Module.

### 1.4. Health Check

```yaml {caption="[File 3] Liveness and Readiness Probes of the Nginx Ingress Controller Pod", linenos=table}
...
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
...
```

The Nginx Ingress Controller provides a `/healthz` URL that Redirects Packets to Nginx's `/healthz` URL. Therefore, if no response is received for a request sent to the Nginx Ingress Controller's `/healthz`, it means that a problem has occurred in the Nginx Ingress Controller or Nginx. Generally, the Liveness and Readiness Probes of the Nginx Ingress Controller Pod are set to the Nginx Ingress Controller's `/healthz` to check the Health of the Nginx Ingress Controller and Nginx. [File 3] shows an example configuration of the Liveness and Readiness Probes of the Nginx Ingress Controller Pod, and [Figure 1] includes the flow where a request sent to the Nginx Ingress Controller's `/healthz` is Redirected again to Nginx's `/healthz`.

## 2. References

* Ingress-Nginx Controller : [https://kubernetes.github.io/ingress-nginx/](https://kubernetes.github.io/ingress-nginx/)
