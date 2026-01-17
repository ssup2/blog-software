---
title: nc (netcat)
---

This document summarizes the usage of `nc` (netcat) for sending and receiving data from network connections.

## 1. nc

nc (netcat) is a tool for sending and receiving data from network connections.

### 1.1. nc [IP] [Port]

```shell {caption="[Shell 1] netcat [IP] [Port]"}
$ nc 10.0.0.10 80
GET /
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

Establishes a connection with the given IP and Port, and sends/receives data through the established connection. [shell 1] shows the output of `netcat [IP] [Port]` connecting to nginx and receiving the / (root) page from nginx.

### 1.2. nc -zv [IP] [Port]

Only establishes a connection with the given IP and Port without sending any data.

### 1.3. nc -l [Port]

Listens and waits on the given Port.

## 2. References

* [https://m.blog.naver.com/PostView.nhn?blogId=tawoo0&logNo=221564885896&proxyReferer=https:%2F%2Fwww.google.com%2F](https://m.blog.naver.com/PostView.nhn?blogId=tawoo0&logNo=221564885896&proxyReferer=https:%2F%2Fwww.google.com%2F)

