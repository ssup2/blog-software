---
title: Java Monitor, synchronized
---

This document summarizes the Monitor technique for synchronization between Threads and analyzes the synchronized technique that operates based on Monitor in Java.

## 1. Monitor

Monitor is a High Level synchronization technique for synchronizing between Threads. Monitor consists of **one Lock** and **multiple Condition Variables**. Monitor performs a control role to prevent multiple threads from accessing the Critical Section simultaneously using Lock. It also performs the role of waking up Threads waiting using Condition Variables.

## 2. Java Monitor

Every Instance (Object) in Java owns one Monitor. Each Monitor uses only **one Lock and one Condition Variable (Wait Queue)**. Therefore, all Instances in Java internally have one Lock and one Condition Variable.

### 2.1. synchronized

Java's `synchronized` Keyword is one of the techniques for synchronizing between Threads. The `synchronized` Keyword performs synchronization between Threads using the Monitor that exists in each general Instance.

```java {caption="[Code 1] synchronized Method", linenos=table}
public class TwoMap {
    private Map<String, String> map1 = new HashMap<String, String>();
    private Map<String, String> map2 = new HashMap<String, String>();
    
    public synchronized void put1(String key, String value){
        map1.put(key, value);
    }
    public synchronized void put2(String key, String value){
        map2.put(key, value);
    }
    
    public synchronized String get1(String key){
        return map1.get(key);
    }
    public synchronized String get2(String key){
        return map2.get(key);
    }
}
```

The `synchronized` Keyword is commonly used with Methods. [Code 1] is an example of using `synchronized` Methods. When the `synchronized` Keyword is attached to a Method, a Thread must acquire the Lock of the Monitor of the Instance calling the Method to execute it. Therefore, even if you create one Instance called `TwoMap` and multiple Threads call the Methods of the `TwoMap` Instance simultaneously, only one Method is executed at a time.

```java {caption="[Code 2] synchronized Instance", linenos=table}
public class TwoMap {
    private Map<String, String> map1 = new HashMap<String, String>();
    private Map<String, String> map2 = new HashMap<String, String>();
    private final Object syncObj1 = new Object();
    private final Object syncObj2 = new Object();
    
    public void put1(String key, String value){
        synchronized (syncObj1) {
            map1.put(key, value);
        }
    }
    public void put2(String key, String value){        
        synchronized (syncObj2) {
            map2.put(key, value);
        }
    }
  
    public String get1(String key){
        synchronized (syncObj1) {
            return map1.get(key);
        }
    }
    public String get2(String key){
        synchronized (syncObj2) {
            return map2.get(key);
        }
    }
}
```

The `synchronized` Keyword can be used with general Instances. [Code 2] is an example of using Instances with the `synchronized` Keyword. In this case, a Thread must acquire the Lock of the Monitor of the Instance specified in the parentheses of the `synchronized` Keyword to execute the Code inside the `synchronized` Keyword Block. Therefore, in [Code 2], the `put1()` and `get1()` Methods use the Monitor of `syncObj1`, so the `put1()` and `get1()` Methods are not executed simultaneously. On the other hand, the `put2()` Method that uses the Monitor of `syncObj2` can be executed simultaneously with the `put1()` Method.

```java {caption="[Code 3] wait(), notifyAll()", linenos=table}
public class Channel {
    private String packet;
    private boolean isPacketExist;
 
    public synchronized void send(String packet) {
        while (isPacketExist) {
            try {
                wait();
            } catch (InterruptedException e)  {
                Thread.currentThread().interrupt(); 
                Log.error("Thread interrupted", e); 
            }
        }
        isPacketExist = true;
        
        this.packet = packet;
        notifyAll();
    }
 
    public synchronized String receive() {
        while (!isPacketExist) {
            try {
                wait();
            } catch (InterruptedException e)  {
                Thread.currentThread().interrupt(); 
                Log.error("Thread interrupted", e); 
            }
        }
        isPacketExist = false;

        notifyAll();
        return packet;
    }
}
```

When a Thread is executing Code while holding the Lock of an Instance's Monitor and needs to wait after yielding the Lock to another Thread, you can use the `wait()` function. The `wait()` function is implemented using the Instance's Monitor's Condition Variable. Threads waiting in the Condition Variable can be awakened through the `notify()` and `notifyAll()` functions. The `notify()` function only awakens one arbitrary Thread waiting in the Condition Variable. The `notifyAll()` function awakens all Threads waiting in the Condition Variable. Even if all Threads are awakened, only one Thread acquires the Lock and the remaining Threads wait again.

[Code 3] shows an example of using the `wait()` and `notifyAll()` functions. The `send()` function waits through the `wait()` function when a Packet exists in the Channel. Afterward, when the `receive()` function is called, the Channel's Packet is removed, and when `notifyAll()` function is called, it wakes up and stores the Packet in the Channel. Conversely, the `receive()` function waits through the `wait()` function when no Packet exists in the Channel. Afterward, when the `send()` function is called, a Packet is stored in the Channel, and when `notifyAll()` function is called, it wakes up and removes the Packet from the Channel.

## 2. References

* [https://en.wikipedia.org/wiki/Monitor_(synchronization)](https://en.wikipedia.org/wiki/Monitor_(synchronization))
* [http://christian.heinleins.net/apples/sync/](http://christian.heinleins.net/apples/sync/)
* [http://egloos.zum.com/iilii/v/4071694](http://egloos.zum.com/iilii/v/4071694)
* [https://www.baeldung.com/java-wait-notify](https://www.baeldung.com/java-wait-notify)

