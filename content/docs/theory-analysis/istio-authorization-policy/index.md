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

Istio의 Authorization Policy는 **Pod와 Pod 사이** 또는 **Pod와 외부 사이**의 통신을 제어하는 기능을 제공한다. [Text 1]은 Authorization Policy의 형식을 나타내고 있다. Authorization Policy는 크게 **Selector**, **Action**, **Rule** 3가지 요소로 구성되어 있다.

* Selector : Selector는 Authorization Policy가 적용될 Pod를 지정할때 이용한다. 만약 Selector가 지정되지 않으면 Authorization Policy는 Authorization Policy가 존재하는 Namespace 내의 모든 Pod에 적용된다.
* Action : Action은 Authorization Policy를 통해서 통신이 허용 또는 거부 될지를 결정하는 요소이다. **ALLOW**, **DENY**, **CUSTOM**, **AUDIT** 4가지 중에 하나를 선택할 수 있으며, 의미 그대로 ALLOW는 허용, DENY는 거부, CUSTOM은 사용자 정의 규칙을 의미한다. 마지막으로 AUDIT은 실제 통신의 허용 여부를 결정하지는 않고 통신 로그를 남기는 역할을 수행한다.
* Rule : Rule은 어느 구간의 통신이 허용 또는 거부 될지를 결정한다.

### 1.1. 허용, 거부 처리 과정

{{< figure caption="[Figure 1] Istio Authorization Process" src="images/istio-authorization-process.png" width="900px" >}}

[Figure 1]은 Authorization Policy로 인해서 어떻게 통신의 허용 또는 거부가 결정되는 과정을 나타내고 있다. 허용 또는 거부 처리 과정은 Authorization Policy의 **존재 및 Selector에 의한 적용 여부**와 어떤 Authorization Policy에 설정된 **Action**과 **Rule**에 의해서 결정된다. 총 4단계의 처리 과정을 통해서 통신의 허용 또는 거부가 결정된다.

1. 1 단계에서는 Selector에 의해서 선택된 특정 Pod (Workload)를 위한 CUSTOM Action의 Authorization Policy가 존재하고, 그 결과 거부가 결정되면 해당 통신은 거부된다. 반면에 허용된다면 2단계로 진행된다.
2. 2 단계에서는 Selector에 의해서 선택된 특정 Pod (Workload)를 위한 DENY Action의 Authorization Policy가 존재하고 Rule과 일치한 통신 경로라면, 통신은 거부된다. 만약 아니라면 3단계로 진행된다.
3. 3 단계에서는 Selector에 의해서 선택된 특정 Pod (Workload)를 위한 ALLOW Action의 Authoration Policy가 아무것도 존재하지 않는다면, 통신은 허용된다. 만약 Selector에 의해서 선택된 특정 Pod를 위한 ALLOW Action의 Authorization Policy가 존재한다면 4단계로 진행된다.

 통신 요청이 들어오는 대상의 통신 정보를 수집한다. 수집된 통신 정보는 다음과 같은 순서로 허용, 거부 처리 과정을 거친다.

### 1.1. from Rules

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}
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
    - source:
        ipBlocks: ["10.0.0.0/24"]
    - source:
        principals: ["cluster.local/ns/default/sa/user1"]
    - source:
        requestPrincipals: ["user1"]
    - source:
        remoteIpBlocks: ["20.0.0.0/24"]
```

### 1.2. to Rules

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
        paths: ["/api/v1/data"]
        hosts: ["api.example.com", "api.example2.com"]
    - 
```

### 1.3. Custom

### 1.4. vs Network Policy

Istio Authorization Policy와 유사한 Kubernetes Object중에 하나는 Network Policy가 존재한다. Network Policy 또한 Pod와 Pod 사이의 통신 또는 Pod와 외부 사이의 통신을 제어하는데 이용된다. 다만 Istio Authorization Policy는 **Network Layer 7**에서 동작하는 반면 Network Policy는 **Network Layer 3/4**에서 동작한다.

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}

```

## 2. 참조

* Istio Authorization Policy : [https://istio.io/latest/docs/reference/config/security/authorization-policy/](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
* Istio Authorization Policy : [https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/](https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/)