---
title: Kubernetes kubeconfig
---

This post analyzes the kubeconfig of Kubernetes.

## 1. Kubernetes kubeconfig

{{< figure caption="[Figure 1] Kubernetes kubeconfig" src="images/kubeconfig.png" width="800px" >}}

**kubeconfig** is the configuration file used by the `kubectl` command, the Client of Kubernetes. It contains the connection information of the Kubernetes API Server that the `kubectl` command needs to access, and the authentication and authorization information used by the `kubectl` command. kubeconfig has a yaml format and largely consists of three items: `clusters`, `users`, and `contexts`. kubeconfig can be configured through the `kubectl config` command. [Figure 1] shows a diagram of kubeconfig.

The `clusters` item of kubeconfig stores the information of multiple Clusters. The Cluster information stores the name of the Cluster, the access path of the Cluster's API Server, and the Base64-encoded CA (Certificate Authority) certificate information used by the Cluster. The `users` item of kubeconfig stores the information of multiple Users. The User information stores the name of the User, the Base64-encoded Public certificate of the User, and the Base64-encoded Private Key of the User. Based on the information of the User's Public certificate, Kubernetes performs authentication and authorization.

The `contexts` of kubeconfig consists of an array of Context names and information. Here, a Context means a combination of a Cluster and a User. In [Figure 1], Context-A means the state where User-A uses Cluster-A. Similarly, in [Figure 1], Context-C means the state where User-C uses Cluster-B. The `current-context` item of kubeconfig means the Context currently in use. In [Figure 1], it can be seen that Context-B is specified in the `current-context` item. Therefore, if `kubectl` uses the kubeconfig of [Figure 1], `kubectl` connects to the Cluster-B Cluster as the User-B User and performs Client operations.

### 1.1. Example

```yaml {caption="[File 1] Admin kubeconfig", linenos=table}
apiVersion: v1
kind: Config
current-context: kubernetes-admin@kubernetes
preferences: {}
contexts:
- name: kubernetes-admin@kubernetes
  context:
    cluster: kubernetes
    user: kubernetes-admin
clusters:
- name: kubernetes
  cluster:
    server: https://192.168.0.61:6443
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01Ea3hNREUxTVRJeE5Gb1hEVE13TURrd09ERTFNVEl4TkZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTXNBCmhMaVcvNm43RmNwSmdDUmExSHBIaGIzY1NMNC9UWnBQcjYzcXZ3OC9DRG1Wd0dUTlZheXBIYkt4dmV1dGg5UFkKaGdpT3JtTHlaVG1SSTZ3VlhnSzdVMmtHQmgyKzR2YTVDWlViV0s2TGNZcEQxTW1weGhyd1VLR0JURms3eEVaZQprQ0U1VEhwWUpZZXprNG0vVVpTR2ViaG1saHQweXk2QjZTWStJeTlFM0EySkczOHEvRzZnLzFlMzNyajQvcDN6CmRnbXJ5cUZEUGQrbWlFeEFHN3pUSjV4Slo4Q2I4WldtWU9RQmp1eTlnNFFOSDYvVmRxd1lnNVI4eWhzV1dRY2cKczlndVlpSXNaRVFhc053d2lwOUFnR2xVcWNSbVBjbDh2b21rVjRFc01zRUhXb1k3SDVTWGNEL2lDSFh2eW9vKwpOU25NSGdSRmlNczc0NHA5QkxrQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFCNHVPL1FCM05KNTJhSTJFdlQ3YjNxVkVaUGsKaGpsTHZkNmdKZlhTdXJWZEV6M2hXVFp4S0RVa24wSDVaTUlLS1hlb1BFak1UcEJFNTFzV3NRZUx0QlBzSFNxOApVQkpJbUZwcmgwZVhjdC9vdStHUFpkbHZJTlFWdkg0NTRONTBvZzhTbTk0K09pdUlRSUlOWEVMcWVCWStWZ0h3CnIyT3JsZGQxQWtBZ3dyWG9ucmJzVnRVa2d0bzlTT2ZlellpeS9oU2NmVWlpRkF4S2t4eTVrWG5CamhkaVNvRnQKV1YrQ0M2REhSRU9uVU9wRU5BYWQvMHNOdmJKbEVVUmxQancrNUFGaEptSkpRK1NhckFleVZIdWkyQ0F3ak1WdQpKa1IycVllZjQ2VDRiQzlnNmMyd2J3SUZVUlIrVGlya3JqRjU2UjZLM3E0aGJ3R1FQdkNtOG1DRDZSTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM4akNDQWRxZ0F3SUJBZ0lJUzd0V1UwMWtvSWd3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TURBNU1UQXhOVEV5TVRSYUZ3MHlNVEE1TVRBeE5URXlNVFZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQW9YRGpXT0RnanRQMFd5dEoKbjFjOW1aK2RlaFdJck9IcEFkaVB1VVNRdVpyUkgxNlJud2xTQ0xoK3lRRUZiKzlJdFJuRFlvUGU0THAydUNFMgpSUStsaTF5emN6Yi9idkxHT2Y3dTI3ZE1BYTVNQmpreTcyaTZrSStaR0oxeDBvRXhXU29xTUdrWTB4dUFGeFNVCmUyQm1YTkFLV3FDS0grSVhDVnN6T2ZUZ2grUjBXZ0tJeTRDZFppcVNrY05HZHRHdUwxRW1wU1dUYlkxNG0yZWcKaW9HTDFHb3pOd2FWYW8zT1psMGE3TUJkSER4YWVTQlprRlhXRWlVZ1ZzMmpCa2pzaTFNNVdXL2t5R3dvY09zWQpCSWdKR2ExY2dEalZGK1M0aVFhdEpaM2lld3dnbFFnRGtwVTlwM2JtSHkwUHp5bTRBWVo5aXNubUFKZXdXQ3cwCkZ6cHViUUlEQVFBQm95Y3dKVEFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFFQ3kyeitjbm1mcnFsQmU2c1k4UCtsd1ZYMTdKNitWVjEzSApFdjl3NmNEK3FSYjNUQTMxSzFoQ1JsNG9pUzdxblpvdjZ5U3BhblN4cHRkdCtBVWpleW5RSkFoWkJwaFRnSkVYCkZIM01pVjQ0Zkd3MFNHQ3N6dUJCMWVWeWY4cFNSbjVSMk1ZVEdxQkdmTFpERThJN09oV3JBSkxZaTR6YjM4cWgKQ2hYNTZzUW1iYUxKNEpqd000dG1aNmhLM2NZR29uZkNrLzg2NHdMRnN4T3BzaDBwWFM1SUZ0ZjV0WFZnZWxINAowbDVxTlhzWDc1VXE2cm44NWc1alRPZjhnek5DekRNSmVsSk8rMUZoWHBIc3dxcW9GZ3g3dnVnamVlZEpuK1BMClQ0N0gzajAyNU5xMDBJS21qanZqMHljR2x5ZklIaGNaT2RVdDdMcEdwYllDc0lRRmp3Yz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBb1hEaldPRGdqdFAwV3l0Sm4xYzltWitkZWhXSXJPSHBBZGlQdVVTUXVaclJIMTZSCm53bFNDTGgreVFFRmIrOUl0Um5EWW9QZTRMcDJ1Q0UyUlErbGkxeXpjemIvYnZMR09mN3UyN2RNQWE1TUJqa3kKNzJpNmtJK1pHSjF4MG9FeFdTb3FNR2tZMHh1QUZ4U1VlMkJtWE5BS1dxQ0tIK0lYQ1Zzek9mVGdoK1IwV2dLSQp5NENkWmlxU2tjTkdkdEd1TDFFbXBTV1RiWTE0bTJlZ2lvR0wxR296TndhVmFvM09abDBhN01CZEhEeGFlU0JaCmtGWFdFaVVnVnMyakJranNpMU01V1cva3lHd29jT3NZQklnSkdhMWNnRGpWRitTNGlRYXRKWjNpZXd3Z2xRZ0QKa3BVOXAzYm1IeTBQenltNEFZWjlpc25tQUpld1dDdzBGenB1YlFJREFRQUJBb0lCQUJOQmpNeUlIaURMSlVWTwpsM3g3QW16MWZlb1c4WE4xaXI1ZW4xNEEwS1ppMGZqRTVlZXJTKzZnV3ZjTXVTSk56MFZTcWx4dzBEL0wzZWMrCmh1T2I1eW9GUjU1QmZCdzJ0dkFwK1VHWnptWVE3UjU4NmhkbVRZSjZyazhpVUhaRVZLZUhBUHMvUGVmSVN2SDEKMFhRWjNudkprTUtZallFYURaZGZHbkFhUmtIUERJL1k5T21HcmdnTnBhZUJxdkQrN29wdDArZEFrbWNncmVJZgpGNm5yY0RsanRqeGo4WHluSGNoaTIzdXFDMUVPVVRXQ3BFUWt1aittbjhKQXd1eitQN3Ira1FjcFFxNTlxU3RJCnZFUmlHTnFKNzVZcXNGRHpzQUNMK3RhbjFBelNuUkRkTXFsLzYwbTRzUmd2STRmOFF4ZlNHZGl4SU1PTmdrMkUKZHJkODU5MENnWUVBMGd1VWR1c1VtaCsrUmVxQm5ROU1TclBXMGtBQnN3eC84a1ZrK3VKOUpaY2wyYS8rNXlJNgp2T0VxMFROSS9MVWtHUWVzOFltT1VoSmh4RWp4dW1tWlZQY1ljUm1iRkNjeGFsNGdLR0h5WmJ6VmpwUUc2b3g3CkVnekdwQTNjeStLRlhabC9sa2lLeGZxaWNlalNiZE1BWXB3L1FCZ0pGYi9nQnNWMnUzdjJmZWNDZ1lFQXhNTUkKVzkrMi9YUlpEWEZHZm5MUzJ3RSsrak9LMmQ4ekp6VE5zdUwyV0dSZkhqY21KRG15Mkd3T2tCNDMyQWd6SWszcwpRZ3RscmwweldTUzd6d0tnMU0vYkoyMWdPN0hqTnhWUlNhaVpNelZ6NGZZMUMxYVdsV3BXUW5MT3lYdW5GclRhCkJVRlBnblliVkVEVGZJUVR2OVBkb28wM0h3WmgzVWg1WnNybEhvc0NnWUVBeEp6MlVnSm0vSVl1TTMvNTU2ekUKTzBEd0cwcXl6SWtzMHZsR050bi9UMHFXc1poZXdMaDN4d24yYkhEWEowWGdEbFh5K3YxSjdXVXJndkxNNHpPcAp4YkN1ZmwvN20vZTc5OWMzdnRWQWN4ODV3QWFzR3ExNUhrSTdScUY3UnBZNVJJNUVzY1loc0lTVnZvNnpPdjVCCjVBeGg0SHNmTmU2dm8yYi9aeXY0WlkwQ2dZRUF1QzlwajdjbmNMS00rZ3hqVk5MZmxxcmY3UTU2bCtCYjNnT0wKMmp5akpiTXZadlZ3K3RBWUhvZG9TbmcvQmpjR3hzSHl1eEE0S3JTTDhKSjJUQjNGdC9DcTBZbU5YOVB4UWdydQpnT2tXSDkyVmtKd01vNFIyaVg5MUo5YVl3L3JBT24wbzZXcHRwMDR2M3ZxZi9oc1U4YWk5Ky8vODdVbm9LbUJCClpIdmhabWtDZ1lFQXQzejhLSzVzTXJaNHdObEJ3WElqa0dzYlYxWDZya3o1aWxpTWU0Sk1MV3UyYVYwSzF3MGgKajBUbzRaTXJYYWRha2ZDUGg3UGV1SzlYVEk2TEJTNkFKOXJEaGZ5bEg4NFN0eWFOYWkzN0V5YjFwTDJWUGV0SAorVFFPOVhtR0NWNzc0RlpUR2gzSm1qalQ1QUpGbXJrYmtvUkU5TUJnKzE1eU44L0VaWjRPV3Q4PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
```

[File 1] shows the actual kubeconfig file that `kubeadm` generates for the Admin of the Cluster when the Cluster is configured with the `kubeadm` command. In [File 1], the Cluster information named `kubernetes` is stored in the `clusters` item. `server` stores the connection information of the API Server of the `kubernetes` Cluster, and `certificate-authority-data` stores the CA (Certificate Authority) certificate information used by the `kubernetes` Cluster, encoded in Base64. Looking at the CA certificate information of the `kubernetes` Cluster, the string `kubernetes`, the name of the Cluster, is stored in the Common Name field.

In [File 1], the information of the User named `kubernetes-admin` is stored in the `users` item. `client-certificate-data` stores the Base64-encoded Public certificate of the `kubernetes-admin` User, and `client-key-data` stores the Base64-encoded Private Key of the `kubernetes-admin` User. Looking at the Public certificate information of the `kubernetes-admin` User, the string `kubernetes-admin`, the name of the User, is stored in the Common Name field, and the string `system:masters` is stored in the Organization field. `system:masters` means the Group to which the `kubernetes-admin` User belongs.

```yaml {caption="[File 2] cluster-admin ClusterRoleBinding", linenos=table}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:masters
```

[File 2] shows the ClusterRoleBinding named `cluster-admin` applied to the Cluster. The ClusterRole named `cluster-admin` is a Role that has permissions for all APIs. It can be seen that the target to which the `cluster-admin` ClusterRole is applied (bound) is the Group named `system:masters`. Therefore, since the `kubernetes-admin` User belongs to the `system:masters` Group, it has permissions for all APIs.

In [File 1], the Context information named `kubernetes-admin@kubernetes` is stored in the `contexts` item. The `kubernetes-admin@kubernetes` Context means that the `kubernetes-admin` User uses the `kubernetes` Cluster. It can be seen that the `kubernetes-admin@kubernetes` Context is specified in the `current-context` item. This means that the `kubectl` command currently connects to the Cluster named `kubernetes` as the User named `kubernetes-admin`.

## 2. References

* Organizing Cluster Access Using kubeconfig Files : [https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
