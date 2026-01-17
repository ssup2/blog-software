---
title: mutt Gmail Installation and Usage / Ubuntu 18.04 Environment
---

## 1. Installation and Usage Environment

The installation and usage environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user

## 2. mutt Installation

```shell
$ sudo apt-get install mutt
```

Install the mutt package.

## 3. Gmail Access Permission Configuration

Configure Gmail access permissions through the links below.
* Guide: [https://support.google.com/accounts/answer/6010255?hl=en](https://support.google.com/accounts/answer/6010255?hl=en)
* Secure Apps: [https://myaccount.google.com/lesssecureapps](https://myaccount.google.com/lesssecureapps)

## 4. mutt Configuration

```shell
$ mkdir -p ~/Mail
$ touch /var/mail/root
$ chmod 660 /var/mail/root
$ chown root:mail /var/mail/root
```

Create mutt-related folders and files.

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

Create the ~/.muttrc file with the content from [File 1].

## 5. Usage

```shell
$ mutt
```

Run mutt. Shortcuts are as follows.
* m: Compose a new mail message.
* G: Fetch new messages.

## 6. References

* [http://nickdesaulniers.github.io/blog/2016/06/18/mutt-gmail-ubuntu/](http://nickdesaulniers.github.io/blog/2016/06/18/mutt-gmail-ubuntu/)

