---
title: Spring Bean Annotation
---

Spring의 Bean과 연관된 Annotation을 정리한다.

## 1. @Component

```java {caption="[Code 1] @Component 예제", linenos=table}
@Component
public class MyComponentA {
}

@Component("myComponentC")
public class MyComponentB {
}
```

`@Component`가 붙은 Class는 의미그대로 Spring에서 **Component**로 관리되는 Class를 의미한다. Component로 관리된다는 의미는 해당 Class의 Instance가 **Bean**으로 관리된다는 의미이다. Spring은 **Spring의 Component Scanner**를 통해서 `@Component`가 붙은 Class의 정보를 얻은 다음, 얻은 정보를 바탕으로 Bean을 생성하고 필요에 따라 DI(Dependency Injection)를 수행한다. Bean의 Default 이름은 Class 이름에서 첫글자를 소문자로 바꾼것을 이용한다. 따라서 [Code 1]의 `MyComponentA` Class의 Bean 이름은 `myComponentA`가 된다. Bean의 이름은 `@Component`의 Value로 명시할 수도 있다. [Code 1]의 `MyComponentB` Class의 Bean의 이름은 `@Component`의 Value에 명시된 `myComponentC`가 된다.

## 2. @Configuration

```java {caption="[Code 2] @Configuration 예제 1", linenos=table}
package com.ssup2;

@Component
public class MyBeanB {
}
```

```java {caption="[Code 3] @Configuration 예제 2", linenos=table}
@Configuration
@ComponentScan("com.ssup2")
public class MyConfig {

    @Bean
    public Mybean myBeanA() {
        return new myBeanA();
    }
}
```

`@Configuration`은 Spring에게 **Bean Method**를 포함하고 있는 Class라는걸 알려주기 위한 Annotation이다. 또한 `@Configuration`은 Spring의 Component Scanner에게 Component의 Package를 알려주어, Component Scanner가 Component를 발견 할 수 있도록 도와준다. [Code 2], [Code 3]에서 `@Bean`을 이용하여 `myBeanA`이라는 Bean Method를 정의하고 있다. 또한 `@ComponentScan`을 이용하여 Component Scanner에게 `MyBeanB`가 있는 Package를 알려주고 있다. Configuration은 `@Component`를 상속하고 있다. 따라서 `@Configuration`이 붙은 Class의 Instance 역시 Spring의 Bean으로 관리된다.

### 2.1. @Bean

```java {caption="[Code 4] @Bean 예제", linenos=table}
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

`@Bean`은 Bean Method에 붙여 해당 Method가 Bean Method인 것을 Spring에게 알리는 역할을 수행한다. Bean Method는 반드시 Instance를 반환한다. Bean Method를 통해 생성되는 Bean의 Default 이름은 Method 이름이 된다. [Code 4]의 `myBeanA()` Method를 통해 생성되는 Bean의 이름은 `myBeanA`가 된다. 또한 `@Bean`의 Value를 통해서 Bean Method를 통해 생성되는 Bean의 이름을 지정할 수 있다. [Code 4]의 `myBeanB()` Method를 통해 생성되는 Bean의 이름은 `@Bean`의 Value인 `myBeanC`가 된다.

## 3. @Service, @Controller, @Repository

```java {caption="[Code 5] @Service, @Controller, @Repository 예제", linenos=table}
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

`@Service`는 Business Logic을 담고있는 Class에 붙인다. `@Controller`는 MVC Pattern의 Controller를 담당하는 Class에 붙인다. `@Repository`는 Data Access를 담당하는 Class에 붙인다. `@Service`, `@Controller`, `@Repository` 모두 `@Component`를 상속하고 있다. 따라서 앞의 3개의 Annotation이 붙은 Class의 Instance는 Spring의 Bean으로 관리된다.

## 4. 참조

* [https://www.baeldung.com/spring-bean-annotations](https://www.baeldung.com/spring-bean-annotations)
* [http://wonwoo.ml/index.php/post/2000](http://wonwoo.ml/index.php/post/2000)
* [https://www.javarticles.com/2016/01/spring-componentscan-annotation-example.html](https://www.javarticles.com/2016/01/spring-componentscan-annotation-example.html)