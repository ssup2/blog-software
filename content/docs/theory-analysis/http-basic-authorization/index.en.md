---
title: HTTP Basic Authentication
---

## 1. HTTP Basic Authentication

The **HTTP Basic Authentication** technique is the simplest authentication technique defined in the HTTP standard. [Figure 1] shows an example of the HTTP Basic Authentication technique.

{{< figure caption="[Figure 1] HTTP Basic Authentication" src="images/http-basic-example.png" width="600px" >}}

* The Client requests a Resource from the Server.
* Authentication is required to use the Resource requested by the Client. Therefore, the Server informs the Client of the need for authentication through the `WWW-Authenticate` Header. The `Basic` string tells the Client that the Basic authentication process is required.
  * `realm` is an attribute that indicates the Protection Space of the requested Resource. The Client may use different IDs and Passwords for each Protection Space that a Resource belongs to.
* The Client that received the authentication request adds the **ID:Password** string encoded in **Base64** to the `Authorization` Header and requests the Resource from the Server once again. In [Figure 1], the ID and Password are both assumed to be `ssup2`. The Base64 encoding result of the `ssup2:ssup2` string is the `c3N1cDI6c3N1cDI=` string.
* The Server that received the encoded ID:Password string checks whether it matches the value it encoded itself, and if it matches, delivers the requested Resource.

HTTP Basic Authentication is used when the Client knows the ID and Password and simple authentication over HTTP is needed. Since the ID and Password are encoded in Base64, the structure easily exposes the ID and Password. The exposure of the ID and Password can be prevented by using SSL or TLS.

## 2. References

* HTTP Basic Authentication Scheme : [https://tools.ietf.org/html/rfc7617](https://tools.ietf.org/html/rfc7617)
* [HTTP] Basic Authentication : [http://iloveulhj.github.io/posts/http/http-basic-auth.html](http://iloveulhj.github.io/posts/http/http-basic-auth.html)
