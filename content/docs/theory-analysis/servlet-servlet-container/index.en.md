---
title: Servlet, Servlet Container
---

This document analyzes Servlet and Servlet Container.

## 1. Servlet

Servlet is one of Java EE standards and refers to classes that operate on servers based on **javax.servlet Package**. Each Servlet must define three methods: init(), service(), and destroy().

* init() : init() is called when Servlet is created. A Parameter receives an Instance based on javax.servlet.ServletConfig Interface, and it performs operations to initialize Servlet and allocate resources used by Servlet.
* service() : Called each time a request is delivered to Servlet. Performs actual Service Logic.
* destroy() : Called when Servlet is deleted. Performs operations to release resources used by Servlet.

## 2. Servlet Container

{{< figure caption="[Figure 1] Servlet Container" src="images/servlet-servlet-container.png" width="900px" >}}

Servlet Container performs the role of **creating and managing Servlet Instances**. It is also called Web Container. [Figure 1] shows the position of Servlet Container when configuring servers in 3 Tier Architecture. HTTP requests are processed through the following process.

* When Web Browser sends HTTP request to Web Server, Web Server delivers the received HTTP request as-is to WAS Server's Web Server.
* WAS Server's Web Server delivers HTTP request to Servlet Container again.
* Servlet Container checks if Servlet Instance needed for HTTP request processing exists. If it does not exist, it creates Servlet Instance and calls init() method of that Servlet Instance to initialize Servlet Instance.
* Servlet Container calls service() method of Servlet Instance to process HTTP request and delivers processing result to WAS Server's Web Server.
* WAS Server's Web Server delivers HTTP response to Web Server, and Web Server delivers the received HTTP response to Web Browser.

```java {caption="[Code 1] Servlet Example", linenos=table}
public class MyServlet extends HttpServlet {
    private Object thisIsNOTThreadSafe;

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Object thisIsThreadSafe;
    }
}
```

Looking at the HTTP request processing process, Servlet Instances do not create one for each HTTP request, but use existing Servlet Instances. That is, a single Servlet Instance processes multiple HTTP requests simultaneously. Therefore, **Servlet Instances are not Thread-Safe.** As in the HttpServlet example of [Code 1], member variables of Servlet are not Thread-Safe. To use Thread-Safe variables, method local variables must be used. Servlet Container calls destroy() method of Servlet Instances that should be removed when not used and marks them so that JVM's GC (Garbage Collector) can release Servlet Instances. GC releases marked Servlet Instances.

## 3. References

*  [https://dzone.com/articles/what-servlet-container](https://dzone.com/articles/what-servlet-container)
* [http://ecomputernotes.com/servlet/intro/servlet-container](http://ecomputernotes.com/servlet/intro/servlet-container)
* [https://stackoverflow.com/questions/2183974/difference-between-each-instance-of-servlet-and-each-thread-of-servlet-in-servle](https://stackoverflow.com/questions/2183974/difference-between-each-instance-of-servlet-and-each-thread-of-servlet-in-servle)

