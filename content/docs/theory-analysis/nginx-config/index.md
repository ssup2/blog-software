---
title: Nginx Config
---


Nginx의 Config를 분석한다.

## 1. Nginx Config

```text {caption="[File 1] nginx.conf", linenos=table}
user       nginx;  ## Default: nobody
worker-processes  5;  ## Default: 1
error-log  logs/error.log;
pid        logs/nginx.pid;
worker-rlimit-nofile 8192;

events {
  worker-connections  4096;  ## Default: 1024
}

http {
  include    conf/mime.types;
  include    /etc/nginx/proxy.conf;
  include    /etc/nginx/fastcgi.conf;
  index    index.html index.htm index.php;

  default-type application/octet-stream; ## Default: text/plain
  log-format   main '$remote-addr - $remote-user [$time-local]  $status '
    '"$request" $body-bytes-sent "$http-referer" '
    '"$http-user-agent" "$http-x-forwarded-for"';
  access-log   logs/access.log  main;
  sendfile     on;
  tcp-nopush   on;
  server-names-hash-bucket-size 128; # this seems to be required for some vhosts

  server { # php/fastcgi
    listen       80;
    server-name  domain1.com www.domain1.com;
    access-log   logs/domain1.access.log  main;

    location ~ \.php$ {
      fastcgi-pass   127.0.0.1:1025;
    }
  }

  server { # simple reverse-proxy
    listen       80;
    server-name  domain2.com www.domain2.com;
    access-log   logs/domain2.access.log  main;

    # serve static files
    location ~ ^/(images|javascript|js|css|flash|media|static)/  {
      root    /var/www/virtual/big.server.com/htdocs;
      expires 30d;
    }

    # pass requests for dynamic content to rails/turbogears/zope, et al
    location / {
      proxy-pass      http://127.0.0.1:8080;
    }
  }

  upstream big-server-com {
    server 127.0.0.3:8000 weight=5;
    server 127.0.0.3:8001 weight=5;
    server 192.168.0.1:8000;
    server 192.168.0.1:8001;
  }

  server { # simple load balancing
    listen          80;
    server-name     big.server.com;
    access-log      logs/big.server.access.log main;

    location / {
      proxy-pass      http://big-server-com;
    }
  }
}
```

```text {caption="[File 2] mime.types", linenos=table}
types {
  text/html                             html htm shtml;
  text/css                              css;
  text/xml                              xml rss;
  image/gif                             gif;
  image/jpeg                            jpeg jpg;
  application/x-javascript              js;
  text/plain                            txt;
  text/x-component                      htc;
  text/mathml                           mml;
  image/png                             png;
  image/x-icon                          ico;
  image/x-jng                           jng;
  image/vnd.wap.wbmp                    wbmp;
  application/java-archive              jar war ear;
  application/mac-binhex40              hqx;
  application/pdf                       pdf;
  application/x-cocoa                   cco;
  application/x-java-archive-diff       jardiff;
  application/x-java-jnlp-file          jnlp;
  application/x-makeself                run;
  application/x-perl                    pl pm;
  application/x-pilot                   prc pdb;
  application/x-rar-compressed          rar;
  application/x-redhat-package-manager  rpm;
  application/x-sea                     sea;
  application/x-shockwave-flash         swf;
  application/x-stuffit                 sit;
  application/x-tcl                     tcl tk;
  application/x-x509-ca-cert            der pem crt;
  application/x-xpinstall               xpi;
  application/zip                       zip;
  application/octet-stream              deb;
  application/octet-stream              bin exe dll;
  application/octet-stream              dmg;
  application/octet-stream              eot;
  application/octet-stream              iso img;
  application/octet-stream              msi msp msm;
  audio/mpeg                            mp3;
  audio/x-realaudio                     ra;
  video/mpeg                            mpeg mpg;
  video/quicktime                       mov;
  video/x-flv                           flv;
  video/x-msvideo                       avi;
  video/x-ms-wmv                        wmv;
  video/x-ms-asf                        asx asf;
  video/x-mng                           mng;
}
```

```text {caption="[File 3] proxy.conf", linenos=table}
proxy-redirect          off;
proxy-set-header        Host            $host;
proxy-set-header        X-Real-IP       $remote-addr;
proxy-set-header        X-Forwarded-For $proxy-add-x-forwarded-for;
client-max-body-size    10m;
client-body-buffer-size 128k;
proxy-connect-timeout   90;
proxy-send-timeout      90;
proxy-read-timeout      90;
proxy-buffers           32 4k;
```

```text {caption="[File 4] fastcgi.conf", linenos=table}
fastcgi-param  SCRIPT-FILENAME    $document-root$fastcgi-script-name;
fastcgi-param  QUERY-STRING       $query-string;
fastcgi-param  REQUEST-METHOD     $request-method;
fastcgi-param  CONTENT-TYPE       $content-type;
fastcgi-param  CONTENT-LENGTH     $content-length;
fastcgi-param  SCRIPT-NAME        $fastcgi-script-name;
fastcgi-param  REQUEST-URI        $request-uri;
fastcgi-param  DOCUMENT-URI       $document-uri;
fastcgi-param  DOCUMENT-ROOT      $document-root;
fastcgi-param  SERVER-PROTOCOL    $server-protocol;
fastcgi-param  GATEWAY-INTERFACE  CGI/1.1;
fastcgi-param  SERVER-SOFTWARE    nginx/$nginx-version;
fastcgi-param  REMOTE-ADDR        $remote-addr;
fastcgi-param  REMOTE-PORT        $remote-port;
fastcgi-param  SERVER-ADDR        $server-addr;
fastcgi-param  SERVER-PORT        $server-port;
fastcgi-param  SERVER-NAME        $server-name;

fastcgi-index  index.php;

fastcgi-param  REDIRECT-STATUS    200;
```

nginx.conf 파일은 Nginx 주요 설정이 포함되어 있는 파일이다. [File 1]은 nginx.conf 예제를 나타내고 있으며, [File 2 ~ 4]를 Include하고 있다. [File 1 ~ 4]의 설정 내용을 분석한다.

### 1.1. nginx.conf Top

```text {caption="[File 1-1] nginx.conf Top", linenos=table}
user       nginx;  ## Default: nobody
worker-processes  5;  ## Default: 1
error-log  logs/error.log;
pid        logs/nginx.pid;
worker-rlimit-nofile 8192;
```

* user : Nginx Worker Process의 User를 의미한다. Worker Process의 권한을 설정할때 이용한다.
* worker-processes : Nginx Worker Process의 개수를 의미한다. 기본값은 1이다.
* error-log : Nginx Error Log의 경로를 의미한다.
* pid : Nginx Master Process의 PID가 저장되는 Log의 경로를 의미한다.
* worker-rlimit-nofile : Nginx Worker Process가 이용할 수 있는 최대 File Desciptor의 개수를 의미한다. 일반적으로 Worker Process 갖을 수 있는 최대 Connection 개수의 2배를 설정한다. 기본값은 1024이다.

### 1.2. events Block

```text {caption="[File 1-2] nginx.conf events Block", linenos=table}
events {
  worker-connections  4096;  ## Default: 1024
}
```

events Block은 Network Connection 처리 관련 설정을 포함한다.

* worker-connections : Nginx Worker Process가 동시에 갖을 수 있는 최대 Connection의 개수를 의미한다.

### 1.3. http Block

http Block은 HTTP, HTTPS 관련 설정을 포함하고 있다.

#### 1.3.1 http Block Top

```text {caption="[File 1-3] nginx.conf http Block Top-1", linenos=table}
http {
  include    conf/mime.types;
  include    /etc/nginx/proxy.conf;
  include    /etc/nginx/fastcgi.conf;
  index    index.html index.htm index.php;
```

* include mime.types : [File 2]를 Include 한다. Nginx에서 이용하기 위한 MIME(Multipurpose Internet Mail Extensions)를 설정한다. MIME은 Image와 영상과 같은 파일을 Text 형태로 전송하기 위한 Encoding/Decoding 기법을 의미한다. 
* include proxy.conf : [File 3]을 Include 한다. Nginx의 Reverse Proxy 관련 설정을 적용한다.
* include fastcgi.conf : [File 4]를 Include 한다. FastCGI 관련 설정을 적용한다.
* index : Index Page를 의미한다.

```text {caption="[File 1-3] nginx.conf http Block Top-2", linenos=table}
  default-type application/octet-stream; ## Default: text/plain
  log-format   main '$remote-addr - $remote-user [$time-local]  $status '
    '"$request" $body-bytes-sent "$http-referer" '
    '"$http-user-agent" "$http-x-forwarded-for"';
  access-log   logs/access.log  main;
  sendfile     on;
  tcp-nopush   on;
  server-names-hash-bucket-size 128; # this seems to be required for some vhosts
```

* default-type : Default MIME를 의미한다.
* log-format : HTTP, HTTPS 처리 Log의 format을 의미한다. 기본값은 text/plain이다.
* access-log : HTTP, HTTPS 처리 Log의 경로를 의미한다.
* sendfile : Static File (Image, Video) 전송시 sendfile() System Call 이용 유무를 의미한다. sendfile() System Call은 2개의 File Descriptor 사이의 Data 전송시 Kernel Level 안에서만 Zero Copy를 기반으로 수행하기 때문에 기존의 read()/write() System Call에 비해서 빠르다.
* tcp-nopush : sendfile() System Call 이용시 TCP Socket에 TCP-CORK 설정 유무를 의미한다. TCP-CORK은 TCP Socket으로 Packet 전송시 Packet을 TCP Socket Buffer에 모았다가 한번에 보내도록 설정한다. sendfile on으로 설정되어 있을 경우에만 의미있다.
* server-names-hash-bucket-size : Nginx에 등록할 수 있는 최대 Server Name의 개수를 의미한다.

```text {caption="[File 3-1] proxy.conf Top", linenos=table}
proxy-redirect          off;
proxy-set-header        Host            $host;
proxy-set-header        X-Real-IP       $remote-addr;
proxy-set-header        X-Forwarded-For $proxy-add-x-forwarded-for;
client-max-body-size    10m;
client-body-buffer-size 128k;
```

* proxy-redirect : Nginx의 Proxied Server로부터 받은 Response의 HTTP Location, Refresh Header를 변경유무를 의미한다. HTTP Location Header는 Resource의 위치가 변경되었을때 변경된 Resource의 URL을 갖고 있는 Header이다. HTTP Refresh Header는 Client가 Refresh를 하도록 명령하는 Header이다.
* proxy-set-header Host : HTTP Host Header를 설정한다. HTTP Host Header는 어느 Virtual Host (Server)에 의해서 처리되었는지를 저장하는 Header이다.
* proxy-set-header X-Real-IP : HTTP X-Real-IP Header를 설정한다. HTTP X-Real-IP Header는 Client의 IP 정보를 저장하는 Header이다.
* proxy-set-header X-Forwarded-For : HTTP X-Forwarded-For Header를 설정한다. HTTP X-Forwarded-For Header는 Client의 IP 정보를 저장하는 Header이다.
* client-max-body-size : 허용되는 Client Request의 최대 Body Size를 의미한다.
* client-body-buffer-size : Client Request의 Body를 위한 Read Buffer의 크기를 의미한다.

```text {caption="[File 3-2] proxy.conf Bottom", linenos=table}
proxy-connect-timeout   90;
proxy-send-timeout      90;
proxy-read-timeout      90;
proxy-buffers           32 4k;
```

* proxy-connect-timeout : TCP Connection이 구축되는데 필요한 최대 대기 시간을 의미한다.
* proxy-send-timeout : Proxied Server에 Client의 Request를 전송하는데 필요한 최대 대기 시간을 의미한다.
* proxy-read-timeout : Proxied Server로부터 Response를 수신하는데 필요한 최대 대기 시간을 의미한다.
* proxy-buffers : Proxied Server와의 Connection 한개당 이용하는 Read Buffer의 크기를 의미한다. 순서대로 Buffer의 개수와 각 Buffer의 크기를 의미한다.

### 1.3.2. http Block server Block

하나의 server Block은 하나의 Virtual Server를 의미한다. Virtual Server는 Apache HTTP Server의 Virtual Host와 동일한 의미를 갖는다.

```text {caption="[File 1-4] nginx.conf http Block server Block-1", linenos=table}
  server { # php/fastcgi
    listen       80;
    server-name  domain1.com www.domain1.com;
    access-log   logs/domain1.access.log  main;

    location ~ \.php$ {
      fastcgi-pass   127.0.0.1:1025;
    }
  }
```

FastCGI를 이용하는 PHP Application의 Reverse Proxy로 동작하도록 설정되어 있다.

* listen : Virtual Server의 Listen Port를 의미한다.
* server-name : Virtual Server의 이름을 의미한다. 주로 Domain 이름으로 설정한다.
* access-log : Virtual Server 관련 Log의 경로를 의미한다.
* location Block : FastCGI를 이용하는 PHP Application을 이용하도록 설정되어 있다.

```text {caption="[File 1-5] nginx.conf http Block server Block-2", linenos=table}
  server { # simple reverse-proxy
    listen       80;
    server-name  domain2.com www.domain2.com;
    access-log   logs/domain2.access.log  main;

    # serve static files
    location ~ ^/(images|javascript|js|css|flash|media|static)/  {
      root    /var/www/virtual/big.server.com/htdocs;
      expires 30d;
    }

    # pass requests for dynamic content to rails/turbogears/zope, et al
    location / {
      proxy-pass      http://127.0.0.1:8080;
    }
  }
```

Reverse Proxy로 동작하도록 설정되어 있다.

* First location Block : root 경로의 Static File들을 제공하도록 설정되어 있다.
* Second location Block : 127.0.0.1:8080 Port의 Reverse Proxy로 동작하도록 설정되어 있다.

```text {caption="[File 1-5] nginx.conf http Block server Block-3", linenos=table}
  upstream big-server-com {
    server 127.0.0.3:8000 weight=5;
    server 127.0.0.3:8001 weight=5;
    server 192.168.0.1:8000;
    server 192.168.0.1:8001;
  }

  server { # simple load balancing
    listen          80;
    server-name     big.server.com;
    access-log      logs/big.server.access.log main;

    location / {
      proxy-pass      http://big-server-com;
    }
  }
```

Load Balancing을 수행하는 Reverse Proxy로 동작하도록 설정되어 있다.

* upstream Block : Nginx가 수행하는 Load Balancing으로 인해서 분배될 Packet이 전달되는 Target Server들을 의미한다.
* location Block : upstream Block에서 설정한 Load Balancing Target Server들을 이용하여 Load Balancing을 수행하도록 설정되어 있다.

## 2. 참조

* [https://www.nginx.com/resources/wiki/start/topics/examples/full/](https://www.nginx.com/resources/wiki/start/topics/examples/full/)
* [https://stackoverflow.com/questions/37591784/nginx-worker-rlimit-nofile](https://stackoverflow.com/questions/37591784/nginx-worker-rlimit-nofile)
* [https://charsyam.wordpress.com/2019/03/14/%EC%9E%85%EA%B0%9C%EB%B0%9C-nagle-%EC%95%8C%EA%B3%A0%EB%A6%AC%EC%A6%98%EA%B3%BC-tcp-cork/](https://charsyam.wordpress.com/2019/03/14/%EC%9E%85%EA%B0%9C%EB%B0%9C-nagle-%EC%95%8C%EA%B3%A0%EB%A6%AC%EC%A6%98%EA%B3%BC-tcp-cork/)