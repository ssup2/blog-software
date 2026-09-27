---
title: JVM
---

This post analyzes the JVM (Java Virtual Machine).

## 1. JVM (Java Virtual Machine)

{{< figure caption="[Figure 1] JVM Architecture" src="images/jvm-architecture.png" width="900px" >}}

Java is a language built on the philosophy of **Write once, Run anywhere**. For an App written once to run on various Platforms, the App's execution environment must not be dependent on the Platform. The **JVM** is a User Level Program that sits between the Platform and the Java App and provides a consistent execution environment to the Java App to solve this problem. The JVM largely consists of the Class Loader, Runtime Memory, Execution Engine, and Native Method Interface (JNI).

### 1.1. Class Loader

The Class Loader plays the role of loading Class Files compiled into Byte Code into Memory. There are three default Class Loaders: the Bootstrap, Extension, and System Class Loaders.

* **Bootstrap Class Loader** : Loads the Java Core Library called `rt.jar` (runtime). ex) `java.lang.System`
* **Extension Class Loader** : Loads the Classes under `$JAVA_HOME/lib/ext`.
* **System Class Loader** : Loads the Classes in `$CLASSPATH`. The App's Classes generally belong to this.

Besides the three Class Loaders above, when a Java App developer wants to manage Class Loading, a User Class Loader can be created by directly inheriting the Class Loader Class. The Class Loader uses the **Parent Delegation Model**. It refers to the method in which, after a Class Loader confirms that the Class to be loaded is not in Memory, it unconditionally calls the Parent Class Loader before loading the Class itself. If the Class is still not loaded after calling the Parent Class Loader, it loads the Class itself. The called Parent Class Loader also calls its own Parent Class Loader before loading the Class itself. Through the Parent Delegation Model, a Java App developer can easily build a Class Loader without worrying about duplicate Class Loading when developing a User Class Loader.

{{< figure caption="[Figure 2] JVM Class Loader Hierarchy" src="images/class-loader-hierarchy.png" width="500px" >}}

Due to the Parent Delegation Model, Class Loaders naturally form a hierarchy. [Figure 2] shows the hierarchy between Class Loaders. All Class Loaders except the Bootstrap Class necessarily have a Parent Class Loader. The Class Loader performs the following three stages of operation.

* **Loading** : Loads the Class composed of Bytecode into Memory.
* **Linking** : Initializes `static` variables and Resolves Symbols.
  * **Verify** : Verifies that the Bytecode is correct.
  * **Prepare** : `static` variables are initialized to the Default Value according to the variable Type. ex) `int` -> 0
  * **Resolve** : When a Class uses an external Class at Class Compile time, the Memory address of the external Class is not known at Compile time. Therefore, the external Class is represented as a Symbol and inserted into the Bytecode. Since the Memory address of each Class has been determined as the Classes were loaded into Memory in the previous Loading stage, the Symbols inserted into the Bytecode are replaced with the actual Class Memory addresses.
* **Initialization** : Initializes `static` variables with the values in the Code.

### 1.2. Runtime Memory

{{< figure caption="[Figure 3] JVM Runtime Memory" src="images/runtime-memory.png" width="900px" >}}

Runtime Memory is the Memory area managed by the JVM. It consists of the Method Area, Heap, Stack, PC Register, and Native Method Stack.

* **Method Area** : The area where the Bytecode of Methods is loaded. `static` variables are also managed in the Method Area.
* **Heap** : The area where Instances created with the `new` syntax are loaded. To be more precise, the variables of Instances are managed in the Heap. The String Constant Pool, where String Literals are stored, is also located in the Heap.
* **Stack** : The area where local variables are loaded. When a Thread calls a Method, a new Stack Frame is created accordingly, and local variables are allocated. When the operation of the Method ends, the allocated Stack Frame is released and the previous Stack Frame is used. Each Thread has its own dedicated Stack space. It can be said that the Context of each Thread is maintained using the Stack.
* **PC Register** : The PC (Program Counter) Register area is the area that manages the address of the next Bytecode each Thread will execute. Therefore, like the Stack, each Thread has its own dedicated PC Register.
* **Native Method Stack** : A Native Method refers to a Method written in a Native language like CPP. When executing a Native Method, a separate Native Method Stack is used to manage the local variables of the Native Method. Similar to the Stack, each Thread has its own dedicated one.

### 1.3. Execution Engine

It executes the actual Bytecode using the Runtime Memory. The Execution Engine consists of the Interpreter, JIT Compiler, and Garbage Collector.

* **Interpreter** : Interprets and executes Bytecode.
* **JIT (Just-In-Time) Compiler** : Since Bytecode must be interpreted and executed by the Interpreter, performance Overhead occurs. The JIT Compiler identifies frequently executed Bytecode during Runtime and compiles it into Assembly language. Since Bytecode compiled into Assembly language can be executed by the CPU without the Interpreter, the performance Overhead of the Interpreter can be eliminated.
* **Garbage Collector** : Java has a Garbage Collector that automatically manages the Heap area where Instances are loaded. Therefore, Java does not release allocated Instances with a `delete` command like CPP.

### 1.4. Native Method Interface (JNI)

It plays the role of an Interface that helps the Execution Engine execute Native Methods in Native Method Libraries.

## 2. References
* The JVM Architecture Explained : [https://dzone.com/articles/jvm-architecture-explained](https://dzone.com/articles/jvm-architecture-explained)
* Java Type Loading, Linking, and Initialization : [http://www.artima.com/insidejvm/ed2/lifetypeP.html](http://www.artima.com/insidejvm/ed2/lifetypeP.html)
* Java Virtual Machine's Internal Architecture : [https://www.artima.com/insidejvm/ed2/jvm2.html](https://www.artima.com/insidejvm/ed2/jvm2.html)
