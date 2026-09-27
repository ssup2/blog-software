---
title: OAuth 2.0
---

This post analyzes OAuth 2.0, which is used when performing Authorization.

## 1. OAuth 2.0

{{< figure caption="[Figure 1] ID/Password Auth" src="images/id-password-auth.png" width="800px" >}}

**OAuth 2.0** is the **Authorization** Protocol currently used by most authorization services. It is a Protocol that emerged to improve the problems of the old authentication/authorization method based on the User's ID/Password. [Figure 1] shows the old authentication/authorization method through the User's ID/Password that Apps used to rely on. When an App needed to access the API of a Service Provider such as Google or Facebook, in the past the App sent requests to the Service Provider's API Server using the ID/Password that the User entered into the App.

Such an ID/Password based Auth method has several problems. First, even if the App performs malicious actions using the User's ID/Password, there is no way for the User or the API Server to restrict or detect the App's malicious actions. Also, since the App must store the User's ID/Password it received, much attention must also be paid to the App's security.

These problems can be solved by using OAuth 2.0. With OAuth 2.0, the App accesses the API Server using the **Access Token** received from the Authorization Server, not the User's ID/Password. The Access Token has the characteristic of expiring after a certain time. Therefore, even if the App holds the Access Token, it can only access limited Resources within a limited time, so the App's malicious actions can be prevented through the Access Token. Also, since the App does not need to store the User's ID/Password, it is advantageous for the App's security.

Most Apps using OAuth 2.0 do not directly manage User information, but instead access the Service Provider's User API through OAuth 2.0 and use the User information managed by the Service Provider. Therefore, once a User registers their information with the Service Provider through the sign-up process, the User can use various Apps that use OAuth 2.0 without signing up for each of them.

### 1.1. Component

{{< figure caption="[Figure 2] OAuth 2.0 Component" src="images/oauth-2.0-component.png" width="700px" >}}

[Figure 2] shows the components in detail when the authorization function is composed using OAuth 2.0 in a Web environment. **User** represents the person who uses the App. In OAuth 2.0, it is called the **Resource Owner**. Here, **Resource** can be understood as Data. **User Agent** plays the role of receiving the User's input and delivering it to the App or Authorization Server, or showing the User the content received from the App or Authorization Server. Generally, in a Web environment, the User Agent means a Web Browser.

**App** represents the App that wants to receive Resource access permission from the Authorization Server. Since it is a Web environment, the App can be thought of as a Web Server or a WAS. **Authorization Server** is the Server that issues and manages Access Tokens. The API Server means the Server that provides the User's Resources (Data). In OAuth 2.0, it is called the **Resource Server**. Generally, the Authorization Server and the Resource Server are provided by the same Service Provider.

### 1.2. Access Token

The Access Token is a Token that holds authorization permission. The App can access a specific API Server using the Access Token. The Access Token contains authorization information such as **Timeout (authorization allowed time) and Scope (authorization range)**. Therefore, the Access Token has the characteristic of expiring after the Timeout. Also, through the Access Token, only the Resources included in the authorization range, not all Resources, can be accessed.

The important point is that the Access Token is a Token that contains only **authorization** information, not authentication information. That is, any App can use the permissions of the Access Token if it has the Access Token. Therefore, the Access Token must not be exposed to the outside, and the design must ensure that only authenticated Apps can obtain the Access Token. When authentication information is needed in the App, OIDC (OpenID Connect), which is based on OAuth 2.0, can be used.

For the App to be issued an Access Token from the Authorization Server, the App must be registered with the Authorization Server. When the App is registered with the Authorization Server, the Authorization Server issues a **Client ID** and a **Client Secret**. The Client ID is a value for distinguishing Apps in the Authorization Server, and the Client Secret is a value for issuing Access Tokens. The Client Secret must not be exposed to the outside.

{{< figure caption="[Figure 3] OAuth 2.0 Access Token Issuance Process" src="images/oauth-2.0-access-token-flow.png" width="900px" >}}

[Figure 3] shows the issuance process of the Access Token.

* 1,2,3 : When the User's authorization is needed to use a specific Resource while the App is running, the App delivers a Redirect command to the User Agent toward the Auth Server's authorization URL. Along with the Redirect command, the Client ID, the Scope information needed by the App, and the App's Callback URL for returning to the App after authorization is completed are also sent. The Client ID, Scope, and Callback URL are all delivered in the form of URL Queries of the authorization URL.
* 4,5,6 : The Auth Server delivers an appropriate UI for User authentication and Resource authorization to the User Agent based on the Client ID, Scope, and Callback URL information delivered as URL Queries.
* 7 : The User performs User authentication and Resource authorization through the UI. User authentication is performed by entering the User's ID/Password, and the Resource authorization process is performed by showing the Scope information requested by the App.
* 8,9 : The User Agent delivers the authentication and authorization information to the Auth Server and receives the **Auth Code** and the App URL to return to the App. The Auth Code is a temporary Token for obtaining the Access/Refresh Token later. The Auth Code is also delivered in the form of a URL Query of the Callback URL.
* 10,11,12 : The User Agent moves to the App's Callback URL. The App obtains the Auth Code through the URL Query, and then is issued the Access Token, which can access the Resources, and the Refresh Token, which is used to newly receive an Access Token, using the obtained Auth Code together with the Client ID and Client Secret.

{{< figure caption="[Figure 4] Google OAuth 2.0 Authorization UI" src="images/auth-google-ui.png" width="600px" >}}

[Figure 4] shows the process of performing User authentication and Resource authorization using Google's Authorization UI. It performs Login and asks the User for consent by showing the authorization Scope information requested by the App.

### 1.3. Resource Access

{{< figure caption="[Figure 5] OAuth2.0 Resource Access" src="images/oauth-2.0-resource-access-flow.png" width="900px" >}}

[Figure 5] shows the process of accessing a Resource using the Access Token issued to the App.

* 1,2 : The User requests a Resource through the User Agent.
* 3,4 : The App uses the issued Access Token and delivers the Access Token together with the Resource request.
* 5,6 : The Resource Server checks whether the Access Token is valid and then delivers the Resource to the App.
* 7,8 : The App delivers the Resource to the User through the User Agent.

### 1.4. Refresh Token

The Refresh Token is a Token used to be issued a **new Access Token** when the Access Token the App was using has Timed out and become Invalid. The Authorization Server delivers the Refresh Token together only when it issues an Access Token to the App for the **first** time. Therefore, the App must store and use the Refresh Token. The Authorization Server does not necessarily have to send the Refresh Token. An App without a Refresh Token must request the User again to be issued a new Access Token when the Access Token becomes Invalid. The Refresh Token is also called a **Bearer Token**. [Figure 6] shows the process of the App using the Refresh Token.

{{< figure caption="[Figure 6] Refresh Token Usage Process" src="images/oauth-2.0-refresh-token-flow.png" width="900px" >}}

[Figure 6] shows the process of using the Refresh Token.

* 1,2,3 : The App receives the User's request and requests a Resource from the Resource Server using the Access Token.
* 4,5 : The Resource Server asks the Authorization Server whether the Access Token is valid.
* 6,7,8 : When the App receives the result that the Access Token is Invalid, it receives a new Access Token from the Authorization Server using the Refresh Token.
* 9 ~ 14 : The App requests the Resource again using the newly received Access Token together with the Client ID and Client Secret, and delivers the received Resource to the User through the User Agent.

## 2. References

* OAuth2 Server : [http://jlabusch.github.io/oauth2-server/index.html](http://jlabusch.github.io/oauth2-server/index.html)
* Learning Authentication through the Google API (oauth 2.0) : [https://opentutorials.org/course/2473/16571](https://opentutorials.org/course/2473/16571)
* The Client ID and Secret - OAuth 2.0 Simplified : [https://www.oauth.com/oauth2-servers/client-registration/client-id-secret/](https://www.oauth.com/oauth2-servers/client-registration/client-id-secret/)
* Google OAuth2 API Explained : [https://medium.com/@pumudu88/google-oauth2-api-explained-dbb84ff97079](https://medium.com/@pumudu88/google-oauth2-api-explained-dbb84ff97079)
* OAuth 2.0 Authorization : [http://tutorials.jenkov.com/oauth2/authorization.html](http://tutorials.jenkov.com/oauth2/authorization.html)
