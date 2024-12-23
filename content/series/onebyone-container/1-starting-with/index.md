---
title: 1. 시작하며
---

## 시작하며

Cloud 환경이 보편화 되면서 Container는 Software에 종사하고 있는 사람들에게 필수 기술로 자리잡고 있다. DevOps Engineer라면 Container는 반드시 익혀야 하는 기술이 되었다. Software Developer라도 어느 정도는 Container를 다룰 필요가 있는 환경으로 바뀌고 있다. Container를 처음 접하는 사람은 Docker를 이용하여 간편하게 Container를 이용할 수 있다. 하지만 단순히 Docker를 이용한 경험만으로는 Container를 깊게 이해하기는 쉽지 않다. Container는 Linux Kernel의 다양한 기능의 조합으로 구성되는데, 구성하고 있는 기능의 개수도 많고 각 기능은 대부분 Linux Kernel의 심화 기능이기 때문에 Linux를 잘 모르는 사람이 이해하기 쉽지 않기 때문이다.

본 글은 Container를 구성하는 Linux Kernel 기능들을 하나씩 소개하는 방식으로 Container의 이해를 돕도록 구성되어 있다. 기본적인 Container 설명이 끝나면 대표적인 Container 관리 도구인 Docker와 Container Orchestrator로 많이 이용되고 있는 Kubernetes 분석을 통해서 Container가 어떻게 실제로 응용되어 이용되고 있는지 소개한다. 마지막으로는 Container와 많이 비교되는 VM과의 비교를 통해서 Container의 장단점을 파악할 수 있도록 구성하였다. 모든 과정은 실습을 통해서 직접 눈으로 확인할 수 있도록 하여 독자들이 Container를 몸으로 익힐 수 있게 구성하였다.