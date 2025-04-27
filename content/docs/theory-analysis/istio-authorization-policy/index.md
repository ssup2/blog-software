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

Istio의 Authorization Policy는 Pod의 Istio Sidecar가 주입된 Pod로 들어오는 요청을 거부/허용 할지를 결정하는 기능을 제공한다. [Text 1]은 Authorization Policy의 형식을 나타내고 있다. Authorization Policy는 크게 **Selector**, **Action**, **Rule** 3가지 요소로 구성되어 있다.

* Selector : Selector는 Authorization Policy가 적용될 Pod를 지정한다. 만약 Selector가 지정되지 않으면 Authorization Policy는 Authorization Policy가 존재하는 Namespace 내의 모든 Pod에 적용된다. 본 글에서는 Selector에 의해서 Authorization Policy가 적용될 Pod를 **Target Pod**라고 지칭한다. Worklaod Pod 뿐만 아니라 Istio의 Ingress Gateway와 Egress Gateway도 Target Pod가 될 수 있다.
* Rule : Rule은 Target Pod로 들어오는 **요청의 조건**을 지정한다.
* Action : Action은 Rule에 의해서 Target Pod로 들어오는 요청을 거부/허용 할지 결정한다. **ALLOW**, **DENY**, **CUSTOM**, **AUDIT** 4가지 중에 하나를 선택할 수 있으며, 의미 그대로 ALLOW는 허용, DENY는 거부, CUSTOM은 사용자 정의 규칙을 의미한다. 마지막으로 AUDIT은 실제 Inbound Traffic을 제어하지는 않고 관련 로그만 남기는 역할을 수행한다.

Authorization Policy는 Target Pod로 들어오는 요청을 거부/허용하는, 즉 **Ingress Traffic**을 제어하는 기법이며 Outbound Traffic을 제어하는 기능은 제공하지 않는다. 또한 Authorization Policy는 **Target Pod의 Sidecar로 동작중인 Envoy Proxy에서 동작**하기 때문에, 만약 Target Pod에 Sidecar가 주입되지 않은 경우에는 동작하지 않으며 모든 요청이 허용된다. 또한 **mTLS 설정이 필요한 Rule**을 이용할 경우에는 Target Pod의 Sidecar뿐만 아니라, 요청을 시작하는 Pod에도 Sidecar가 주입되어 있어야 mTLS가 동작하기 때문에 Target Pod와 요청을 시작하는 Pod에 모두 Sidecar가 주입되어 있어야 한다.

### 1.1. 허용, 거부 처리 과정

{{< figure caption="[Figure 1] Istio Authorization Process" src="images/istio-authorization-process.png" width="900px" >}}

[Figure 1]은 Authorization Policy로 인해서 어떻게 Inbound Traffic의 허용 또는 거부가 결정되는 과정을 나타내고 있다. 허용 또는 거부 처리 과정은 Authorization Policy의 **존재 여부**와 어떤 Authorization Policy에 설정된 **Action**에 의해서 결정된다. 총 4단계의 처리 과정을 통해서 Inbound Traffic의 허용 또는 거부가 결정된다.

1. 1 단계에서는 Target Pod (Workload)를 위한 **CUSTOM** Action의 Authorization Policy가 **존재**하고, 그 결과 거부가 결정되면 해당 요청은 거부된다. 반면에 허용된다면 2단계로 진행된다.
2. 2 단계에서는 Target Pod (Workload)를 위한 **DENY** Action의 Authorization Policy가 **존재**하고 Rule과 일치한 요청이라면, 해당 요청은 거부된다. 만약 아니라면 3단계로 진행된다.
3. 3 단계에서는 Target Pod (Workload)를 위한 **ALLOW** Action의 Authoration Policy가 아무것도 **존재하지 않는**다면, 요청은 허용된다. 만약 Selector에 의해서 선택된 특정 Pod를 위한 ALLOW Action의 Authorization Policy가 존재한다면 4단계로 진행된다.
4. 4 단계에서는 Target Pod (Workload)를 위한 **ALLOW** Action의 Authoration Policy의 Rule과 일치한 요청이라면 요청은 허용된다. 만약 Rule과 일치하지 않는다면 요청은 거부된다.

### 1.2. Rule

하나의 Authorization Policy는 다수의 Rule을 포함할 수 있으며, 하나의 Rule은 **from**, **to**, **when** 3가지 요소로 구성되어 있다. 다수의 Rule이 존재할 경우 하나의 Rule만 만족하면 조건이 성립되는 **OR 조건**으로 동작하며, 하나의 Rule안에 다수의 조건이 존재할 경우 모든 조건을 만족해야 조건이 성립되는 **AND 조건**으로 동작한다.

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

[Text 2]는 **From** Rule의 예제를 나타내고 있다. From Rule은 Target Pod로 요청을 전달할 수 있는 **외부 주체**를 정의한다. From Rule에는 다수의 **Source**가 존재할 수 있으며, 하나의 Source에는 **namespace**, **ipBlocks**, **serviceAccounts**, **principals**, **requestPrincipals**, **remoteIpBlocks** 6가지의 조건과 **not** Prefix를 붙인 **notNamespace**, **notIpBlocks**, **notServiceAccounts**, **notPrincipals**, **notRequestPrincipals**, **notRemoteIpBlocks** 6가지의 조건 총 12가지의 조건을 이용할 수 있으며, not Prefix를 붙인 조건은 해당 조건을 만족하지 않는 경우를 의미한다.

* namespaces : 요청 시작이 가능한 Pod의 Namespace를 지정한다. 동작하기 위해서는 mTLS 설정이 필요하다.
* ipBlocks : 요청을 시작하는 주체의 IP를 지정한다. 여기서 IP는 IP Header의 Source IP를 의미한다. CIDR 또는 단일 IP 형태로 지정할 수 있다.
* serviceAccounts : 요청 시작이 가능한 특정 Namespace의 Service Account를 이용하는 Pod를 지정한다. `[namespace]/[serviceaccount]` 형태로 Namespace와 Service Account를 지정한다. 예를 들어 `default/user`는 `default` Namespace에서 `user`라는 Service Account를 이용하는 Pod를 의미한다. 동작하기 위해서는 mTLS 설정이 필요하다.
* principals : 요청 시작이 가능한 특정 Namespace의 Service Account를 이용하는 Pod를 지정한다. `cluster.local/ns/[namespace]/sa/[serviceaccount]` 형태로 Namespace와 Service Account를 지정한다. 예를 들어 `cluster.local/ns/default/sa/user`는 `default` Namespace에서 `user`라는 Service Account를 이용하는 Pod를 의미한다. 동작하기 위해서는 mTLS 설정이 필요하다.
* requestPrincipals : 요청을 허용할 JWT Token의 정보를 지정한다. `"[ISS]/[SUB]"` 형태로 Issuer와 Subject를 지정한다. 예를 들어 `example.com/sub`는 Issuer가 `example.com`이고 Subject가 `sub`인 JWT Token을 의미한다.
* remoteIpBlocks : 요청을 시작하는 주체의 IP를 지정한다. 여기서 IP는 `X-Forwarded-For` Header에 저장된 Source IP를 의미한다.

다수의 Source가 존재할 경우 하나의 Source만 만족하면 조건이 성립되는 **OR 조건**으로 동작하며, 하나의 Source안에 다수의 조건이 존재할 경우 모든 조건을 만족해야 조건이 성립되는 **AND 조건**으로 동작한다. 따라서 [Text 2]의 경우에는 Target Pod로 `test` Namespace에서 `user`라는 Service Account를 이용하는 Pod에서 `10.0.0.0/24`나 `20.0.0.20` IP로 연결을 시작하는 경우, 또는 `example.com/sub`라는 Subject를 가진 JWT Token을 이용하는 경우 요청을 허용한다.

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

[Text 3]는 **To** Rule의 예제를 나타내고 있다. To Rule은 외부 주체에서 Target Pod에 전송하는 **요청의 조건**을 지정한다. To Rule에는 다수의 **Operation**이 존재할 수 있으며, 하나의 Operation에는 **methods**, **paths**, **hosts**, **ports** 4가지의 조건과 **not** Prefix를 붙인 **notMethods**, **notPaths**, **notHosts**, **notPorts** 4가지의 조건 총 8가지의 조건을 이용할 수 있으며, not Prefix를 붙인 조건은 해당 조건을 만족하지 않는 경우를 의미한다.

다수의 Operation이 존재할 경우 하나의 Operation만 만족하면 조건이 성립되는 **OR 조건**으로 동작하며, 하나의 Operation안에 다수의 조건이 존재할 경우 모든 조건을 만족해야 조건이 성립되는 **AND 조건**으로 동작한다. 따라서 [Text 3]의 경우에는 Target Pod로 `api.example.com`, `api.example2.com` Hostname으로 `GET`, `POST` 메서드를 이용하여 `/v1/users` Path로 요청을 전송하는 경우, 또는 `api.ssup.com`, `api.ssup2.com` Hostname으로 `GET`, `POST`, `DELETE` 메서드를 이용하여 `443` 포트로 요청을 전송하는 경우 요청을 거부한다.

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

[Text 4]는 **When** Rule의 예제를 나타내고 있다. When Rule은 From Rule과 To Rule 사이에서 **세밀한 조건**을 지정하는데 이용한다. 다수의 Key/Value를 이용하여 조건을 설정할 수 있으며, 다수의 Key/Value가 설정되는 경우에는 하나의 Key/Value가 설정된 조건을 만족하는 경우에만 조건이 성립되는 **OR 조건**으로 동작한다.

when의 key/value에 이용할수 있는 조건은 [Link](https://istio.io/latest/docs/reference/config/security/conditions/)에서 확인할 수 있으며, from rule과 to rule에서도 이용 가능한 IP, Namespace, JWT Token의 정보를 설정할 수 있는걸 확인할 수 있다. 따라서 from과 to를 이용하지 않고 when만을 이용하여 조건을 설정하는것도 가능은 하다. 다만 일반적으로 when만 이용하여 조건을 지정하는 경우는 드물며, from과 to를 활용하여 큰 범위의 조건을 지정하고 세밀한 조건은 when에서 지정하는 것이 일반적인 방법이다.

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

[Text 5]는 **Custom Action**의 예제를 나타내고 있다. Custom Action은 사용자가 직접 정의한 조건을 이용하여 요청을 거부/허용 할 수 있는 기능을 제공한다. Authorization Rules를 통해서 제어할수 없는 조건을 Custom Action을 통해서 제어하는 한다. 일반적으로 Istio의 Ingress Gateway에 붙여 별도의 인증 시스템을 연동하는 경우에 많이 이용된다. [Text 5]의 예시도 Selector에 의해서 Istio의 Ingress Gateway에 붙은 Custom Action인 것을 확인할 수 있다. Custom Action에서 허용되더라도 Custom Action뒤에 처리되는 Deny, Allow Authorization Policy에 의해서 요청이 거부될 수도 있다.

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

Authorization Policy의 Provider는 Custom Action의 **Custom Logic을 처리하는 곳**을 지정하며, Provider는 Istio의 Mesh Config에 정의되어 있다. [Text 6]은 Provider가 정의된 Mesh Config의 예제를 나타내고 있다. `custom-authz`라는 Provider가 정의되어 있으며, 이 Provider는 `istio-system` Namespace에 존재하는 `custom-authz`라는 Service에 `8000` 포트로 요청을 전송하여 요청 거부/허용을 결정한다. `includeRequestHeadersInCheck`을 통해서 요청 거부/허용을 결정하기 위해서 반드시 필요한 Header를 지정할 수 있으며, 예제에서는 `custom-authz` Header를 지정하고 있다. Provider가 200 응답을 반환하면 요청은 허용되며, 200외의 응답을 반환하면 요청은 거부된다.

### 1.4. vs Network Policy

Authorzation Policy는 Target Pod로 전송되는 요청의 거부/허용 여부를 결정하는 반면에, Network Policy는 Target Pod의 Inbound/Outbound Traffic을 제어하는데 이용한다. Authorzation Policy는 L7 Layer에서 동작하기 때문에 HTTP Header 정보를 기반으로 요청의 거부/허용 여부를 결정하는 반면에, Network Policy는 L3/L4 Layer에서 동작하기 때문에 IP, Port 정보를 기반으로 Inbound/Outbound Traffic을 제어한다. Authorization Policy는 Istio의 Envoy Proxy에서 동작하는 반면에, Network Policy는 Kubernetes의 CNI Plugin에서 동작한다.

## 2. 참조

* Istio Authorization Policy : [https://istio.io/latest/docs/reference/config/security/authorization-policy/](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
* Istio Authorization Policy : [https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/](https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/)
* Istio Authorization Policy : [https://netpple.github.io/docs/istio-in-action/Istio-ch9-securing-3-authorizing](https://netpple.github.io/docs/istio-in-action/Istio-ch9-securing-3-authorizing)