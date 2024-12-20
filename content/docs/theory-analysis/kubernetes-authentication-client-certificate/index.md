---
title: Kubernetes Authentication Client Certificate
---

Client 인증서를 기반으로하는 Kubernetes Authentication 기법을 분석한다.

## 1. Kubernetes Authentication Client Certificate

{{< figure caption="[Figure 1] Kubernetes Authentication Client Certificate" src="images/kubernetes-authentication-client-certificate.png" width="700px" >}}

Kubernetes는 Client 인증서 기반의 인증 기법을 제공한다. [Figure 1]은 Client 인증서 기반의 Kubernetes 인증 기법을 나타내고 있다. Client의 인증서와 Key는 Client CA 인증서로 Signing하여 생성한다. Kubernetes API Server는 Client CA 인증서를 "--client-ca-file" Option을 통해서 얻는다. Client가 Client의 인증서 및 Key와 함께 Kubernetes API Server에 접근하면 Kubernetes API Server는 Client의 인증서를 Client CA 인증서와 Client Key를 통해 유효한지 확인한다.

Client의 인증서에는 하나의 CN (Common Name)과 다수의 O (Organization) 항목이 존재한다. **Kubernetes에서는 CN 항목의 값을 User의 이름으로 인식하며, O 항목의 값은 Group의 이름으로 인식한다.**  따라서 Client 인증서와 Key를 통해서 인증한 Client에게 Role을 부여하기 위해서는 Client 인증서에 있는 User 또는 Group에게 Role을 부여하면 된다. [Figure 1]의 Client 인증서에는 User의 이름으로 "ssup2"가 설정되어 있고, Group의 이름으로 "system:masters"와 "kube"가 설정되어 있다.

```yaml {caption="[Text 1] Role Binding with User", linenos=table}
kind: RoleBinding
metadata:
  name: ssup2-user-role-binding
  namespace: default
subjects:
- kind: User
  name: ssup2
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: role-name
  apiGroup: rbac.authorization.k8s.io
```

```yaml {caption="[Text 2] Role Binding with Group", linenos=table}
kind: RoleBinding
metadata:
  name: kube-group-role-binding
  namespace: default
subjects:
- kind: Group
  name: kube
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: role-name
  apiGroup: rbac.authorization.k8s.io
```

[Text 1]은 "ssup2" User에게 Role을 부여하기 위한 Role Binding을 나타내고 있고, [Text 2]는 "kube" Group에게 Role을 부여하기 위한 Role Binding을 나타내고 있다. "system:"으로 시작하는 Group은 Kubernetes에서 예약된 Group 이름이다. 따라서 "system:masters" Group도 Kubernetes에서 예약된 Group을 의미한다. Kubernetes에서 "system:masters" Group은 Super 권한을 갖는 Group이다.

```yaml {caption="[Text 3] kubeconfig with Client Certificate", linenos=table}
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <K8s-API-SERVER-ROOT-CA-CRT>
    server: <K8s-API-SERVER-URL>
  name: my-cluster 
contexts:
- context:
  name: default-context
  context:
    cluster: my-cluster
    user: my-user
current-context: default-context
users:
- name: my-user
  user:
    client-certificate-data: <CLIENT-CERTIFICATE>
    client-key-data: <CLIENT-KEY>
```

kubeconfig 설정을 통해서 kubectl에서도 Client Certificate를 이용할 수 있다. [Text 3]은 Client Certificate를 이용하는 kubeconfig를 나타내고 있다. client-certificate-data 항목에 Client의 인증서 내용을 설정하고 client-key-data 항목에 Client Key를 설정한다.

## 2. 참고

* [https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certs](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certs)
* [https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects)
* [https://coffeewhale.com/kubernetes/authentication/x509/2020/05/02/auth01/](https://coffeewhale.com/kubernetes/authentication/x509/2020/05/02/auth01/)