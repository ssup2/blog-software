---
title: AWS EKS IRSA
---

## 1. Granting AWS IAM Roles to AWS EKS Service Accounts (IRSA)

{{< figure caption="[Figure 1] AWS EKS IRSA" src="images/aws-eks-irsa.png" width="900px" >}}

AWS EKS 1.14 and later provides the **IRSA** (IAM Roles for Service Accounts) feature, which allows an AWS IAM Role to be granted to a Service Account of an EKS (K8s) Cluster. Through the IRSA feature, a Pod that uses a Service Account granted an AWS IAM Role becomes able to use AWS Services. [Figure 1] shows this process divided into 4 steps: Service Account creation, Pod creation, Service Account Token creation/rotation, and Service Account Token usage. The main components of [Figure 1] are as follows.

* **AWS EKS OIDC Identity Provider** : Represents the dedicated OIDC Identity Provider that each EKS Cluster has. It is registered (Federated) with AWS IAM as a trusted OIDC Identity Provider.
* **Private/Public Key** : The AWS EKS OIDC Identity Provider and the Kubernetes API Server share and use the same Private/Public Key.
* **Pod Identity Webhook** : Represents a Mutating Webhook of the Kubernetes API Server. When a Pod uses a Service Account granted an AWS IAM Role, it performs the role of modifying the Pod's Spec so that the AWS IAM Role granted to the Service Account can be used inside the Pod.
* **Projected SA Token** : Represents the Token of a Service Account granted an AWS IAM Role. It is a separate Token from the default Service Account Token used by default in Kubernetes. Unlike the default Service Account Token, it has an **expiration time** and an **Audience** configured, and is characterized by being rotated periodically. It takes the form of a JWT Token.

The example used for the explanation is the [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html). This is because the AWS Load Balancer Controller running in an AWS EKS Cluster also needs to access the NLB (Network Load Balancer) and ALB (Application Load Balancer) AWS Services to control Load Balancers, so the Service Account used by the AWS Load Balancer Controller is also granted an AWS IAM Role through this feature.

### 1.1. Service Account Creation

```yaml {caption="[Text 1] Service Account with Role ARN", linenos=table}
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::132099918825:role/eksctl-ssup2-eks-cluster-addon-iamserviceacc-Role1-13GTAZQ9TJV8M
  creationTimestamp: "2021-04-06T14:53:13Z"
  labels:
    app.kubernetes.io/managed-by: eksctl
  name: aws-load-balancer-controller
  namespace: kube-system
  resourceVersion: "4643"
  selfLink: /api/v1/namespaces/kube-system/serviceaccounts/aws-load-balancer-controller
  uid: ceec1768-8be2-4ca9-9a24-f8bf4c1cce20
secrets:
- name: aws-load-balancer-controller-token-trf5m
```

To grant an AWS IAM Role to a Service Account, the Service Account must be created first. At this point, the **ARN of the AWS IAM Role** to be granted must be specified in the **eks.amazonaws.com/role-arn Annotation**. [Text 1] shows the Service Account used by the AWS Load Balancer Controller. It can be seen that the `arn:aws:iam::132099918825:role/eksctl-ssup2-eks-cluster-addon-iamserviceacc-Role1-13GTAZQ9TJV8M` Role is granted.

```json {caption="[Text 2] AWS IAM Role's Trust Relationship", linenos=table}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::132099918825:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/B0678ED568FC12BBC37256BBA2A4BB53"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-northeast-2.amazonaws.com/id/B0678ED568FC12BBC37256BBA2A4BB53:aud": "sts.amazonaws.com",
          "oidc.eks.ap-northeast-2.amazonaws.com/id/B0678ED568FC12BBC37256BBA2A4BB53:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
```

[Text 2] shows the Trust Relationship of the AWS IAM Role granted to the Service Account used by the AWS Load Balancer Controller in [Text 1]. The **Trust Relationship** represents the **authentication method and conditions** for using the AWS IAM Role. The `Principal` item indicates from whom authentication must be received in order to be granted the AWS IAM Role. In [Text 2], it can be seen that the URL of the EKS Cluster's OIDC Identity Provider is specified. Therefore, it means that a Pod running inside the EKS Cluster must be authenticated by that EKS Cluster's OIDC Identity Provider in order to be granted the AWS IAM Role.

The `Action` of the Trust Relationship specifies the method for being granted the AWS IAM Role, and it can be seen that `AssumeRoleWithWebIdentity` is specified in the `Action` item of [Text 2]. `AssumeRoleWithWebIdentity` means authenticating through a JWT Token issued by the OIDC Identity Provider. `Condition` represents the conditions of the Claims that must be included in the JWT Token. [Text 2] indicates that `sts.amazonaws.com` must be specified in the `aud` Claim, and `system:serviceaccount:kube-system:aws-load-balancer-controller` must be specified in the `sub` Claim.

In the IRSA process, the Projected SA Token is used as the JWT Token, and the Projected SA Token satisfies all of the conditions specified above. Therefore, the AWS IAM Role granted to the Service Account can be obtained and used through the Projected SA Token.

### 1.2. Pod Creation

```yaml {caption="[Text 3] Mutated Pod Spec", linenos=table}
...
spec:
  containers:
  - args:
    - --cluster-name=ssup2-eks-cluster
    - --ingress-class=alb
    env:
    - name: AWS_DEFAULT_REGION
      value: ap-northeast-2
    - name: AWS_REGION
      value: ap-northeast-2
    - name: AWS_ROLE_ARN
      value: arn:aws:iam::132099918825:role/eksctl-ssup2-eks-cluster-addon-iamserviceacc-Role1-13GTAZQ9TJV8M
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    image: amazon/aws-alb-ingress-controller:v2.1.3
...
  serviceAccount: aws-load-balancer-controller
  serviceAccountName: aws-load-balancer-controller
...
    volumeMounts:
    - mountPath: /var/run/secrets/eks.amazonaws.com/serviceaccount
      name: aws-iam-token
      readOnly: true
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: aws-load-balancer-controller-token-wq7kf
      readOnly: true
...
  volumes:
  - name: aws-iam-token
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          audience: sts.amazonaws.com
          expirationSeconds: 86400
          path: token
  - name: aws-load-balancer-controller-token-wq7kf
    secret:
      defaultMode: 420
      secretName: aws-load-balancer-controller-token-wq7kf
...
```

To perform the `AssumeRoleWithWebIdentity` operation inside a Pod, information such as the Region of the Kubernetes Cluster where the Pod runs, the AWS IAM Role to be granted, and the location of the JWT Token is required. This required information is forcibly injected into the Pod by the **Pod Identity Webhook** that exists in the EKS Control Plane. When a Pod using a Service Account granted an AWS IAM Role is created, the Pod Identity Webhook modifies (Mutates) the Pod's Spec to inject the information. [Text 3] shows the AWS Load Balancer Controller Pod modified by the Pod Identity Webhook.

The Pod Identity Webhook creates the `AWS_DEFAULT_REGION`, `AWS_REGION`, `AWS_ROLE_ARN`, and `AWS_WEB_IDENTITY_TOKEN_FILE` environment variables and the Projected SA Token Volume named `aws-iam-token`, and makes the Pod mount it. The Projected SA Token exists inside the Projected SA Token Volume named `aws-iam-token`. It can be seen that the Projected SA Token Volume configuration also includes the expiration time and Audience settings.

The `AWS_*` environment variables and the `aws-iam-token` Token added by the Pod Identity Webhook are used by the AWS SDK. The AWS SDK performs the `AssumeRoleWithWebIdentity` operation through the information in the configured environment variables. In [Text 3], it can be seen that the default Service Account configuration assigned to every Pod by default still exists.

### 1.3. Service Account Token Creation/Rotation

To perform the `AssumeRoleWithWebIdentity` operation, a JWT-format ID Token containing authentication information issued by the OIDC Identity Provider must be used. However, the Kubernetes API Server does not receive an ID Token issued by the OIDC Identity Provider, but instead generates the JWT Token directly and injects it into the Pod. For the K8s API Server to generate JWT Tokens on behalf of the OIDC Identity Provider, the API Server also uses the Private/Public Key used by the OIDC Identity Provider.

The Kubernetes API Server performs the configuration needed for JWT Token generation through the following Parameters.

* `service-account-signing-key-file` : Specifies the path of the Key file used when signing Service Account Tokens. It is expected that the Private Key of the EKS Cluster's OIDC Identity Provider is specified.
* `service-account-key-file` : Specifies the path of the Key file used when verifying signed Service Account Tokens. It is expected that the Public Key of the EKS Cluster's OIDC Identity Provider is specified.
* `service-account-issuer` : Sets the URL of the OIDC Identity Provider, which is the issuer of Service Account Tokens. It is expected that the EKS Cluster's OIDC Identity Provider URL is set in the Kubernetes API Server of EKS.

```json {caption="[Text 4] Projected SA Token", linenos=table}
{
  "aud": [
    "sts.amazonaws.com"
  ],
  "exp": 1618776732,
  "iat": 1618690332,
  "iss": "https://oidc.eks.ap-northeast-2.amazonaws.com/id/B0678ED568FC12BBC37256BBA2A4BB53",
  "kubernetes.io": {
    "namespace": "kube-system",
    "pod": {
      "name": "aws-load-balancer-controller-bc59445f-l4brz",
      "uid": "6fc3fe55-6add-4712-bfdc-c0073b99d33f"
    },
    "serviceaccount": {
      "name": "aws-load-balancer-controller",
      "uid": "ceec1768-8be2-4ca9-9a24-f8bf4c1cce20"
    }
  },
  "nbf": 1618690332,
  "sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
}
```

[Text 4] shows the content of the AWS Load Balancer Controller Pod's Projected SA Token after performing JWT Decoding. Due to the `service-account-issuer` Parameter, the URL of the EKS Cluster's OIDC Identity Provider is set in the Issuer (`iss`) Claim. Due to the `sts.amazonaws.com` Audience setting in [Text 3], `sts.amazonaws.com` is also set in the Audience (`aud`) Claim.

Since the AWS Load Balancer Controller runs in the `kube-system` Namespace and uses the `aws-load-balancer-controller` Service Account, the related content is set in the Subject (`sub`) Claim. It can also be seen that an expiration time exists in the Expiration (`exp`) Claim. It can be confirmed that the content of the Projected SA Token in [Text 3] satisfies the Condition of the AWS IAM Role in [Text 2].

```json {caption="[Text 5] Default Service Account Token", linenos=table}
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "kube-system",
  "kubernetes.io/serviceaccount/secret.name": "aws-load-balancer-controller-token-trf5m",
  "kubernetes.io/serviceaccount/service-account.name": "aws-load-balancer-controller",
  "kubernetes.io/serviceaccount/service-account.uid": "ceec1768-8be2-4ca9-9a24-f8bf4c1cce20",
  "sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
}
```

[Text 5] shows the content of the default Service Account Token created by default in the AWS Load Balancer Controller Pod after performing JWT Decoding. Compared with the Projected SA Token in [Text 4], it can be seen that several Claims, including the Expiration Claim and the Audience Claim, are not included.

### 1.4. Service Account Token Usage

The App inside the Pod sends the Projected SA Token to AWS STS to obtain a Credential through the `AssumeRoleWithWebIdentity` operation. AWS STS, which received the Projected SA Token, checks the Token's Issuer and verifies whether it is a trusted (Federated) OIDC Identity Provider. Once it is confirmed as a trusted OIDC Identity Provider, it checks whether the Projected SA Token is valid using the OIDC Identity Provider's Public Key. If the Projected SA Token is determined to be valid, AWS STS sends a Credential to the App inside the Pod. Afterwards, the App is granted the AWS IAM Role using the Credential and accesses AWS Services.

Although the Projected SA Token was actually issued not by the EKS Cluster's OIDC Identity Provider but by the Kubernetes API Server, since the Kubernetes API Server issued the Projected SA Token using the Private Key shared with the OIDC Identity Provider, AWS STS **regards** it as a Token issued by the EKS Cluster's OIDC Identity Provider and processes it.

```shell {caption="[Shell 1] Listing Federated OIDC Identity Providers"}
$ aws iam list-open-id-connect-providers
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::132099918825:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/B0678ED568FC12BBC37256BBA2A4BB53"
        }
    ]
}
```

[Shell 1] shows listing the trusted OIDC Identity Providers through AWS IAM. It can be seen that the EKS Cluster's OIDC Identity Provider is also registered as a trusted OIDC Identity Provider.

## 2. References

* Introducing fine-grained IAM roles for service accounts : [https://aws.amazon.com/ko/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/](https://aws.amazon.com/ko/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/)
* Enabling cross-account access to Amazon EKS cluster resources : [https://aws.amazon.com/ko/blogs/containers/enabling-cross-account-access-to-amazon-eks-cluster-resources/](https://aws.amazon.com/ko/blogs/containers/enabling-cross-account-access-to-amazon-eks-cluster-resources/)
* EKS IAM Roles for Service Accounts : [https://pnguyen.io/posts/eks-iam-roles-for-service-accounts/](https://pnguyen.io/posts/eks-iam-roles-for-service-accounts/)
* Create service account IAM policy and role - Amazon EKS : [https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html](https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html)
* AssumeRoleWithWebIdentity - AWS Security Token Service : [https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
* Configure Service Accounts for Pods - Kubernetes : [https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection)
* kube-apiserver - Kubernetes : [https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
* Federate Kubernetes with AWS IAM using OIDC : [https://reece.tech/posts/oidc-k8s-to-aws/](https://reece.tech/posts/oidc-k8s-to-aws/)
* Controlling IAM Permissions of Kubernetes Pods in EKS: Pod Identity Webhook : [https://tech.devsisters.com/posts/pod-iam-role/](https://tech.devsisters.com/posts/pod-iam-role/)
* Separating IAM Roles in AWS EKS : [https://www.blog-dreamus.com/post/flo-tech-aws-eks%EC%97%90%EC%84%9C%EC%9D%98-iam-%EC%97%AD%ED%95%A0-%EB%B6%84%EB%A6%AC](https://www.blog-dreamus.com/post/flo-tech-aws-eks%EC%97%90%EC%84%9C%EC%9D%98-iam-%EC%97%AD%ED%95%A0-%EB%B6%84%EB%A6%AC)
* TokenRequestProjectionについて調べてみた : [https://qiita.com/hiyosi/items/feec917d502af8ad8863](https://qiita.com/hiyosi/items/feec917d502af8ad8863)
* ServiceAccount token volume projection in manifest file : [https://stackoverflow.com/questions/57192079/serviceaccount-token-volume-projection-projected-token-in-path-in-manifest-f](https://stackoverflow.com/questions/57192079/serviceaccount-token-volume-projection-projected-token-in-path-in-manifest-f)
* Service Account Token Volume Projection : [https://kangwoo.kr/2020/02/13/service-account-token-volume-projection/](https://kangwoo.kr/2020/02/13/service-account-token-volume-projection/)
* OAuth2 Proxy with Kubernetes Service Accounts : [https://www.ianunruh.com/posts/oauth2-proxy-with-k8s-service-accounts/](https://www.ianunruh.com/posts/oauth2-proxy-with-k8s-service-accounts/)
