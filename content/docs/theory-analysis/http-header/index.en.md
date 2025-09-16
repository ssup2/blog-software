---
title: HTTP Header
---

## 1. HTTP Header

### 1.1. General Header

General Header refers to headers used in both requests and responses.

#### 1.1.1. Date

``` {caption="[Text 1] Date Header Format"}
Date: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

The `Date` header indicates **the creation date and time of the request or response message**. [Text 1] shows the format of the `Date` header.

* `<day-name>` : Indicates the day of the week, using strings `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
* `<day>` : Indicates the day.
* `<month>` : Indicates the month, using strings `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec`.
* `<year>` : Indicates the year.
* `<hour>` : Indicates the hour.
* `<minute>` : Indicates the minute.
* `<second>` : Indicates the second.
* `GMT` : Indicates Greenwich Mean Time, always using GMT time.

``` {caption="[Text 2] Date Header Example"}
Date: Wed, 21 Oct 2015 07:28:00 GMT
Date: Mon, 19 Oct 2015 07:28:00 GMT
Date: Tue, 20 Oct 2015 07:28:00 GMT
```

[Text 2] shows some examples of the `Date` header.

#### 1.1.2. Connection

``` {caption="[Text 3] Connection Header Format"}
Connection: <connection-option>
```

The `Connection` header indicates connection control information. [Text 3] shows the format of the `Connection` header.

* `<connection-option>` : Indicates connection control settings.
  * `close` : Closes the connection after processing the request.
  * `keep-alive` : Maintains the connection after processing the request.
  
When the `Connection` header is not present, **HTTP/1.0** uses `close` as the default setting, and **HTTP/1.1** uses `keep-alive` as the default setting. Generally, the server operates according to the connection control settings requested by the client. That is, the `Connection` headers of requests and responses generally have the same setting values. However, depending on the server's situation, even if the client sends a request with `keep-alive` settings wanting to maintain the connection continuously, the server may respond with `close` settings and terminate the connection.

#### 1.1.3. Cache-Control

``` {caption="[Text 4] Cache-Control Header Format"}
Cache-Control: <cache-directive>
```

The `Cache-Control` header is a header for directing cache policies. Here, Cache refers to **Local Cache** located in the browser and **Shared Cache** located in CDN and Proxy servers. [Text 4] shows the format of the `Cache-Control` header. When a client sends a request including the `Cache-Control` header, it means policy direction for Shared Cache, and conversely, when a server sends a response including the `Cache-Control` header, it means policy direction for Local Cache. Therefore, the Cache Directives used by clients and servers are different.

* Client's `<cache-directive>` : Indicates policy direction for Shared Cache.
  * `max-age=<seconds>` : If Shared Cache has cached data less than seconds, it responds with cached data, and if it has cached data more than seconds, it re-caches new data from the Origin Server and then responds.
  * `max-stale=<seconds>` : If Shared Cache has cached data less than `data validity period + seconds`, it responds with cached data, and if it has cached data more than `data validity period + seconds`, it re-caches new data from the Origin Server and then responds.
  * `min-fresh=<seconds>` : If Shared Cache has cached data less than `data validity period - seconds`, it responds with cached data, and if it has cached data more than `data validity period - seconds`, it re-caches new data from the Origin Server and then responds.
  * `no-cache` : Shared Cache must verify original data from the Origin Server before responding. Used together with headers like `If-Modified-Since`, `If-None-Match`.
  * `no-store` : Shared Cache does not store data received from the Origin Server. The client always receives new data from the Origin Server.
  * `no-transform` : Shared Cache does not transform data.
  * `only-if-cached` : Shared Cache checks if there is cached data and responds with that data if available, otherwise does not respond.

* Server's `<cache-directive>` : Indicates policy direction for Local Cache or Shared Cache. Multiple Cache Directives can be used.
  * `max-age=<seconds>` : If Local Cache has cached data less than seconds, it responds with cached data, and if it has cached data more than seconds, it re-caches new data from the Origin Server and then responds.
  * `s-maxage=<seconds>` : If Shared Cache has cached data less than seconds, it responds with cached data, and if it has cached data more than seconds, it re-caches new data from the Origin Server and then responds.
  * `no-cache` : Local Cache must verify original data from the Origin Server before responding.
  * `no-store` : Local Cache does not cache data. The client always receives new data from the Origin Server.
  * `no-transform` : Local Cache does not transform data.
  * `must-revalidate` : When data expires, Local Cache must verify original data from the Origin Server before responding.
  * `proxy-revalidate` : When data expires, Shared Cache must verify original data from the Origin Server before responding.
  * `private` : Caches data only in Local Cache.
  * `public` : Caches data in both Local Cache and Shared Cache.
  * `immutable` : Indicates that data received from the Origin Server does not change.
  * `stale-while-revalidate=<seconds>` : When data expires, Local Cache fetches original data from the Origin Server for seconds time, and temporarily responds with cached invalid data while fetching data.
  * `stale-if-error=<seconds>` : When the Origin Server sends a 5XX response, Local Cache responds with cached data for seconds time.

Generally, clients use the `no-cache` value in Request Headers, and servers use the `no-cache` value in Response Headers.

### 1.2. Request Header

`Request` Header refers to headers used in requests.

#### 1.2.1. Host

``` {caption="[Text 5] Host Header Format"}
Host: <host>[:<port>]
```

The `Host` header indicates the name and port number of the host to send the request to. [Text 5] shows the format of the `Host` header. When using HTTP, port `80` is used by default, and when using HTTPS, port `443` is used by default. When not using the default port number, the port number can be omitted.

``` {caption="[Text 6] Host Header Example"}
Host: example.com
Host: example.com:8080
```

[Text 6] shows some examples of the `Host` header.

#### 1.2.2. Authorization

``` {caption="[Text 7] Authorization Header Format"}
Authorization: <auth-scheme> <authorization-parameters>
```

The `Authorization` header indicates the authentication information of the client sending the request. [Text 7] shows the format of the `Authorization` header.

* `<auth-scheme>` : Indicates the authentication method.
  * `Basic` : Encodes and transmits username and password using Base64 encoding.
  * `Bearer` : Indicates Token authentication method.
  * `Digest` : Indicates Digest authentication method. Transmits authentication information by hashing the request's headers and body.
  * `AWS4-HMAC-SHA256` : Indicates AWS authentication method.
* `<authorization-parameters>` : Indicates parameters required for authentication.

``` {caption="[Text 8] Authorization Header Example"}
Authorization: Basic YWxhZGRpbjpvcGVuc2VzYW1l
Authorization: Bearer <token>
Authorization: Digest username="<username>", realm="<realm>", qop=<qop>, nonce="<nonce>", uri="<uri>", response="<response>", opaque="<opaque>"
Authorization: AWS4-HMAC-SHA256 Credential=<access_key_id>/<date>/<region>/<service>/aws4_request, SignedHeaders=<signed_headers>, Signature=<signature>
```

[Text 8] shows some examples of the `Authorization` header.

#### 1.2.3. User-Agent

``` {caption="[Text 9] User-Agent Header Format"}
User-Agent: <user-agent>
```

The `User-Agent` header indicates information about the client sending the request. [Text 9] shows the format of the `User-Agent` header.

``` {caption="[Text 10] User-Agent Header Example"}
User-Agent: curl/7.64.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36
```

[Text 10] shows some examples of the `User-Agent` header. It shows examples of curl client and Chrome browser on macOS.

#### 1.2.4. If-Modified-Since

``` {caption="[Text 11] If-Modified-Since Header Format"}
If-Modified-Since: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

The `If-Modified-Since` header is used when a client wants to receive only resources that have been modified after a specific date and time. [Text 11] shows the format of the `If-Modified-Since` header.

* `<day-name>` : Indicates the day of the week, using strings `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
* `<day>` : Indicates the day.
* `<month>` : Indicates the month, using strings `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec`.
* `<year>` : Indicates the year.
* `<hour>` : Indicates the hour.
* `<minute>` : Indicates the minute.
* `<second>` : Indicates the second.
* `GMT` : Indicates Greenwich Mean Time, always using GMT time.

``` {caption="[Text 12] If-Modified-Since Header Example"}
If-Modified-Since: Wed, 21 Oct 2015 07:28:00 GMT
```

[Text 12] shows an example of the `If-Modified-Since` header. The server sends a `200 OK` response only if there are resources modified after October 21, 2015, 7:28:00 AM, and if the resource has not been modified, it sends a `304 Not Modified` response.

#### 1.2.5. If-None-Match

``` {caption="[Text 13] If-None-Match Header Format"}
If-None-Match: <etag>
``` 

The `If-None-Match` header is used when a client sending a request wants to check the version of a specific resource. [Text 13] shows the format of the `If-None-Match` header.

* `<etag>` : Indicates the version of the resource.

``` {caption="[Text 14] If-None-Match Header Example"}
If-None-Match: "v1.0"
If-None-Match: "v1.1", "v1.2", "v2.0"
```

[Text 14] shows some examples of the `If-None-Match` header. In the first example, if the server has updated the `v1.0` version of the resource requested by the client, it responds with a `200 OK` response along with the updated version's Etag in the `ETag` header. If the `v1.0` version of the resource has not been updated, it sends a `304 Not Modified` response. Multiple Etags can be specified as in the second example. When multiple Etags are specified, the server sends a `304 Not Modified` response even if only one Etag matches.

#### 1.2.6. Accept

``` {caption="[Text 15] Accept Header Format"}
Accept: <media-type>, <media-type>...
```

The `Accept` header indicates the media types that the client sending the request can receive. [Text 15] shows the format of the `Accept` header. Multiple media types can be specified, and each media type is separated by a `,` character.

* `<media-type>` : Indicates the media type.
  * `text/html` : HTML document
  * `application/xhtml+xml` : XHTML document
  * `application/xml` : XML document
  * `*/*` : All media types

``` {caption="[Text 16] Accept Header Example"}
Accept: text/html
Accept: text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8
```

[Text 16] shows some examples of the `Accept` header. The `q` value indicates priority and has a value between 0 and 1. The higher the `q` value, the higher the priority. If there is no `q` value, it is considered as `1`. Therefore, in the second example of [Text 16], `text/html` and `application/xhtml+xml` have the highest priority, followed by `application/xml` and `*/*` in order of decreasing priority.

#### 1.2.7. Accept-Encoding

``` {caption="[Text 17] Accept-Encoding Header Format"}
Accept-Encoding: <encoding-option>, <encoding-option>...
```

The `Accept-Encoding` header indicates the encodings that the client sending the request can receive. [Text 17] shows the format of the `Accept-Encoding` header. Multiple encodings can be specified, and each encoding is separated by a `,` character.

* `<encoding-option>` : Indicates the encoding.
  * `gzip` : gzip encoding
  * `deflate` : deflate encoding
  * `br` : brotli encoding
  * `identity` : No encoding used

``` {caption="[Text 18] Accept-Encoding Header Example"}
Accept-Encoding: gzip;q=0.9,deflate;q=0.8,br;q=1.0
Accept-Encoding: identity
```

[Text 18] shows some examples of the `Accept-Encoding` header. The `q` value indicates priority and has a value between 0 and 1. The higher the `q` value, the higher the priority. If there is no `q` value, it is considered as `1`. Therefore, in the first example of [Text 18], `br` has the highest priority, followed by `gzip` and `deflate` in order of decreasing priority.

#### 1.2.8. Accept-Language

``` {caption="[Text 19] Accept-Language Header Format"}
Accept-Language: <language-range>, <language-range>...
```

The `Accept-Language` header indicates the languages that the client sending the request can receive. [Text 19] shows the format of the `Accept-Language` header. Multiple languages can be specified, and each language is separated by a `,` character.

* `<language-range>` : Indicates the language range.
  * `en-US` : American English
  * `en-GB` : British English
  * `ko` : Korean
  * `*` : All languages

``` {caption="[Text 20] Accept-Language Header Example"}
Accept-Language: en-US,ko;q=0.8
Accept-Language: en-GB,en;q=0.9,ko;q=0.8
```

[Text 20] shows some examples of the `Accept-Language` header. The `q` value indicates priority and has a value between 0 and 1. The higher the `q` value, the higher the priority. If there is no `q` value, it is considered as `1`. Therefore, in the first example of [Text 20], `en-US` has the highest priority, followed by `ko`. In the second example, `en-GB` has the highest priority, followed by `en` and `ko` in order of decreasing priority.

#### 1.2.9. X-Forwarded-For

``` {caption="[Text 21] X-Forwarded-For Header Format"}
X-Forwarded-For: <client-ip>, <proxy-ip>, <proxy-ip>, ...
```

The `X-Forwarded-For` header indicates the IP information of the client sending the request and proxy servers. [Text 21] shows the format of the `X-Forwarded-For` header. It can include one client IP and multiple proxy server IP information.

* `<client-ip>` : Indicates the IP address of the client sending the request.
* `<proxy-ip>` : Indicates the IP address of the proxy server processing the request. If there are multiple proxy servers processing the request, multiple proxy server IPs are attached sequentially in the order they process the request.

``` {caption="[Text 22] X-Forwarded-For Header Example"}
X-Forwarded-For: 203.0.113.45, 10.0.0.1, 192.168.10.2
```

[Text 22] shows some examples of the `X-Forwarded-For` header. It shows that the client's IP address is `203.0.113.45`, the first proxy server's IP address is `10.0.0.1`, and the second proxy server's IP address is `192.168.10.2`.

#### 1.2.10. X-Forwarded-Host

``` {caption="[Text 23] X-Forwarded-Host Header Format"}
X-Forwarded-Host: <host>
```

The `X-Forwarded-Host` header is used to preserve the host information that the client originally requested. This is because the Host header can be changed when routing requests based on the host. [Text 23] shows the format of the `X-Forwarded-Host` header.

* `<host>` : Indicates host information.

``` {caption="[Text 24] X-Forwarded-Host Header Example"}
X-Forwarded-Host: example.com
X-Forwarded-Host: ssup2.com
```

[Text 24] shows some examples of the `X-Forwarded-Host` header.

#### 1.2.11. X-Forwarded-Port

``` {caption="[Text 25] X-Forwarded-Port Header Format"}
X-Forwarded-Port: <port>
```

The `X-Forwarded-Port` header is used to preserve the port information that the client originally requested. This is because the port can be changed as the request passes through CDN and Load Balancer. [Text 25] shows the format of the `X-Forwarded-Port` header.

* `<port>` : Indicates port information.

``` {caption="[Text 26] X-Forwarded-Port Header Example"}
X-Forwarded-Port: 80
X-Forwarded-Port: 443
```

[Text 26] shows some examples of the `X-Forwarded-Port` header.

#### 1.2.12. X-Forwarded-Proto

``` {caption="[Text 27] X-Forwarded-Proto Header Format"}
X-Forwarded-Proto: <protocol>
```

The `X-Forwarded-Proto` header is used to preserve the protocol information that the client originally requested. This is because the protocol information can be changed as the request passes through CDN and Load Balancer. [Text 27] shows the format of the `X-Forwarded-Proto` header.

* `<protocol>` : Indicates protocol information.

``` {caption="[Text 28] X-Forwarded-Proto Header Example"}
X-Forwarded-Proto: http
X-Forwarded-Proto: https
```

[Text 28] shows some examples of the `X-Forwarded-Proto` header.

#### 1.2.13. X-Forwarded-Server

``` {caption="[Text 29] X-Forwarded-Server Header Format"}
X-Forwarded-Server: <server>
```

The `X-Forwarded-Server` header indicates the name of the proxy server that processed the request. [Text 29] shows the format of the `X-Forwarded-Server` header. Even if the request passes through multiple proxy servers, only the name of the last proxy server is included.

* `<server>` : Indicates the server name.

``` {caption="[Text 30] X-Forwarded-Server Header Example"}
X-Forwarded-Server: proxy1.example.com
```

[Text 30] shows some examples of the `X-Forwarded-Server` header.

#### 1.2.14. X-Forwarded-User

``` {caption="[Text 31] X-Forwarded-User Header Format"}
X-Forwarded-User: <user>
```

The `X-Forwarded-User` header indicates the user information that sent the request. [Text 31] shows the format of the `X-Forwarded-User` header.

* `<user>` : Indicates user information.

``` {caption="[Text 32] X-Forwarded-User Header Example"}
X-Forwarded-User: user1
X-Forwarded-User: user2
```

[Text 32] shows some examples of the `X-Forwarded-User` header.

#### 1.2.15. X-Real-IP

``` {caption="[Text 33] X-Real-IP Header Format"}
X-Real-IP: <ip-address>
```

The `X-Real-IP` header indicates the IP address of the client that sent the request. [Text 33] shows the format of the `X-Real-IP` header. It is similar to the `X-Forwarded-For` header but only includes the client's IP address and does not include proxy server IP addresses. It is a header used in Nginx or HAProxy.

* `<ip-address>` : Indicates the IP address.

``` {caption="[Text 34] X-Real-IP Header Example"}  
X-Real-IP: 182.168.1.50
```

[Text 34] shows some examples of the `X-Real-IP` header.

#### 1.2.16. X-Request-ID

``` {caption="[Text 35] X-Request-ID Header Format"}
X-Request-ID: <request-id>
``` 

The `X-Request-ID` header indicates a unique ID representing the request. [Text 35] shows the format of the `X-Request-ID` header. Generally, request IDs are generated in UUID format.

* `<request-id>` : Indicates the request ID.

``` {caption="[Text 36] X-Request-ID Header Example"}
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
```

[Text 36] shows some examples of the `X-Request-ID` header.

#### 1.2.17. X-Trace-ID

``` {caption="[Text 37] X-Trace-ID Header Format"}
X-Trace-ID: <trace-id>
```

The `X-Trace-ID` header indicates the trace ID of the server processing the request. [Text 37] shows the format of the `X-Trace-ID` header.

* `<trace-id>` : Indicates the trace ID.

``` {caption="[Text 38] X-Trace-ID Header Example"} 
X-Trace-ID: 550e8400-e29b-41d4-a716-446655440000
```

[Text 38] shows some examples of the `X-Trace-ID` header.

### 1.3. Response Header

#### 1.3.1. Server

``` {caption="[Text 39] Server Header Format"}
Server: <server>
```

The `Server` header indicates the name of the server software that processed the request. [Text 39] shows the format of the `Server` header.

* `<server>` : Indicates the server software name.

``` {caption="[Text 40] Server Header Example"}
Server: nginx/1.23.1
Server: Apache/2.4.54
```

[Text 40] shows some examples of the `Server` header.

#### 1.3.2. Content-Type

``` {caption="[Text 41] Content-Type Header Format"}
Content-Type: <media-type>
```

The `Content-Type` header indicates the media type of the response. [Text 41] shows the format of the `Content-Type` header.

* `<media-type>` : Indicates the media type.
 * text/html : HTML document
 * text/plain : Text document
 * application/json : JSON document
 * image/png : PNG image
 * image/jpeg : JPEG image
 * image/gif : GIF image
 * image/webp : WebP image

``` {caption="[Text 42] Content-Type Header Example"}
Content-Type: text/html
Content-Type: text/plain
Content-Type: application/json
Content-Type: image/png
Content-Type: image/jpeg
```

[Text 42] shows some examples of the `Content-Type` header.

#### 1.3.3. Content-Length

``` {caption="[Text 43] Content-Length Header Format"}
Content-Length: <length>
```

The `Content-Length` header indicates the length of the response. [Text 43] shows the format of the `Content-Length` header.

* `<length>` : Indicates the length. The unit is bytes.

``` {caption="[Text 44] Content-Length Header Example"}
Content-Length: 0
Content-Length: 1024
Content-Length: 512
```

[Text 44] shows some examples of the `Content-Length` header.

#### 1.3.4. Content-Encoding

``` {caption="[Text 45] Content-Encoding Header Format"}
Content-Encoding: <encoding>
```

The `Content-Encoding` header indicates the compression method of the response. [Text 45] shows the format of the `Content-Encoding` header.

* `<encoding>` : Indicates the compression method.
 * `gzip` : gzip compression
 * `deflate` : deflate compression
 * `br` : brotli compression
 * `identity` : No compression

``` {caption="[Text 46] Content-Encoding Header Example"}
Content-Encoding: gzip
Content-Encoding: deflate
Content-Encoding: br
Content-Encoding: identity
```

[Text 46] shows some examples of the `Content-Encoding` header.

#### 1.3.5. Content-Language

``` {caption="[Text 47] Content-Language Header Format"}
Content-Language: <language>
```

The `Content-Language` header indicates the language of the response. [Text 47] shows the format of the `Content-Language` header.

* `<language>` : Indicates the language.
  * `en-US` : American English
  * `en-GB` : British English
  * `ko` : Korean

``` {caption="[Text 48] Content-Language Header Example"}
Content-Language: en-US
Content-Language: en-GB
Content-Language: ko
```

[Text 48] shows some examples of the `Content-Language` header.

#### 1.3.6. Content-Location

``` {caption="[Text 49] Content-Location Header Format"}
Content-Location: <location>
```

The `Content-Location` header indicates the actual location of the resource when the location of the resource requested by the client and the actual resource are different. [Text 49] shows the format of the `Content-Location` header.

* `<location>` : Indicates the actual location of the resource.

``` {caption="[Text 50] Content-Location Header Language Example"}
# Request
GET /about HTTP/1.1
Host: example.com
Accept-Language: ko

# Response
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Location: /about_ko.html
```

``` {caption="[Text 51] Content-Location Header API Example"}
# Request
GET /api/v1/users/latest HTTP/1.1
Host: api.example.com

# Response
HTTP/1.1 200 OK
Content-Type: application/json
Content-Location: /api/v1/users/v5
```

[Text 50] shows a case where the client requests the `/about` resource with `Accept-Language: ko` and receives the Korean version `/about_ko.html`. [Text 51] shows a case where the client requests the `/api/v1/users/latest` resource and receives the latest version `/api/v1/users/v5`. Both show that the location of the originally requested resource has changed.

#### 1.3.8. Expires

``` {caption="[Text 52] Expires Header Format"}
Expires: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

The `Expires` header indicates the date and time when the resource expires. [Text 52] shows the format of the `Expires` header. It is similar to the `Cache-Control` header, but while the `Cache-Control` header indicates relative time, the `Expires` header indicates absolute time.

* `<day-name>` : Indicates the day of the week, using strings `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
* `<day>` : Indicates the day.
* `<month>` : Indicates the month, using strings `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec`.
* `<year>` : Indicates the year.
* `<hour>` : Indicates the hour.
* `<minute>` : Indicates the minute.
* `<second>` : Indicates the second.
* `GMT` : Indicates Greenwich Mean Time, always using GMT time.

``` {caption="[Text 53] Expires Header Example"}
Expires: Wed, 21 Oct 2015 07:28:00 GMT
```

[Text 53] shows an example of the `Expires` header.

#### 1.3.9. Last-Modified

``` {caption="[Text 54] Last-Modified Header Format"}
Last-Modified: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

The `Last-Modified` header indicates the date and time when the resource was last modified. [Text 54] shows the format of the `Last-Modified` header. Generally, clients use the date and time values of the `Last-Modified` header to generate the `If-Modified-Since` header and make requests.

* `<day-name>` : Indicates the day of the week, using strings `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
* `<day>` : Indicates the day.
* `<month>` : Indicates the month, using strings `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec`.
* `<year>` : Indicates the year.
* `<hour>` : Indicates the hour.
* `<minute>` : Indicates the minute.
* `<second>` : Indicates the second.
* `GMT` : Indicates Greenwich Mean Time, always using GMT time.

``` {caption="[Text 55] Last-Modified Header Example"}
Last-Modified: Wed, 21 Oct 2015 07:28:00 GMT
```

[Text 55] shows an example of the `Last-Modified` header.

#### 1.3.10. ETag

``` {caption="[Text 56] ETag Header Format"}
ETag: <etag>
```

The `ETag` header indicates a unique identifier for the resource. [Text 56] shows the format of the `ETag` header. Generally, clients use the value of the `ETag` header to generate the `If-None-Match` header and make requests.

* `<etag>` : Indicates a unique identifier for the resource.

``` {caption="[Text 57] ETag Header Example"}
ETag: "v1.0"
ETag: "v1.1"
```

[Text 57] shows examples of the `ETag` header.

#### 1.3.11. Access-Control-Allow-Origin

``` {caption="[Text 58] Access-Control-Allow-Origin Header Format"}
Access-Control-Allow-Origin: <origin>
```

The `Access-Control-Allow-Origin` header is used when allowing requests only for specific origins through CORS techniques. [Text 58] shows the format of the `Access-Control-Allow-Origin` header.

* `<origin>` : Indicates the allowed origin.

``` {caption="[Text 59] Access-Control-Allow-Origin Header Example"}
Access-Control-Allow-Origin: *
Access-Control-Allow-Origin: https://example.com
```

[Text 59] shows some examples of the `Access-Control-Allow-Origin` header. The first example shows allowing requests for all origins. The second example shows allowing requests only for the `https://example.com` origin.

#### 1.3.12. Access-Control-Allow-Methods

``` {caption="[Text 60] Access-Control-Allow-Methods Header Format"}
Access-Control-Allow-Methods: <method>
```

The `Access-Control-Allow-Methods` header is used when allowing requests only for specific methods through CORS. [Text 60] shows the format of the `Access-Control-Allow-Methods` header.

* `<method>` : Indicates the allowed method. When allowing multiple methods, they are separated by commas (`,`).

``` {caption="[Text 61] Access-Control-Allow-Methods Header Example"}
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Methods: GET, POST
```

[Text 61] shows some examples of the `Access-Control-Allow-Methods` header.

#### 1.3.13. Access-Control-Allow-Headers

``` {caption="[Text 62] Access-Control-Allow-Headers Header Format"}
Access-Control-Allow-Headers: <header>
```

The `Access-Control-Allow-Headers` header is used when allowing requests only for specific headers through CORS. [Text 62] shows the format of the `Access-Control-Allow-Headers` header.

* `<header>` : Indicates the allowed header.

``` {caption="[Text 63] Access-Control-Allow-Headers Header Example"}
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Headers: X-Custom-Header
```

[Text 63] shows some examples of the `Access-Control-Allow-Headers` header.

#### 1.3.14. Access-Control-Allow-Credentials

``` {caption="[Text 64] Access-Control-Allow-Credentials Header Format"}
Access-Control-Allow-Credentials: <boolean>
```

The `Access-Control-Allow-Credentials` header is used when allowing requests with specific credentials through CORS. [Text 64] shows the format of the `Access-Control-Allow-Credentials` header.

* `<boolean>` : Indicates `true` or `false`.

``` {caption="[Text 65] Access-Control-Allow-Credentials Header Example"}
Access-Control-Allow-Credentials: true
```

[Text 65] shows an example of the `Access-Control-Allow-Credentials` header.

#### 1.3.15. Access-Control-Allow-Max-Age

``` {caption="[Text 66] Access-Control-Allow-Max-Age Header Format"}
Access-Control-Allow-Max-Age: <max-age>
``` 

The `Access-Control-Allow-Max-Age` header is used when allowing requests for a specific time through CORS. [Text 66] shows the format of the `Access-Control-Allow-Max-Age` header.

* `<max-age>` : Indicates the allowed time. The unit is seconds.

``` {caption="[Text 67] Access-Control-Allow-Max-Age Header Example"}
Access-Control-Allow-Max-Age: 3600
```

[Text 67] shows an example of the `Access-Control-Allow-Max-Age` header.

#### 1.3.16. Location

``` {caption="[Text 68] Location Header Format"}
Location: <location>
```

The `Location` header indicates the location of the moved resource when the location of the requested resource has changed. [Text 68] shows the format of the `Location` header.

* `<location>` : Indicates the location of the moved resource.

``` {caption="[Text 69] Location Header Example"}
# Request
GET /old-blog-post HTTP/1.1
Host: example.com

# Response
HTTP/1.1 301 Moved Permanently
Location: /new-blog-post
```

[Text 69] shows an example of the `Location` header. It shows a case where the `/old-blog-post` resource was requested but the moved `/new-blog-post` resource is received. It is generally used together with 3XX responses.

## 2. References

* HTTP Header : [https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
* HTTP Cache-Control : [https://toss.tech/article/smart-web-service-cache](https://toss.tech/article/smart-web-service-cache)
* HTTP Cache-Control : [https://hudi.blog/http-cache/](https://hudi.blog/http-cache/)
