---
title: Kubernetes Authentication Webhook
---

This post analyzes the Webhook-based Kubernetes Authentication technique.

## 1. Kubernetes Authentication Webhook

{{< figure caption="[Figure 1] Kubernetes Authentication Service Account" src="images/kubernetes-authentication-webhook.png" width="700px" >}}

Kubernetes provides a **Webhook-based authentication technique**. The Webhook-based authentication technique has the advantage of being able to integrate with various forms of external authentication servers. [Figure 1] shows the Webhook-based Kubernetes authentication technique. The Kubernetes Client (`kubectl`) obtains a Token from the external authentication server through an authentication process. The Kubernetes Client that has obtained the Token passes the Token to the Kubernetes API Server through the `Authorization: Bearer $TOKEN` Header. The Kubernetes API Server that has received the Token is authenticated by passing a **TokenReview** Object containing the Token information to the external authentication server.

```yaml {caption="[Text 1] Webhook Config", linenos=table}
apiVersion: v1
kind: Config
# clusters refers to the remote authentication server.
clusters:
  - name: authentication-server
    cluster:
      certificate-authority: authentication-server-ca-crt-path
      server: https://authentication-server.ssup2.com/authenticate

# users refers to the API server's webhook configuration.
users:
  - name: k8s-api-server
    user:
      client-certificate: k8s-api-server-crt-path
      client-key: k8s-api-server-crt-key-path

current-context: webhook
contexts:
- context:
    cluster: authentication-server
    user: k8s-api-server
  name: webhook
```

The way to configure an external authentication server for the Kubernetes API Server is to pass a Webhook Config file through the `--authentication-token-webhook-config-file` Option. The Webhook Config file has the same format as a kubeconfig file, but its configuration contents are different. [Text 1] shows the Webhook Config. The Cluster entry stores information related to the external authentication server, and the User entry stores the certificate information the Kubernetes API Server uses when communicating with the external authentication server.

```json {caption="[Text 2] TokenReview Spec", linenos=table}
{
  "apiVersion": "authentication.k8s.io/v1",
  "kind": "TokenReview",
  "spec": {
    "token": "<token>",
    "audiences": ["https://ssup2.com", "https://ssup3.com"]
  }
}
```

To pass the Token to the external authentication server, the Kubernetes API Server internally creates a TokenReview Object and stores the Token in the **Spec** of the TokenReview Object. The Kubernetes API Server then passes the created TokenReview Object to the external authentication server. [Text 2] shows the TokenReview Object that the Kubernetes API Server passes to the external authentication server.

```yaml {caption="[Text 3] TokenReview Status Success", linenos=table}
{
  "apiVersion": "authentication.k8s.io/v1",
  "kind": "TokenReview",
  "status": {
    "authenticated": true,
    "user": {
      "username": "ssup2",
      "groups": ["system:masters", "kube"]
    },
    "audiences": ["https://ssup2.com", "https://ssup3.com"]
  }
}
```

```yaml {caption="[Text 4] TokenReview Status Failed", linenos=table}
{
  "apiVersion": "authentication.k8s.io/v1",
  "kind": "TokenReview",
  "status": {
    "authenticated": false,
    "error": "Credentials are expired"
  }
}
```

If the Token is valid, the external authentication server that has received the TokenReview Object stores the information that authentication succeeded, the name of the User the Token authenticates, and the Group information the User belongs to in the **Status** of the TokenReview Object, and passes it to the Kubernetes API Server. If the Token is not valid, it stores the information that authentication failed in the Status of the TokenReview Object and passes it to the Kubernetes API Server. [Text 3] shows the Status of the TokenReview Object set by the external authentication server when the Token is valid, and [Text 4] shows the Status of the TokenReview Object set by the external authentication server when the Token is not valid.

## 2. References

* Kubernetes Authenticating - Webhook Token Authentication : [https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication)
* k8s 인증 완벽이해 #4 - Webhook 인증 : [https://coffeewhale.com/kubernetes/authentication/webhook/2020/05/05/auth04/](https://coffeewhale.com/kubernetes/authentication/webhook/2020/05/05/auth04/)
