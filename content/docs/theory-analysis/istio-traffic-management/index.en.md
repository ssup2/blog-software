---
title: Istio Traffic Management
---

This post analyzes Virtual Service, Destination Rule, and Gateway, which are responsible for Traffic control in Istio.

## 1. Istio Traffic Management

{{< figure caption="[Figure 1] Version Service, Deployment" src="images/version-service-deploy.png" width="650px" >}}

```yaml {caption="[File 1] version-app-deploy-service.yaml", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-v1
  labels:
    app: version
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: version
      version: v1
  template:
    metadata:
      labels:
        app: version
        version: v1
    spec:
      containers:
      - name: version
        image: docker.io/ssup2/version:v1
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-v2
  labels:
    app: version
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: version
      version: v2
  template:
    metadata:
      labels:
        app: version
        version: v2
    spec:
      containers:
      - name: version
        image: docker.io/ssup2/version:v2
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: version
  labels:
    app: version
    service: version
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: version
---
apiVersion: v1
kind: Service
metadata:
  name: version-v1
  labels:
    app: version
    service: version
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: version
    version: v1
---
apiVersion: v1
kind: Service
metadata:
  name: version-v2
  labels:
    app: version
    service: version
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: version
    version: v2
```

Istio provides three Resources for Traffic control: Virtual Service, Destination Rule, and Gateway. [Figure 1] and [File 1] show the Service and Deployment for an App called `version`, used to understand and apply Virtual Service, Destination Rule, and Gateway. The version App included in the `version:v1` Image is a simple App that returns the string `version v1` on an HTTP request, and the App included in the `version:v2` Image returns the string `version v2` on an HTTP request.

The `version:v1/v2` Containers are deployed through Deployments, and there is a `version-v1` Service connecting `version:v1` and a `version-v2` Service connecting `version:v2`. There is also a `version` Service that connects both `version:v1/v2`. Therefore, sending an HTTP request to the `version-v1` Service returns the string `version v1`, and sending an HTTP request to the `version-v2` Service returns the string `version v2`. Sending an HTTP request to the `version` Service returns the strings `version v1` and `version v2` at random.

### 1.1. Virtual Service

{{< figure caption="[Figure 2] Version Virtual Service" src="images/version-virtual-service.png" width="700px" >}}

```yaml {caption="[File 2] version-virtual-service.yaml", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: version-v1-v2
spec:
  hosts:
  - version
  http:
  - route:
    - destination:
        host: version-v1
      weight: 10
    - destination:
        host: version-v2
      weight: 90
```

**Virtual Service** performs the role of routing Traffic based on the **Host**. Here, the Host means the address the Client connects to. [Figure 2] and [File 2] show the `version-v1-v2` Virtual Service, which routes Traffic targeting the `version` Host to the `version-v1` and `version-v2` Services at a 1:9 ratio. In addition to Weight, it also provides L7-based Routing techniques that route according to the URI (PATH) or Header of the request. The Routing target can be not only a Service but also another Virtual Service.

The reason the `version-v1-v2` Virtual Service can use `version` as its Host is that the `version` Service is declared. Although Traffic is not actually routed through the `version` Service, the `version` Service must be declared, because if the `version` Service does not exist, the `version-v1-v2` Virtual Service cannot use `version` as its Host.

### 1.2. Destination Rule

{{< figure caption="[Figure 3] Version Virtual Service, Destination Rule" src="images/version-virtual-service-desitination-rule.png" width="750px" >}}

```yaml {caption="[File 3] version-virtual-service-destination-rule.yaml", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: version
spec:
  host: version
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: LEAST-CONN
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: version
spec:
  hosts:
  - version
  http:
  - route:
    - destination:
        host: version
        subset: v1
      weight: 10
    - destination:
        host: version
        subset: v2
      weight: 90
```

For Traffic routed based on the Host, the **Destination Rule** decides how the Traffic is delivered to the Host. The Destination Rule is not a Resource that must be defined for Istio Traffic control; if no Destination Rule is defined, Traffic is routed by the Virtual Service. The Destination Rule has various features, but when multiple Versions exist for the same Host, it creates a Subset for each Version so that Traffic can be controlled through the Virtual Service.

[Figure 3] and [File 3] show an example of such a Destination Rule. The `subsets` part divides the `version` Service into `v1` and `v2` Subsets (Groups) according to the Labels of the Pods connected to the `version` Service. It can be seen that the `v1` and `v2` Subsets are referenced by the `version` Virtual Service and configured to route Traffic to the `v1` and `v2` Subsets at a 1:9 ratio. Since the `v2` Subset is configured with `loadBalancer` `LEAST-CONN`, Traffic among the Pods included in the `v2` Subset is load balanced according to the Least Connection Algorithm. The Load Balancing Algorithm defaults to `ROUND-ROBIN`, and `LEAST-CONN`, `RANDOM`, and L7-based Consistent Hashing techniques can be applied.

### 1.3. Gateway

{{< figure caption="[Figure 4] Version Gateway, Virtual Service" src="images/version-gateway-virtual-service.png" width="750px" >}}

```yaml {caption="[File 4] version-gateway-virtual-service.yaml", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: version
spec:
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "ssup2.com"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: version-gateway
spec:
  hosts:
  - version
  - ssup2.com
  gateways:
  - version
  http:
  - route:
    - destination:
        host: version
```

**Gateway** performs the role of exposing a Virtual Service to the outside of the Kubernetes Cluster. [Figure 4] and [File 4] show an example of exposing the `version-gateway` Virtual Service to the outside of the Kubernetes Cluster through the `version` Gateway. In the Gateway, the Protocol, Port number, and the Host (Domain) used to access the Virtual Service from outside the Kubernetes Cluster can be configured. Also, although not specified in [File 4], certificate (TLS) information can be configured as needed so that HTTPS requests can be received.

To connect a Virtual Service to a Gateway, the Host configured in the Gateway must be added to the `hosts` of the Virtual Service. In addition, the name of the Gateway to which the Virtual Service is connected must be specified in the `gateways` of the Virtual Service.

## 2. References

* Istio Traffic Management : [https://istio.io/latest/docs/concepts/traffic-management/](https://istio.io/latest/docs/concepts/traffic-management/)
* Istio Virtual Service : [https://istio.io/latest/docs/reference/config/networking/virtual-service/](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
* Istio Destination Rule : [https://istio.io/latest/docs/reference/config/networking/destination-rule/](https://istio.io/latest/docs/reference/config/networking/destination-rule/)
* How to Manage Traffic Using Istio on Kubernetes : [https://medium.com/better-programming/how-to-manage-traffic-using-istio-on-kubernetes-cd4b96e00b57](https://medium.com/better-programming/how-to-manage-traffic-using-istio-on-kubernetes-cd4b96e00b57)
* Istio Traffic management : [https://bcho.tistory.com/1367](https://bcho.tistory.com/1367)
