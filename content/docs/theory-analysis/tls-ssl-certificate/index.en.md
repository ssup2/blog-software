---
title: TLS, SSL Certificate
---

This post analyzes TLS, SSL Certificates.

## 1. Certificate Classification by Domain Coverage

Certificates are classified as follows according to the range of Domains they apply to.

### 1.1. Single Domain

A certificate that can be used for only one **single Domain**.

* `aaa.ssup2.com`
* `bbb.ssup2.com`

### 1.2. Multi (SAN) Domain

A certificate that can be used for one **primary Domain** and multiple **additional Domains**.

* `aaa.ssup2.com` (primary) + `bbb.ssup2.com` (additional 1) + `ccc.ssup2.com` (additional 2)

### 1.3. Wildcard Domain

As the name implies, it contains the Wildcard (`*`) character and refers to a certificate that can be used for **multiple Subdomains** under one Domain or Subdomain. It is classified as an n-th level certificate depending on the position of the Wildcard.

* `*.ssup2.com` / 2nd level
  * `ssup2.com`
  * `aaa.ssup2.com`
  * `bbb.ssup2.com`
* `*.blog.ssup2.com` / 3rd level
  * `blog.ssup2.com`
  * `aaa.blog.ssup2.com`
  * `bbb.blog.ssup2.com`

### 1.4. Multi Wildcard Domain

A certificate that can be used for multiple Subdomains under multiple Domains or multiple Subdomains.

* `*.blog.ssup2.com` + `*.git.ssup2.com`
  * `blog.ssup2.com`
  * `aaa.blog.ssup2.com`
  * `git.ssup2.com`
  * `aaa.git.ssup2.com`

## 2. References

* Types of SSL/TLS Certificates : [https://eunhyee.tistory.com/228](https://eunhyee.tistory.com/228)
* What is a Multi-Domain (SAN) Certificate? : [https://knowledge.digicert.com/solution/SO9440.html](https://knowledge.digicert.com/solution/SO9440.html)
* How to Choose the Right Type of TLS/SSL Certificate : [https://www.digicert.com/blog/how-to-choose-the-right-type-of-tls-ssl-certificate](https://www.digicert.com/blog/how-to-choose-the-right-type-of-tls-ssl-certificate)
