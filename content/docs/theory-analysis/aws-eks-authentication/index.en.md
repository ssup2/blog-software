---
title: AWS EKS Authentication
---

Analyzes the authentication process of AWS EKS.

## 1. AWS EKS Authentication

{{< figure caption="[Figure 1] AWS EKS Authentication" src="images/aws-eks-authentication.png" width="700px" >}}

[Figure 1] shows the authentication process of AWS EKS Cluster. EKS Cluster performs authentication using **AWS IAM Authenticator**. EKS Cluster authentication based on AWS IAM Authenticator is used when kubectl accesses the K8s API Server of EKS Cluster, or when kubelet running on Worker Node accesses the K8s API Server of EKS Cluster.

```yaml {caption="[File 1] kubelet kubeconfig", linenos=table}
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/eksctl/ca.crt
    server: https://B0678ED568FC12BBC37256BBA2A4BB53.yl4.ap-northeast-2.eks.amazonaws.com
  name: ssup2-eks-cluster.ap-northeast-2.eksctl.io
contexts:
- context:
    cluster: ssup2-eks-cluster.ap-northeast-2.eksctl.io
    user: kubelet@ssup2-eks-cluster.ap-northeast-2.eksctl.io
  name: kubelet@ssup2-eks-cluster.ap-northeast-2.eksctl.io
current-context: kubelet@ssup2-eks-cluster.ap-northeast-2.eksctl.io
kind: Config
preferences: {}
users:
- name: kubelet@ssup2-eks-cluster.ap-northeast-2.eksctl.io
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - eks
      - get-token
      - --cluster-name
      - ssup2-eks-cluster
      - --region
      - ap-northeast-2
      command: aws
      env:
      - name: AWS_STS_REGIONAL_ENDPOINTS
        value: regional
```

```yaml {caption="[File 2] kubectl kubeconfig", linenos=table}
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ...
    server: https://B0678ED568FC12BBC37256BBA2A4BB53.yl4.ap-northeast-2.eks.amazonaws.com
  name: ssup2-eks-cluster.ap-northeast-2.eksctl.io
contexts:
- context:
    cluster: ssup2-eks-cluster.ap-northeast-2.eksctl.io
    user: ssup2@ssup2-eks-cluster.ap-northeast-2.eksctl.io
  name: ssup2@ssup2-eks-cluster.ap-northeast-2.eksctl.io
current-context: ssup2@ssup2-eks-cluster.ap-northeast-2.eksctl.io
kind: Config
preferences: {}
users:
- name: ssup2@ssup2-eks-cluster.ap-northeast-2.eksctl.io
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - eks
      - get-token
      - --cluster-name
      - ssup2-eks-cluster
      - --region
      - ap-northeast-2
      command: aws
      env:
      - name: AWS_STS_REGIONAL_ENDPOINTS
        value: regional
```

[File 1] shows kubelet's kubeconfig, and [File 2] shows kubectl's kubeconfig. Looking at the user section of both kubeconfigs, you can see that they execute the "aws eks get-token" command. The "aws eks get-token" command generates a **Presigned URL** of AWS STS's **GetCallerIdentity API** that identifies who the Identity (target) executing "aws eks get-token" is, and generates a Token by encoding the generated URL. Here, Identity refers to **AWS IAM's User/Role**.

Presigned URL literally means a pre-assigned URL. To call AWS STS's GetCallerIdentity API, Secrets such as AccessKey/SecretAccessKey are needed, but when calling GetCallerIdentity API using Presigned URL, it can be called without Secrets. The Presigned URL of GetCallerIdentity API delivered through Token is passed to AWS IAM Authenticator and used to identify who the Identity executing the "aws eks get-token" command is.

```shell {caption="[Shell 1] aws eks get-token Command Output"}
$ aws eks get-token --cluster-name ssup2-eks-cluster
{
	"kind": "ExecCredential",
	"apiVersion": "client.authentication.k8s.io/v1alpha1",
	"spec": {},
	"status": {
		"expirationTimestamp": "2022-04-26T17:46:42Z",
		"token": "k8s-aws-v1.aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFSNVFPRVpQVTRRWFg1SDRGJTJGMjAyMjA0MjYlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjIwNDI2VDE3MzI0MlomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTIxOGQ4MDQ5NTBlZGMxMWRlZmQ0OWMwYTFkNWZkYWNjMzI0Y2M4MzBmZDZmMDZkNTlhN2Q5NzUwMGZhM2U3Mzg"
	}
}
```

[Shell 1] shows the output result of the "aws eks get-token" command.

```shell {caption="[Shell 2] Decode Token"}
$ base64url decode aHR0cHM6Ly9zdHMuYXAtbm9ydGhlYXN0LTIuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFSNVFPRVpQVTRRWFg1SDRGJTJGMjAyMjA0MjYlMkZhcC1ub3J0aGVhc3QtMiUyRnN0cyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjIwNDI2VDE3MzI0MlomWC1BbXotRXhwaXJlcz02MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPTIxOGQ4MDQ5NTBlZGMxMWRlZmQ0OWMwYTFkNWZkYWNjMzI0Y2M4MzBmZDZmMDZkNTlhN2Q5NzUwMGZhM2U3Mzg
https://sts.ap-northeast-2.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAR5QOEZPU4QXX5H4F%2F20220426%2Fap-northeast-2%2Fsts%2Faws4_request&X-Amz-Date=20220426T173242Z&X-Amz-Expires=60&X-Amz-SignedHeaders=host%3Bx-k8s-aws-id&X-Amz-Signature=218d804950edc11defd49c0a1d5fdacc324cc830fd6f06d59a7d97500fa3e738
```

If you perform base64url decoding on the string after "k8s-aws-v1" in the token of [Shell 1], you can see the Presigned URL of GetCallerIdentity API as shown in [Shell 2].

```shell {caption="[Shell 3] Decode Token"}
$ curl -H "x-k8s-aws-id: ssup2-eks-cluster" "https://sts.ap-northeast-2.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAR5QOEZPU4QXX5H4F%2F20220426%2Fap-northeast-2%2Fsts%2Faws4_request&X-Amz-Date=20220426T173242Z&X-Amz-Expires=60&X-Amz-SignedHeaders=host%3Bx-k8s-aws-id&X-Amz-Signature=218d804950edc11defd49c0a1d5fdacc324cc830fd6f06d59a7d97500fa3e738"
<GetCallerIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
  <GetCallerIdentityResult>
    <Arn>arn:aws:iam::142021912854:user/ssup2</Arn>
    <UserId>DCDAJXZHJQB4JQK2FDWQ</UserId>
    <Account>142021912854</Account>
  </GetCallerIdentityResult>
  <ResponseMetadata>
    <RequestId>9bdb9ca4-65c5-4659-8ca0-0e0625d14c5d</RequestId>
  </ResponseMetadata>
</GetCallerIdentityResponse>
```

If you perform a Get request to the Presigned URL of GetCallerIdentity API with the "x-k8s-aws-id: Cluster name" Header, you can identify who the Identity executing the "aws eks get-token" command is. [Shell 3] shows an example of performing a Get request to the Presigned URL of GetCallerIdentity API obtained in [Shell 2]. You can see that the "ssup2" User executed the "aws eks get-token" command.

AWS IAM Authenticator is registered as an authentication Webhook Server in EKS Cluster's K8s API Server. Therefore, the Token generated by kubelet/kubectl through the "aws eks get-token" command is passed to AWS IAM Authenticator. AWS IAM Authenticator identifies the target executing the "aws eks get-token" command through the process of [Shell 2] and [Shell 3].

```yaml {caption="[File 3] aws-auth ConfigMap in kube-system Namespace", linenos=table}
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::132099418825:role/eksctl-ssup2-eks-cluster-nodegrou-NodeInstanceRole-1CR0AFVMLFHSE
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::132099418825:role/eksctl-ssup2-eks-cluster-nodegrou-NodeInstanceRole-1FLORRGQWIWD8
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: arn:aws:iam::142627221238:user/ssup2
      username: admin
      groups:
        - system:masters
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
...
```

After identifying the Identity executing the "aws eks get-token" command, AWS IAM Authenticator checks which User/Group of EKS Cluster the identified Identity is **Mapped** to. Then AWS IAM Authenticator passes the Mapped EKS Cluster's User/Group to EKS Cluster's K8s API Server.

The Mapping information between the Identity executing the "aws eks get-token" command and EKS Cluster's User/Group is stored in the **aws-auth** ConfigMap that exists in the kube-system Namespace. [File 3] shows an example of the "aws-auth" ConfigMap. The mapUsers item is used to Map AWS IAM Users executing the "aws eks get-token" command with EKS Cluster's User/Group, and the mapRoles item is used to Map AWS IAM Roles executing the "aws eks get-token" command with EKS Cluster's User/Group.

In [File 3], you can see that the ssup2 AWS IAM User is Mapped to EKS Cluster's admin User or system:masters Group. When creating Node Groups in EKS Cluster, AWS IAM Roles used by each Node Group are created, and Node Group's AWS IAM Roles can also be seen in the mapRoles item of [File 3].

## 2. References

* [https://faddom.com/accessing-an-amazon-eks-kubernetes-cluster/](https://faddom.com/accessing-an-amazon-eks-kubernetes-cluster/)
* [https://github.com/kubernetes-sigs/aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator)
* [https://m.blog.naver.com/alice_k106/221967218283](https://m.blog.naver.com/alice_k106/221967218283)
* [http://www.noobyard.com/article/p-ktxvpcyg-er.html](http://www.noobyard.com/article/p-ktxvpcyg-er.html)
* [https://github.com/saibotsivad/base64-url-cli](https://github.com/saibotsivad/base64-url-cli)
* [https://github.com/aws/aws-cli/blob/master/awscli/customizations/eks/get_token.py](https://github.com/aws/aws-cli/blob/master/awscli/customizations/eks/get_token.py)
* [https://github.com/boto/boto3/blob/master/docs/source/guide/s3-presigned-urls.rst](https://github.com/boto/boto3/blob/master/docs/source/guide/s3-presigned-urls.rst)

