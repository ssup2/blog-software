---
title: Servlet, Servlet Container
---

Servlet과 Servlet Container를 분석한다.

## 1. Servlet

Servlet은 Java EE의 표준중 하나로 **javax.servlet Package**를 기반으로 Server에서 동작하는 Class들을 의미한다. 각 Servlet은 init(), service(), destory() 3개의 method를 반드시 정의해야 한다.

* init() : init()은 Servlet 생성시 호출된다. Parameter로 javax.servlet.ServletConfig Interface 기반의 Instance가 넘어오는데, Servlet을 초기화 하고 Servlet이 이용하는 자원을 할당하는 동작을 수행한다.
* service() : Servlet으로 요청이 전달 될때마다 호출된다. 실제 Service Logic을 수행한다.
* destroy() : Servlet이 삭제될때 호출된다. Servlet에서 이용하는 자원을 해지하는 동작을 수행한다.

## 2. Servlet Container

{{< figure caption="[Figure 1] Servlet Container" src="images/servlet-servlet-container.png" width="900px" >}}

Servlet Container는 **Servlet Instance를 생성하고 관리**하는 역할을 수행한다. Web Container라고도 불린다. [Figure 1]은 3 Tier Architecture로 서버를 구성할때의 Servlet Container의 위치를 나타내고 있다. HTTP 요청을 다음과 같은 과정을 통해 처리된다.

* Web Brower에서 Web Server에게 HTTP 요청을 보내면 Web Server는 받은 HTTP 요청을 그대로 WAS Server의 Web Server에게 전달한다.
* WAS Server의 Web Server는 다시 HTTP 요청을 Servlet Container에게 전달한다.
* Servlet Container는 HTTP 요청 처리에 필요한 Servlet Instance가 존재하는지 확인한다. 존재하지 않다면 Servlet Instance를 생성하고 해당 Servlet Instance의 init() method를 호출하여 Servlet Instance를 초기화 한다.
* Servlet Container는 Servlet Instance의 service() method를 호출하여 HTTP 요청을 처리하고, WAS Server의 Web Server에게 처리 결과를 전달한다.
* WAS Server의 Web Server는 HTTP 응답을 Web Server에게 전달하고, Web Server는 받은 HTTP 응답을 Web Brower에게 전달한다.

```java {caption="[Code 1] Servlet 예제", linenos=table}
public class MyServlet extends HttpServlet {
    private Object thisIsNOTThreadSafe;

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Object thisIsThreadSafe;
    }
}
```

HTTP 요청 처리 과정을 보면 Servlet Instance는 HTTP 요청이 올때마다 하나씩 생성하는게 아니라 기존의 Servlet Instance를 이용한다. 즉 하나의 Servlet Instance가 여러개의 HTTP 요청을 동시에 처리하게 된다. 따라서 **Servlet Instance는 Thread-Safe하지 않는다.** [Code 1]의 HtttpServlet 예제처럼 Servlet의 멤버 변수는 Thread-Safe하지 않는다. Thread-Safe한 변수를 이용하기 위해서는 Method의 지역변수를 이용해야 한다. Servlet Container는 사용되지 않아 제거되야할 Servlet Instance의 destory() method를 호출하고 JVM의 GC(Garbage Collector)에서 Servlet Instance를 해지할 수 있도록 표시해둔다. GC는 표시된 Servlet Instance를 해지한다.

## 3. 참조

*  [https://dzone.com/articles/what-servlet-container](https://dzone.com/articles/what-servlet-container)
* [http://ecomputernotes.com/servlet/intro/servlet-container](http://ecomputernotes.com/servlet/intro/servlet-container)
* [https://stackoverflow.com/questions/2183974/difference-between-each-instance-of-servlet-and-each-thread-of-servlet-in-servle](https://stackoverflow.com/questions/2183974/difference-between-each-instance-of-servlet-and-each-thread-of-servlet-in-servle)
