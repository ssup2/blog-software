---
title: 금융 IT 시스템
---

## 1. 금융 IT 시스템

{{< figure caption="[Figure 1] Financial It 시스템" src="images/financial-it-system.png" width="800px" >}}

[Figure 1]은 금율 IT 시스템의 일반적인 구성요소를 나타내고 있다.

### 1.1. Channel 시스템 (채널계)

Channel 시스템은 사용자가 시스템에 접속하는 다양한 채널을 관리하는 시스템을 의미한다. 모바일 뱅킹, 인터넷 뱅킹등 은행/주식 거래를 위해서 접근하는 수단을 담당한다. 또한 필요에 따라서는 Account 시스템의 데이터를 시각화하여 사용자에게 전달하는 역할도 수행한다. 3-Tier 아키텍처의 Web Server 역할과 유사한 역할을 수행한다. 일반적으로 DMZ 구간에 구성되어 내부 시스템과 분리된다.

### 1.2. Account 시스템 (계정계)

Account 시스템은 은행, 증권 서비스와 같은 핵심 금융 서비스를 제공하는 시스템을 의미한다. 따라서 장애시 금전적 피해로 직결되며, 고객의 데이터를 직접 접근하는 시스템이다. 이러한 특징 때문에 가장 보수적인 성향을 갖는다. 3-Tier 아키텍처의 Backend Server와 유사한 역할을 수행한다.

### 1.3. Information 시스템 (정보계)

계정계로부터 발생한 데이터를 수집하여 분석 환경을 제공하는 시스템을 의미한다. 일반적으로 **ODS**, **EDW**, **데이터 Mart**로 구성되어 있다.

* ODS (Operational 데이터 Store) : 기간계의 데이터를 복사하여 임시로 저장하는 역할을 수행한다. EDW가 직접 계정계의 시스템에 접근하여 데이터를 수집 하면 계정계에 영향을 줄 수 있기 때문에, ODS를 통해서 계정계에서 발생할 수 있는 Side-Effect를 최소한다. EDW에 최적화되어 데이터가 저장되며, 일반적으로 **거래 내역**과 같이 Low Level 또는 Atomic 데이터 를 포함하도록 설계된다.
* EDW (Enterprise 데이터 Warehouse) : ODS에 저장된 데이터를 기반으로 데이터 분석에 최적화된 형태로 데이터를 저장하는 데이터 저장소를 의미한다.
* 데이터 Mart : 데이터 분석의 속도와 편의성을 높이기 위해서 EDW의 데이터를 주제/Domain 별로 구성한 별도의 데이터 저장소를 의미한다. 일반적으로 각 주제/Domain 마다 별도의 데이터 Mart를 구성한다.

### 1.4. External 시스템 (대외계)

외부 기관과 연계 업무를 처리하는 시스템을 의미한다. **타행 이체**, **주식 주문**과 같은 업무를 처리한다. 채널계와 함께 DMZ 구간에 구성되어, 내부 시스템과 분리된다.

### 1.5. Operational 시스템 (운영계)

시스템 운영을 담당한다. 통합 관제, 모니터링, 유지보수 등의 업무를 수행한다.

### 1.6. Legacy 시스템 (기간계)

새로운 시스템 도입 전에 과거의 시스템을 지칭한다.

## 2. 참조

* [https://12bme.tistory.com/237](https://12bme.tistory.com/237)
* [https://spidyweb.tistory.com/218](https://spidyweb.tistory.com/218)
* [https://velog.io/@chokye/%EA%B8%88%EC%9C%B5IT-%EA%B8%B0%EC%B4%88%EC%A0%81%EC%9D%B8-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%A1%B0](https://velog.io/@chokye/%EA%B8%88%EC%9C%B5IT-%EA%B8%B0%EC%B4%88%EC%A0%81%EC%9D%B8-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%A1%B0)