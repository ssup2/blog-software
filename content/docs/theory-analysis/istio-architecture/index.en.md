---
title: Istio Architecture
---

## 1. Istio Architecture

{{< figure caption="[Figure 1] Istio Architecture" src="images/istio-architecture.png" width="600px" >}}

[Figure 1] shows the Istio Architecture. Istio can be divided into a Control Plane that manages Istio and a Data Plane that handles data communication between applications. The Control Plane consists of four components: **Pilot**, **Mixer**, **Citadel**, and **Galley**. The Data Plane contains application pods that provide services. Here, "Service" refers to either Kubernetes Service objects or Istio Virtual Service objects. Application pods consist of an **Application Container** where the actual application runs and a **Sidecar Container**. The sidecar refers to a dedicated proxy server for each application pod. The sidecar container is composed of **Envoy**, which performs the actual sidecar role, and **pilot-agent**, which configures Envoy according to commands from the Control Plane.

The Control Plane components are as follows:

* **Pilot**: Discovers services existing in the Kubernetes cluster through the Kubernetes API Server and delivers the discovered service information to pilot-agent, enabling Envoy to perform load balancing of packets to appropriate applications connected to the service.
* **Mixer**: Delivers packet transmission permission policies between applications to pilot-agent, restricting communication between Envoys (between applications). Additionally, Mixer receives metric information collected through pilot-agent and Envoy existing in application pods, and delivers this metric information to adapters that serve as metric collectors. Prometheus is a representative adapter.
* **Citadel**: Delivers certificates to pilot-agent, handling security for communication between Envoys.
* **Galley**: Performs the role of configuring and managing the remaining components of the Control Plane.

The Data Plane components are as follows:

* **Envoy**: Operates in a separate container within each application pod, performing the sidecar role of receiving all packets sent by the application and transmitting them on its behalf, and receiving all packets that the application should receive before delivering them back to the application. It also performs the role of sending collected metric information to Mixer.
* **pilot-agent**: Receives necessary information from Control Plane components and configures Envoy to perform functions such as packet load balancing, packet encapsulation/decapsulation, rate limiting, and circuit breaking. It also performs the role of sending collected metric to Mixer.

### 1.1. Istio Architecture After v1.5

{{< figure caption="[Figure 2] Istio Architecture After v1.5" src="images/istio-architecture-1.5.png" width="700px" >}}

Istio's architecture changed after version 1.5. [Figure 2] shows the Istio Architecture after version 1.5. Pilot, Galley, and Citadel have been consolidated into a single component (binary) called **Istiod**, and **Mixer** has been deprecated.

The packet permission policies between applications that Mixer used to handle have been replaced by Envoy's functionality and Citadel's security features. Rate limiting that Mixer used to perform has also been changed to utilize Envoy's functionality. The metric that Mixer used to collect from pilot-agent and Envoy is now collected directly by Prometheus and Jaeger.

## 2. References

* Introducing Istio Service Mesh for Microservices
* [https://istio.io/docs/concepts/what-is-istio/](https://istio.io/docs/concepts/what-is-istio/)
* [https://stackoverflow.com/questions/48639660/difference-between-mixer-and-pilot-in-istio](https://stackoverflow.com/questions/48639660/difference-between-mixer-and-pilot-in-istio)
* [https://istio.io/latest/news/releases/1.5.x/announcing-1.5/upgrade-notes/](https://istio.io/latest/news/releases/1.5.x/announcing-1.5/upgrade-notes/)
* [https://istio.io/v1.5/docs/tasks/policy-enforcement/enabling-policy/](https://istio.io/v1.5/docs/tasks/policy-enforcement/enabling-policy/)
* [https://istio.io/latest/blog/2020/istiod/](https://istio.io/latest/blog/2020/istiod/)
* [https://developer.ibm.com/components/istio/blogs/istio-15-release/](https://developer.ibm.com/components/istio/blogs/istio-15-release/)