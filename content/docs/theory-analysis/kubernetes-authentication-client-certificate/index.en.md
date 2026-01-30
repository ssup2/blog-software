---
title: Kubernetes Authentication Client Certificate
---

Analyzes Kubernetes authentication methods based on client certificates.

## 1. Kubernetes Authentication Client Certificate

{{< figure caption="[Figure 1] Kubernetes Authentication Client Certificate" src="images/kubernetes-authentication-client-certificate.png" width="700px" >}}

Kubernetes provides authentication methods based on client certificates. [Figure 1] shows Kubernetes authentication methods based on client certificates. Client certificates and keys are created by signing with a Client CA certificate. The Kubernetes API Server obtains the Client CA certificate through the `--client-ca-file` option. When a client accesses the Kubernetes API Server with the client's certificate and key, the Kubernetes API Server verifies whether the client's certificate is valid through the Client CA certificate and client key.

A client certificate contains one CN (Common Name) and multiple O (Organization) fields. **In Kubernetes, the value of the CN field is recognized as the user's name, and the value of the O field is recognized as the group's name.** Therefore, to grant roles to clients authenticated through client certificates and keys, roles should be granted to users or groups in the client certificate. The client certificate in [Figure 1] has `ssup2` set as the user's name, and `system:masters` and `kube` set as group names.

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

[Text 1] shows a Role Binding to grant a role to the `ssup2` user, and [Text 2] shows a Role Binding to grant a role to the `kube` group. Groups starting with `system:` are reserved group names in Kubernetes. Therefore, the `system:masters` group also refers to a reserved group in Kubernetes. In Kubernetes, the `system:masters` group is a group with super privileges.

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

Client certificates can also be used in kubectl through kubeconfig settings. [Text 3] shows a kubeconfig using a client certificate. Set the client certificate content in the `client-certificate-data` field and set the client key in the `client-key-data` field.

## 2. References

* [https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certs](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certs)
* [https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects)
* [https://coffeewhale.com/kubernetes/authentication/x509/2020/05/02/auth01/](https://coffeewhale.com/kubernetes/authentication/x509/2020/05/02/auth01/)


