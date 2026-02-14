---
title: 构建 Kotlin
categories:
  - KMP
tags:
  - KMP
  - KN
description:
published: false
---

代码仓
- kotlin 2.0.21：https://github.com/Tencent-TDS/KuiklyBase-kotlin
- kotlin 2.2.21：https://gitcode.com/CPF-KMP-CMP/kotlin/tree/main-2.2.21-OH
- kotiln master：https://github.com/jetbrains/kotlin

产物仓
- kba：https://mirrors.tencent.com/nexus/repository/maven-tencent
- oh：https://maven.eazytec-cloud.com/nexus/repository/maven-public
- 腾讯代理：https://mirrors.tencent.com/nexus/repository/maven-public/

## mac arm

推荐 tart 虚机中构建，避免环境问题

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-tahoe-xcode:26.2 kotlin-2.2.21-macos-26.2
tart list

tart clone kotlin-2.2.21-macos-26.2 kt22 # 干净的景象存个档，tart退出时类似关机会保存
tart list

tart run kt22
```

在tart虚拟机的命令行继续

```shell
brew install --cask temurin@21

mkdir code
cd code
git clone https://gitcode.com/CPF-KMP-CMP/kotlin.git

bash scripts/build-ohos.sh 
```