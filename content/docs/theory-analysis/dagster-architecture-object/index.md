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

```python {caption="[Code 1] Op Example", linenos=table}
@op(description="Generate a list of numbers from 1 to 10")
def generate_numbers():
    return list(range(1, 11))

@op(description="Filter even numbers from the list")
def filter_even_numbers(numbers):
    return [num for num in numbers if num % 2 == 0]

@op(description="Filter odd numbers from the list")
def filter_odd_numbers(numbers):
    return [num for num in numbers if num % 2 != 0]

@op(description="Calculate the sum of the given list of even numbers")
def sum_even_numbers(numbers):
    return sum(numbers)

@op(description="Calculate the sum of the given list of odd numbers")
def sum_odd_numbers(numbers):
    return sum(numbers)

@op(description="Sum two numbers")
def sum_two_numbers(first_number, second_number):
    return first_number + second_number
```

Op는 Workflow에서 실행되는 가장 작은 단위의 Action을 의미한다. 이러한 Op들을 조합하여 Workflow를 구성할 수 있다. Airflow를 기준으로 하나의 Task가 Dagster에서는 Op에 해당한다. [Code 1]은 Op의 예제를 나타내고 있다. `generate_numbers()`, `filter_even_numbers()`, `filter_odd_numbers()`, `sum_even_numbers()`, `sum_odd_numbers()`, `sum_two_numbers()` 6개의 Action 함수가 정의되어 있고, `Op` Decorator를 통해 Op인것을 명시한다.

Dagster에서는 Action 위주의 Workflow를 구성하는것 보다 Data 중심의 Workflow를 구성을 권장하기 때문에 Op보다는 다음에 소개할 Asset을 중심으로 Workflow 구성을 권장한다. 따라서 Op는 Slack 알림/e-mail 알림과 같이 Asset으로 간주하기 어려운 Action들 또는 하나의 Asset 내부에서 너무 많은 Action이 필요할때 Action을 쪼개는 용도로 활용된다.

#### 1.1.2. Asset

```python {caption="[Code 2] Asset Example", linenos=table}
@asset(description="Generated a list of numbers from 1 to 10")
def generated_numbers():
    return list(range(1, 11))

@asset(description="Filtered even numbers from the list")
def filtered_even_numbers(generated_numbers):
    return [num for num in generated_numbers if num % 2 == 0]

@asset(description="Filter odd numbers from the list")
def filtered_odd_numbers(generated_numbers):
    return [num for num in generated_numbers if num % 2 != 0]

@asset(description="Calculate the sum of the even numbers")
def summed_even_numbers(filtered_even_numbers):
    return sum(filtered_even_numbers)

@asset(description="Calculate the sum of the odd numbers")
def summed_odd_numbers(filtered_odd_numbers):
    return sum(filtered_odd_numbers)

@asset(description="Sum the two sums")
def summed_two_numbers(summed_even_numbers, summed_odd_numbers):
    return summed_even_numbers + summed_odd_numbers
```

Asset은 Workflow 과정중에 생성되는 Data를 의미한다. ETL 과정의 최종 Data 뿐만 아니라 ETL 과정 중간중간 생성되는 Data 또한 Asset으로 정의할 수 있다. 즉 Workflow를 순차적인 Action의 실행이 아닌 Data의 변화 과정으로 이해할 수 있으며, 이 경우 이용되는 Dagster의 Object가 Asset이다.

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
