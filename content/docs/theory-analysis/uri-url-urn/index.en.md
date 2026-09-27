---
title: URI, URL, URN
---

This post analyzes URI, URL, and URN.

## 1. URI (Uniform Resource Identifier)

{{< figure caption="[Figure 1] URI, URL, URN Relationship" src="images/uri-url-urn.png" width="300px" >}}

**URI** means, as the name implies, a unique **identifier** attached to a Resource. Here, a Resource mainly refers to a **Web Resource** used on the internet. A URI consists of a URL, which is used to indicate the location of a Web Resource, and a URN, which indicates the name of a Web Resource. [Figure 1] shows the relationship between URI, URL, and URN.

## 2. URL (Uniform Resource Locator)

{{< figure caption="[Figure 2] URL" src="images/url.png" width="700px" >}}

A URL is used, as the name implies, to give unique location information to a Web Resource. [Figure 2] shows an example of a URL. The components of a URL are as follows. For the term Root Domain, the common meaning and the meaning from the DNS perspective are different. [Figure 2] shows both meanings to avoid confusion.

* **Scheme** : Generally refers to the Protocol for accessing the Web Resource.
* **Root Domain (DNS View)** : From the DNS perspective, the Root Domain refers to the topmost Domain. It is represented by `.` and is generally omitted.
* **Top-level Domain** : Refers to the top-level Domain. There are ccTLDs (country code TLD) such as `.kr` and `.us`, and gTLDs (generic TLD) such as `.com` and `.net`.
* **Domain Name / Second-level Domain** : Refers to the Domain name, and since it is a sub-Domain of the Top-Level Domain, it is also called the Second-level Domain.
* **Root Domain (Common)** : The common Root Domain refers to the combination of the Domain Name and the Top-level Domain.
* **Subdomain / Third-level Domain** : Refers to an auxiliary Domain, and since it is a sub-Domain of the Second-level Domain, it is also called the Third-level Domain. It is also possible to compose a Domain with multiple Depths by configuring multiple Subdomains.
* **FQDN** : Refers to the combination of all Domains.
* **Port** : Refers to the Port for accessing the Web Resource, and it can be omitted when using the Default Port used for each Scheme. Ex) HTTP/80, HTTPS/443
* **Subdirectory** : Refers to the Path under the Domain. Depth can be expressed using the `/` character.
* **Query String** : Used to pass Parameters to a Web Resource through the URL. It starts at the end of the URL with the `?` character and has the form `<key>=<value>`. Multiple Key-Values can be set using multiple `&` characters.

## 3. URN (Uniform Resource Name)

{{< figure caption="[Figure 3] URN" src="images/urn.png" width="550px" >}}

A URN is used, as the name implies, to give a unique name to a Web Resource. [Figure 3] shows an example of a URN. The components of a URN are as follows.

* **NID (Namespace Identifier)** : Represents the Namespace.
* **NSS (Namespace Specific String)** : Refers to a unique String value within the Namespace. To express Depth like the Subdirectory of a URL, a URN sometimes expresses Depth through the `:` character, and even in this case, all parts except the NID part are regarded as the NSS.

```text {caption="[Text 1] URN Example"}
urn:isbn:0451450523a (Book Number)
urn:isan:0000-0000-2CEA-0000-1-0000-0000-Y (Move Number)
urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66 (UUID)
urn:mpeg:mpeg7:schema:2001<br/>
```

[Text 1] shows examples of URNs.

## 4. References

* URL, URI, URN: What's the Difference? : [https://auth0.com/blog/url-uri-urn-differences/](https://auth0.com/blog/url-uri-urn-differences/)
* URI? URL? URN? Distinguishing Resource Identifiers : [https://blog.itcode.dev/posts/2021/05/29/uri-url-urn](https://blog.itcode.dev/posts/2021/05/29/uri-url-urn)
* URI : [https://en.wikipedia.org/wiki/Uniform_Resource_Identifier](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier)
* URL : [https://raventools.com/marketing-glossary/root-domain/](https://raventools.com/marketing-glossary/root-domain/)
* URN : [https://en.wikipedia.org/wiki/Uniform_Resource_Name](https://en.wikipedia.org/wiki/Uniform_Resource_Name)
* URN : [https://datatracker.ietf.org/doc/html/rfc8141#page-10](https://datatracker.ietf.org/doc/html/rfc8141#page-10)