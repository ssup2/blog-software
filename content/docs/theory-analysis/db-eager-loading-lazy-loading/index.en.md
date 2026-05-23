---
title: DB Eager Loading, Lazy Loading
---

This document analyzes DB eager loading and lazy loading techniques.

## 1. Eager Loading

```java linenos {caption="[Code 1] Eager Loading", linenos=table}
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

Eager loading, as the name suggests, is a technique that **loads all related data at the moment data is loaded**. [Code 1] shows an example of eager loading in Java Spring Framework (JPA). You can see that the School class has a 1:N relationship with Student, and that it is configured with the eager approach. Therefore, when School data is loaded, related Student information is also loaded at the same time. Loading at the same time here does not guarantee that all data is obtained in a single SQL query. Multiple SQL queries may be executed. This varies by DB library and framework.

Because related data is loaded at the same time, it has the advantage that application developers can easily predict when and which data will be loaded. On the other hand, it has the disadvantage of loading data that is not used by the application. One more point to note is that eager loading is not a fundamental technique for solving the "N+1 problem." As mentioned earlier, multiple SQL queries may be executed when loading related data.

Even in a Java Spring Framework environment like [Code 1], even when eager loading is explicitly specified, related data is fetched from the DB multiple times using multiple SQL queries. To use only one SQL query by leveraging join syntax, you must explicitly use join syntax through JPQL.

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

Lazy loading, as the name suggests, is a technique that performs **data loading at the moment data is actually used**. [Code 2] shows an example of lazy loading in Java Spring Framework. You can see that the School class has a 1:N relationship with Student, and that it is configured with the lazy approach. When School data is loaded, only School data is loaded initially, and Student data is loaded later when Student data is actually used.

Because only data that is actually used is loaded, it has the advantage of preventing unnecessary loading. On the other hand, it has the disadvantage that related data must be fetched from the DB multiple times using multiple SQL queries. In addition, because it becomes difficult for application developers to predict when actual loading occurs, it has a disadvantage from a performance prediction perspective. Lazy loading is also not a fundamental technique for solving the "N+1 problem," because it is a technique that separates loading through the execution of multiple SQL queries.

## 3. References

* [https://www.imperva.com/learn/performance/lazy-loading/](https://www.imperva.com/learn/performance/lazy-loading/)
* [https://stackoverflow.com/questions/31366236/lazy-loading-vs-eager-loading](https://stackoverflow.com/questions/31366236/lazy-loading-vs-eager-loading)
* [https://velog.io/@bread-dd/JPA%EB%8A%94-%EC%99%9C-%EC%A7%80%EC%97%B0-%EB%A1%9C%EB%94%A9%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%A0%EA%B9%8C](https://velog.io/@bread-dd/JPA%EB%8A%94-%EC%99%9C-%EC%A7%80%EC%97%B0-%EB%A1%9C%EB%94%A9%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%A0%EA%B9%8C)
* [https://stackoverflow.com/questions/2990799/difference-between-fetchtype-lazy-and-eager-in-java-persistence-api](https://stackoverflow.com/questions/2990799/difference-between-fetchtype-lazy-and-eager-in-java-persistence-api)
* [https://www.baeldung.com/hibernate-lazy-eager-loading](https://www.baeldung.com/hibernate-lazy-eager-loading)
