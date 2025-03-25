---
title: Dagster Architecture, Object
draft: true
---

## 1. Dagster Architecture, Object

{{< figure caption="[Figure 1] Dagster Architecture" src="images/dagster-architecture.png" width="1000px" >}}

[Figure 1]은 Dagster Architecture를 나타내고 있다. Dagster Architecture는 크게 Workflow를 제어하는 **Control Plane**과 실제 Workflow가 동작하는 **Data Plane**으로 구분지을 수 있다. Control Plane에는 Web Server (Dagit), Daemon, Code Location, Run이 존재하며, Data Plane에는 Workflow 및 Workflow 동작에 필요한 I/O Manager 및 External Resource로 구성되어 있다.

Dagster는 다양한 Type의 **Object**를 제공하며, User는 이러한 Object들을 조합하여 Workflow를 구성할 수 있다. Workflow에 이용되는 모든 Dagster Object들은 Control Plane의 Code Location에 모두 정의되어 활용된다.

### 1.1. Dagster Object

Dagster에서는 다양한 Type의 Object들이 존재하지만 대표적인 Object들은 다음과 같다.

#### 1.1.1. Op

Op는 Workflow에서 실행되는 가장 작은 단위의 Action을 의미한다. 이러한 Op들을 조합하여 Workflow를 구성할 수 있다.

#### 1.1.2. Asset

Asset은 Dagster에서 생성되는 Data를 의미한다. 

#### 1.1.3. Job

#### 1.1.4. Run

#### 1.1.5. I/O Manager

#### 1.1.6. Sensor

#### 1.1.7. Schedule

### 1.2. Control Plane

#### 1.2.1. Web Server (Dagit)

Dagster는 Dagit이라는 이름의 Web Server를 제공하여 Dagster를 **Web 기반의 UI**를 통해서 제어할 수 있는 환경을 제공한다. 또한 Dagster의 상태를 제어하고 조회할 수 있는 **GraphQL API**를 제공하는 역활도 수행한다.

#### 1.2.2. Code Location

Code Location은 Dagster에서 실행되는 **Workflow가 정의**되어 있는 위치를 의미한다. 따라서 Workflow 구성에 필요한 모든 Dagster Resource가 Code Location에 정의되어 있다. Daster에는 다양한 Resource Type들이 존재하지만 대표적인 Resource Type들은 다음과 같다.

#### 1.2.3. Daemon

#### 1.2.4. Run

### 1.3. Data Plane

#### 1.3.1. Op

#### 1.2.2. Asset

#### 1.2.3. I/O Manager

## 2. 참조

* Dagster Architecture : [https://docs.dagster.io/guides/deploy/oss-deployment-architecture](https://docs.dagster.io/guides/deploy/oss-deployment-architecture)
* Dagster Concepts : [https://docs.dagster.io/getting-started/concepts](https://docs.dagster.io/getting-started/concepts)
