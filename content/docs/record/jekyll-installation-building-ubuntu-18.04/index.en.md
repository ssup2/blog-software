---
title: Jekyll Installation, Build / Ubuntu 18.04 Environment
---

## 1. Build Environment

The build environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user

## 2. Ubuntu Package Installation

```shell
$ apt install ruby-full build-essential zlib1g-dev
```

Install Ubuntu Packages required for running Jekyll.

## 3. Ruby Gem, Jekyll Installation

```shell
$ gem install bundler -v '1.16.1'
$ bundle install
$ gem install jekyll
```

Install Ruby Gems and Jekyll required for running Jekyll.

## 4. Jekyll Service

```shell
$ bundle exec jekyll serve
```

Run the Jekyll Blog locally using the jekyll serve command from the Jekyll Blog's Root folder and verify operation.
*  http://127.0.0.1:4000

## 5. References

* https://jekyllrb.com/docs/installation/ubuntu/

