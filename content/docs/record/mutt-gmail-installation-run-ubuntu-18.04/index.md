---
title: mutt Gmail 설치, 사용 / Ubuntu 18.04 환경
---

## 1. 설치, 사용 환경

설치, 사용 환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user

## 2. mutt 설치

```shell
$ sudo apt-get install mutt
```

mutt Package를 설치한다.

## 3. Gmail Access 권한 설정

아래의 링크를 통해서 Gmail Access 권한을 설정한다.
* Guide : [https://support.google.com/accounts/answer/6010255?hl=en](https://support.google.com/accounts/answer/6010255?hl=en)
* Secure Apps : [https://myaccount.google.com/lesssecureapps](https://myaccount.google.com/lesssecureapps)

## 4. mutt 설정

```shell
$ mkdir -p ~/Mail
$ touch /var/mail/root
$ chmod 660 /var/mail/root
$ chown root:mail /var/mail/root
```

mutt 관련 폴더, 파일을 생성한다.

```text {caption="[File 1] ~/.muttrc", linenos=table}
set realname = "<first and last name>"
set from = "<gmail username>@gmail.com"
set use-from = yes
set envelope-from = yes

set smtp-url = "smtps://<gmail username>@gmail.com@smtp.gmail.com:465/"
set smtp-pass = "<gmail password>"
set imap-user = "<gmail username>@gmail.com"
set imap-pass = "<gmail password>"
set folder = "imaps://imap.gmail.com:993"
set spoolfile = "+INBOX"
set ssl-force-tls = yes

# G to get mail
bind index G imap-fetch-mail
set editor = "vim"
set charset = "utf-8"
set record = ''
```

~/.muttrc 파일을 [File 1]의 내용으로 생성한다.

## 5. 사용법

```shell
$ mutt
```

mutt을 실행한다. 단축키는 아래와 같다.
* m : Compose a new mail message.
* G : Fetch new messages.

## 6. 참조

* [http://nickdesaulniers.github.io/blog/2016/06/18/mutt-gmail-ubuntu/](http://nickdesaulniers.github.io/blog/2016/06/18/mutt-gmail-ubuntu/)
