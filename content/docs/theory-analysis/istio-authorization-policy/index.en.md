---
title: Istio Authorization Policy
---

## 1. Istio Authorization Policy

```yaml {caption="[Text 1] Istio Authorization Policy Format", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: [Name]
  namespace: [Namespace]
spec:
  selector:
    matchLabels:
      [key]: [value]
  action: [ALLOW | DENY | CUSTOM | AUDIT]
  rules:
...
```

Istio's Authorization Policy provides functionality to determine whether to deny/allow requests coming into pods with Istio sidecar injected. [Text 1] shows the format of the Authorization Policy. Authorization Policy is largely composed of three elements: **Selector**, **Action**, and **Rule**.

* Selector : Selector specifies the pods to which the Authorization Policy will be applied. If no Selector is specified, the Authorization Policy is applied to all pods within the namespace where the Authorization Policy exists. In this article, pods to which the Authorization Policy is applied by the Selector are referred to as **Target Pods**. Not only Workload Pods but also Istio's Ingress Gateway and Egress Gateway can be Target Pods.
* Rule : Rule specifies the **conditions of requests** coming into the Target Pod.
* Action : Action determines whether to deny/allow requests coming into the Target Pod by the Rule. You can choose one of **ALLOW**, **DENY**, **CUSTOM**, and **AUDIT**, where ALLOW means allow, DENY means deny, CUSTOM means user-defined rules. Finally, AUDIT does not actually control Inbound Traffic but only logs related information.

Authorization Policy is a technique for controlling **Ingress Traffic** by determining whether to deny/allow requests sent to Target Pods, and does not provide functionality to control Outbound Traffic. Also, since Authorization Policy **operates in the Envoy Proxy running as the Target Pod's Sidecar**, if no sidecar is injected into the Target Pod, it does not operate and all requests are allowed. Additionally, when using **Rules that require mTLS settings**, mTLS operates only when sidecars are injected not only into the Target Pod's sidecar but also into the pod that initiates the request, so sidecars must be injected into both the Target Pod and the pod that initiates the request.

### 1.1. Allow/Deny Processing Process

{{< figure caption="[Figure 1] Istio Authorization Process" src="images/istio-authorization-process.png" width="900px" >}}

[Figure 1] shows the process of how allow or deny of Inbound Traffic is determined due to Authorization Policy. The allow or deny processing is determined by the **existence** of Authorization Policy and the **Action** set in which Authorization Policy. The allow or deny of Inbound Traffic is determined through a total of 4 processing steps.

1. In step 1, if a **CUSTOM** Action Authorization Policy for the Target Pod (Workload) **exists** and denial is determined as a result, the request is denied. On the other hand, if it is allowed, it proceeds to step 2.
2. In step 2, if a **DENY** Action Authorization Policy for the Target Pod (Workload) **exists** and the request matches the Rule, the request is denied. If not, it proceeds to step 3.
3. In step 3, if no Authorization Policy with **ALLOW** Action for the Target Pod (Workload) **exists**, the request is allowed. If an Authorization Policy with ALLOW Action for specific pods selected by the Selector exists, it proceeds to step 4.
4. In step 4, if the request matches the Rule of the Authorization Policy with **ALLOW** Action for the Target Pod (Workload), the request is allowed. If it does not match the Rule, the request is denied.

### 1.2. Rule

One Authorization Policy can include multiple Rules, and one Rule is composed of three elements: **from**, **to**, and **when**. When multiple Rules exist, it operates as an **OR condition** where the condition is established if only one Rule is satisfied, and when multiple conditions exist within one Rule, it operates as an **AND condition** where all conditions must be satisfied for the condition to be established.

#### 1.2.1. From

```yaml {caption="[Text 2] from Rule Example", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: from-rule
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-service
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["test"]
        ipBlocks: ["10.0.0.0/24", "20.0.0.20"]
        principals: ["cluster.local/ns/default/sa/user"]
    - source:
        requestPrincipals: ["example.com/sub"]
        remoteIpBlocks: ["20.0.0.0/24"]
```

[Text 2] shows an example of the **From** Rule. From Rule defines **external entities** that can send requests to the Target Pod. From Rule can have multiple **Sources**, and one Source can use 6 conditions: **namespace**, **ipBlocks**, **serviceAccounts**, **principals**, **requestPrincipals**, **remoteIpBlocks**, and 6 conditions with **not** prefix: **notNamespace**, **notIpBlocks**, **notServiceAccounts**, **notPrincipals**, **notRequestPrincipals**, **notRemoteIpBlocks**, for a total of 12 conditions. Conditions with the not prefix mean cases that do not satisfy the corresponding condition.

* namespaces : Specifies the namespace of pods that can initiate requests. mTLS settings are required for operation.
* ipBlocks : Specifies the IP of the entity that initiates the request. Here, IP means the Source IP in the IP Header. It can be specified in CIDR or single IP format.
* serviceAccounts : Specifies pods that use Service Accounts of specific namespaces that can initiate requests. Namespace and Service Account are specified in `[namespace]/[serviceaccount]` format. For example, `default/user` means a pod that uses a Service Account named `user` in the `default` namespace. mTLS settings are required for operation.
* principals : Specifies pods that use Service Accounts of specific namespaces that can initiate requests. Namespace and Service Account are specified in `cluster.local/ns/[namespace]/sa/[serviceaccount]` format. For example, `cluster.local/ns/default/sa/user` means a pod that uses a Service Account named `user` in the `default` namespace. mTLS settings are required for operation.
* requestPrincipals : Specifies JWT Token information to allow requests. Issuer and Subject are specified in `"[ISS]/[SUB]"` format. For example, `example.com/sub` means a JWT Token with Issuer `example.com` and Subject `sub`.
* remoteIpBlocks : Specifies the IP of the entity that initiates the request. Here, IP means the Source IP stored in the `X-Forwarded-For` header.

When multiple Sources exist, it operates as an **OR condition** where the condition is established if only one Source is satisfied, and when multiple conditions exist within one Source, it operates as an **AND condition** where all conditions must be satisfied for the condition to be established. Therefore, in the case of [Text 2], it allows requests when connecting from pods using the `user` Service Account in the `test` namespace to the Target Pod with IPs `10.0.0.0/24` or `20.0.0.20`, or when using a JWT Token with Subject `example.com/sub`.

####  1.2.2. To

```yaml {caption="[Text 3] to Rule Example", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: to-rule
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-service
  action: DENY
  rules:
  - to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/v1/users"]
        hosts: ["api.example.com", "api.example2.com"]
        ports: [80, 443]
    - operation:
        methods: ["GET", "POST", "DELETE"]
        hosts: ["api.ssup.com", "api.ssup2.com"]
        ports: [443]
```

[Text 3] shows an example of the **To** Rule. To Rule specifies **conditions of requests** sent from external entities to the Target Pod. To Rule can have multiple **Operations**, and one Operation can use 4 conditions: **methods**, **paths**, **hosts**, **ports**, and 4 conditions with **not** prefix: **notMethods**, **notPaths**, **notHosts**, **notPorts**, for a total of 8 conditions. Conditions with the not prefix mean cases that do not satisfy the corresponding condition.

When multiple Operations exist, it operates as an **OR condition** where the condition is established if only one Operation is satisfied, and when multiple conditions exist within one Operation, it operates as an **AND condition** where all conditions must be satisfied for the condition to be established. Therefore, in the case of [Text 3], it denies requests when sending requests to the Target Pod using `GET`, `POST` methods to `/v1/users` path with hostnames `api.example.com`, `api.example2.com`, or when sending requests to port `443` using `GET`, `POST`, `DELETE` methods with hostnames `api.ssup.com`, `api.ssup2.com`.

#### 1.2.3. When

```yaml {caption="[Text 4] when Rule Example", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: when-rule
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-service
  action: ALLOW
  - from:
    - source:
        namespaces: ["test"]
    - source:
        principals: ["cluster.local/ns/default/sa/user"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/info*"]
    - operation:
        methods: ["POST"]
        paths: ["/data"]
    when:
    - key: request.auth.claims[iss]
      values: ["https://accounts.google.com"]
```

[Text 4] shows an example of the **When** Rule. When Rule is used to specify **detailed conditions** between From Rule and To Rule. Conditions can be set using multiple Key/Value pairs, and when multiple Key/Value pairs are set, it operates as an **OR condition** where the condition is established only when one Key/Value condition is satisfied.

The conditions that can be used in when's key/value can be found at [Link](https://istio.io/latest/docs/reference/config/security/conditions/), and you can see that information about IP, Namespace, and JWT Token that can also be used in from rule and to rule can be set. Therefore, it is possible to set conditions using only when without using from and to. However, it is rare to specify conditions using only when in general, and the common method is to specify broad conditions using from and to and specify detailed conditions in when.

### 1.3. Custom Action

```yaml {caption="[Text 5] Custom Action Example", linenos=table}
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: custom-authz
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istio-ingressgateway
  action: CUSTOM
  provider:
    name: "custom-authz"
  rules:
  - to:
    - operation:
        paths: ["/v1/users"]
```

[Text 5] shows an example of **Custom Action**. Custom Action provides functionality to deny/allow requests using user-defined conditions. It controls conditions that cannot be controlled through Authorization Rules using Custom Action. It is commonly used when integrating separate authentication systems attached to Istio's Ingress Gateway. The example in [Text 5] also shows that it is a Custom Action attached to Istio's Ingress Gateway by the Selector. Even if allowed in Custom Action, the request may be denied by Deny, Allow Authorization Policy processed after Custom Action.

```yaml {caption="[Text 6] Istio ConfigMap Example for extensionProviders Example", linenos=table}
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |-
    extensionProviders:
    - name: "custom-authz"
      envoyExtAuthzHttp:
        service: "custom-authz.istio-system.svc.cluster.local"
        port: "8000"
        includeRequestHeadersInCheck: ["custom-authz"]
```

The Provider of Authorization Policy specifies **where Custom Logic of Custom Action is processed**, and the Provider is defined in Istio's Mesh Config. [Text 6] shows an example of Mesh Config where the Provider is defined. A Provider named `custom-authz` is defined, and this Provider determines request deny/allow by sending requests to a service named `custom-authz` in the `istio-system` namespace on port `8000`. Through `includeRequestHeadersInCheck`, you can specify headers that are absolutely necessary for determining request deny/allow, and in the example, the `custom-authz` header is specified. If the Provider returns a 200 response, the request is allowed, and if it returns a response other than 200, the request is denied.

### 1.4. vs Network Policy

While Authorization Policy determines whether to deny/allow requests sent to Target Pods, Network Policy is used to control Inbound/Outbound Traffic of Target Pods. Authorization Policy operates at the L7 Layer, so it determines whether to deny/allow requests based on HTTP Header information, while Network Policy operates at the L3/L4 Layer, so it controls Inbound/Outbound Traffic based on IP and Port information. Authorization Policy operates in Istio's Envoy Proxy, while Network Policy operates in Kubernetes' CNI Plugin.

## 2. References

* Istio Authorization Policy : [https://istio.io/latest/docs/reference/config/security/authorization-policy/](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
* Istio Authorization Policy : [https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/](https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/)
* Istio Authorization Policy : [https://netpple.github.io/docs/istio-in-action/Istio-ch9-securing-3-authorizing](https://netpple.github.io/docs/istio-in-action/Istio-ch9-securing-3-authorizing)
