---
title: Spring Bean Annotation
---

This document summarizes Annotations related to Spring Beans.

## 1. @Component

```java {caption="[Code 1] @Component Example", linenos=table}
@Component
public class MyComponentA {
}

@Component("myComponentC")
public class MyComponentB {
}
```

A Class with `@Component` attached means a Class managed as a **Component** in Spring, as the name suggests. Being managed as a Component means that Instances of that Class are managed as **Beans**. Spring obtains information about Classes with `@Component` attached through **Spring's Component Scanner**, then creates Beans based on the obtained information and performs DI (Dependency Injection) as needed. The Default name of a Bean uses the Class name with the first letter changed to lowercase. Therefore, the Bean name of the `MyComponentA` Class in [Code 1] becomes `myComponentA`. The Bean name can also be specified as the Value of `@Component`. The Bean name of the `MyComponentB` Class in [Code 1] becomes `myComponentC` specified in the Value of `@Component`.

## 2. @Configuration

```java {caption="[Code 2] @Configuration Example 1", linenos=table}
package com.ssup2;

@Component
public class MyBeanB {
}
```

```java {caption="[Code 3] @Configuration Example 2", linenos=table}
@Configuration
@ComponentScan("com.ssup2")
public class MyConfig {

    @Bean
    public Mybean myBeanA() {
        return new myBeanA();
    }
}
```

`@Configuration` is an Annotation to inform Spring that it is a Class containing **Bean Methods**. Also, `@Configuration` informs Spring's Component Scanner of the Package of Components so that the Component Scanner can discover Components. In [Code 2], [Code 3], a Bean Method named `myBeanA` is defined using `@Bean`. Also, `@ComponentScan` is used to inform the Component Scanner of the Package where `MyBeanB` exists. Configuration inherits `@Component`. Therefore, Instances of Classes with `@Configuration` attached are also managed as Spring Beans.

### 2.1. @Bean

```java {caption="[Code 4] @Bean Example", linenos=table}
public class MyBeanA {
}

public class MyBeanB {
}

@Configuration
public class MyConfig {

    @Bean
    public MybeanA myBeanA() {
        return new myBeanA();
    }

    @Bean("myBeanC")
    public MybeanB myBeanB() {
        return new myBeanB();
    }
}
```

`@Bean` is attached to Bean Methods to inform Spring that the Method is a Bean Method. Bean Methods must return Instances. The Default name of Beans created through Bean Methods becomes the Method name. The Bean name created through the `myBeanA()` Method in [Code 4] becomes `myBeanA`. Also, you can specify the name of Beans created through Bean Methods through the Value of `@Bean`. The Bean name created through the `myBeanB()` Method in [Code 4] becomes `myBeanC`, which is the Value of `@Bean`.

## 3. @Service, @Controller, @Repository

```java {caption="[Code 5] @Service, @Controller, @Repository Example", linenos=table}
@Service
public class MyService {
}

@Controller
public class MyController {
}

@Repository
public class MyRepository {
}
```

`@Service` is attached to Classes containing Business Logic. `@Controller` is attached to Classes responsible for Controllers in the MVC Pattern. `@Repository` is attached to Classes responsible for Data Access. `@Service`, `@Controller`, and `@Repository` all inherit `@Component`. Therefore, Instances of Classes with the 3 Annotations attached are managed as Spring Beans.

## 4. References

* [https://www.baeldung.com/spring-bean-annotations](https://www.baeldung.com/spring-bean-annotations)
* [http://wonwoo.ml/index.php/post/2000](http://wonwoo.ml/index.php/post/2000)
* [https://www.javarticles.com/2016/01/spring-componentscan-annotation-example.html](https://www.javarticles.com/2016/01/spring-componentscan-annotation-example.html)

