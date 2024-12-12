---
title: USE Method, RED Method
draft: true
---

모니터링 방법론인 Use Method와 Red Method를 살펴본다.

## 1. USE Method

USE Method는 **Utilization**, **Saturation**, **Errors** 3가지를 기반으로 모니터링을 수행하는 방법론을 의미하며, 일반적으로 **Hardware** 장애 탐지에 적합한 방법론이다.

* Utilization : 자원이 이용되는 평균 시간
* Saturation : 자원이 포화되어 처리되지 못한 작업의 정도
* Errors : 오류 또는 장애 횟수

## 2. RED Method

RED Method는 **Rate**, **Errors**, **Duration** 3가지를 기반으로 모니터링을 수행하는 방법론을 의미하며, 일반적으로 **Service (Application)** 관련 장애 탐지에 적합한 방법론이다.

* Rate : 초당 요청 수
* Errors : 요청 처리에 실패한 횟수
* Duration : 요청 처리시간

## 3. 활용

일반적으로 USE Method와 RED Method를 같이 활용하는 방법을 권장한다. Monitoring Dashboard 구성시 Hardward와 연관된 Dashboard에는 USE Method를 기반으로 구성하며, Service와 관련된 Dashboard에는 RED Method를 기반으로 구성을 통해서 두 Method를 모두 활용할 수 있다.

## 4. 참조

* [https://www.pusnow.com/note/use-method-and-red-method/](https://www.pusnow.com/note/use-method-and-red-method/)
* [https://pagertree.com/learn/devops/what-is-observability/use-and-red-method](https://pagertree.com/learn/devops/what-is-observability/use-and-red-method)