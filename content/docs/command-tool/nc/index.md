---
title: nc (netcat)
---

Network Connection으로부터 Data를 송수신하는 nc (netcat)의 사용법을 정리한다.

## 1. nc

nc (netcat)는 Network Connection으로부터 Data를 송수신하는 Tool이다.

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

입력 받은 IP, Port와 Connection을 맺고, 맺은 Connection을 통해 Data를 송수신한다. [shell 1]은 `netcat [IP] [Port]`를 이용하여 nginx에 접속하고, nginx로부터 / (root) Page를 수신하는 모습을 나타내고 있다.

### 1.2. nc -zv [IP] [Port]

입력 받은 IP, Port와의 Connection만 맺고 어떠한 Data도 전송하지 않는다. 

### 1.3. nc -l [Port]

입력 받은 Port로 Listen하고 대기 한다.

## 2. 참조

* [https://m.blog.naver.com/PostView.nhn?blogId=tawoo0&logNo=221564885896&proxyReferer=https:%2F%2Fwww.google.com%2F](https://m.blog.naver.com/PostView.nhn?blogId=tawoo0&logNo=221564885896&proxyReferer=https:%2F%2Fwww.google.com%2F)