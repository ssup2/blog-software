---
title: HTTP Cookie and Session
---

This post analyzes HTTP Cookie and Session.

## 1. Cookie

{{< figure caption="[Figure 1] HTTP Cookie" src="images/http-cookie.png" width="600px" >}}

**HTTP Cookie** refers to Key-Value values stored by the Client (Web Browser). [Figure 1] shows the Cookie issuance process.

* The Client requests a Web Page from the Server.
* The Server sends the Cookie information in the `Set-Cookie` Header along with the Web Page. It also sends the Cookie's expiration time (`Expires`) and scope (`Domain`, `Path`) information together. In [Figure 1], the value of the `name` Cookie is `supsup`, and its expiration date is October 21, 2018. The scope is the `/` (root) Path of the `ssup2.com` Domain, which means the Cookie is valid on the Web Pages of the `ssup2.com` Domain and all its Subdomains.
* The Client includes the appropriate Cookies in the `Cookie` Header based on the Cookie information the Server requested to store, and sends them.

Since the Client includes the Cookies requested by the Server when sending requests to the Server, the Server can identify which Client sent the request. Therefore, through HTTP Cookies, the Server can provide Logic that has **state**. HTTP Cookies are mainly used to implement operations such as Session management, personalization, and user behavior tracking.

## 2. Session

{{< figure caption="[Figure 2] HTTP Session" src="images/http-session.png" width="600px" >}}

HTTP Cookies are used to implement HTTP Sessions. The Client stores a Session ID in the `JSESSION` Cookie at the Server's request. After that, it sends the `JSESSION` Cookie every time it requests a Web Page from the Server. The Server looks at the Session ID value of the `JSESSION` Cookie to distinguish which Client the Web Page request came from, thereby implementing the Session.

Generally, a Session Cookie does not include an expiration time, and a Cookie without an expiration time means a Cookie that disappears when the Client closes. However, most Web Browsers (Clients) these days keep even Cookies without an expiration date to maintain the Session.

## 3. References

* HTTP 쿠키 : [https://developer.mozilla.org/ko/docs/Web/HTTP/Cookies](https://developer.mozilla.org/ko/docs/Web/HTTP/Cookies)
