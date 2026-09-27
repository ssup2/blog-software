---
title: Kubernetes Gateway API Inference Extension
---

This post analyzes the Gateway API Inference Extension, which provides routing capabilities for LLM Inference Traffic in Kubernetes. The analyzed version of the Gateway API Inference Extension is v1.6.

## 1. Kubernetes Gateway API Inference Extension

{{< figure caption="[Figure 1] Inference Gateway Architecture" src="images/inference-gateway.png" width="900px" >}}

**Gateway API Inference Extension** is an extension API that extends the Gateway API to provide routing capabilities optimized for LLM Inference Traffic. LLM Inference Traffic has different characteristics from general Web Traffic. Since the number of Tokens to process differs per request, the processing cost varies widely between requests, and processing a single request takes from several seconds to several minutes. In addition, since Model Servers use expensive GPUs, they are operated with a small number of Replicas unlike general Web Servers.

Because of these characteristics, when the Round Robin or Random Load Balancing of a Kubernetes Service is used for LLM Inference Traffic, if requests with high processing cost are concentrated on a specific Model Server, requests pile up in that Model Server's Queue, increasing Tail Latency and causing imbalanced GPU utilization. The Gateway API Inference Extension solves this problem through Load Balancing that selects the optimal Model Server based on the state of the Model Servers, and a Gateway with the Gateway API Inference Extension applied is called an **Inference Gateway**.

[Figure 1] shows the architecture of the Inference Gateway. The Gateway API Inference Extension consists of the **InferencePool** Resource, which defines a set of Model Servers, and the **Endpoint Picker (EPP)** Component, which selects the optimal Model Server. Since the Inference Gateway operates based on Envoy's **External Processing (ext-proc) Filter**, it can be used with Gateway API implementations that support ext-proc, and representative implementations include Envoy Gateway, Istio, kgateway, NGINX Gateway Fabric, and GKE Inference Gateway.

### 1.1. InferencePool

```yaml {caption="[File 1] InferencePool Example", linenos=table}
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: vllm-llama3-8b
  namespace: llm-namespace
spec:
  selector:
    matchLabels:
      app: vllm-llama3-8b
  targetPorts:
  - number: 8000
  endpointPickerRef:
    name: vllm-llama3-8b-epp
    port:
      number: 9002
    failureMode: FailOpen
```

**InferencePool** is a Resource that defines a set of Model Server Pods serving the same Model. InferencePool defines a set of Pods similarly to a Kubernetes Service, but differs in that it delegates the selection of the Load Balancing target to the EPP specified in `endpointPickerRef`. [File 1] shows an example of an InferencePool that groups vLLM-based Model Server Pods. `selector` specifies the Labels of the Model Server Pods to be included in the InferencePool, and `targetPorts` specifies the Port on which the Model Server receives requests. `endpointPickerRef` specifies the name and Port of the Service that exposes the EPP, and the Gateway requests Model Server selection from the EPP through that Service.

The `failureMode` of `endpointPickerRef` defines the behavior when the EPP fails. If it is set to `FailOpen`, Traffic is delivered through general Load Balancing when the EPP fails, and if it is set to `FailClose`, Traffic is not delivered and fails when the EPP fails. In line with the role-oriented design of the Gateway API, the InferencePool is managed by the Inference Platform Owner who manages the GPU Nodes and Model Servers, and App developers use the InferencePool only by referencing it through an HTTPRoute.

```yaml {caption="[File 2] HTTPRoute Example Referencing an InferencePool", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-route
  namespace: llm-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "llm.ssup2.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: vllm-llama3-8b
```

The Gateway API Inference Extension does not define a separate Route Resource and uses the existing Gateway API's Gateway and HTTPRoute as they are. [File 2] shows an example of an HTTPRoute referencing an InferencePool. When an InferencePool is specified in the HTTPRoute's `backendRefs` through `group` and `kind` instead of a Service, Traffic matching the HTTPRoute's `matches` conditions is delivered to the InferencePool and routed to the Model Server Pod selected by the EPP. Therefore, the existing Gateway API's Hostname and Path based routing and Traffic ratio control features can also be used together with the InferencePool.

### 1.2. Endpoint Picker

{{< figure caption="[Figure 2] Endpoint Picker Request Processing Flow" src="images/endpoint-picker.png" width="900px" >}}

**Endpoint Picker** (EPP) is a Component that selects the optimal Model Server to process a request from among the Model Servers included in an InferencePool, and it is deployed as a separate Pod and communicates with the Gateway through Envoy's ext-proc Protocol. [Figure 2] shows the request processing flow of the EPP. The Gateway determines the InferencePool to which Traffic will be delivered through the HTTPRoute, and then delivers the request information to the EPP. The EPP selects the optimal Model Server based on the Metrics of the Model Servers included in the InferencePool and returns it to the Gateway, and the Gateway delivers the request to the selected Model Server Pod.

The EPP periodically collects the Metrics exposed by the Model Servers, and selects a Model Server based on the number of requests waiting in the Model Server's Queue, KV Cache utilization, the list of loaded LoRA Adapters, and Prefix Cache state. For example, it preferentially selects a Model Server with a short Queue and spare KV Cache capacity, and delivers requests using a LoRA Adapter to a Model Server where that Adapter is already loaded, eliminating the Adapter loading cost. The specification of the Metrics that Model Servers must expose is standardized as the **Model Server Protocol**, and Model Serving Platforms such as vLLM support it.

Since the EPP's selection techniques are implemented in the form of Plugins, the selection techniques can be extended by adding Custom Plugins as needed. Starting from v1.6, the lightweight **Lightweight EPP** is provided as the default EPP, and the existing EPP and the **Body-based Router**, which performs routing based on the Model name in the request Body, have been migrated to the llm-d Project for further development.

### 1.3. InferenceObjective

```yaml {caption="[File 3] InferenceObjective Example", linenos=table}
apiVersion: inference.networking.x-k8s.io/v1alpha2
kind: InferenceObjective
metadata:
  name: chat-critical
  namespace: llm-namespace
spec:
  priority: 10
  poolRef:
    name: vllm-llama3-8b
```

**InferenceObjective** is a Resource that defines the priority of requests. [File 3] shows an example of an InferenceObjective that sets a priority for the `vllm-llama3-8b` InferencePool. `priority` specifies the priority of requests, and when the Model Servers of the InferencePool are saturated, the EPP rejects requests with lower priority to guarantee the processing of requests with higher priority. Requests without a defined InferenceObjective are processed with the default priority of `0`, and since the requests rejected under saturation are those with a priority lower than `0`, requests are processed normally even without an InferenceObjective.

Since InferenceObjective is still an Alpha-stage Resource, it may change in the future, and starting from v1.6 it has been migrated to a separate Repository for further development.

## 2. References

* Gateway API Inference Extension : [https://gateway-api-inference-extension.sigs.k8s.io/](https://gateway-api-inference-extension.sigs.k8s.io/)
* Gateway API Inference Extension GitHub : [https://github.com/kubernetes-sigs/gateway-api-inference-extension](https://github.com/kubernetes-sigs/gateway-api-inference-extension)
* Introducing Gateway API Inference Extension : [https://kubernetes.io/blog/2025/06/05/introducing-gateway-api-inference-extension/](https://kubernetes.io/blog/2025/06/05/introducing-gateway-api-inference-extension/)
* InferencePool : [https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/](https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/)
* Inference Extension API Spec : [https://gateway-api-inference-extension.sigs.k8s.io/reference/spec/](https://gateway-api-inference-extension.sigs.k8s.io/reference/spec/)
* llm-d : [https://llm-d.ai/](https://llm-d.ai/)
