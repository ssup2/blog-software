---
title: Java Design Pattern Strategy
---

This document summarizes the Strategy Pattern implemented in Java.

## 1. Java Strategy Pattern

**Strategy Pattern means a Pattern that defines different algorithms (Strategies) as separate Classes and allows the defined Classes to be exchanged and used.** Strategy Pattern is used when you want to flexibly change and use various algorithms.

```java {caption="[Code 1] Java Strategy Pattern", linenos=table}
// operation
public interface Operation {
   public int doOperation(int n1, int n2);
}

public class OperationAdd implements Operation {
   @Override
   public int doOperation(int n1, int n2) {
      return n1 + n2;
   }
}

public class OperationSub implements Operation{
   @Override
   public int doOperation(int n1, int n2) {
      return n1 - n2;
   }
}

// operator
public class Operator {
   private Operation operation;

   public Operator(Operation operation){
      this.operation = operation;
   }

   public int execute(int n1, int n2){
      return operation.doOperation(n1, n2);
   }
}

// main
public class Main {
    public static void main(String[] args) {
        Operator operatorAdd = new Operator(new OperationAdd());
        Operator operatorSub = new Operator(new OperationSub());

        operatorAdd.execute(10, 5); // 15
        operatorAdd.execute(10, 5); // 5
    }
}
```

[Code 1] shows a simple Strategy Pattern implemented in Java. The `OperationAdd` and `OperationSub` Classes are concrete Classes that implement the `Operation` Interface, and are Classes that have different algorithms (Strategies). You can see that the `Operator` Class receives an `Operation` Class that has an algorithm as a Parameter and uses it.

## 2. References

* [https://www.tutorialspoint.com/design_pattern/strategy_pattern.htm](https://www.tutorialspoint.com/design_pattern/strategy_pattern.htm)

