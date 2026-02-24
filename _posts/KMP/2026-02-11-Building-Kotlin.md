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

- 直接在物理机上构建和虚拟机内跑的命令一样，参考下面 2 构建命令
- 使用虚拟机构建可以从百度网盘下载已经编译过的镜像，下面 3 里有链接
- 在 tart 虚机中构建可以避免环境问题，虚拟机中环境供参考

```
% xcodebuild -showsdks
DriverKit SDKs:
	DriverKit 25.2                	-sdk driverkit25.2

iOS SDKs:
	iOS 26.2                      	-sdk iphoneos26.2

iOS Simulator SDKs:
	Simulator - iOS 26.2          	-sdk iphonesimulator26.2

macOS SDKs:
	macOS 26.2                    	-sdk macosx26.2
	macOS 26.2                    	-sdk macosx26.2

tvOS SDKs:
	tvOS 26.2                     	-sdk appletvos26.2

tvOS Simulator SDKs:
	Simulator - tvOS 26.2         	-sdk appletvsimulator26.2

visionOS SDKs:
	visionOS 26.2                 	-sdk xros26.2

visionOS Simulator SDKs:
	Simulator - visionOS 26.2     	-sdk xrsimulator26.2

watchOS SDKs:
	watchOS 26.2                  	-sdk watchos26.2

watchOS Simulator SDKs:
	Simulator - watchOS 26.2      	-sdk watchsimulator26.2

% xcode-select -p 
/Applications/Xcode_26.2.app/Contents/Developer

% /usr/libexec/java_home -V
Matching Java Virtual Machines (2):
    21.0.10 (arm64) "Eclipse Adoptium" - "OpenJDK 21.0.10" /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
    1.8.0_482 (arm64) "Azul Systems, Inc." - "Zulu 8.92.0.21" /Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home
/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home

% java --version 
openjdk 17.0.18 2026-01-20
OpenJDK Runtime Environment Homebrew (build 17.0.18+0)
OpenJDK 64-Bit Server VM Homebrew (build 17.0.18+0, mixed mode, sharing)

% which java 
/opt/homebrew/opt/openjdk@17/bin/java
```

1\. 安装tart，拉取镜像

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-tahoe-xcode:26.2 kotlin-2.2.21-macos-26.2
tart list

tart clone kotlin-2.2.21-macos-26.2 kt22 # 干净的景象存个档，tart退出时类似关机会保存
tart list

# 可选：给 VM 分配更多 CPU 和内存，clean build的话资源尽量给多点
# tart set kt22 --cpu 4 --memory 8192

tart run kt22
```

2\. 构建命令

```shell
brew install --cask temurin@21 zulu@8

mkdir code
cd code
git clone https://gitcode.com/CPF-KMP-CMP/kotlin.git

bash scripts/build-ohos.sh 
```

3\. 镜像 <-> 文件，编译过的镜像：https://pan.baidu.com/s/18VO4OW4lqU9Y-EmwGNUQLw?pwd=m7um

```shell
# 保存 kt22 到本地 .tvm 文件（压缩格式）
tart stop kt22
tart export kt22 ./kotlin-2.2.21-macos-26.2-built.tvm

# 从文件导入为新名字的 VM
tart import ./kotlin-2.2.21-macos-26.2-built.tvm kotlin-2.2.21-macos-26.2-built
tart list
```
