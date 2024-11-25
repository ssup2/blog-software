---
title: Linux Kernel ChangeLog Download
---

## 1. Linux Kernel ChangeLog Download

```shell
$ rsync -zarv --include="*/" --include="ChangeLog*" --exclude="*" -m 'rsync://rsync.kernel.org/pub/linux/kernel/' .
```

모든 Linux Kernel의 ChangeLog를 Download 한다.

## 2. 참조

* [https://unix.stackexchange.com/questions/506344/best-method-for-searching-linux-kernel-changelog-from-4-18-0-to-4-20-16](https://unix.stackexchange.com/questions/506344/best-method-for-searching-linux-kernel-changelog-from-4-18-0-to-4-20-16)