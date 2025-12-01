---
title: Web Browser Local Storage, Session Storage, Cookie
---

Analyzes Local Storage, Session Storage, and Cookie used in Web Browser.

## 1. Local Storage

{{< figure caption="[Figure 1] Chrome Local Storage" src="images/chrome-local-storage.png" width="700px" >}}

Local Storage is a Key/Value-based storage space used by Web Browser. It is stored in Storage of the PC where Web Browser is installed and can only be used in Web Browser's JavaScript/HTML. Up to 5MB of storage space can be used per Domain. Data stored in Local Storage has the characteristic of no expiration.

## 2. Session Storage

{{< figure caption="[Figure 2] Chrome Session Storage" src="images/chrome-session-storage.png" width="700px" >}}

Session Storage is a Key/Value-based storage space used by Web Browser. It is stored in Storage of the PC where Web Browser is installed and can only be used in Web Browser's JavaScript/HTML. Up to 5MB of storage space can be used per Domain.

Data stored in Session Storage has the same lifespan as Web Browser's Window/Tab. That is, when Web Browser's Windows/Tabs are closed, all Data stored in Session Storage is also removed. This characteristic is the biggest difference from Local Storage.

## 3. Cookie

{{< figure caption="[Figure 3] Chrome Cookie" src="images/chrome-cookie.png" width="1000px" >}}

Cookie is a storage space that uses Storage of the PC where Web Browser is installed, but the stored Data is mainly a storage space for storing Data sent by Web Server. Web Server sends Data to be stored in Cookie along with the response when sending responses to Web Browser as needed. When Web Browser receives Data to be stored in Cookie from Web Server, it stores it in Cookie, and when sending requests to Web Server thereafter, it also sends Data stored in Cookie. That is, Cookie is a storage space for Web Server. Web Browser can also utilize Data stored in Cookie.

The reason Cookie is needed in Web Server is to enable Web Server to recognize Web Browser and provide a Stateful environment to User. Since HTTP/HTTPS is a Stateless Protocol, it is difficult to provide Stateful operations to User simply through HTTP/HTTPS. Since Web Server can make Web Client send specific Data along with requests through Cookie, by utilizing this, Web Server can distinguish Web Browsers and provide a Stateful environment to User.

## 4. References

* [http://www.gwtproject.org/doc/latest/DevGuideHtml5Storage.html](http://www.gwtproject.org/doc/latest/DevGuideHtml5Storage.html)
* [https://krishankantsinghal.medium.com/local-storage-vs-session-storage-vs-cookie-22655ff75a8](https://krishankantsinghal.medium.com/local-storage-vs-session-storage-vs-cookie-22655ff75a8)

