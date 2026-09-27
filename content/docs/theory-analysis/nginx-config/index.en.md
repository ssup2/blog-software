---
title: Nginx Config
---


This post analyzes the Config of Nginx.

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

The `nginx.conf` file contains the main configuration of Nginx. [File 1] shows an example of `nginx.conf`, and it Includes [File 2 ~ 4]. This post analyzes the configuration contents of [File 1 ~ 4].

### 1.1. nginx.conf Top

```text {caption="[File 1-1] nginx.conf Top", linenos=table}
user       nginx;  ## Default: nobody
worker-processes  5;  ## Default: 1
error-log  logs/error.log;
pid        logs/nginx.pid;
worker-rlimit-nofile 8192;
```

* `user` : Specifies the User of the Nginx Worker Processes. It is used to set the permissions of the Worker Processes.
* `worker-processes` : Specifies the number of Nginx Worker Processes. The default value is 1.
* `error-log` : Specifies the path of the Nginx Error Log.
* `pid` : Specifies the path of the Log where the PID of the Nginx Master Process is stored.
* `worker-rlimit-nofile` : Specifies the maximum number of File Descriptors that a Nginx Worker Process can use. It is generally set to twice the maximum number of Connections that a Worker Process can have. The default value is 1024.

### 1.2. events Block

```text {caption="[File 1-2] nginx.conf events Block", linenos=table}
events {
  worker-connections  4096;  ## Default: 1024
}
```

The `events` Block contains configuration related to Network Connection handling.

* `worker-connections` : Specifies the maximum number of Connections that a Nginx Worker Process can have simultaneously.

### 1.3. http Block

The `http` Block contains HTTP and HTTPS related configuration.

#### 1.3.1 http Block Top

```text {caption="[File 1-3] nginx.conf http Block Top-1", linenos=table}
http {
  include    conf/mime.types;
  include    /etc/nginx/proxy.conf;
  include    /etc/nginx/fastcgi.conf;
  index    index.html index.htm index.php;
```

* `include mime.types` : Includes [File 2]. It configures the MIME (Multipurpose Internet Mail Extensions) types used by Nginx. MIME refers to an Encoding/Decoding technique for transmitting files such as Images and Videos in Text form. 
* `include proxy.conf` : Includes [File 3]. It applies the Reverse Proxy related configuration of Nginx.
* `include fastcgi.conf` : Includes [File 4]. It applies the FastCGI related configuration.
* `index` : Specifies the Index Page.

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

* `default-type` : Specifies the Default MIME type.
* `log-format` : Specifies the format of the HTTP and HTTPS processing Log. The default value is `text/plain`.
* `access-log` : Specifies the path of the HTTP and HTTPS processing Log.
* `sendfile` : Specifies whether to use the `sendfile()` System Call when transmitting Static Files (Image, Video). The `sendfile()` System Call is faster than the conventional `read()`/`write()` System Calls because Data transfer between two File Descriptors is performed based on Zero Copy entirely at the Kernel Level.
* `tcp-nopush` : Specifies whether to set `TCP-CORK` on the TCP Socket when using the `sendfile()` System Call. `TCP-CORK` makes Packets sent to the TCP Socket accumulate in the TCP Socket Buffer and be sent at once. It is meaningful only when `sendfile on` is set.
* `server-names-hash-bucket-size` : Specifies the maximum number of Server Names that can be registered in Nginx.

```text {caption="[File 3-1] proxy.conf Top", linenos=table}
proxy-redirect          off;
proxy-set-header        Host            $host;
proxy-set-header        X-Real-IP       $remote-addr;
proxy-set-header        X-Forwarded-For $proxy-add-x-forwarded-for;
client-max-body-size    10m;
client-body-buffer-size 128k;
```

* `proxy-redirect` : Specifies whether to change the HTTP `Location` and `Refresh` Headers of the Response received from Nginx's Proxied Server. The HTTP `Location` Header is a Header that holds the URL of the changed Resource when the location of a Resource has changed. The HTTP `Refresh` Header is a Header that instructs the Client to Refresh.
* `proxy-set-header Host` : Sets the HTTP `Host` Header. The HTTP `Host` Header is a Header that stores which Virtual Host (Server) processed the request.
* `proxy-set-header X-Real-IP` : Sets the HTTP `X-Real-IP` Header. The HTTP `X-Real-IP` Header is a Header that stores the Client's IP information.
* `proxy-set-header X-Forwarded-For` : Sets the HTTP `X-Forwarded-For` Header. The HTTP `X-Forwarded-For` Header is a Header that stores the Client's IP information.
* `client-max-body-size` : Specifies the maximum allowed Body Size of a Client Request.
* `client-body-buffer-size` : Specifies the size of the Read Buffer for the Body of a Client Request.

```text {caption="[File 3-2] proxy.conf Bottom", linenos=table}
proxy-connect-timeout   90;
proxy-send-timeout      90;
proxy-read-timeout      90;
proxy-buffers           32 4k;
```

* `proxy-connect-timeout` : Specifies the maximum wait time required to establish a TCP Connection.
* `proxy-send-timeout` : Specifies the maximum wait time required to send the Client's Request to the Proxied Server.
* `proxy-read-timeout` : Specifies the maximum wait time required to receive a Response from the Proxied Server.
* `proxy-buffers` : Specifies the size of the Read Buffer used per Connection with the Proxied Server. The values specify, in order, the number of Buffers and the size of each Buffer.

### 1.3.2. http Block server Block

One `server` Block represents one Virtual Server. A Virtual Server has the same meaning as a Virtual Host of the Apache HTTP Server.

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

It is configured to operate as a Reverse Proxy for a PHP Application using FastCGI.

* `listen` : Specifies the Listen Port of the Virtual Server.
* `server-name` : Specifies the name of the Virtual Server. It is usually set to a Domain name.
* `access-log` : Specifies the path of the Log related to the Virtual Server.
* `location` Block : Configured to use the PHP Application that uses FastCGI.

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

It is configured to operate as a Reverse Proxy.

* First `location` Block : Configured to serve the Static Files under the `root` path.
* Second `location` Block : Configured to operate as a Reverse Proxy for the `127.0.0.1:8080` Port.

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

It is configured to operate as a Reverse Proxy that performs Load Balancing.

* `upstream` Block : Specifies the Target Servers to which the Packets distributed by Nginx's Load Balancing are delivered.
* `location` Block : Configured to perform Load Balancing using the Load Balancing Target Servers set in the `upstream` Block.

## 2. References

* NGINX Full Example Configuration : [https://www.nginx.com/resources/wiki/start/topics/examples/full/](https://www.nginx.com/resources/wiki/start/topics/examples/full/)
* Nginx worker_rlimit_nofile : [https://stackoverflow.com/questions/37591784/nginx-worker-rlimit-nofile](https://stackoverflow.com/questions/37591784/nginx-worker-rlimit-nofile)
