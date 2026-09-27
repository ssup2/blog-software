---
title: Kubernetes Authentication Service Account
---

This post analyzes Service Account, one of the Kubernetes Authentication techniques.

## 1. Kubernetes Authentication Service Account

{{< figure caption="[Figure 1] Kubernetes Authentication Service Account" src="images/kubernetes-authentication-service-account.png" width="800px" >}}

A **Service Account** in Kubernetes is an account managed as an Object inside the Kubernetes Cluster. A Service Account is used when an App inside a Pod or a User of the Kubernetes Cluster authenticates to the Kubernetes API Server. [Figure 1] shows the process of creating a Service Account, injecting the Service Account into a Pod, and using the Service Account.

### 1.1. Service Account

```json {caption="[Text 1] Kubernetes default Service Account Token", linenos=table}
{
  "alg": "RS256",
  "kid": "DovKx1v1oJHU9--TMhqvB0X-kEqX6Ex1B0sCplrIicc"
}
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "default",
  "kubernetes.io/serviceaccount/secret.name": "default-token-d8wvm",
  "kubernetes.io/serviceaccount/service-account.name": "default",
  "kubernetes.io/serviceaccount/service-account.uid": "45d65b20-49d0-40aa-8f6d-0af8a8196db6",
  "sub": "system:serviceaccount:default:default"
}
```

Each Service Account stores three pieces of information: `token`, `ca.crt`, and `namespace`. `token` refers to the Token used when authenticating to the Kubernetes API Server. It is in **JWT** form and has the characteristic of **having no expiration date**. [Text 1] is the result of decoding the `token` of the `default` Service Account of a Kubernetes Cluster. It can be seen that information related to the `default` Service Account is stored in it.

`ca.crt` represents the Private Root CA certificate used by the Kubernetes API Server. Therefore, in most cases the `ca.crt` of all Service Accounts is identical. `ca.crt` is used when a Client using the Service Account accesses the Kubernetes API Server. `namespace` represents the Namespace where the Service Account exists. A Service Account is an Object that exists separately in each Namespace.

#### 1.1.1. default Service Account

```shell {caption="[Shell 1] Kubernetes Service Account"}
$ kubectl get sa -A | grep default                           [13:42:56]
cert-manager      default                              1         20d
default           default                              1         20d
kube-system       default                              1         20d
type: kubernetes.io/service-account-token
```

Kubernetes automatically creates a Service Account named `default` in each Namespace. [Shell 1] shows the `default` Service Account that exists in each Namespace. The `default` Service Account is the Service Account that a Pod uses by default when the Service Account to be used by the Pod is not specified at Pod creation time. If a Pod is created in the `kube-system` Namespace and the Service Account used by the Pod is not specified, that Pod uses the `default` Service Account of the `kube-system` Namespace.

The role of creating the `default` Service Account when a Namespace is created, or deleting the `default` Service Account when a Namespace is removed, is performed by the `serviceaccount` Controller of the Kubernetes Controller Manager.

### 1.2. Create Service Account

```shell {caption="[Shell 2] Checking Kubernetes Service Account"}
$ kubectl get serviceaccounts default -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
...
secrets:
- name: default-token-d8wvm

$ kubectl get secrets default-token-d8wvm -o yaml
apiVersion: v1
data:
  ca.crt: (BASE64)
  namespace: (BASE64)
  token: (BASE64)
kind: Secret
metadata:
  name: default-token-d8wvm
...
type: kubernetes.io/service-account-token
```

In Kubernetes, the `token`, `ca.crt`, and `namespace` of a Service Account are not stored directly in the Service Account, but in the Secret specified in the Service Account. [Shell 2] shows the process of checking the `token`, `ca.crt`, and `namespace` information stored in the Secret specified in the `default` Service Account.

When a Service Account is created by a Kubernetes Client, the `serviceaccount-token` Controller of the Kubernetes Controller Manager obtains the created Service Account information from the Kubernetes API Server, and then creates a Secret containing the `token`, `ca.crt`, and `namespace` information. Afterwards, it stores the name of the created Secret in the Service Account and finishes the Service Account configuration.

In [Text 1], it can be seen that the JWT Token is signed using the RSA256 asymmetric encryption algorithm. The Key used for JWT signing is specified through the `--service-account-private-key-file` Option of the Controller Manager.

### 1.3. Create Pod with Service Account

If a Service Account is not specified when a Pod is created, Kubernetes forcibly configures the Pod to use the `default` Service Account of the Namespace where the Pod exists. This forced configuration is performed by the ServiceAccount Admission Controller that exists in the Kubernetes API Server.

The Kubernetes API Server, which receives a Pod creation request from a Kubernetes Client, sends the Pod creation request to the ServiceAccount Admission Controller. The ServiceAccount Admission Controller changes (Mutation) the Pod's Spec so that the Service Account can be used inside the Pod.

```yaml {caption="[Text 2] Kubernetes Pod Spec", linenos=table}
...
spec:
  containers:
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-d8wvm
      readOnly: true
...
  serviceAccount: default
  serviceAccountName: default
...
  volumes:
  - name: default-token-d8wvm
    secret:
      defaultMode: 420
      secretName: default-token-d8wvm
```

The ServiceAccount Admission Controller looks at the Pod's Spec included in the Pod creation request, and if a Service Account is not specified in the Spec, it changes the Pod's Spec to use the `default` Service Account. It also changes the Pod's Spec to mount the `token`, `ca.crt`, and `namespace` included in the Service Account as a Volume so that they are accessible inside the Pod. [Text 2] shows the Pod's Spec changed by the ServiceAccount Admission Controller.

```shell {caption="[Shell 3] Checking token, ca.crt, and namespace inside a Kubernetes Pod"}
$ ls /var/run/secrets/kubernetes.io/serviceaccount
ca.crt  namespace  token
```

The path where the Volume is mounted by default is set to `/var/run/secrets/kubernetes.io/serviceaccount`. Therefore, going into the `/var/run/secrets/kubernetes.io/serviceaccount` path inside the Pod, the `token`, `ca.crt`, and `namespace` files can be found. If the Service Account to be used is specified in the Pod's Spec, the ServiceAccount Admission Controller changes only the Volume-related Spec so that the specified Service Account can be used inside the Pod.

### 1.4. Use Service Account

A Kubernetes Client (`kubectl`) that knows the Token of a Service Account performs authentication by delivering the Token of the Service Account to the Kubernetes API Server. The Token of the Service Account can be delivered with the `Authorization: Bearer $TOKEN` Header. The Kubernetes API Server, which receives the Token of the Service Account, verifies whether the Token is valid using the Key configured with the `--service-account-key-file` Option.

Therefore, the Key configured with the `--service-account-private-key-file` Option of the Controller Manager and the Key configured with the `--service-account-key-file` Option of the Kubernetes API Server must have an asymmetric Key Pair relationship with each other. In addition, since the Kubernetes API Server uses a Private Root CA certificate, the Client must also have the Private Root CA certificate of the Kubernetes API Server.

#### 1.4.1. in Pod

```shell {caption="[Shell 4] Using Kubernetes Service Account"}
$ TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
$ curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt "https://kubernetes.default.svc.cluster.local/api/v1/nodes" -H "Authorization: Bearer $TOKEN"
```

Inside a Pod, the Service Account can be used simply through the `curl` command. [Shell 4] shows how to use the Service Account through the `curl` command inside a Pod. The Token of the Service Account and the `ca.crt` of the Kubernetes API Server, which can be found inside the Pod, are used.

##### 1.4.2. in kubeconfig

```yaml {caption="[Text 3] kubeconfig with Service Account", linenos=table}
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
    token: <SERVICE-ACCOUNT-TOKEN>
```

The Service Account can also be used in `kubectl` through kubeconfig configuration. [Text 3] shows a kubeconfig that uses a Service Account. It can be seen that the Token of the Service Account and the `ca.crt` of the Kubernetes API Server are specified.

## 2. References

* Accessing Clusters : [https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod)
* Service Accounts - OpenShift Developer Guide : [https://docs.openshift.com/container-platform/3.4/dev-guide/service-accounts.html](https://docs.openshift.com/container-platform/3.4/dev-guide/service-accounts.html)
* kube-apiserver : [https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
* Kubernetes kubeconfig with service account token : [https://stackoverflow.com/questions/55629894/kubernetes-kubeconfig-with-service-account-token](https://stackoverflow.com/questions/55629894/kubernetes-kubeconfig-with-service-account-token)
