---
title: Jekyll 설치, Build / Ubuntu 18.04 환경
---

## 1. Build 환경

Build 환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user

## 2. Ubuntu Package 설치

```shell
$ apt install ruby-full build-essential zlib1g-dev
```

Jeykll 구동에 필요한 Ubuntu Package를 설치한다.

## 3. Ruby Gem, Jekyll 설치

```shell
$ gem install bundler -v '1.16.1'
$ bundle install
$ gem install jekyll
```

Jekyll 구동에 필요한 Ruby Gem 및 Jekyll을 설치한다.

## 4. Jekyll Servce

```shell
$ bundle exec jekyll serve
```

Jekyll Blog의 Root 폴더에서 jekyll serve 명령어를 이용하여 Local에서 Jekyll Blog를 구동하고, 동작을 확인한다.
*  http://127.0.0.1:4000

## 5. 참조

* https://jekyllrb.com/docs/installation/ubuntu/