---
title: Kubernetes Admission Controller
---

Analyzes Kubernetes Admission Controllers.

## 1. Kubernetes Admission Controller

{{< figure caption="[Figure 1] Kubernetes Admission Controller" src="images/kubernetes-admission-controller.png" width="900px" >}}

Kubernetes Admission Controller refers to a controller that extends Kubernetes functionality by hooking into the Kubernetes API processing flow. Kubernetes extends security, policy, and configuration-related features through Admission Controllers. [Figure 1] shows the Kubernetes Admission Controller. The Kubernetes API Server sequentially passes API request information one by one to **Compiled-in Admission Controllers** included within the Kubernetes API Server during the API request processing flow. Compiled-in Admission Controllers that receive API request information can reject, approve, or modify and approve the API request.

When the Kubernetes API server receives a rejection response from a Compiled-in Admission Controller, it stops processing that API request. When the Kubernetes API server receives an approval response from a Compiled-in Admission Controller, it passes the same API request information to the next Compiled-in Admission Controller and waits for a response. Only API requests that pass through all enabled Compiled-in Admission Controllers in this way are stored in etcd and reflected.

API requests have hooks twice: once in the Mutating phase and once in the Validating phase, for a total of two hooks. The Mutating phase hook is used to modify API requests as its name suggests. Additionally, it can reject API requests to stop processing if necessary. The Validating phase hook is used to validate API requests as-is. It can only reject API requests to stop processing and cannot modify API requests like the Mutating phase hook.

Admission Controllers come in two types: **Compiled-in Admission Controllers** compiled together with the Kubernetes API Server, and **Custom Admission Controllers** developed by Kubernetes users that run outside the Kubernetes API Server.

### 1.1. Compiled-in Admission Controller

Compiled-in Admission Controller refers to an Admission Controller that exists compiled together with the Kubernetes API Server. Only the Compiled-in Admission Controllers to be used can be enabled through the `--enable-admission-plugins` option of the Kubernetes API Server. Compiled-in Admission Controllers can be classified into controllers that use only Mutating Hooks, controllers that use only Validating Hooks, and controllers that use both Mutating Hooks and Validating Hooks, depending on their needs. Controllers using Mutating Hooks must implement the `Admit()` function of [MutationInterface](https://github.com/kubernetes/kubernetes/blob/v1.19.2/staging/src/k8s.io/apiserver/pkg/admission/interfaces.go#L129), and controllers using Validating Hooks must implement the `Validate()` function of [ValidationInterface](https://github.com/kubernetes/kubernetes/blob/f5743093fd1c663cb0cbc89748f730662345d44d/staging/src/k8s.io/apiserver/pkg/admission/interfaces.go#L138).

For example, the `DefaultIngressClass` Admission Controller is a Compiled-in Admission Controller that uses only Mutating Hooks. Mutating Hooks are used to set the Ingress Class of Ingresses that do not have an Ingress Class set to the Default Ingress Class. The `NamespaceExists` Admission Controller is a Compiled-in Admission Controller that uses only Validating Hooks. Validating Hooks are used to reject API requests related to non-existent namespaces.

The `ServiceAccount` Admission Controller is a Compiled-in Admission Controller that uses both Mutating Hooks and Validating Hooks. Mutating Hooks are used to set the Default Service Account for Pods that do not have a Service Account set, and to add mount settings to Pods so that tokens of the set Service Account can be obtained inside the Pod. Validating Hooks are used to check whether the Service Account set in the Pod is actually valid. Many Kubernetes features are implemented through Compiled-in Admission Controllers in this way.

### 1.2. Custom Admission Controller

Custom Admission Controller refers to an Admission Controller developed by Kubernetes users that runs outside the Kubernetes API Server. To understand how Custom Admission Controllers work, it is necessary to understand the roles of the `MutatingAdmissionWebhook` Controller and `ValidatingAdmissionWebhook` Controller, which are Compiled-in Admission Controllers. [Figure 1] also shows the operation of the `MutatingAdmissionWebhook` Controller and `ValidatingAdmissionWebhook` Controller.

The `MutatingAdmissionWebhook` Controller delivers received API request information to registered Custom Mutating Admission Controllers via webhooks and waits for responses. When multiple Custom Mutating Admission Controllers exist, it repeats the action of delivering received API request information one by one sequentially to Custom Mutating Admission Controllers and waiting for responses.

When multiple Custom Mutating Admission Controllers exist, the order in which API request information is delivered is called sequentially in alphabetical order of the `MutatingWebhookConfiguration` object names used for Custom Mutating Admission Controller registration. However, this order is not officially guaranteed by Kubernetes and may change as Kubernetes versions increase in the future. For this reason, Kubernetes documentation states that Custom Admission Controllers must be developed assuming that the Mutating Webhook call order can change at any time.

The `ValidatingAdmissionWebhook` Controller delivers received API request information to registered Custom Validating Admission Controllers via webhooks and waits for responses. When multiple Custom Validating Admission Controllers exist, it delivers received API request information simultaneously in parallel to Custom Validating Admission Controllers and waits for responses. If any response is rejected, the API request is rejected.

Custom Admission Controllers run on multiple Pods for HA (High Availability) and are bound together through Services. The `MutatingAdmissionWebhook` Controller and `ValidatingAdmissionWebhook` Controller deliver API request information through the Service of Custom Admission Controller Pods. API request information is delivered to Custom Admission Controllers in HTTP format.

```yaml {caption="[File 1] MutatingWebhookConfiguration", linenos=table}
apiVersion: admissionregistration.k8s.io/v1
  kind: MutatingWebhookConfiguration
  metadata:
    name: MutatingController
  webhooks:
  - name: MutatingWebhook
    admissionReviewVersions: ["v1", "v1beta1"]
    clientConfig:
      service:
        namespace: default
        name: MutatingWebhook
        path: /Mutating
      caBundle: KUBE-CA
    rules:
    - operations:
      - CREATE
      apiGroups:
      - ""
      apiVersions:
      - "v1"
      resources:
      - pods
    failurePolicy: Ignore
    timeoutSeconds: 5
```

```yaml {caption="[File 2] ValidatingWebhookConfiguration", linenos=table}
apiVersion: admissionregistration.k8s.io/v1
  kind: ValidatingWebhookConfiguration
  metadata:
    name: ValidatingController
  webhooks:
  - name: ValidatingWebhook
    admissionReviewVersions: ["v1", "v1beta1"]
    clientConfig:
      service:
        namespace: default
        name: ValidatingWebhook
        path: /Validating
      caBundle: <kube-ca>
    rules:
    - operations:
      - DELETE
      apiGroups:
      - ""
      apiVersions:
      - "v1"
      resources:
      - pods
    failurePolicy: Fail
    timeoutSeconds: 5
```

For a Custom Admission Controller to receive API request information from the `MutatingAdmissionWebhook` Controller, the Custom Admission Controller must be registered with the `MutatingAdmissionWebhook` Controller. Custom Admission Controllers can be registered with the `MutatingAdmissionWebhook` Controller through `MutatingWebhookConfiguration` files. [File 1] shows a `MutatingWebhookConfiguration` file.

Similarly, for a Custom Admission Controller to receive API request information from the `ValidatingAdmissionWebhook` Controller, the Custom Admission Controller must be registered with the `ValidatingAdmissionWebhook` Controller. Custom Admission Controllers can be registered with the `ValidatingAdmissionWebhook` Controller through `ValidatingWebhookConfiguration` files. [File 2] shows a `ValidatingWebhookConfiguration` file.

It can be seen that `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` are configured in the same format. Multiple webhooks can be registered at once through the `webhooks` field. The `clientConfig` field contains Service information and Path information needed to access the webhook. In [File 1], the webhook exists at the `/Mutating` path of the `MutatingWebhook` Service in the default namespace. The `rules` field is the part that configures which API request information to send to Custom Admission Controllers. In [File 1], only API request information related to Pod Create of v1 API Version is sent to Custom Admission Controllers.

```yaml {caption="[Data 1] API Request Information Sent to Custom Admission Controller", linenos=table}
{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "request": {
    "uid": "705ab4f5-6393-11e8-b7cc-42010a800002",
    "kind": {"group":"autoscaling","version":"v1","kind":"Scale"},
    "resource": {"group":"apps","version":"v1","resource":"deployments"},
    "subResource": "scale",

    "requestKind": {"group":"autoscaling","version":"v1","kind":"Scale"},
    "requestResource": {"group":"apps","version":"v1","resource":"deployments"},
    "requestSubResource": "scale",

    "name": "my-deployment",
    "namespace": "my-namespace",

    "operation": "UPDATE",
    "userInfo": {
      "username": "admin",
      "uid": "014fbff9a07c",
      "groups": ["system:authenticated","my-admin-group"],
      "extra": {
        "some-key":["some-value1", "some-value2"]
      }
    },

    "object": {"apiVersion":"autoscaling/v1","kind":"Scale",...},
    "oldObject": {"apiVersion":"autoscaling/v1","kind":"Scale",...},
    "options": {"apiVersion":"meta.k8s.io/v1","kind":"UpdateOptions",...},

    "dryRun": false
  }
}
```

[Data 1] shows the API request information that the `MutatingAdmissionWebhook` Controller or `ValidatingAdmissionWebhook` Controller sends to Custom Admission Controllers. The `name` and `namespace` fields can be used to identify which object the API request was for. The `userInfo` field stores information about the user who sent the API request. The `oldObject` field stores the state of the object before the API request. The `object` field stores the final state of the object that will be created or modified by the API request.

```yaml {caption="[Data 2] Custom Admission Controller Response", linenos=table}
{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "response": {
    "uid": "<value from request.uid>",
    "allowed": false,
    "status": {
      "code": 403,
      "message": "You cannot do this because it is Tuesday and your name starts with A"
    }
  }
}
```

[Data 2] shows the response that Custom Admission Controllers send to the Kubernetes API Server. The `allowed` field stores whether the API request is approved. The `status` field can store the reason for API request rejection.

```yaml {caption="[Data 3] Mutating Custom Admission Controller API Request Modification Response", linenos=table}
{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "response": {
    "uid": "<value from request.uid>",
    "allowed": true,
    "patchType": "JSONPatch",
    "patch": "W3sib3AiOiAiYWRkIiwgInBhdGgiOiAiL3NwZWMvcmVwbGljYXMiLCAidmFsdWUiOiAzfV0="
  }
}
```

[Data 3] shows the response that Mutating Custom Admission Controllers send to the Kubernetes API Server when API requests need to be modified. The changes to the API request are stored in the `patch` field by encoding `JSONPatch`, which is a format for storing JSON changes, in Base64 format.

## 2. References

* [https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
* [https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/)
* [https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
* [https://docs.openshift.com/container-platform/3.11/architecture/additional-concepts/dynamic-admission-controllers.html](https://docs.openshift.com/container-platform/3.11/architecture/additional-concepts/dynamic-admission-controllers.html)
* [https://m.blog.naver.com/alice-k106/221546328906](https://m.blog.naver.com/alice-k106/221546328906)


