---
title: 3.5. Namespace의 한계점
---

## Namespace의 한계점

지금까지 PID, Network, Mount Namespace에 대해서 알아보았다. 이러한 Namespace들을 통해서 각 Container는 높은 수준의 격리된 환경에서 동작 가능하다. 하지만 현재까지 Namespace는 완전한 격리 환경을 제공하지는 못한다. 예를들어 Linux Kernel의 Network Stack 관련 몇몇 설정들은 모든 Network Namespace에서 공유되어 이용된다.

conntrack은 Linux에서 Network Connection을 관리하는 Module이다. conntrack이 관리할 수 있는 최대 Connection 개수는 "/proc/sys/net/netfilter/nf-conntrack-max" 파일에서 확인할 수 있으며, Host Network Namespace에서는 "/proc/sys/net/netfilter/nf-conntrack-max" 파일에 숫자를 써서 conntrack의 최대 Connection 개수를 설정할 수 있다. 나머지 Network Namespace에서는 Host Network Namespace에서 설정한 conntrack의 최대 Connection 개수를 그대로 노출한다.

```console {caption="[Shell 1] conntrack의 최대 Connection 개수 변경", linenos=table}
# netshoot Container 생성
(host)# docker run -d --rm --name netshoot nicolaka/netshoot sleep infinity

# Host에서 conntrack의 최대 Connection의 개수 확인
(host)# cat /proc/sys/net/netfilter/nf-conntrack-max
131072

# netshoot Container에서 conntrack의 최대 Connection의 개수 확인
(netshoot)# docker exec -it netshoot cat /proc/sys/net/netfilter/nf-conntrack-max
131072

# Host에서 conntrack의 최대 Connection의 개수 변경 및 확인
(host)# echo 200000 > /proc/sys/net/netfilter/nf-conntrack-max
(host)# cat /proc/sys/net/netfilter/nf-conntrack-max
200000

# netshoot Container에서 변경된 conntrack의 최대 Connection의 개수 확인
(netshoot)# docker exec -it netshoot cat /proc/sys/net/netfilter/nf-conntrack-max
200000
```

[Shell 1]은 Host에서 conntrack의 최대 Connection 개수를 확인 및 변경한 다음, netshoot Container에서도 conntrack의 최대 Connection 개수를 확인하는 과정을 나타내고 있다. Host에서 변경한 conntrack의 최대 Connection 개수가 netshoot Container에서도 동일하게 보이는것을 확인할 수 있다. 

중요한 점은 Host와 Container의 모든 Connection의 개수의 합이 conntrack의 최대 Connection 개수 설정 값을 초과할 수 없다는 점이다. 즉 conntrack의 최대 Connection 개수가 100개로 설정되어 있을때 Host에서 100개의 Connection을 맺고 있다면, Host에서 뿐만 아니라 나머지 Container들에서도 더이상 Connection을 추가로 생성할 수 없다는 의미이다. 이처럼 Network Namespace는 각 Network Namespace별로 Network Connection도 격리하여 별도로 관리해 줄거라 생각되지만, 실제로는 격리하여 별도로 관리하지 않는다.

예시로든 conntrack의 최대 Connection 개수뿐만 아니라 많은 Linux Kernel 관련 설정들이 Namespace에 의해서 격리되어 관리되지 않는다. 이처럼 Namespace에 의해서 격리되지 않는 Linux Kernel 관련 설정들은 App의 동작을 확인하는 개발 환경에서는 큰 문제가 되지는 않겠지만, 실제 사용자에게 Service를 제공하는 Container 기반의 Production 환경에서는 다수의 Container로 인해서 문제가 될 수 있다. 따라서 개발 환경에서 발생하지 않는 문제가 Container 기반의 Production 환경에서 발생한다면, 문제의 발생 원인이 Namespace에 의해서 격리되지 않아 발생하는건지 검토하는 과정이 필요하다.
