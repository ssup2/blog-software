---
title: Financial IT System
---

## 1. Financial IT System

{{< figure caption="[Figure 1] Financial IT System" src="images/financial-it-system.png" width="800px" >}}

[Figure 1] shows the general components of a Financial IT System.

### 1.1. Channel System

The Channel System refers to the system that manages the various channels through which users access the system. It is responsible for the means of access for banking/stock trading, such as mobile banking and internet banking. It also plays the role of visualizing the data of the Account System and delivering it to users when needed. It performs a role similar to the Web Server in a 3-Tier architecture. It is generally placed in the DMZ zone and separated from internal systems.

### 1.2. Account System

The Account System refers to the system that provides core financial services such as banking and securities services. Therefore, a failure directly leads to monetary damage, and it is the system that directly accesses customer data. Because of these characteristics, it has the most conservative tendency. It performs a role similar to the Backend Server in a 3-Tier architecture.

### 1.3. Information System

The Information System refers to the system that collects data generated from the Account System and provides an analysis environment. It generally consists of **ODS**, **EDW**, and **Data Mart**.

* **ODS** (Operational Data Store) : Plays the role of copying data from the core system and storing it temporarily. Since the EDW directly accessing the Account System to collect data can affect the Account System, the ODS minimizes the Side-Effects that can occur on the Account System. Data is stored in a form optimized for the EDW, and it is generally designed to contain Low Level or Atomic data such as **transaction history**.
* **EDW** (Enterprise Data Warehouse) : Refers to a data store that stores data in a form optimized for data analysis based on the data stored in the ODS.
* **Data Mart** : Refers to a separate data store that organizes EDW data by subject/Domain to improve the speed and convenience of data analysis. Generally, a separate Data Mart is composed for each subject/Domain.

### 1.4. External System

Refers to the system that handles work linked with external organizations. It handles tasks such as **interbank transfers** and **stock orders**. It is placed in the DMZ zone together with the Channel System and separated from internal systems.

### 1.5. Operational System

Responsible for system operation. It performs tasks such as integrated control, monitoring, and maintenance.

### 1.6. Legacy System

Refers to the past system before a new system is introduced.

## 2. References

* 금융권 IT시스템에 대한 이해 : [https://12bme.tistory.com/237](https://12bme.tistory.com/237)
* 기간계, 정보계, ODS, EDW, Data Mart, OLAP : [https://spidyweb.tistory.com/218](https://spidyweb.tistory.com/218)
* 기초적인 금융IT 시스템 구조와 용어 : [https://velog.io/@chokye/%EA%B8%88%EC%9C%B5IT-%EA%B8%B0%EC%B4%88%EC%A0%81%EC%9D%B8-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%A1%B0](https://velog.io/@chokye/%EA%B8%88%EC%9C%B5IT-%EA%B8%B0%EC%B4%88%EC%A0%81%EC%9D%B8-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%A1%B0)