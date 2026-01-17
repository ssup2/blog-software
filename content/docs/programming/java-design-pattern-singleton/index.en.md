---
title: Java Design Pattern Singleton
---

This document summarizes the Singleton Pattern implemented in Java.

## 1. Java Singleton Pattern

**Singleton Pattern means a Pattern that allocates only one Global Instance in the JVM and shares it for use.** There are several ways to implement the Singleton Pattern in Java.

```java {caption="[Code 1] Java Singleton Pattern Old Version", linenos=table}
public class Singleton { 
    private static Singleton instance;

    private Singleton() {} // Private constructor

    public static Singleton getInstance() { 
        if(instance == null) { 
            instance = new Singleton();
        } 
        return instance; 
    } 
}
```

[Code 1] shows the classic Singleton Pattern. Since the constructor is declared Private, new Instances cannot be created through constructor calls. Instances can only be obtained through `getInstance()` function calls. The `getInstance()` function allocates and returns a new Instance only when no Instance exists, and returns the existing Instance when one exists. Therefore, all Instances obtained through `getIntance()` function calls are the same Instance.

```java {caption="[Code 2] Java Singleton Pattern Synchronized Version", linenos=table}
public class Singleton { 
    private static Singleton instance; 

    private Singleton(){} 
    
    public static synchronized Singleton getInstance() { // synchronized
        if(instance == null) { 
            instance = new Singleton();
        }
        return instance;
    }
}
```

The `getInstance()` function in [Code 1] can cause problems due to Race Conditions during Instance allocation when multiple Threads call it simultaneously in a Multi-thread environment. The simplest way to solve this problem is to use "synchronized" to prevent the `getInstance()` function from being called simultaneously.

```java {caption="[Code 3] Java Singleton Pattern Static Version", linenos=table}
public class Singleton {
    private static Singleton instance = new Singleton();

    private Singleton(){}
    
    public static Singleton getInstance() {
        return instance;
    }
}
```

The `getInstance()` function in [Code 2] can prevent simultaneous Instance allocation through `synchronized`, but since `synchronized` is unnecessary after the Instance is allocated, performance degradation due to `synchronized` is a problem. The simplest way to prevent performance degradation due to `synchronized` is to allocate the Instance to a Static variable as in [Code 3]. Static variables are initialized only once when the Class is Loaded, so Race Conditions do not occur.

```java {caption="[Code 4] Java Singleton Pattern Lazy Holder Version", linenos=table}
public class Singleton { 
    private Singleton(){} 
    
    public static Singleton getInstance() { 
        return LazyHolder.INSTANCE; 
    }
    
    private static class LazyHolder { 
        private static final Singleton INSTANCE = new Singleton(); 
    }
}
```

[Code 3] has the problem that Instances are always allocated even if they are not actually used. To solve this problem, [Code 4] uses Lazy Holder to allocate Static variables only when the Instance is actually used. In [Code 4], the `LazyHolder` Class is Loaded when `getInstance()` is first called. Class Loading is not performed simultaneously by multiple Threads, so Race Conditions do not occur. When implementing Singleton through Java, use Lazy Holder as in [Code 4].

## 2. References

* [https://javaplant.tistory.com/21](https://javaplant.tistory.com/21)
* [https://elfinlas.github.io/2019/09/23/java-singleton/](https://elfinlas.github.io/2019/09/23/java-singleton/)

