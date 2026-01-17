---
title: Java Design Pattern Command
---

This document summarizes the Command Pattern implemented in Java.

## 1. Java Command Pattern

Command Pattern is a Pattern that encapsulates requests (Commands) so that requests can be performed even if the requester does not exactly understand the request. Command Pattern consists of Classes that perform the following roles.

* Receiver : A Class that performs the role of receiving requests and actually processing requests.
* Command : A Class that performs the role of delivering **specific requests** to the Receiver. Command Class must implement the Command Interface and contains a Receiver Instance.
* Invoker : A collection Class of Concrete Instances. Requesters call Command objects through the Invoker to deliver requests to the Receiver.

```java {caption="[Code 1] Java Command Pattern", linenos=table}
// receiver
public class Light{
     public Light(){}

     public void turnOn(){
        System.out.println("light on");
     }

     public void turnOff(){
        System.out.println("light off");
     }
}

// command interface
public interface Command{
    void execute();
}

// concrete command
public class TurnOnLightCommand implements Command{
   private Light theLight;

   public TurnOnLightCommand(Light light){
        this.theLight=light;
   }

   public void execute(){
      theLight.turnOn();
   }
}

public class TurnOffLightCommand implements Command{
   private Light theLight;

   public TurnOffLightCommand(Light light){
        this.theLight=light;
   }

   public void execute(){
      theLight.turnOff();
   }
}

// invoker
public class Switch {
    private Command flipUpCommand;
    private Command flipDownCommand;

    public Switch(Command flipUpCmd, Command flipDownCmd){
        this.flipUpCommand = flipUpCmd;
        this.flipDownCommand = flipDownCmd;
    }

    public void flipUp(){
         flipUpCommand.execute();
    }

    public void flipDown(){
         flipDownCommand.execute();
    }
}

// main
public class Main{
   public static void main(String[] args){
       Light light=new Light();
       Command switchUp=new TurnOnLightCommand(light);
       Command switchDown=new TurnOffLightCommand(light);

       Switch s= new Switch(switchUp, switchDown);
       s.flipUp();   // light on
       s.flipDown(); // light off
   }
}
```

[Code 1] shows the Command Pattern implemented in Java. The `Light` Class performs the role of Receiver, the `TurnOnLightCommand`/`TurnOffLightCommand` Classes perform the role of Command, and the `Switch` Class performs the role of Invoker. You can see that in the `main()` function, Light On/Off operations are performed through the `Switch` Instance.

## 2. References

* [https://stackoverflow.com/questions/32597736/why-should-i-use-the-command-design-pattern-while-i-can-easily-call-required-met](https://stackoverflow.com/questions/32597736/why-should-i-use-the-command-design-pattern-while-i-can-easily-call-required-met)
* [https://www.tutorialspoint.com/design_pattern/command_pattern.htm](https://www.tutorialspoint.com/design_pattern/command_pattern.htm)
* [https://stackoverflow.com/questions/4834979/difference-between-strategy-pattern-and-command-pattern](https://stackoverflow.com/questions/4834979/difference-between-strategy-pattern-and-command-pattern)
* [https://ko.wikipedia.org/wiki/%EC%BB%A4%EB%A7%A8%EB%93%9C_%ED%8C%A8%ED%84%B4](https://ko.wikipedia.org/wiki/%EC%BB%A4%EB%A7%A8%EB%93%9C_%ED%8C%A8%ED%84%B4)
* [https://gdtbgl93.tistory.com/23](https://gdtbgl93.tistory.com/23)
* [https://blog.hexabrain.net/352](https://blog.hexabrain.net/352)

