---
title: Golang Google OIDC Usage
---

This document acquires and analyzes Google OIDC-based tokens using Golang.

## 1. OIDC Configuration

Configuration is required to obtain OIDC-based ID tokens and OAuth-based access tokens from Google Cloud Platform.

{{< figure caption="[Figure 1] Project Creation" src="images/project-create.png" width="700px" >}}

As shown in [Figure 1], access [https://console.developers.google.com](https://console.developers.google.com/) to create a project.

{{< figure caption="[Figure 2] OAuth Addition" src="images/oauth-add.png" width="900px" >}}

As shown in [Figure 2], go to the "APIs & Services" section and select "Add OAuth Client ID" to add OAuth authentication.

{{< figure caption="[Figure 3] OAuth Client ID Creation" src="images/oauth-clientid-create.png" width="800px" >}}

As shown in [Figure 3], create a Client ID of "Web Application" type. The "Name" can be set arbitrarily. For "Redirect URI", specify "/auth/google/callback", which is the path that will be processed in the example code. After creation is complete, check the **Client ID** and **Client Secret**.

## 2. App Code

```golang {caption="[Code 1] Golang Google OIDC Example App", linenos=table}
// Code : https://github.com/ssup2/golang-Google-OIDC/blob/master/main.go

func main() {
	// Init variables
	ctx := context.Background()

	// Set OIDC, oauth oidcProvider
	oidcProvider, err := oidc.NewProvider(ctx, "https://accounts.google.com")
	if err != nil {
		log.Fatal(err)
	}
	oauth2Config := oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     oidcProvider.Endpoint(),
		RedirectURL:  "http://127.0.0.1:3000/auth/google/callback",   // Set callback URL
		Scopes:       []string{oidc.ScopeOpenID, "profile", "email"}, // Set scope
	}

	// Define handler to redirect for login and permissions
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		state, err := randString(16)
		if err != nil {
			http.Error(w, "Internal error", http.StatusInternalServerError)
			return
		}
		nonce, err := randString(16)
		if err != nil {
			http.Error(w, "Internal error", http.StatusInternalServerError)
			return
		}
		setCallbackCookie(w, r, "state", state)
		setCallbackCookie(w, r, "nonce", nonce)

		// Redirect to Google login and permissions page
		http.Redirect(w, r, oauth2Config.AuthCodeURL(state, oidc.Nonce(nonce)), http.StatusFound)
	})

	// Define callback (redirect) handler
	http.HandleFunc("/auth/google/callback", func(w http.ResponseWriter, r *http.Request) {
		// Get state from URL and validate it
		state, err := r.Cookie("state")
		if err != nil {
			http.Error(w, "state not found", http.StatusBadRequest)
			return
		}
		if r.URL.Query().Get("state") != state.Value {
			http.Error(w, "state did not match", http.StatusBadRequest)
			return
		}

		// Get authorization code from URL
		authCode := r.URL.Query().Get("code")

		// Get ID token and access token through authorization code
		oauth2Token, err := oauth2Config.Exchange(ctx, authCode)
		if err != nil {
			http.Error(w, "Failed to exchange token: "+err.Error(), http.StatusInternalServerError)
			return
		}

		// Get and validate ID token
		oidcConfig := &oidc.Config{
			ClientID: clientID,
		}
		oidcVerifier := oidcProvider.Verifier(oidcConfig)
		rawIDToken, ok := oauth2Token.Extra("id_token").(string)
		if !ok {
			http.Error(w, "No id_token field in oauth2 token.", http.StatusInternalServerError)
			return
		}
		idToken, err := oidcVerifier.Verify(ctx, rawIDToken)
		if err != nil {
			http.Error(w, "Failed to verify ID Token: "+err.Error(), http.StatusInternalServerError)
			return
		}

		// Get nonce from ID token and validate it
		nonce, err := r.Cookie("nonce")
		if err != nil {
			http.Error(w, "nonce not found", http.StatusBadRequest)
			return
		}
		if idToken.Nonce != nonce.Value {
			http.Error(w, "nonce did not match", http.StatusBadRequest)
			return
		}

		// Marshal and make up response
		resp := struct {
			OAuth2Token   *oauth2.Token
			IDToken       string
			IDTokenClaims *json.RawMessage // ID Token payload is just JSON.
		}{oauth2Token, rawIDToken, new(json.RawMessage)}
		if err := idToken.Claims(&resp.IDTokenClaims); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Write response
		data, err := json.MarshalIndent(resp, "", "    ")
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Write(data)
	})

	// Run HTTP server
	log.Printf("listening on http://%s/", "127.0.0.1:3000")
	log.Fatal(http.ListenAndServe("127.0.0.1:3000", nil))
}
```

[Code 1] shows part of a Golang app that obtains ID tokens and access tokens using Google OIDC. The full app code can be found in the following repository:

* [https://github.com/ssup2/golang-Google-OIDC](https://github.com/ssup2/golang-Google-OIDC)

The operation process is as follows:

* When a user accesses the "/" path of the Golang app, the Golang app redirects the user to the Google authentication/authorization web page.
* When the user's authentication and authorization process is complete on the Google authentication/authorization web page, the Google authentication/authorization web page redirects the user back to the "/auth/google/callback" path of the Golang app. In this case, an authorization code is also passed as a URL query.
* When the user accesses the "/auth/google/callback" path of the Golang app, the Golang app obtains the authorization code from the URL, then obtains and outputs ID tokens and access tokens through the obtained authorization code.

Line-by-line explanations of [Code 1] are as follows:

* Line 16 : Scope sets the range of user information included in ID token values.
* Lines 21, 41 : State is a temporary string to prevent CSRF attacks on users. State is generated and stored in cookies before authentication/authorization, and after redirect, it is checked whether the State in the URL matches the State in cookies.
* Lines 26, 78 : Nonce is a string used to verify whether ID tokens are valid. ID tokens are generated to include nonce and stored in cookies, and after redirect, it is checked whether the nonce in the obtained ID token matches the nonce in cookies.
* Line 52 : Authorization code exists in the "code" query of the URL.

## 3. Google Authentication/Authorization

{{< figure caption="[Figure 4] Google Authentication" src="images/google-authn.png" width="600px" >}}

```text {caption="[Text 1] Google Authentication URL", linenos=table}
https://accounts.google.com/o/oauth2/v2/auth/identifier?
client_id=554362356429-cu4gcpn45gb3incmm2v32sofslliffg2.apps.googleusercontent.com&
nonce=at7kn_XhHFySNbXRelfLwQ&
redirect_uri=http%3A%2F%2F127.0.0.1%3A3000%2Fauth%2Fgoogle%2Fcallback&
response_type=code&
scope=openid%20profile%20email&
state=usovevjnYZYpCTOaalbSWw&flowName=GeneralOAuthFlow
```

[Figure 3] is the Google authentication screen that is accessed when redirected after accessing the "/" path of the Golang app. [Text 1] shows the URL used when accessing the Google authentication screen. You can see that Client ID, Nonce, Callback URL (Redirect URL), Scope, and State information are included in the URL as queries.

## 4. ID Token, Access Token

```text {caption="[Text 2] Callback URL", linenos=table}
http://127.0.0.1:3000/auth/google/callback?state=usovevjnYZYpCTOaalbSWw&
code=4%2F0AX4XfWgoC8l0tmZ9anfZVb9mgtiYquLKZekXouqAoFKSN4-BZimF7m8wa5nDUElbBD8Jhg&
scope=email+profile+openid+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.profile+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email&
authuser=0&
prompt=consent
```

[Text 2] shows an example of a redirect URL. You can see that the "code" query contains the authorization code, and the "scope" query contains scope information.

```json {caption="[Text 3] Callback Result - Access Token, ID Token", linenos=table}
{
    "OAuth2Token": {
        "access_token": "ya29.A0ARrdaM8GQORQw-hKwlyNHfVB1cyGkmwRmWZiYOC_AEj8xV8QMEs35nfmVXtGDNrORxvcm9WCSBbujzEX2P-EeTeYmzJyrufai9QttcHQAgq1hfkGjQv7Gd3ZI4aZNl6GiY6fBSToILzPgF1dB-iXwymDVk3F",
        "token_type": "Bearer",
        "expiry": "2022-03-26T01:30:17.032547872+09:00"
    },
    "IDToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjU4YjQyOTY2MmRiMDc4NmYyZWZlZmUxM2MxZWIxMmEyOGRjNDQyZDAiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI1NTQzNjIzNTY0MjktY3U0Z2NwbjQ1Z2IzaW5jbW0ydjMyc29mc2xsaWZmZzIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI1NTQzNjIzNTY0MjktY3U0Z2NwbjQ1Z2IzaW5jbW0ydjMyc29mc2xsaWZmZzIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTM2MzI0NTgzMjQwNTY4MzY2MjEiLCJlbWFpbCI6InN1cHN1cDU2NDJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJndDNndXI5c3VkUmpXNHRsazJQVnl3Iiwibm9uY2UiOiJhdDdrbl9YaEhGeVNOYlhSZWxmTHdRIiwibmFtZSI6InNzcyBzc3MiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EtL0FPaDE0R2otLXUybVgtOEFITkNyeGJ4ZmJOR1R6YnJ4QmJSbExoT2dpM3M0dFE9czk2LWMiLCJnaXZlbl9uYW1lIjoic3NzIiwiZmFtaWx5X25hbWUiOiJzc3MiLCJsb2NhbGUiOiJrbyIsImlhdCI6MTY0ODIyMjIyMCwiZXhwIjoxNjQ4MjI1ODIwfQ.rpv5ZonWufD9CSDZi9hn3tjBEMDrwMTEW7BwXilvPGa2U1pzzvGZhiY6Qxjbs4rqoJaaVu4vPdd5iob1oxloeY7e5s4I2mIaVxONpvOdeO3yj1FzWAnVgwZ7zRHEk0J2PVgwcXG-InWOX4TwFE8ZgWHnQD1WLQTQvB-PzQF7OUCy_0SYEz2qU5YCA2tYj7u59oMI1aWdLQXEhJwFlXyIdh3lTlWXLAXP04NSO9w5M7kQfk480nqk9kTyo29aZtnSM_c-uvxP4z95HHq9pBaktDiptZtOMf5EoLrQYDG1UQzQylozTWsw5GOeFlRsOfsvMOZDV8uwCGR648Qn6eME2A",
    "IDTokenClaims": {
        "iss": "https://accounts.google.com",
        "azp": "554362356429-cu4gcpn45gb3incmm2v32sofslliffg2.apps.googleusercontent.com",
        "aud": "554362356429-cu4gcpn45gb3incmm2v32sofslliffg2.apps.googleusercontent.com",
        "sub": "113632458324056836621",
        "email": "supsup5642@gmail.com",
        "email_verified": true,
        "at_hash": "gt3gur9sudRjW4tlk2PVyw",
        "nonce": "at7kn_XhHFySNbXRelfLwQ",
        "name": "sss sss",
        "picture": "https://lh3.googleusercontent.com/a-/AOh14Gj--u2mX-8AHNCrxbxfbNGTzbrxBbRlLhOgi3s4tQ=s96-c",
        "given_name": "sss",
        "family_name": "sss",
        "locale": "ko",
        "iat": 1648222220,
        "exp": 1648225820
    }
}
```

[Text 3] shows examples of ID token claims and access tokens.

## 5. References

* [https://www.daleseo.com/google-oidc/](https://www.daleseo.com/google-oidc/)
* [https://www.daleseo.com/google-oauth/](https://www.daleseo.com/google-oauth/)
* [https://opentutorials.org/course/2473/16571](https://opentutorials.org/course/2473/16571)
* [https://github.com/coreos/go-oidc](https://github.com/coreos/go-oidc)

