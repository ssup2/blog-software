---
title: SSL Self-signed Certificate Creation
---

## 1. Creation Environment and Features

The creation environment and features are as follows.
* Ubuntu 18.04 LTS
* Resolved the missing-subjectAltName issue that occurs in Chrome 58+ versions.

## 2. Root CA Key and Root Certificate Creation

```shell
$ openssl genrsa -out rootca.key 2048
$ openssl req -x509 -new -nodes -key rootca.key -sha256 -days 356 -subj /C=KO/ST=None/L=None/O=None/CN=ssup2 -out rootca.crt
```

Create `rootca.key` and `rootca.crt` files.
* Key: RSA-based 2048 bytes
* CN: ssup2 (can be changed arbitrarily)

## 3. Server Certificate Creation

Enter the server's IP or domain name for CN (Common Name). Domain names require exact matches. For example, if CN is ssup2.com, it cannot be used from www.ssup2.com.
* Example: 192.168.0.100, ssup2.com, www.ssup2.com, *.ssup2.com (wildcard)

### 3.1. v3.ext File Creation

```text {caption="[File 1] v3.ext", linenos=table}
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt-names

[alt-names]
IP.1 = 192.168.0.100
```

Create the `v3.ext` file with the content from [File 1].
* CN (Common Name): 192.168.0.100

### 3.2. Server Key, Server Certificate, and Server pem File Creation

```shell
$ openssl req -new -newkey rsa:2048 -sha256 -nodes -keyout server.key -subj /C=KO/ST=None/L=None/O=None/CN=192.168.0.100 -out server.csr
$ openssl x509 -req -in server.csr -CA rootca.crt -CAkey rootca.key -CAcreateserial -out server.crt -days 356 -sha256 -extfile ./v3.ext
$ cat server.crt server.key > server.pem
```

Create server.key, server.crt, and server.pem files.
* CN (Common Name): 192.168.0.100

## 4. References

* [https://alexanderzeitler.com/articles/Fixing-Chrome-missing-subjectAltName-selfsigned-cert-openssl/](https://alexanderzeitler.com/articles/Fixing-Chrome-missing-subjectAltName-selfsigned-cert-openssl/)
* [https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate](https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate)

