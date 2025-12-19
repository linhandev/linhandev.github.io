---
title: 构建LLVm
categories:
  - LLVM
tags:
  - KMP
  - KN
  - LLVM
description: 
published: false
---

KN的LLVM通过[Kotlin项目自己写的脚本](https://github.com/JetBrains/kotlin/tree/master/kotlin-native/tools/llvm_builder)构建
- 这脚本主要是在组装cmake和ninja命令参数，确定参数后后续增量构建可以直接用命令
- 默认是2阶段
- build-targets 不传是打所有的组件，传是只打distribution-components里声明的组件更快产物更小
- zsh变量就算有空格也认为是一个字符串，需要 var=(a b c) 使用var时才会认为是传入了多个参数

### master-llvm12-backup

```shell
LLVM_FOLDER=/Users/hl/git/llvm/oh12
git clone http://gitcode.com/openharmony/third_party_llvm-project $LLVM_FOLDER
```

mac arm

```shell
brew install ninja cmake wget ccache
# cmake 4.2.1
# ninja 1.13.2

cd kotlin-native/tools/llvm_builder

export DEVELOPER_DIR=/Applications/Xcode-14.3.1.app/Contents/Developer/
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
python3 package.py \
  --distribution-components $DISTRIBUTION_COMPONENTS \
  --llvm-sources $LLVM_FOLDER \
  --save-temporary-files # --pack

# 增量构建
cd llvm-stage-2-build
ninja install-distribution

# 发布产物
# 前面打包命令加一个 --pack
```

linux

```shell
cd kotlin-native/tools/llvm_builder/images/linux/
docker build --platform linux/amd64 -t kotlin-llvm-builder --file ./Dockerfile .

LLVM_FOLDER=/Users/hl/git/llvm/oh19
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
docker run --platform linux/amd64 --rm -it -v .:/output -v $LLVM_FOLDER:/llvm kotlin-llvm-builder --llvm-sources /llvm --install-path /output/llvm-12.0.1-x86_64-linux --distribution-components $DISTRIBUTION_COMPONENTS --save-temporary-files # --pack
```

### llvm-19.1.7

遇到cmake < 3.5不再被支持，有两个声明cmake最低3.1的，bump到3.5

```shell
LLVM_FOLDER=/Users/hl/git/llvm/oh19
export DEVELOPER_DIR=/Applications/Xcode-16.4.app/Contents/Developer/
# 其他的同12
```
