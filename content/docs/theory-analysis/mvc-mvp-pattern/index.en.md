---
title: MVC, MVP Pattern
---

This post analyzes the MVC Pattern and MVP Pattern, programming models widely used in GUI programming.

## 1. MVC Pattern

{{< figure caption="[Figure 1] MVC Pattern" src="images/mvc-pattern.png" width="600px" >}}

The **MVC Pattern** consists of three components: Model, View, and Controller. The Model is the part (Business Logic) that obtains the Data used by the Application from the DB and processes the Data. The View is the part that displays the UI used by the User. Finally, the Controller receives the User's requests and delivers them to the Model or View, and also performs the role of coordinating between the Model and the View. It is used in JSP/Servlet.

### 1.1. JSP, Servlet

{{< figure caption="[Figure 2] JSP MVC Model 1" src="images/mvc-pattern-model1-with-jsp.png" width="700px" >}}

[Figure 2] shows MVC Model 1 using JSP. JSP performs the roles of both the View and the Controller. It is a Model used when building simple WebPages.

{{< figure caption="[Figure 3] Servlet, JSP MVC Model 2" src="images/mvc-pattern-model2-with-jsp-servlet.png" width="700px" >}}

[Figure 2] shows MVC Model 2 using Servlet and JSP. JSP performs the role of the View, and the Servlet performs the role of the Controller. In JSP MVC Model 2, the Model does not update the View directly but updates it through the Controller.

## 2. MVP Pattern

{{< figure caption="[Figure 4] MVP Pattern" src="images/mvp-pattern.png" width="600px" >}}

The MVP Pattern consists of three components: Model, View, and Presenter. Unlike the MVC Pattern, the Presenter is included as a component. The Presenter serves as a stepping stone between the Model and the View. Unlike the MVC Pattern, all User requests are first delivered to the View, and there is no dependency between the Model and the View. It is used in Android Applications.

## 3. References

* [WPF] Differences between MVC, MVP, MVVM : [http://hackersstudy.tistory.com/71](http://hackersstudy.tistory.com/71)
* [Design Pattern] MVC Architecture : [https://gmlwjd9405.github.io/2018/11/05/mvc-architecture.html](https://gmlwjd9405.github.io/2018/11/05/mvc-architecture.html)
* JSP MVC model2 : [https://programmers.tistory.com/entry/JSP-MVC-model2](https://programmers.tistory.com/entry/JSP-MVC-model2)
