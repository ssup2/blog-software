---
title: CORS
---

Analyze CORS (Cross-Origin Resource Sharing) technique.

## 1. CORS (Cross-Origin Resource Sharing)

Generally, Web Applications can freely access Resources of **Origin** (source where Web Application exists), but for Resources of **Cross-Origin** (source where Web Application does not exist), only Resources allowed by Cross-Origin can be used. CORS technique is a technique that informs Web Applications of available Resources from Cross-Origin and restricts Resource usage. Here, Web Application generally means **JavaScript** executed in Web Browser.

When User accesses "https://ssup2.com" through Web Browser, Web Browser receives and executes JavaScript from "https://ssup2.com". The received JavaScript may include operations to fetch Resources from "https://ssup2.github.io". In this case, since Resources of Cross-Origin (https://ssup2.github.io) rather than Origin (https://ssup2.com) that Web Browser accessed must be used, Web Browser must use CORS technique. Web Browser first receives Resource usage permission from "https://ssup2.github.io" through CORS, then accesses Resources of "https://ssup2.github.io".

Through CORS technique, Cross-Origin can prevent unverified arbitrary Web Applications from accessing its Resources. Since it is a technique where Web Browser allows and restricts Resource usage according to CORS technique, it is a Web Browser-based security technique. Before CORS technique existed, Web Applications could not access Cross-Origin Resources due to security reasons.

### 1.1. Origin

{{< figure caption="[Figure 1] Origin" src="images/origin.png" width="500px" >}}

[Figure 1] shows the clear definition of Origin. **Combination of Scheme, Host, and Port** represents one Origin. Therefore, "https://ssup2.com" and "https://ssup2.github.io" are different Origins, so CORS technique is used. On the other hand, "https://ssup2.com" and "https://ssup2.com/category" are the same Origin, so they are used without CORS technique.

### 1.2. CORS Process

{{< figure caption="[Figure 2] CORS Preflight" src="images/cors-preflight-process.png" width="900px" >}}

[Figure 2] shows the processing procedure of **Preflight** method, which is the most used in CORS. Web Browser sends Origin information and Method and Header information to be allowed from Cross-Origin in **Origin** and **Access-Control-Request-\*** Headers to Cross-Origin "https://ssup2.github.io" to request Resource usage. After that, "https://ssup2.github.io" allows Resource usage through **Access-Control-Allow-\*** Headers. **Access-Control-Allow-Max-Ages** unit represents seconds.

{{< figure caption="[Figure 3] CORS Simple Request" src="images/cors-simple-request-process.png" width="900px" >}}

[Figure 3] shows the processing procedure of **Simple Request** method of CORS. It is a method that requests Cross-Origin's Resources immediately with **Origin** Header without receiving Resource usage permission from Cross-Origin. To use Simple Request method, Simple Request's Method and Header have the following restrictions.

* Method restrictions : Only HEAD, GET, POST Methods can be used
* Header restrictions : Only Accept, Accept-Language, Content-Language, Content-Type Headers can be used
  * Content-Type Header Value restrictions : Only application/x-www-form-urlencoded, multipart/form-data, text/plain Values can exist in Content-Type Header

## 2. References

* [https://stackoverflow.com/questions/27365303/what-is-the-issue-cors-is-trying-to-solve](https://stackoverflow.com/questions/27365303/what-is-the-issue-cors-is-trying-to-solve)
* [https://ko.javascript.info/fetch-crossorigin](https://ko.javascript.info/fetch-crossorigin)
* [https://developer.mozilla.org/ko/docs/Web/HTTP/CORS](https://developer.mozilla.org/ko/docs/Web/HTTP/CORS)
* [https://evan-moon.github.io/2020/05/21/about-cors/](https://evan-moon.github.io/2020/05/21/about-cors/)
* [https://security.stackexchange.com/questions/108835/how-does-cors-prevent-xss](https://security.stackexchange.com/questions/108835/how-does-cors-prevent-xss)

