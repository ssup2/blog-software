---
title: Istio Authorization Policy
draft: true
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

Istio의 Authorization Policy는 **Pod와 Pod 사이** 또는 **Pod와 외부 사이**의 연결을 제어하는 기능을 제공한다. [Text 1]은 Authorization Policy의 형식을 나타내고 있다. Authorization Policy는 크게 **Selector**, **Action**, **Rule** 3가지 요소로 구성되어 있다.

* Selector : Selector는 Authorization Policy가 적용될 Pod를 지정할때 이용한다. 만약 Selector가 지정되지 않으면 Authorization Policy는 Authorization Policy가 존재하는 Namespace 내의 모든 Pod에 적용된다. 본 글에서는 Selector에 의해서 Authorization Policy가 적용될 Pod를 **Target Pod**라고 지칭한다.
* Action : Action은 Authorization Policy를 통해서 연결이 허용 또는 거부 될지를 결정하는 요소이다. **ALLOW**, **DENY**, **CUSTOM**, **AUDIT** 4가지 중에 하나를 선택할 수 있으며, 의미 그대로 ALLOW는 허용, DENY는 거부, CUSTOM은 사용자 정의 규칙을 의미한다. 마지막으로 AUDIT은 실제 연결의 허용 여부를 결정하지는 않고 연결 로그를 남기는 역할을 수행한다.
* Rule : Rule은 어느 구간의 연결이 허용 또는 거부 될지를 결정한다.

### 1.1. 허용, 거부 처리 과정

{{< figure caption="[Figure 1] Istio Authorization Process" src="images/istio-authorization-process.png" width="900px" >}}

[Figure 1]은 Authorization Policy로 인해서 어떻게 연결의 허용 또는 거부가 결정되는 과정을 나타내고 있다. 허용 또는 거부 처리 과정은 Authorization Policy의 **존재 여부**와 어떤 Authorization Policy에 설정된 **Action**에 의해서 결정된다. 총 4단계의 처리 과정을 통해서 연결의 허용 또는 거부가 결정된다.

1. 1 단계에서는 Target Pod (Workload)를 위한 **CUSTOM** Action의 Authorization Policy가 **존재**하고, 그 결과 거부가 결정되면 해당 연결은 거부된다. 반면에 허용된다면 2단계로 진행된다.
2. 2 단계에서는 Target Pod (Workload)를 위한 **DENY** Action의 Authorization Policy가 **존재**하고 Rule과 일치한 연결 경로라면, 연결은 거부된다. 만약 아니라면 3단계로 진행된다.
3. 3 단계에서는 Target Pod (Workload)를 위한 **ALLOW** Action의 Authoration Policy가 아무것도 **존재하지 않는**다면, 연결은 허용된다. 만약 Selector에 의해서 선택된 특정 Pod를 위한 ALLOW Action의 Authorization Policy가 존재한다면 4단계로 진행된다.
4. 4 단계에서는 Target Pod (Workload)를 위한 **ALLOW** Action의 Authoration Policy의 Rule과 일치한 연결 경로라면 연결은 허용된다. 만약 Rule과 일치하지 않는다면 연결은 거부된다.

### 1.2. Rule

Authorization Policy의 Rule은 연결을 정의하는 요소이다. Rule은 **from**과 **to** 2가지 요소로 구성되어 있다.

#### 1.2.1. from

```yaml {caption="[Text 2] from Rule", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-user1
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

**from**은 Target Pod로 연결을 수행할 수 있는 외부 주체를 정의한다. from에는 다수의 **Source**가 존재할 수 있으며, 하나의 Source에는 **namespace**, **ipBlocks**, **principals**, **requestPrincipals**, **remoteIpBlocks** 5가지의 조건과 **not** Prefix를 붙인 **notNamespace**, **notIpBlocks**, **notPrincipals**, **notRequestPrincipals**, **notRemoteIpBlocks** 5가지의 조건 총 10가지의 조건을 이용할 수 있으며, not Prefix를 붙인 조건은 해당 조건을 만족하지 않는 경우를 의미한다.

* namespaces : 연결을 시작이 가능한 Pod의 Namespace를 지정한다.
* ipBlocks : 연결을 시작하는 주체의 IP를 지정한다. 여기서 IP는 IP Header의 Source IP를 의미한다. CIDR 또는 단일 IP 형태로 지정할 수 있다.
* principals : 연결을 시작이 가능한 특정 Namespace의 Service Account를 이용하는 Pod를 지정한다. `cluster.local/ns/[namespace]/sa/[serviceaccount]` 형태로 Namespace와 Service Account를 지정한다. 예를 들어 `cluster.local/ns/default/sa/user`는 `default` Namespace에서 `user`라는 Service Account를 이용하는 Pod를 의미한다.
* requestPrincipals : 연결을 허용할 JWT Token의 정보를 지정한다. `"[ISS]/[SUB]"` 형태로 Issuer와 Subject를 지정한다. 예를 들어 `example.com/sub`는 Issuer가 `example.com`이고 Subject가 `sub`인 JWT Token을 의미한다.
* remoteIpBlocks : 연결을 시작하는 주체의 IP를 지정한다. 여기서 IP는 `X-Forwarded-For` Header에 저장된 Source IP를 의미한다.

다수의 Source가 존재할 경우 하나의 Source만 만족하면 조건이 성립되는 **OR 조건**으로 동작하며, 하나의 Source안에 다수의 조건이 존재할 경우 모든 조건을 만족해야 조건이 성립되는 **AND 조건**으로 동작한다.

####  1.2.2. to

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-read-only
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-api
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

**to**는 Target Pod에서 연결할 수 있는 외부 주체를 정의한다. to에는 다수의 **Operation**이 존재할 수 있으며, 하나의 Operation에는 **methods**, **paths**, **hosts**, **ports** 4가지의 조건과 **not** Prefix를 붙인 **notMethods**, **notPaths**, **notHosts**, **notPorts** 4가지의 조건 총 8가지의 조건을 이용할 수 있으며, not Prefix를 붙인 조건은 해당 조건을 만족하지 않는 경우를 의미한다. 

### 1.3. Custom

### 1.4. vs Network Policy

Istio Authorization Policy와 유사한 Kubernetes Object중에 하나는 Network Policy가 존재한다. Network Policy 또한 Pod와 Pod 사이의 연결 또는 Pod와 외부 사이의 연결을 제어하는데 이용된다. 다만 Istio Authorization Policy는 **Network Layer 7**에서 동작하는 반면 Network Policy는 **Network Layer 3/4**에서 동작한다.

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}

```

## 2. 참조

* Istio Authorization Policy : [https://istio.io/latest/docs/reference/config/security/authorization-policy/](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
* Istio Authorization Policy : [https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/](https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/)