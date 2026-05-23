---
title: DB N+1 Problem
---

This document summarizes the DB N+1 problem.

## 1. N+1 Problem

```java {caption="[Code 1] N + 1 Problem Entity", linenos=table}
@Entity
public class School {
    @Id
    private String id;

    private String name;

    @OneToMany(fetch = FetchType.EAGER)
    //@OneToMany(fetch = FetchType.LAZY)
    private List<Student> students;
}

@Entity
public class Student{
    @Id
    private String id;

    private String name;
}
```

The N+1 problem refers to a situation where, when fetching N records (data), the application developer expects a single SQL query to run, but N+1 queries actually run and affect application performance. The N+1 problem generally occurs when the application uses abstraction techniques such as ORM (Object Relational Mapping) to abstract SQL queries, rather than using SQL directly in the application.

[Code 1] shows an entity example in Java Spring Framework (JPA) where the N+1 problem can occur. You can see that the School entity and Student entity have a 1:N relationship. If there are 2000 School records and `findAll()` is called on the School entity, one SELECT SQL query is executed to fetch all School records, and 2000 SELECT SQL queries are executed to fetch Students belonging to each School. You can see that a total of N+1 SQL queries are executed. The most representative way to solve this N+1 problem is to use **table join**. In Java Spring Framework, you can explicitly specify a join using JPQL.

Another way to solve the N+1 problem is to use the **eager loading** technique. However, eager loading is not a technique that solves the N+1 problem in all environments. Eager loading is a technique for obtaining all related data at a specific point in time, not a technique that forces a single query. In practice, even in a Java Spring Framework environment, applying eager loading still performs multiple SQL queries, so it cannot solve the N+1 problem. Therefore, to solve the N+1 problem using eager loading, you must first understand how the framework and ORM you use execute SQL.

## 2. References

* [https://incheol-jung.gitbook.io/docs/q-and-a/spring/n+1](https://incheol-jung.gitbook.io/docs/q-and-a/spring/n+1)
* [https://wwlee94.github.io/category/blog/spring-jpa-n+1-query/](https://wwlee94.github.io/category/blog/spring-jpa-n+1-query/)
* [https://thecodingmachine.io/solving-n-plus-1-problem-in-orms](https://thecodingmachine.io/solving-n-plus-1-problem-in-orms)
