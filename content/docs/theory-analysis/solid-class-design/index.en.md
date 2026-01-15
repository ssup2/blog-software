---
title: SOLID Class Design
---

This document organizes SOLID, which presents five principles when designing Classes.

## 1. SOLID

SOLID is a term that presents five principles when designing Classes in object-oriented programming. The term SOLID was created by taking the initials of Single Responsibility, Open/closed, Liskov Substitution, Interface Segregation, and Dependency Inversion.

### 1.1. Single Responsibility

A single Class has a single responsibility. That is, there should be only one reason for a Class to change.

```java {caption="[Code 1] Before Applying Single Responsibility", linenos=table}
class Text {
    String text;

    String getText() { ... }
    void setText(String s) { ... }

    /*methods that change the text*/
    void allLettersToUpperCase() { ... }
    void findSubTextAndDelete(String s) { ... }

    /*method for formatting output*/
    void printText() { ... }
}
```

Text Class has two responsibilities: changing Text and outputting Text.

```java {caption="[Code 2] After Applying Single Responsibility", linenos=table}
class Text {
    String text;

    String getText() { ... }
    void setText(String s) { ... }

    /*methods that change the text*/
    void allLettersToUpperCase() { ... }
    void findSubTextAndDelete(String s) { ... }
}

class Printer {
    Text text;

    Printer(Text t) {
       this.text = t;
    }

    void printText() { ... }
}
```

By defining Printer Class and delegating output responsibility that Text Class had to Printer Class, Text Class and Printer Class can each have only one responsibility.

### 1.2. Open/closed

This principle states that it should be open for extension but closed for modification of existing Classes. That is, it means that new functionality should be freely addable while minimizing Class changes.

```java {caption="[Code 3] Before Applying Open/closed", linenos=table}
public class ClaimApprovaManager {

    public void processHealthClaim (HealthInsuranceSurveyor surveyor) {
        if(surveyor.isValidClaim()) {
            System.out.println("ClaimApprovalManager: Valid claim. Currently processing claim for approval....");
        }
    }

    public void processVehicleClaim (VehicleInsuranceSurveyor surveyor) {
        if(surveyor.isValidClaim()) {
            System.out.println("ClaimApprovalManager: Valid claim. Currently processing claim for approval....");
        }
    }
}
```

ClaimApprovalManager Class has the disadvantage that a Method for ClaimApprovalManager must be added for each Surveyor Class whenever Surveyor Class is added.

```java {caption="[Code 4] After Applying Open/closed", linenos=table}
public abstract class InsuranceSurveyor {
    public abstract boolean isValidClaim();
}

public class HealthInsuranceSurveyor extends InsuranceSurveyor {
    public boolean isValidClaim() {
        System.out.println("HealthInsuranceSurveyor: Validating health insurance claim...");
        return true;
    }
}

public class VehicleInsuranceSurveyor extends InsuranceSurveyor {
    public boolean isValidClaim() {
        System.out.println("VehicleInsuranceSurveyor: Validating vehicle insurance claim...");
        return true;
    }
}

public class ClaimApprovalManager {
    public void processClaim(InsuranceSurveyor surveyor) {
        if(surveyor.isValidClaim()) {
            System.out.println("ClaimApprovalManager: Valid claim. Currently processing claim for approval....");
        }
    }
}
```

ClaimApprovalManager can now accommodate various Surveyor Classes without code changes through InsuranceSurveyor Interface.

### 1.3. Liskov Substitution

This principle states that Subclasses must always be able to replace their Superclasses. That is, it means that Superclass's Method functionality should not be arbitrarily changed or modified to cause errors in Subclasses.

```java {caption="[Code 5] Liskov Substitution Example", linenos=table}
public class Rectangle {
    protected double itsWidth;
    protected double itsHeight;

    public void SetWidth(double w) {
        this.itsWidth = w;
    }

    public void SetHeight(double h) {
        this.itsHeight = h;
    }
}

public class Square : Rectangle {
    public new void SetWidth(double w) {
        base.itsWidth = w;
        base.itsHeight = w;
    }

    public new void SetHeight(double h) {
        base.itsWidth = h;
        base.itsHeight = h;
    }
}
```

Since a square is also a rectangle, Square Class was implemented by inheriting Rectangle Class. In Rectangle Class, Width and Height could be set separately, but in Square Class, Width and Height are set to the same value simultaneously. Therefore, this is a Class design that violates the Liskov Substitution principle.

### 1.4. Interface Segregation

This principle states that when configuring Classes using Interfaces, Interfaces should not be made to define methods unnecessary for Class configuration. That is, it means to split Interfaces into small functional units and have Classes select and implement necessary Interfaces.

```java {caption="[Code 6] Before Applying Interface Segregation", linenos=table}
public interface Toy {
    void setPrice(double price);
    void setColor(String color);
    void move();
    void fly();
}
```

Toy Interface of [Code 6] defines three types of methods: color, movement, and flight. The problem is that since not all toys have movement and flight functions, move and fly Methods of Toy Classes without movement and flight functions become dummy Methods.

```java {caption="[Code 7] After Applying Interface Segregation", linenos=table}
public interface Toy {
    void setPrice(double price);
    void setColor(String color);
}

public interface Movable {
    void move();
}

public interface Flyable {
    void fly();
}
```

Toy Interface was separated to create Movable and Flyable Interfaces. When configuring Toy Classes, only necessary Interfaces can be selected and configured.

### 1.5. Dependency Inversion

This principle states that dependencies between Classes should maintain loose relationships through Interfaces. When Instance A references Instance B through Interface B, Instance A depends on Instance B without knowing exactly what action Instance B performs. This term Dependency Inversion is used because the called Instance determines the action of the calling Instance.

```java {caption="[Code 8] Before Applying Dependency Inversion", linenos=table}
public class LightBulb {
    public void turnOn() {
        System.out.println("LightBulb: Bulb turned on...");
    }
    public void turnOff() {
        System.out.println("LightBulb: Bulb turned off...");
    }
}

public class ElectricSwitch {
    public LightBulb lightBulb;
    public boolean on;
    public ElectricSwitch(LightBulb lightBulb) {
        this.lightBulb = lightBulb;
        this.on = false;
    }
    public boolean isOn() {
        return this.on;
    }
    public void press(){
        boolean checkOn = isOn();
        if (checkOn) {
            lightBulb.turnOff();
            this.on = false;
        } else {
            lightBulb.turnOn();
            this.on = true;
        }
    }
}
```

ElectricSwitch Class directly references and uses LightBulb Class. ElectricSwitch Class must continue to change whenever new electronic products are added.

```java {caption="[Code 9] After Applying Dependency Inversion", linenos=table}
public interface Switchable {
    void turnOn();
    void turnOff();
}

public class ElectricSwitch implements Switch {
    public Switchable client;
    public boolean on;
    public ElectricSwitch(Switchable client) {
        this.client = client;
        this.on = false;
    }
    public boolean isOn() {
        return this.on;
    }
    public void press(){
        boolean checkOn = isOn();
        if (checkOn) {
            client.turnOff();
            this.on = false;
        } else {
            client.turnOn();
            this.on = true;
        }
    }
}

public class LightBulb implements Switchable {
    @Override
    public void turnOn() {
        System.out.println("LightBulb: Bulb turned on...");
    }

    @Override
    public void turnOff() {
        System.out.println("LightBulb: Bulb turned off...");
    }
}

public class Fan implements Switchable {
    @Override
    public void turnOn() {
        System.out.println("Fan: Fan turned on...");
    }

    @Override
    public void turnOff() {
        System.out.println("Fan: Fan turned off...");
    }
}
```

ElectricSwitch Class depends only on Switchable Class. And the action of Switchable Class differs depending on whether LightBulb or Fan is injected into Switchable Class.

## 2. References

* [https://springframework.guru/solid-principles-object-oriented-programming/](https://springframework.guru/solid-principles-object-oriented-programming/)

