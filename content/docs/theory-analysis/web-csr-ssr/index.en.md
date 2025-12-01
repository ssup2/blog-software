---
title: Web Client Side Rendering, Server Side Rendering
---

Analyzes Web's Client Side Rendering technique and Server Side Rendering technique.

## 1. Client Side Rendering (CSR)

{{< figure caption="[Figure 1] CSR" src="images/csr.png" width="700px" >}}

CSR (Client Side Rendering) technique refers to a technique where all Web Page Rendering is performed in Web Browser, which is the Client. Here, performing Rendering means the process of executing JavaScript to construct incomplete HTML into complete HTML (DOM Tree). Web Browser must be able to obtain complete HTML of Web Page to display Web Page as UI. The Rendering process also includes fetching Data from external Servers as needed.

[Figure 1] shows the CSR process. When User requests a specific Web Page to Server through Web Browser, Server delivers both the Web Page's HTML and JavaScript embedded in HTML to Web Browser. Thereafter, Web Browser performs Rendering to construct HTML and exposes Web Page's UI to User.

## 2. Server Side Rendering (SSR)

{{< figure caption="[Figure 2] SSR" src="images/ssr.png" width="700px" >}}

SSR (Server Side Rendering) technique refers to a technique where Web Page Rendering is performed on Server. [Figure 2] shows SSR. When User requests a specific Web Page to Server through Web Browser, Server performs Rendering internally and sends complete HTML to Web Browser.

Web Browser that received complete HTML first exposes Web Page's UI to User. At this time, User can only see Web Page's UI but cannot manipulate Web Page. Thereafter, Web Browser receives additional JavaScripts needed for Web Page and then enables User to fully use Web Page.

## 3. CSR vs SSR

In CSR technique, Server only needs to deliver HTML and JavaScript it has to Web Browser, so Server can respond quickly without load. Also, since it sends incomplete HTML before Rendering, the size of HTML being sent is generally smaller compared to SSR that sends rendered HTML. Therefore, CSR is generally more advantageous than SSR in terms of TTI (Time To Interactive).

On the other hand, in SSR technique, Web Browser can immediately expose Web UI to User without additional operations once reception of complete HTML through Rendering is finished, so SSR technique is more advantageous than CSR technique in terms of FP (First Paint).

Server load is higher in SSR, which performs Rendering on Server, compared to CSR. In terms of SEO (Search Engine Optimization), SSR that sends complete HTML is more advantageous than CSR. The main reason for choosing SSR instead of CSR is generally to gain benefits of FP (First Paint) and SEO.

## 4. References

* [https://developers.google.com/web/updates/2019/02/rendering-on-the-web?hl=ko](https://developers.google.com/web/updates/2019/02/rendering-on-the-web?hl=ko)
* [https://medium.com/walmartglobaltech/the-benefits-of-server-side-rendering-over-client-side-rendering-5d07ff2cefe8](https://medium.com/walmartglobaltech/the-benefits-of-server-side-rendering-over-client-side-rendering-5d07ff2cefe8)
* [https://velog.io/@gkrba1234/SSR%EA%B3%BC-CSR%EC%97%90-%EB%8C%80%ED%95%B4-%EC%95%8C%EC%95%84%EB%B3%B4%EC%9E%90](https://velog.io/@gkrba1234/SSR%EA%B3%BC-CSR%EC%97%90-%EB%8C%80%ED%95%B4-%EC%95%8C%EC%95%84%EB%B3%B4%EC%9E%90)

