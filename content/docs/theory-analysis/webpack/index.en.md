---
title: webpack
---

## 1. webpack

webpack is a tool that performs the role of a JavaScript Module Bundler. As JavaScript's functionality and roles have expanded, module-based development that separates JavaScript Code into multiple Modules (Files) and develops by importing the separated Modules is also being applied to JavaScript. The problem is that JavaScript Modules are only supported in some Web Browsers. To solve this problem, JavaScript Module Bundlers perform the role of bundling multiple JavaScript Modules into one File. webpack is currently the most popular JavaScript Module Bundler.

{{< figure caption="[Figure 1] webpack" src="images/webpack.png" width="900px" >}}

JavaScript has two Module standards: **CommonJS** or **AMD (Asynchronous Module Definition)**, and webpack supports both standards. [Figure 1] shows webpack's operation process. webpack supports Modules of various Scripts such as TypeScript and CoffeeScript, not just JavaScript Modules. These Scripts are **Transcompiled** to JavaScript through webpack. Also, webpack performs Bundling by identifying dependencies of image files such as jpg and png.

## 2. References

* [https://ui.toast.com/fe-guide/ko-BUNDLER/](https://ui.toast.com/fe-guide/ko-BUNDLER/)
* [https://d2.naver.com/helloworld/0239818](https://d2.naver.com/helloworld/0239818)s

