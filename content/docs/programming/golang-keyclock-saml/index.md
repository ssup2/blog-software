---
title: Golang Keycloak SAML 이용
---

Golang을 활용하여 Keycloak의 SAML을 이용하고 분석한다.

## 1. 인증서 생성

SAML의 Service Provider는 인증서가 필요하다. 다음의 명령어로 인증서를 생성한다.

```shell
$ openssl req -x509 -newkey rsa:2048 -keyout myservice.key -out myservice.cert -days 365 -nodes -subj "/CN=myservice.example.com"
```

## 2. Service Provider Code

```golang {caption="[Code 1] Golang SAML Service Provider Example", linenos=table}
// https://github.com/ssup2/golang-Keycloak-SAML/blob/master/main.go

// Print SAML request
func samlRequestPrinter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("%+v\n", r)
		next.ServeHTTP(w, r)
	})
}

// Echo session info
func echoSession(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "%v\n", samlsp.SessionFromContext(r.Context()))
}

func main() {
	// Load certificate keypair
	keyPair, err := tls.LoadX509KeyPair("myservice.cert", "myservice.key")
	if err != nil {
		panic(err)
	}
	keyPair.Leaf, err = x509.ParseCertificate(keyPair.Certificate[0])
	if err != nil {
		panic(err)
	}

	// Get identity provider info from identity provider meta URL
	idpMetadataURL, err := url.Parse("http://localhost:8080/realms/ssup2/protocol/saml/descriptor")
	if err != nil {
		panic(err)
	}
	idpMetadata, err := samlsp.FetchMetadata(context.Background(), http.DefaultClient,
		*idpMetadataURL)
	if err != nil {
		panic(err)
	}

	// Get SAML service provider middleware
	rootURL, err := url.Parse("http://localhost:8000")
	if err != nil {
		panic(err)
	}
	samlSP, _ := samlsp.New(samlsp.Options{
		URL:         *rootURL,
		Key:         keyPair.PrivateKey.(*rsa.PrivateKey),
		Certificate: keyPair.Leaf,
		IDPMetadata: idpMetadata,
	})

	// Set SAML's metadata and ACS (Assertion Consumer Service) endpoint with SAML request printer
	http.Handle("/saml/", samlRequestPrinter(samlSP))

	// Set session handler to print session info
	app := http.HandlerFunc(echoSession)
	http.Handle("/session", samlSP.RequireAccount(app))

	// Serve HTTP
	http.ListenAndServe(":8000", nil)
}
```

[Code 1]은 SAML Identity Provider를 통해서 User를 인증하고, 인증 과정을 통해서 얻은 SAML Session 정보를 출력하는 SAML Service Provider App이다. 전체 App Code는 다음의 Repo에서 확인 할 수 있다.

* [https://github.com/ssup2/golang-Keycloak-SAML](https://github.com/ssup2/golang-Keycloak-SAML)

동작 과정은 다음과 같다.

* User가 Service Provider의 "/session" Path에 접속하면 Service Provider는 RequireAccount() Middleware 함수를 통해서 SAML Request를 Identity Provider에게 보내어 User가 인증을 할 수 있도록 Redirect한다. SAML Request에는 인증후 User가 요청한 URL 정보도 포함되어 있다. 
* Identity Provider를 통해서 인증이 완료되면 Identity Provider는 이전에 등록된 Service Provider의 ACS Endpoint인 "/saml/acs"로 User를 다시 Redirect하고, 인증 정보인 SAML Response도 ACS Endpoint에 같이 전송한다. SAML Response에는 SAML Request에 포함된 User가 요청한 URL 정보도 포함되어 있다.
* Service Provider의 ACS는 SAML Response를 수신한 다음 인증 정보를 확인하고 Web Browser의 Cookie에 인증을 설정한다. 이후에 Service Provider는 SAML Response에 포함된 User가 요청한 URL로 User를 다시 Redirect하여 User가 Service를 이용할 수 있도록 만든다.

[Code 1]의 각 Line별 설명은 다음과 같다.

* Line 3, 51 : samlRequestPrinter() 함수는 ACS로 들어오는 요청을 출력하는 Middleware이다.
* Line 12 : echoSession() 함수는 SAML이 설정한 Session 정보를 반환하는 함수이다.
* Line 55 : samlSP.RequireAccount() 함수는 "/session" 경로 접근시 Identity Provider에게 인증을 요청하는 Middleware이다.

## 3. Service Provider Metadata 추출

[Code 1]의 Service Provider의 Metadata를 추출해야 한다. 추출한 Metadata는 Identity Provider에 Service Provider를 등록하는데 이용된다. 다음의 명령어로 Service Provider의 Metadata를 추출한다. [Code 1]의 Service Provider는 "/saml/metadata" 경로를 통해서 추출할 수 있다.

```shell
$ go run main.go
$ curl localhost:8000/saml/metadata > metadata
```

## 4. Keycloak 설치, 설정

Docker를 이용하여 Keycloak을 설치한다. Keycloak의 Admin ID/Password는 admin/admin으로 설정한다.

```shell
$ docker run --name keycloak -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin -d quay.io/keycloak/keycloak:17.0.0 start-dev
```
{{< figure caption="[Figure 1] Realm 생성" src="images/keycloak-create-realm.png" width="800px" >}}

"localhost:8080"에 접속하여 Admin 계정으로 Login을 진행한 이후에 [Figure 1]과 같이 "ssup2" Realm을 생성한다. Keycloak의 Realm은 인증 범위를 의미한다. 하나의 Realm에 다수의 Service Provider가 등록될 수 있다.

{{< figure caption="[Figure 2] Client 생성" src="images/keycloak-create-client.png" width="800px" >}}

Service Provider로부터 추출한 Metadata를 Load하여 [Figure 2]와 같이 Client를 생성한다.

{{< figure caption="[Figure 3] Client Signature Off" src="images/keycloak-create-client-signature.png" width="800px" >}}

[Figure 3]과 같이 생성한 Client에 들어가서 Client Signature Required를 Off한다. Service Provider가 이용하는 인증서가 임의의 인증서이기 때문에 Off가 필요하다.

{{< figure caption="[Figure 4] User Password 설정" src="images/keycloak-user-password.png" width="800px" >}}

"users" Group을 생성하고 "users" Group 하위에 "user" User를 생성한다. 이후 [Figure 4]와 같이 생성한 "user" User의 Password를 "user"로 설정한다.

{{< figure caption="[Figure 5] User Role 확인" src="images/keycloak-user-role.png" width="800px" >}}

이후 생성한 "user" User의 Role을 [Figure 5]와 같이 확인 한다.

## 5. Service Provider 실행

{{< figure caption="[Figure 6] User Login" src="images/keycloak-user-login.png" width="800px" >}}

```text {caption="[Text 1] User Login URL", linenos=table}
http://localhost:8080/realms/ssup2/protocol/saml?SAMLRequest=nJJRb9MwFIX%2FiuX31I7TrJu1RCqrEJUGVGvhgbdb55ZacuzgewPs36Nmm1QklAde7fudc4997gn6MNj1yOf4hD9GJBa%2F%2BxDJXi4aOeZoE5AnG6FHsuzsfv3x0ZqFtkCEmX2K8goZ5pkhJ04uBSm2m0b6rtDa1VXd3VVLvKlOq7q86250V8LpiMu6rJzDVVdWx6MUXzGTT7GRZqGl2BKNuI3EELmRRhtTaFOY1aGsbF3b0izKevlNig0S%2Bwg8kWfmwSoVkoNwTsT2Vt9qlRFCT4poHIx6W1Bdwkixfsv4kCKNPeY95p%2Fe4Zenx3%2FKaT2BChxJsXvVeudj5%2BP3%2BZc5vgyR%2FXA47Ird5%2F1BttPv2ClqFu9T7oHnRS4nvitO06jFyJ6fZTuzZ48MHTDcqyur9rUVn6DH7WaXgnfP%2F2HPGSJ5jCzFOoT06yEjMDaS84hStS%2BWf3ev%2FRMAAP%2F%2F&RelayState=cah6dnvLyCdBHc0bl5F2D3EZs1myEwIcGXHgrrgABaRtr0VVrx7ntLhu
```

Service Provider를 실행하고 "/session" Path에 접근하면 [Text 1]의 URL을 통해서 [Figure 6]과 같은 Login 화면을 확인할 수 있다. [Text 1]을 보면 URL의 Query 형태로 "SAML Request"와 "Relay State"를 확인할 수 있다. SAML Request는 Service Provider가 Identity Provider (Keycloak)에게 전송하는 인증 요청이고, Relay State는 Identity Provider의 인증 과정 이후 Identity Provider가 Service Provider의 ACS로 "SAML Response"와 함께 전달하는 값으로, Service Provider가 인증 이후 어떤 동작을 수행할지 판별하는 용도로 이용된다.

```xml {caption="[Text 2] SAML Request", linenos=table}
<?xml version="1.0"?>
<samlp:AuthnRequest xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ID="id-00c535d934e63f7519d60d1afbe4513cce7d13bb" Version="2.0" IssueInstant="2022-02-27T13:55:12.154Z" Destination="http://localhost:8080/realms/ssup2/protocol/saml" AssertionConsumerServiceURL="http://localhost:8000/saml/acs" ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST">
  <saml:Issuer Format="urn:oasis:names:tc:SAML:2.0:nameid-format:entity">http://localhost:8000/saml/metadata</saml:Issuer>
  <samlp:NameIDPolicy Format="urn:oasis:names:tc:SAML:2.0:nameid-format:transient" AllowCreate="true"/>
</samlp:AuthnRequest>
```

[Text 1]의 SAML Request 값을 URL Decoding, Base64 Decoding, XML Inflate를 수행하면 XML 형태의 [Text 2] SAML Request를 얻을수 있다.

```text {caption="[Text 3] Request to Service Provider ACS", linenos=table}
Request : &{Method:POST URL:/saml/acs Proto:HTTP/1.1 ProtoMajor:1 ProtoMinor:1 Header:map[Accept:[text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9] Accept-Encoding:[gzip, deflate, br] Accept-Language:[ko] Cache-Control:[max-age=0] Connection:[keep-alive] Content-Length:[16013] Content-Type:[application/x-www-form-urlencoded] Cookie:[saml_cah6dnvLyCdBHc0bl5F2D3EZs1myEwIcGXHgrrgABaRtr0VVrx7ntLhu=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwOi8vbG9jYWxob3N0OjgwMDAiLCJleHAiOjE2NDU5NzAyMDIsImlhdCI6MTY0NTk3MDExMiwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo4MDAwIiwibmJmIjoxNjQ1OTcwMTEyLCJzdWIiOiJjYWg2ZG52THlDZEJIYzBibDVGMkQzRVpzMW15RXdJY0dYSGdycmdBQmFSdHIwVlZyeDdudExodSIsImlkIjoiaWQtMDBjNTM1ZDkzNGU2M2Y3NTE5ZDYwZDFhZmJlNDUxM2NjZTdkMTNiYiIsInVyaSI6Ii9zZXNzaW9uIiwic2FtbC1hdXRobi1yZXF1ZXN0Ijp0cnVlfQ.oopqK9Ss-gpn_c8OegyIteY7FdIgDhvnd45ogbokbdeHKnUkoorQ-gbAvKbADcIJAAgChu6hU8gD9Cvz5smOpGc_gaFEL0O5Vjpsu7vNLmHxEMiTgJCWWe_vx9THq0VqXif4zANKTpabRMYNf0XLDH5D4Zf7sVQGdDKovKOd4ww89GXy8ImZx0Qvbbcqz45If6rJhPqMJMkNhwYjawttUiHyBBXAFp3u4Cm8f2ujGzSN_LK4J_HYwLmo-ufq9-hy-eKmn5Ji2qM5hkpzZ0N2s4d_IktIvX4rHryOCo8nktCBPYySvVLZ8sBLLtBjFKjQ6MVhkesUbwQWGy_T48R3-Q] Origin:[null] Sec-Ch-Ua:[" Not A;Brand";v="99", "Chromium";v="98", "Google Chrome";v="98"] Sec-Ch-Ua-Mobile:[?0] Sec-Ch-Ua-Platform:["Windows"] Sec-Fetch-Dest:[document] Sec-Fetch-Mode:[navigate] Sec-Fetch-Site:[same-site] Upgrade-Insecure-Requests:[1] User-Agent:[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36]] Body:{Reader:SAMLResponse=PHNhbWxwOlJlc3BvbnNlIHhtbG5zOnNhbWxwPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyL...NaEhsNTV4Ym1UVzBpWE9nTjBPOTljYW8zVGJIR01DZGFiT3pNRGFKbjdkVzdmdWpIbU1GdFdkUHNzanBlRXFWeU5QYVVFRWQvUWVuZUlrWFZBeTFxRWJaaXk5N01uZTI3bEs2TGN1bkFWRjM2RmJ0WWVFQjNRL0l6QVlkS0hDY1Q5Y2thcWRJS2RORE9xMTNzQUkvSEw1NmNRT0VkNlUvbGx4cUtaRXBzcDlsSnVhdlRBMXhHRTRicmVRMUcrUjVlTjVuZHdjNGZMYjh5cll5QmdkNmlNc0JxN05LQTkvUUZUOWxoM2ZBTDA1Z2JkakUzNE9NMnpyVS9aV2dnbkNJT3lvamtTaWd3T3NJaGxlb3RubTA5UGg1NFV1MTdwUlozUVlNL255ZktKSnA4ZEpmUXdXb3R4UXdTZ3lBd3ovaS8weGFCOGY0akhlZEV6Yy93Tk9ObWlDTFlYMnViUTE0dDUxUzhWRGhKck9yTVphR3ZIT2pCNTJIc0pEazNDT2h2ZlExSXlHQ2hiVUx3clk3bUJybGJRQTNjVCtYcnVuNis2TXl6VlhpUXF6Si9HV2Rqd0szUXFYRW9HbXlUQUw1N0p3dWNNaDJ4OERkY0lvemEzbFJXL2lJbHAyWXlzMEV5Y3pqeVMwRkMrN1ZETVNDS2tNTGdnQktHS011SW1razhnZGw2MFFGMG8wVi9JbFlTY2JUbzYxU3BhTmtaTEVtV1l4NmNLZGFHMVduUGhPbzlPaERHWGowMXNQUFo4MTFpNFh4T25sZGN3VmdCOG5la291SnpyZjF1dkF4Y3htWGpGbVdDeURIbmdpdGl4RkNuR3pOR3ZNL21BPT08L3hlbmM6Q2lwaGVyVmFsdWU%2BPC94ZW5jOkNpcGhlckRhdGE%2BPC94ZW5jOkVuY3J5cHRlZERhdGE%2BPC9zYW1sOkVuY3J5cHRlZEFzc2VydGlvbj48L3NhbWxwOlJlc3BvbnNlPg%3D%3D&RelayState=cah6dnvLyCdBHc0bl5F2D3EZs1myEwIcGXHgrrgABaRtr0VVrx7ntLhu} GetBody:<nil> ContentLength:16013 TransferEncoding:[] Close:false Host:localhost:8000 Form:map[] PostForm:map[] MultipartForm:<nil> Trailer:map[] RemoteAddr:[::1]:43304 RequestURI:/saml/acs TLS:<nil> Cancel:<nil> Response:<nil> ctx:0xc00030a040}
```

[Text 3]은 Keycloak에서 인증 완료 이후 Keycloak이 Service Provider의 ACS Endpoint로 전달하는 Request를 나타내고 있다. Request의 Body에는 "SAML Response"와 "Relay State"가 존재하는 것을 확인할 수 있다. Relay State는 [Text 1]의 Relay State와 동일한 것을 확인 할 수 있다. Service Provider는 ACS Endpoint로 전달되는 Relay State를 통해서 User를 "/session" Path로 Redirect 시키는 것을 판단하고 수행한다.

```xml {caption="[Text 4] SAML Response", linenos=table}
<?xml version="1.0"?>
<samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" Destination="http://localhost:8000/saml/acs" ID="ID_f315b052-60c2-46f5-9536-dda9034e71ab" InResponseTo="id-00c535d934e63f7519d60d1afbe4513cce7d13bb" IssueInstant="2022-02-27T13:55:40.326Z" Version="2.0">
  <saml:Issuer>http://localhost:8080/realms/ssup2</saml:Issuer>
  <dsig:Signature xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">
    <dsig:SignedInfo>
      <dsig:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
      <dsig:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
      <dsig:Reference URI="#ID_f315b052-60c2-46f5-9536-dda9034e71ab">
        <dsig:Transforms>
          <dsig:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
          <dsig:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
        </dsig:Transforms>
        <dsig:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
        <dsig:DigestValue>o4plaDgt1LTMoqupZaC9kq+85MbGJH1j4tH0eTgmAHM=</dsig:DigestValue>
      </dsig:Reference>
    </dsig:SignedInfo>
    <dsig:SignatureValue>XucrRf528RG25r19ERoOs8HESzBvitlq6qmm+7jK6N4GQZKUJENkFSc/qtrdYttCSV+a7p7EL2scqQPRJbWuxp1CsBRcvblJjtgsNnmVAXmLYkEQIrXu1s9g2YP6iXf/q7i9vrdU7PMjhsJSVWu75UUFrrQz45bJ2q7ylwH/K7irhw3F3pDCmSJzOjrFrEqETtCBD6HoS2MRSAIl+Dnyo6HVo0tXxWU057QuvrXQN8tnbeDSggD1sUgKWolWj3w0XpENszY+atiTfk6k7GXTALYyg5yQo6Ed7MU22cGJwSuQSUZ9Uind+IuumrTLieC1ewp9Y2T9jC7otOadTTwVQg==</dsig:SignatureValue>
    <dsig:KeyInfo>
      <dsig:KeyName>kZL4ywT4HLjExc7_GfGn5uoaHYyY6aoaj_g44eBSoVY</dsig:KeyName>
      <dsig:X509Data>
        <dsig:X509Certificate>MIICmTCCAYECBgF/HLGW7zANBgkqhkiG9w0BAQsFADAQMQ4wDAYDVQQDDAVzc3VwMjAeFw0yMjAyMjExNDI5MzRaFw0zMjAyMjExNDMxMTRaMBAxDjAMBgNVBAMMBXNzdXAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlplrdEgy+A83ShB5+yPlX7NtFAiS0aln/ZqGFSZYhd4pTTM5NS1EjZgU8oG3TfJ9dDlUEBA44hi1l21bicAejFIBXCUifjkuSMliXsGYf9djE0M7x6VMBSZCUaKKvz8/1D8kX/qJ2szWKsmB8VdR7HKbb2M7wmdu+Pd42FwJARfhRFYGoYH0gTDikU0l8QLdbOAb4NOBWgaA1h6BXo8FQaRrkOil0S1Rt6/dw6k/k/qHv/pmSGB8V8sn4OhtK3VKC/NFcKtPJF5y5DAC4d9YGcSgbhzhUuz2nZ7d/HszLVAtZvIUkIp3TddgqwnVTKEL4T+Z/4ma1f3QCIyaEQiMBwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQBFCH+yKwGrTwGSlXXP27rE2rqjSIYnkzv0na+oCuATxbx+YnCEiKnrNTT+hUggbWns1VhaePFKny8mgPPrSFz5XF5mQtFCY1t9/kWMZDT/AovimoiPTzkyqv/KOHE1xgQ4Hi7Fxwk2TNvCJ+Ref29kc9XBux4yI9+f8UecM09vEbflTLUOaza0KOZKFXbuIRIqJZxABPGkmONB6Jw6zTIgmb91iMGVoSgBTWLDlp5EkbflZaZISk3m3NzT86IyKUi9U+zuoLmeKOFlLSxEyaCyAZtiiQvupUjCqfwUf9zttMcE63N0ZPQXa2J6mniZ2h5neBdPEiaXzl8dtyNZ4zfO</dsig:X509Certificate>
      </dsig:X509Data>
      <dsig:KeyValue>
        <dsig:RSAKeyValue>
          <dsig:Modulus>lplrdEgy+A83ShB5+yPlX7NtFAiS0aln/ZqGFSZYhd4pTTM5NS1EjZgU8oG3TfJ9dDlUEBA44hi1l21bicAejFIBXCUifjkuSMliXsGYf9djE0M7x6VMBSZCUaKKvz8/1D8kX/qJ2szWKsmB8VdR7HKbb2M7wmdu+Pd42FwJARfhRFYGoYH0gTDikU0l8QLdbOAb4NOBWgaA1h6BXo8FQaRrkOil0S1Rt6/dw6k/k/qHv/pmSGB8V8sn4OhtK3VKC/NFcKtPJF5y5DAC4d9YGcSgbhzhUuz2nZ7d/HszLVAtZvIUkIp3TddgqwnVTKEL4T+Z/4ma1f3QCIyaEQiMBw==</dsig:Modulus>
          <dsig:Exponent>AQAB</dsig:Exponent>
        </dsig:RSAKeyValue>
      </dsig:KeyValue>
    </dsig:KeyInfo>
  </dsig:Signature>
  <samlp:Status>
    <samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success"/>
  </samlp:Status>
  <saml:EncryptedAssertion>
    <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#" Type="http://www.w3.org/2001/04/xmlenc#Element">
      <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
      <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
        <xenc:EncryptedKey>
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"/>
          <xenc:CipherData>
            <xenc:CipherValue>O4aXsgqn/IRC2LTehUNNxBCnfnYql408NpapE2q9dZ0D79PgdobNCVuk4E1v/v4aQW07K/7qFDKWA/tYWoIQBB+WG/Fq5yOnUnZ3qMFqagc1+Rfd8T6Ryg43EZ/FKY3NAZa74SFycI+0Gfz/EcqJ7+NyDIbC26tUnAUBNAuTFDgxo+BQyZNBL474JgBaR3vi6vgtcozp7UcMCRbiXAtWUX0kg14jTh3e87ntC3cRC+GJ/hLgxIPlGDyYlD9Fmuwx4wGk3U3TSQSMj9T9eB4PEwKq6/32fKKh+Fj+rshPz/h3wNbgKlpzZyAWXrdqm3Wg2jYfN5aOnN4/v2AC6yMwiw==</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedKey>
      </ds:KeyInfo>
      <xenc:CipherData>
        <xenc:CipherValue>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</xenc:CipherValue>
      </xenc:CipherData>
    </xenc:EncryptedData>
  </saml:EncryptedAssertion>
</samlp:Response>
```

[Text 3]의 SAML Response를 URL Decoding, Base64 Decoding을 수행하면 [Text 4]와 같은 XML 형태의 SAML Response를 얻을 수 있다.

```xml {caption="[Text 5] Session 정보", linenos=table}
{
	{
		http://localhost:8000 1645973740  1645970140 http://localhost:8000 1645970140 G-cb2ffc92-c74c-4f05-997f-350cf64234c1
	} 
	map[Role:[manage-account manage-account-links uma_authorization default-roles-ssup2 offline_access view-profile] SessionIndex:[6ca1b65b-be38-44e2-a782-0a9374d1124e::acf9f286-2c16-46bf-8c1c-f2b7b7c97b42]] true
}
```

Service Provider의 "/session" Endpoint에 접근하면 [Text 5]과 같이 현재의 Session 정보를 확인할 수 있다. Role에 [Figure 5]의 Role이 포함되어 있는것을 확인할 수 있다.

## 6. 참조

* [https://www.keycloak.org/getting-started/getting-started-docker](https://www.keycloak.org/getting-started/getting-started-docker)
* [https://docs.anchore.com/3.0/docs/overview/sso/examples/keycloak/](https://docs.anchore.com/3.0/docs/overview/sso/examples/keycloak/)
* [https://github.com/crewjam/saml](https://github.com/crewjam/saml)
* [https://goteleport.com/blog/how-saml-authentication-works/](https://goteleport.com/blog/how-saml-authentication-works/)
* [https://www.rancher.co.jp/docs/rancher/v2.x/en/admin-settings/authentication/keycloak/](https://www.rancher.co.jp/docs/rancher/v2.x/en/admin-settings/authentication/keycloak/)