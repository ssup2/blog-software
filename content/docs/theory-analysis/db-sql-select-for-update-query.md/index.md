---
title: DB SQL `SELECT FOR UPDATE` Query
---

SQL `SELECT FOR UPDATE` Query를 분석한다.

## 1. `SELECT FOR UPDATE` Query

`SELECT FOR UPDATE` Query는 SELECT 수행 시 Exclusive (Write) Row Lock을 획득한 뒤 읽기 연산을 수행하는 Query로, 획득한 Lock은 Transaction이 종료될 때까지 유지된다. 이는 일반 `SELECT` Query가 Lock 없이 MVCC Snapshot을 읽는 것과 대비된다.

MySQL InnoDB와 같이 MVCC (Multi-Version Concurrency Control) 기반으로 동작하는 DB 환경에서, 일반 `SELECT` Query는 Lock을 획득하지 않고 Transaction 시작 시점의 Snapshot을 읽는 Consistent Read (Snapshot Read) 방식으로 동작한다. 따라서 다른 Transaction이 해당 Row에 대해 Exclusive Row Lock을 보유하고 있더라도 일반 `SELECT` Query는 대기 없이 Snapshot 데이터를 읽을 수 있다.

반면 `SELECT FOR UPDATE` Query는 Exclusive Row Lock 획득을 시도하기 때문에, 다른 Transaction이 해당 Row의 Exclusive Row Lock 또는 Shared Row Lock을 보유하고 있는 경우 그 Lock이 해제될 때까지 대기한 뒤 읽기 동작을 수행한다. 또한 Lock 획득 이후에는 Snapshot이 아닌 현재 커밋된 최신 데이터를 읽는 Current Read 방식으로 동작하며, 해당 Transaction이 종료되기 전까지 획득한 Exclusive Row Lock을 해제하지 않기 때문에 다른 Transaction에서 해당 Row들을 갱신할 수 없다. 따라서 `SELECT FOR UPDATE` Query는 다수의 Transaction 수행 사이에서도 정합성이 보장된 Data를 얻어야 할 경우에 이용한다.

DB의 종류 및 Isolation Level에 따라서 `SELECT FOR UPDATE` Query가 불필요하며 `SELECT` Query만 이용해도 되는 경우가 있다. 예를 들어 MySQL의 가장 높은 Isolation Level인 Serializable을 이용한다면 모든 일반 `SELECT` Query에 Shared Row Lock이 자동으로 부여된다. Shared Lock은 다른 Transaction의 Exclusive Lock 획득을 차단하기 때문에, 읽는 동안 해당 Row가 다른 Transaction에 의해 갱신되는 것을 막을 수 있어 정합성이 보장된 Data를 읽을 수 있다. 하지만 이 경우 DB의 종류 및 Isolation Level에 대한 의존성이 발생하기 때문에, 어느 환경에서도 정합성이 보장된 Data를 얻어야 할 경우에는 `SELECT FOR UPDATE` Query를 명시적으로 이용하는 것이 좋다.

## 2. 참조

* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation)
* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation)
