---
title: KN Codesize优化
categories:
  - KMP
tags:
  - KMP
  - KN
  - Codesize
description:
---

## kotlin 编译参数调整

- kotlin 为苹果手表 target 上了一个 smallBinary 选项，仅用于release build，效果是不进行部分 inline 和将 LLVM IR 上的优化级别从 o3 改为 oz。开启方式：`binaryOption("smallBinary", "true")`
- LLVM IR 上的 inline 会将比较小的函数复制到调用点，用 codesize 换运行性能，关闭 inline 或减小被认为是小函数的行数阈值可以减小 codesize，开启方式：`binaryOption("inlineThreshold", "0")`
- kotlin 2.2 新上的实验特性8位字符串，开启后如果字符串中所有字符都是0～255范围会使用 latin-1 编码，可以通过这个选项减小 so 中字符串常量的大小，开启方式：`binaryOption("latin1Strings", "true")`

```shell
(default) ➜  ovCompose-sample git:(main) ✗ ls -l baseline.so sb.so sb-noinline.so sb-noinline-latin1.so                                                
-rwxr-xr-x@ 1 ohoskt  staff  13333168 Feb 26 00:29 baseline.so
-rwxr-xr-x@ 1 ohoskt  staff  12606928 Feb 26 01:16 sb-noinline-latin1.so
-rwxr-xr-x@ 1 ohoskt  staff  11919840 Feb 26 00:49 sb-noinline.so
-rwxr-xr-x@ 1 ohoskt  staff  12606928 Feb 26 00:32 sb.so
(default) ➜  ovCompose-sample git:(main) ✗ python 
Python 3.12.12 | packaged by conda-forge | (main, Jan 27 2026, 00:01:15) [Clang 19.1.7 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> (13333168 - 12606928) / 13333168
0.0544686754115751
>>> (13333168 - 11919840) / 13333168
0.1060009144113387
>>> 
```

ovcomposeSample 上用前两个选项不 inline+oz 优化级别可以用运行性能换到 10% 的 codesize 下降，latin1选项还需要研究

## cinterop静态库相关最佳实践

kn的so中如果有链进去静态库，建议参考[这篇](./Static-Cinterop-Codesize/)

