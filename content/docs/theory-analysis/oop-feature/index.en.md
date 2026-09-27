---
title: OOP Features
---

## 1. Abstraction

The process of **designing an object as a Class** is called **Abstraction**. An object refers to a real-world thing. An object can be expressed with numerous states and behaviors. Through Abstraction, these numerous elements are designed into a Class used in a program. If a Person Class is abstracted based on gender, the Person Class has male/female information and the corresponding Methods. If a Person Class is abstracted based on age, it has infant/adolescent/adult/elderly information and the corresponding Methods.

## 2. Encapsulation

The process of **hiding** a Class's Logic or state so that it cannot be known from the outside is called Encapsulation. The Private / Public Keywords attached to a Class's variables or methods are important syntax for encapsulating a Class. Through Class Encapsulation, developers using a Class can use it easily by simply calling the Class's Public Methods. Loose coupling between Classes using Interfaces is also a good example of using Encapsulation well.

## 3. Inheritance

The method of defining a Class by **inheriting** the variables and Methods of another Class is called Inheritance. The Class being inherited is called the **Parent Class**, and the Class that inherits is called the **Child Class**. The Child Class can redefine the inherited Methods, and this feature is called **Overwriting**.

## 4. Polymorphism

The characteristic that **different Methods** are invoked even when calling a Class's Method of the same name is called Polymorphism. Although Methods have the same name, they can be implemented so that actually different Methods are invoked depending on the Type of the Method's Parameters, the number of Parameters, and the Return Type, and this feature is called **Overloading**.

```java {caption="[Code 1] Java Polymorphism Example", linenos=table}
class Parent {
    public void print(){
        System.out.println("Parent");
    }
}

class Child extends Parent {
    public void print(){
        System.out.println("Child");
    }
}

public class BlogMain {
    public static void main(String[] args){
        Parent iparent = new Parent();
        Parent ichild = new Child();

        System.out.println(iparent.toString());
        System.out.println(ichild.toString());
    }
}
```

```console {caption="[Shell 1] Result of the Java Polymorphism Example", linenos=table}
Parent
Child
```

Different Methods can also be invoked depending on the Instance. [Code 1] consists of a Parent Class named `Parent` and a Child Class named `Child`. On line 15, a `Parent` Instance is assigned to a `Parent` Class variable named `iparent`, and on line 16, a `Child` Instance is assigned to a `Parent` Class variable named `ichild`. Since both Instances are assigned to `Parent` Class variables, the Code appears to print the `Parent` string on two lines, but the `ichild` instance prints the `Child` string. This is because the Instances actually assigned to the `Parent` Class variables are different. This process, in which the invoked Method changes depending on the Instance, is called **Dynamic Dispatch**.
