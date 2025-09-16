---
title: HTTP Status Code
---

## 1. HTTP Status Code

### 1.1. 1xx Informational

Used to communicate intermediate status of requests from the server to the client.

#### 1.1.1. 100 Continue

Used to communicate temporary information to the client that the request can continue.

#### 1.1.2. 101 Switching Protocols

Indicates that the server will use the protocol requested by the client. Typically used when switching from HTTP to WebSocket protocol.

### 1.2. 2xx Success

Indicates that the server successfully received the request and successfully processed the request.

#### 1.2.1. 200 OK

Indicates that the server successfully received the request and successfully sent a response after processing the request.

#### 1.2.2. 201 Created

Indicates that the server successfully received the request and created a new resource according to the request.

#### 1.2.3. 202 Accepted

Indicates that the server successfully received the request and is currently processing the request. Used for asynchronously processed requests.

#### 1.2.4. 203 Non-Authoritative Information

Indicates that the server successfully received the request and sent a response after processing the request, but an intermediate proxy server modified the response.

#### 1.2.5. 204 No Content

Indicates that the server successfully received the request and processed it well, but there is no content to respond with. Mainly used as a response to resource deletion requests.

#### 1.2.6. 205 Reset Content

Indicates that the server successfully received the request and processed it well, so the client should reset input forms such as forms and views.

#### 1.2.7. 206 Partial Content

Indicates that the server successfully received the request and is responding with only a portion of the requested resource.

### 1.3. 3xx Redirection

Used when the server successfully received the request but the location of the requested resource has changed. The changed resource location is communicated through the `Location` header.

#### 1.3.1. 301 Moved Permanently

Used when the server successfully received the request but the location of the requested resource has been permanently changed. Generally, the server sends the 301 status code along with the moved resource location in the `Location` header, and the client makes another request to the moved resource location. Since the resource location has been permanently changed, the client must send requests to the moved location in the future. The client should not change the request method in principle, but some browsers may change the method to `GET` when sending requests.

#### 1.3.2. 302 Found

Used when the server successfully received the request but the location of the requested resource has been temporarily changed. Generally, the server sends the 302 status code along with the moved resource location in the `Location` header, and the client makes another request to the moved resource location. Since the resource location has been temporarily changed, the client should send requests to the original resource location in the future. The client should not change the request method in principle, but some browsers may change the method to `GET` when sending requests.

#### 1.3.3. 303 See Other

When a client requests resource creation from the server, the server creates the requested resource and sends the location of the created resource along with the 303 status code in the `Location` header. The client then must use the `GET` method to obtain the resource at the moved location.

#### 1.3.4. 307 Temporary Redirect

Used when the server successfully received the request but the location of the requested resource has been temporarily changed. Similar to `302 Found` but differs in that the client's request method is not changed.

#### 1.3.5. 308 Permanent Redirect

Used when the server successfully received the request but the location of the requested resource has been permanently changed. Similar to `301 Moved Permanently` but differs in that the client's request method is not changed.

### 1.4. 4xx Client Error

4XX status codes indicate that the request was incorrect and the server could not process the request.

#### 1.4.1. 400 Bad Request

Indicates that the server successfully received the request but could not process it because the request was incorrect. Generally used when headers, query parameters, body, etc. are incorrect. Also used when the request is too long or has encoding issues.

#### 1.4.2. 401 Unauthorized

Indicates that the server successfully received the request but it is not an authenticated request.

#### 1.4.3. 403 Forbidden

Indicates that the server successfully received the request and it is an authenticated request, but there is no access permission for the requested resource.

#### 1.4.4. 404 Not Found

Used when the server successfully received the request but the requested resource does not exist.

#### 1.4.5. 405 Method Not Allowed

Used when the server successfully received the request but the method used is not available for the requested resource.

#### 1.4.6. 406 Not Acceptable

Used when the server successfully received the request but does not support the media type specified in the `Accept` header of the request.

#### 1.4.7. 407 Proxy Authentication Required

Indicates that the proxy successfully received the request before the server but it is not an authenticated request. Used when authentication is required from the proxy.

#### 1.4.8. 408 Request Timeout

Used when the server could not fully receive the client's request. Generally occurs when the request takes too long and exceeds the server's timeout period.

#### 1.4.9. 409 Conflict

Used when the server successfully received the request but a conflict occurred with another request. Occurs when multiple clients simultaneously modify one resource or simultaneously create resources.

### 1.5. 5xx Server Error

5XX status codes are used when an error occurs on the server and the request cannot be processed.

#### 1.5.1. 500 Internal Server Error

Used when the server successfully received the request but an error occurred on the server during request processing, preventing the request from being processed.

#### 1.5.2. 501 Not Implemented

Used when the server successfully received the request but cannot process it because the server does not support the request.

#### 1.5.3. 502 Bad Gateway

Used when a proxy receives an incorrect response from the server. Occurs when a server error occurs, or when network issues between the proxy and server prevent the proxy from properly delivering requests to the server, or conversely, when the proxy cannot properly deliver the server's response.

#### 1.5.4. 503 Service Unavailable

Used when the server is currently unable to properly process requests. Generally occurs when the server is overloaded or under maintenance.

#### 1.5.5. 504 Gateway Timeout

Used when a proxy does not receive a response from the server within a specific time period. Generally occurs due to server overload or network issues between the proxy and server.

#### 1.5.6. 505 HTTP Version Not Supported

Used when the server does not support the requested HTTP version.

#### 1.5.7. 506 Variant Also Negotiates

Used when the server cannot process the request by referencing header information such as `Accept`, `Accept-Language`, `Accept-Charset`, `Accept-Encoding`, etc.

#### 1.5.8. 507 Insufficient Storage

Used when the server successfully received the request but cannot process it due to insufficient disk space on the server.

#### 1.5.9. 508 Loop Detected

Used when the server successfully received the request but a circular reference occurred during request processing.

#### 1.5.10. 510 Not Extended

Used when the server successfully received the request but cannot process it because the request does not contain HTTP extension content.

#### 1.5.11. 511 Network Authentication Required

Used when the server successfully received the request but network authentication is required during request processing.

#### 1.5.12. 599 Network Connect Timeout Error

Used when the server successfully received the request but the network connection was lost during request processing.

## 2. References

* HTTP Status Code : [https://developer.mozilla.org/ko/docs/Web/HTTP/Reference/Status](https://developer.mozilla.org/ko/docs/Web/HTTP/Reference/Status)
