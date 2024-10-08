---
title: DB Eager Loading, Lazy Loading
---

DB의 Eager Loading 기법과 Lazy Loading 기법을 분석한다.

## 1. Eager Loading

```java linenos {caption="[Code 1] Eager Loading<", linenos=table}
@Entity
public class School {
    @Id
    private String id;

    private String name;

    @OneToMany(fetch = FetchType.EAGER)
    private List<Student> students;
}

@Entity
public class Student{
    @Id
    private String id;

    private String name;
}
```

Eager Loading은 의미 그대로 Data Loading하는 순간 **관련된 Data 모두를 Loading**을 수행하는 기법을 나타낸다. [Code 1]은 Java Spring Framework (JPA)에서의 Eager Loading 기법의 예제를 나타내고 있다. School Class에 Student가 1:N 관계로 연결되어 있는것을 확인할 수 있고, Eager 기법으로 설정되어 있는것도 확인할 수 있다. 따라서 School Data Loading시 School과 관련된 Student 정보들도 한 시점에 Loading하게 된다. 여기서 한 시점에 Loading 한다는 의미는 한번의 SQL Query 수행으로 모든 Data를 한번에 얻는다것을 보장한다는 의미는 아니다. 다수의 SQL Query가 수행될 수 있다. 이 부분은 DB Library, Framework 마다 다르다.

관련 Data를 한 시점에 Loading하기 때문에 App 개발자가 언제, 어떤 Data가 Loading될지 쉽게 예측할 수 있다는 장점을 가지고 있다. 반면 App에서 이용되지 않는 Data도 Loading 한다는 단점을 가지고 있다. 한가지 더 유의해야하는 점은 Eager Loading 기법이 "N+1 문제"를 해결하는 근본적인 기법은 아니라는 점이다. 앞에서 언급한것 처럼 관련 Data Loading시 다수의 SQL Query가 수행될 수 있기 때문이다.

[Code 1]의 Java Spring Framework 환경의 경우에도 Eager Loading을 명시하여도 다수의 SQL Query를 이용하여 여러번 DB로부터 관련 Data를 얻는다. Join 문법을 활용하여 하나의 SQL Query만 이용하도록 만들기 위해서는 JPQL을 통해서 Join 문법을 이용하도록 명시해야 한다.

## 2. Lazy Loading

```java linenos {caption="[Code 2] Lazy Loading", linenos=table}
@Entity
public class School {
    @Id
    private String id;

    private String name;

    @OneToMany(fetch = FetchType.LAZY)
    private List<Student> students;
}

@Entity
public class Student{
    @Id
    private String id;

    private String name;
}
```

Lazy Loading은 의미 그대로 Data가 **실제 이용되는 순간 Data Loading**을 수행하는 기법을 나타낸다. [Code 2]는 Java Spring Framework에서의 Eager Loading 기법의 예제를 나타내고 있다. School Class에 Student가 1:N 관계로 연결되어 있는것을 확인할 수 있고, Lazy 기법으로 설정되어 있는것도 확인할 수 있다. School Data Loading시 처음에는 School Data만 Loading하고, Student Data는 추후 실제 Student Data가 이용되는 순간 Loading 하게 된다.

실제 이용되는 Data만 Loading을 수행하기 때문에 불필요한 Loading을 방지할 수 있다는 장점을 가진다. 반면에 반드시 다수의 SQL Query를 이용하여 여러번 DB로부터 관련 Data를 얻어야 한다는 단점을 갖는다. 또한 App 개발자는 언제 실제 Loading이 발생하는지 예측하기 어려워지기 때문에 성능 예측 측면에서는 단점을 갖는다. Lazy Loading 또한 다수의 SQL Query 수행을 통해서 Loading을 분리하는 기법이기 때문에 "N+1 문제"를 해결하는 근본적인 기법은 아니다.

## 3. 참조

* [https://www.imperva.com/learn/performance/lazy-loading/](https://www.imperva.com/learn/performance/lazy-loading/)
* [https://stackoverflow.com/questions/31366236/lazy-loading-vs-eager-loading](https://stackoverflow.com/questions/31366236/lazy-loading-vs-eager-loading)
* [https://velog.io/@bread-dd/JPA%EB%8A%94-%EC%99%9C-%EC%A7%80%EC%97%B0-%EB%A1%9C%EB%94%A9%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%A0%EA%B9%8C](https://velog.io/@bread-dd/JPA%EB%8A%94-%EC%99%9C-%EC%A7%80%EC%97%B0-%EB%A1%9C%EB%94%A9%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%A0%EA%B9%8C)
* [https://stackoverflow.com/questions/2990799/difference-between-fetchtype-lazy-and-eager-in-java-persistence-api](https://stackoverflow.com/questions/2990799/difference-between-fetchtype-lazy-and-eager-in-java-persistence-api)
* [https://www.baeldung.com/hibernate-lazy-eager-loading](https://www.baeldung.com/hibernate-lazy-eager-loading)