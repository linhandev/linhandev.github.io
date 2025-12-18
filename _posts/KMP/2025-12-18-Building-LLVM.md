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
- 默认是2阶段
- build-targets不传是打所有的组件，传是只打distribution-components里声明的组件更轻量

```shell
brew install ninja cmake wget

export DEVELOPER_DIR=/Applications/Xcode-14.3.1.app/Contents/Developer/

cd /Users/hl/git/llvm/oh12
wget https://raw.githubusercontent.com/Tencent-TDS/KuiklyBase-kotlin/refs/heads/kuikly-base/2.0.20/kotlin-native/tools/llvm_builder/package.py
DISTRIBUTION_COMPONENTS='clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers'
python3 package.py \
  --build-targets install-distribution \
  --distribution-components $DISTRIBUTION_COMPONENTS \
  --llvm-sources . \
  --install-path ./llvm-distribution \
  --save-temporary-files


python3 package.py --build-targets install-distribution --distribution-components $DISTRIBUTION_COMPONENTS --llvm-sources . --save-temporary-files 
```