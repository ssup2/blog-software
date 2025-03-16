---
title: Dagster Architecture on Kubernetes
draft: true
---

Dagster를 Kubernetes 위에서 동작시킬때의 Architecture를 분석한다.

## 1. Run Launcher, Executor

### 1.1. K8s Run Launcher + Multiprocess Executor

{{< figure caption="[Figure 1] Dagster K8s Run Launcher + Multiprocess Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

### 1.2. K8s Run Launcher + K8s Job Executor

{{< figure caption="[Figure 2] Dagster K8s Run Launcher + K8s Job Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

### 1.3. Celery K8s Run Launcher + Celery K8s Job Executor

{{< figure caption="[Figure 3] Dagster Celery K8s Run Launcher + Celery K8s Job Executor Architecture" src="images/dagster-architecture-k8scelery.png" width="1000px" >}}

## 2. 설정 전달

### 2.1. Database

### 2.2. 환경 변수

### 2.3. Retry Policy

## 3. 참조

* Dagster Run Launcher: [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor: [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)
