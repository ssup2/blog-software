---
title: 2. Linux Container
---

## Linux Container 구성 요소

{{< figure caption="[Figure 1] Container를 구성하는데 이용되는 Linux Kernel의 기능들" src="images/linux-kernel-features-for-container.png" width="500px" >}}

Container는 Linux Kernel의 다양한 기능을 조합하여 구성된다. [Figure 1]은 Container를 구성하는데 이용되는 Linux Kernel의 기능들을 주제별로 분류한 그림이다. Container의 기본적인 특징 중 하나는 Container 사이의 격리이다. 하나의 Host에 2개의 Container가 구동 된다고 했을때 각 Container는 서로의 존재를 알지 못한다. 이러한 특징을 격리라고 표현하며 Namespace라고 불리는 기능을 통해서 구현된다.

Namespace는 Container들이 서로의 존재를 알지 못하게 막을수는 있지만, Container의 Resource의 사용량까지는 제어하지 못한다. 각 Container가 이용할 수 있는 Resource를 제한하는 동작은 Cgroup이라고 불리는 기능을 통해서 구현한다. Cgroup은 또한 각 Container의 Resource 사용률을 측정해주는 Monitoring 기능도 수행한다. Image는 Container안의 App의 구동에 필요한 파일의 집합을 의미한다. Image는 일반적으로 특수 File System인 AUFS, OverlayFS을 이용해서 Container안의 App이 이용할 수 있도록 구성한다.

Security는 Container안의 App의 동작을 제한하는 방법을 의미한다. Security는 기존 Linux에서 App (Process)의 동작을 제한할때 많이 이용되던 Linux의 capability, seccomp, LSM (Linux Security Module) 기능을 그대로 이용한다. 본 글에서는 [Figure 1]에 나열한 Linux Kernel의 기능들을 하나씩 소개하여 Container의 이해를 돕도록 구성되어 있다.