---
title: Kubernetes Authentication OIDC
---

Analyzes Kubernetes authentication methods based on OIDC.

## 1. Kubernetes Authentication OIDC

{{< figure caption="[Figure 1] Kubernetes Authentication OIDC" src="images/kubernetes-authentication-oidc.png" width="900px" >}}

Kubernetes provides authentication methods based on OIDC. [Figure 1] shows Kubernetes authentication methods based on OIDC. Kubernetes Client (kubectl) authenticates with the Identity Provider by passing **client-id** and **client-secret** and obtains an **ID Token**. The ID Token delivered by the Identity Provider contains authenticated App/User information stored in **JWT** format. Kubernetes Client that obtained the ID Token passes the ID Token to the Kubernetes API Server through the `Authorization: Bearer $TOKEN` header to authenticate with the Kubernetes API Server.

### 1.1. ID Token Validation

To verify whether an ID Token is valid, the Kubernetes API Server needs HTTPS URL information containing **information about the Identity Provider that issued the ID Token**. The Identity Provider's HTTPS URL can be specified through the `--oidc-issuer-url` option of the Kubernetes API Server. In [Figure 1], since the Identity Provider is `https://accounts.google.com`, set `https://accounts.google.com` in the `--oidc-issuer-url` option. It can be seen that the Identity Provider of the ID Token is also stored in the `iss` claim of the ID Token.

If `https://accounts.google.com` is set in the `--oidc-issuer-url` option, add the `.well-known/openid-configuration` path defined in the OpenID Discovery 1.0 standard to obtain Identity Provider information from the `https://accounts.google.com/.well-known/openid-configuration` path. Additionally, the Kubernetes API Server verifies whether the ID Token has a valid Client ID through the Client ID obtained via the `--oidc-client-id` option. The Client ID of the ID Token is stored in the `aud` claim of the ID Token.

```yaml {caption="[Text 1] Role Binding with User", linenos=table}
kind: RoleBinding
metadata:
  name: ssup2-user-role-binding
  namespace: default
subjects:
- kind: User
  name: https://accounts.google.com#ssup2
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: role-name
  apiGroup: rbac.authorization.k8s.io
```

The Kubernetes API Server considers the `sub` claim of the ID Token as the user name by default. The Identity Provider's HTTPS URL + `#` string is prefixed to this and used as a user within the Kubernetes API Server. Therefore, the ID Token in [Figure 1] represents a user named `https://accounts.google.com#ssup2`. To grant roles to this user, grant roles to the `https://accounts.google.com#ssup2` user through Cluster Role Binding or Role Binding as shown in [Text 1]. The claim and prefix for the user name can be changed through the `--oidc-username-claim` option and `--oidc-username-prefix` option of the Kubernetes API Server.

Group information can also be included in the ID Token, similar to the user name. The Group claim must be configured through the `--oidc-groups-claim` option of the Kubernetes API Server. If the `--oidc-groups-claim` option is set to `groups`, the ID Token in [Figure 1] represents a user belonging to the `system:masters` group and the `kube` group. A prefix can also be added similarly to users through the `--oidc-groups-prefix` option. For kubectl, the ID Token can be set and used through the `--token` option.

## 2. References

* [https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
* [https://coffeewhale.com/kubernetes/authentication/oidc/2020/05/04/auth03/](https://coffeewhale.com/kubernetes/authentication/oidc/2020/05/04/auth03/)

