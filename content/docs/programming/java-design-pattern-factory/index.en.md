---
title: Java Design Pattern Factory
---

This document summarizes the Factory Pattern implemented in Java.

## 1. Java Factory Pattern

**Factory Pattern is a Pattern used when you want to hide the object creation process from the outside.** Factory Pattern has three Patterns: Simple Factory Pattern, Factory Method Pattern, and Abstract Factory Pattern.

```java {caption="[Code 1] Product Class", linenos=table}
// product
public abstract class Product {
    public abstract String getName();
}

public class Book extends Product {
    private String name;

    public Book (String name) {
        this.name = name;
    }

    @Override
    public String getName() {
        return this.name;
    }
}

public class Phone extends Product {
    private String name;

    public Phone (String name) {
        this.name = name;
    }

    @Override
    public String getName() {
        return this.name;
    }
}
```

[Code 1] shows the `Product` Class used as an example for introducing Factory Pattern. The `Product` Class performs the role of Abstract Class, and the `Book` and `Phone` Classes inherit and implement the `Product` Class.

### 1.1. Simple Factory Pattern

```java {caption="[Code 2] Simple Factory Pattern", linenos=table}
// product
public abstract class Product {
    public abstract String getName();
}

public class Book extends Product {
    private String name;

    public Book (String name) {
        this.name = name;
    }

    @Override
    public String getName() {
        return this.name;
    }
}

public class Phone extends Product {
    private String name;

    public Phone (String name) {
        this.name = name;
    }

    @Override
    public String getName() {
        return this.name;
    }
}

// factory
public class SimpleProductFactory {
    public static Product getProduct(String type, String name) {
        if ("book".equals(type))
            return new Book(name);
        else if ("phone".equals(type))
            return new Phone(name);
        return null;
    }
}

// main
public class main {
    public static void main(String[] args) {
        Product book = SimpleProductFactory.getProduct("book", "ssup2-book");
        Product phone = SimpleProductFactory.getProduct("phone", "ssup2-phone");
    }
}
```

Simple Factory Pattern means a Factory Pattern that can be implemented simply, as the name suggests. [Code 2] shows an example of Simple Factory Pattern through the `SimpleProductFactory` Class. You can see that the `getProduct()` Method of `SimpleProductFactory` creates different Product objects depending on the type. Simple implementation is the biggest advantage, but it has the disadvantage that the Code of the `SimpleProductFactory` Class must be changed each time a Product type is added.

### 1.2. Factory Method Pattern

```java {caption="[Code 3] Factory Method Pattern", linenos=table}
{% highlight java linenos %}
// factory
public abstract class ProductFactory {
    abstract protected Product getProduct(String name);
}

public class BookFactory extends ProductFactory {
    @Override
    abstract protected Product getProduct(String name) {
        return new Book(name);
    }
}

public class PhoneFactory extends ProductFactory {
    @Override
    abstract protected Product getProduct(String name) {
        return new Phone(name);
    }
}

// main
public class main {
    public static void main(String[] args) {
        bookFactory = new BookFactory();
        phoneFactory = new PhoneFactory();

        Product book = bookFactory.getProduct("ssup2-book");
        Product phone = phoneFactory.getProduct("ssup2-phone");
    }
}
```

Factory Method Pattern is a Pattern that compensates for the disadvantages of Simple Factory. It is a Pattern that creates dedicated Factories that create objects of a single Type by inheriting Factory Classes. [Code 3] shows the Factory Method Pattern. You can see a `BookFactory` Factory Class that creates only Book objects and a `PhoneFactory` Factory Class that creates only Phone objects by inheriting the `ProductFactory` Class. It has the advantage that existing Factory-related Code does not need to be modified even if Product types are added.

### 1.3. Abstract Factory Pattern

```java {caption="[Code 4] Abstract Factory Pattern", linenos=table}
// factory
public abstract class ProductFactory {
    abstract protected Product getProduct(String name);
}

public class BookFactory extends ProductFactory {
    @Override
    abstract protected Product getProduct(String name) {
        return new Book(name);
    }
}

public class PhoneFactory extends ProductFactory {
    @Override
    abstract protected Product getProduct(String name) {
        return new Phone(name);
    }
}

public class AbstractProductFactory {
    private ProductFactory productFactory

    public ProductFactory(ProductFactory productFactory) {
        this.productFactory = productFactory;
    }

    public Product getProduct(String name) {
        return this.productFactory.getProduct(String name);
    }
}

// main
public class Main {
    public static void main(String[] args) {
        bookFactory = new AbstractProductFactory(new BookFactory());
        phoneFactory = new AbstractProductFactory(new PhoneFactory());

        Product book = bookFactory.getProduct("ssup2-book");
        Product phone = phoneFactory.getProduct("ssup2-phone");
    }
}
```

Abstract Factory Pattern is a Pattern that can create objects of various Types depending on the Factory object being injected. [Code 4] shows the Abstract Factory Pattern. You can see that various Types of Products can be created depending on the Factory Class injected into the `AbstractProductFactory` Class.

## 2. References

* [https://medium.com/bitmountn/factory-vs-factory-method-vs-abstract-factory-c3adaeb5ac9a](https://medium.com/bitmountn/factory-vs-factory-method-vs-abstract-factory-c3adaeb5ac9a)
* [https://www.codeproject.com/Articles/716413/Factory-Method-Pattern-vs-Abstract-Factory-Pattern](https://www.codeproject.com/Articles/716413/Factory-Method-Pattern-vs-Abstract-Factory-Pattern)
* [https://stackoverflow.com/questions/5739611/what-are-the-differences-between-abstract-factory-and-factory-design-patterns](https://stackoverflow.com/questions/5739611/what-are-the-differences-between-abstract-factory-and-factory-design-patterns)
* [https://blog.seotory.com/post/2016/08/java-abstract-factory-pattern](https://blog.seotory.com/post/2016/08/java-abstract-factory-pattern)
* [https://blog.seotory.com/post/2016/08/java-factory-pattern](https://blog.seotory.com/post/2016/08/java-factory-pattern)

