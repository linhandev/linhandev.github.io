---
title: KN Codesize优化
categories:
  - KMP
tags:
  - KMP
  - KN
  - Codesize
description:
published: false
---

```shell

./gradlew :kotlin-native:ohos_arm64CrossDist # :kotlin-native:ohos_arm64PlatformLibs

// 关键用例
./gradlew :native:native.tests:test --continue -Pkotlin.native.tests.tags='!frontend-classic'
// 语法用例
./gradlew :native:native.tests:codegen-box:test --continue -Pkotlin.native.tests.tags='!frontend-classic'
// 全部用例，报告分散在一批 build/reports/tests/test/index.html 文件夹中
./gradlew :nativeCompilerTest --continue -Pkotlin.native.tests.tags='!frontend-classic' 

// 不编编译器，直接用变好的dist文件夹
-Pkn.nativeHome='/Users/ohoskt/git/kmp/cpf-kotlin-another/kotlin-native/dist'
// 测试target
-Pkn.target=ohos_arm64
// 尽量多跑exe
-Pkn.forceStandalone=true
// 默认是测 DEBUG build，配 OPT 测 release build
-Pkn.optimizationMode=OPT


// kgp测试
gradlePluginIntegrationTest

```


/Users/ohoskt/git/kmp/cpf-kotlin-another/kotlin-native/dist/bin/konanc -target ohos_arm64 -produce program -o test.kexe /Users/ohoskt/git/kmp/cpf-kotlin-another/test.kt -Xverbose-phases=ObjectFiles,Linker