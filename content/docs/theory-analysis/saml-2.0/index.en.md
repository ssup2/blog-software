---
title: SAML 2.0
---

This document analyzes SAML (Security Assertion Markup Language) 2.0.

## 1. SAML (Security Assertion Markup Language) 2.0

SAML 2.0 is an Authentication and Authorization Protocol commonly used to implement SSO (Single Sign On). In large organizations, it is common to build dedicated authentication/authorization servers for the organization, and users belonging to the organization need to go through authentication/authorization processes with the self-built authentication/authorization server to use services within the organization. The problem is that when users want to use services from Service Providers such as Google and Facebook, they need a separate authentication/authorization process with that Service Provider.

When SSO is built using SAML 2.0, users can use Service Provider services only through the authentication/authorization process with the organization's dedicated server, without the authentication/authorization process with the Service Provider. This SAML 2.0-based SSO process is achieved through the issuance of **Assertions** that store authentication/authorization information. Assertions store authentication/authorization information in XML format.

### 1.1. Component

{{< figure caption="[Figure 1] SAML 2.0 Component" src="images/saml-2.0-component.png" width="600px" >}}

[Figure 1] shows the components of SAML 2.0 when authentication/authorization functionality is configured using SAML 2.0 in a Web environment. **User** refers to service users. **User Agent** receives user input and delivers it to Service/Identity Providers, or displays content received from Service/Identity Providers to users. Generally, it refers to a Web Browser.

**Service Provider** represents the provider that provides the service users want to use, as the name suggests. It can generally be understood as an API Server provided by IT companies such as Google and Facebook. **Identity Provider** stores user authentication/authorization information and provides authentication/authorization information to Service Providers. It can generally be understood as an authentication/authorization server used internally by a specific organization. Service Providers and Identity Providers are generally composed of different companies/organizations.

### 1.2. Process

The following Requests and Responses are exchanged between SAML 2.0 Components.

* SAML Request : An authentication request sent by Service Provider to Identity Provider. Uses XML Format.
* SAML Response : An authentication result sent by Identity Provider to Service Provider. Uses XML Format. Assertion information is included in the SAML Response.
* Relay State : A value sent together when Service Provider sends SAML Request to Identity Provider, stored by Identity Provider, and sent together when Identity Provider sends SAML Response to Service Provider. After receiving SAML Response, Service Provider determines what action to continue based on Relay State. Relay State is mainly used to store the URL of the Service Provider that the user first attempted to access. Therefore, Service Provider redirects the user again through Relay State sent together after receiving SAML Response. The Format of Relay State is not defined in SAML 2.0. Therefore, each Service Provider has a different Format of Relay State.

In order to exchange SAML Request, SAML Response, and Relay State between Service Provider and Identity Provider, Service Provider must be previously registered with Identity Provider. SAML 2.0 can choose between HTTP Redirect (URL Query) or HTTP Post methods for exchanging SAML Request, SAML Response, and Relay State.

#### 1.2.1. Service Provider HTTP Redirect, Identity Provider HTTP Post

{{< figure caption="[Figure 2] SAML 2.0 Process - Service Provider HTTP Redirect, Identity Provider HTTP Post" src="images/saml-2.0-process-sp-redirect-idp-post.png" width="800px" >}}

[Figure 2] shows the process where Service Provider sends SAML Request and Relay State to Identity Provider through HTTP Redirect, and Identity Provider sends SAML Response and Relay State to Service Provider through HTTP Post Method Body. This is the most commonly used form in SAML 2.0.

* 1,2 : User requests service by accessing Service Provider's URL through User Agent.
* 3 : Since Service Provider's request from User Agent has no authentication/authorization information, it sends **HTTP Redirect** command to User Agent along with SAML Request and Relay State so that User Agent can obtain authentication/authorization information. SAML Request and Relay State are delivered in the form of Query of the redirected URL.
* 4,5 : User Agent accesses Identity Provider with SAML Request and Relay State. Identity Provider constructs authentication UI based on SAML Request and Relay State existing in URL Query and sends it to User Agent.
* 6,7,8,9 : When user performs Login, Identity Provider makes User Agent deliver SAML Response and Relay State to Service Provider's **ACS (Assertion Consumer Service)** URL through **HTTP Post** request. SAML Response and Relay State are sent as Post request Body.
* 10, 11 : User Agent accesses ACS URL through HTTP Post request. Service Provider's ACS sets Session through Assertion information in SAML Response existing in HTTP Post request Body. It also finds the Service Provider URL that user first attempted to access through Relay State existing in HTTP Post request Body and redirects again.
* 12, 13 : User Agent accesses Service Provider's service through Session set by Service Provider's ACS.

## 3. References

* [https://developer.okta.com/docs/concepts/saml/](https://developer.okta.com/docs/concepts/saml/)
* [https://docs.aws.amazon.com/ko-kr/IAM/latest/UserGuide/id-roles-providers-saml.html](https://docs.aws.amazon.com/ko-kr/IAM/latest/UserGuide/id-roles-providers-saml.html)
* [https://support.google.com/a/answer/6262987?hl=ko](https://support.google.com/a/answer/6262987?hl=ko)
* [https://en.wikipedia.org/wiki/SAML-2.0](https://en.wikipedia.org/wiki/SAML-2.0)
* [https://www.samltool.com/generic-sso-res.php](https://www.samltool.com/generic-sso-res.php)
* [https://stackoverflow.com/questions/28110014/can-saml-do-authorization](https://stackoverflow.com/questions/28110014/can-saml-do-authorization)
* [https://stackoverflow.com/questions/28117725/sso-saml-redirect-a-user-to-a-specified-landing-page-after-successful-log-in](https://stackoverflow.com/questions/28117725/sso-saml-redirect-a-user-to-a-specified-landing-page-after-successful-log-in)

