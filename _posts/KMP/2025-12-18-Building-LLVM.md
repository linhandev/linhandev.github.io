---
title: 构建LLVM
categories:
  - LLVM
tags:
  - KMP
  - KN
  - LLVM
description: 使用 Kotlin Native 项目的构建脚本编译 LLVM。包含 Mac Arm 和 Linux 平台的两阶段构建流程，涵盖 LLVM 12 (OpenHarmony master-llvm12-backup 分支) 和 LLVM 19 版本，以及多 Xcode 环境适配、增量构建、Debug 版本配置等技巧。
---

KN的LLVM通过[Kotlin项目自己写的脚本](https://github.com/JetBrains/kotlin/tree/master/kotlin-native/tools/llvm_builder)构建
- 这脚本主要是在组装cmake和ninja命令参数，确定参数后后续增量构建直接用命令
- 默认是2阶段
- build-targets 不传是打所有的组件，传是只打 distribution-components 里声明的组件更快产物更小
- zsh变量的值就算有空格也认为是一个字符串，需要 var=(a b c) 使用var时才会认为是传入了多个参数

## 修改构建脚本

- 加上 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON 选项，构建出来的版本中带 compile_commands.json，方便vscode做代码导航
- 多xcode环境下稳定取得 DEVELOPER_DIR 指向的sysroot

  ```diff
  def detect_xcode_sdk_path():
    """
    Get an absolute path to macOS SDK.
    """
  - return subprocess.check_output(['xcrun', '--show-sdk-path'],
  + return subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'],
      universal_newlines=True).rstrip()
  ```

## master-llvm12-backup

- 分支地址：https://gitcode.com/openharmony/third_party_llvm-project/tree/master-llvm12-backup
- 使用 KN 2.0 的脚本构建
- 适配多xcode环境稍微修改过的脚本：https://gitcode.com/linhandev/third_party_llvm-project/blob/master-llvm12-backup/package.py

### Mac Arm

```shell
LLVM_FOLDER=/Users/ohoskt/git/llvm/oh12
git clone http://gitcode.com/openharmony/third_party_llvm-project $LLVM_FOLDER

brew install ninja cmake wget ccache
# cmake 4.2.1 ninja 1.13.2 实测成功

# 在对应版本的 kotlin 仓库中找
cd kotlin-native/tools/llvm_builder

export DEVELOPER_DIR=/Applications/Xcode-14.3.1.app/Contents/Developer/
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
python3 package.py \
  --distribution-components $DISTRIBUTION_COMPONENTS \
  --llvm-sources $LLVM_FOLDER \
  --save-temporary-files # --pack

# 增量构建
cd $LLVM_FOLDER/llvm-stage-2-build
ninja install-distribution # 产物在 llvm-distribution 文件夹

# 打发布产物
# python脚本传 --pack
```

py脚本的实际编译命令

```shell
Force-creating directory /Users/ohoskt/git/llvm/oh12/llvm-stage-1
Force-creating directory /Users/ohoskt/git/llvm/oh12/llvm-stage-1-build

/Users/ohoskt/git/llvm/oh12/llvm-stage-1-build
Running command: cmake -G Ninja
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
-DLLVM_ENABLE_ASSERTIONS=OFF
-DLLVM_ENABLE_TERMINFO=OFF
-DLLVM_INCLUDE_GO_TESTS=OFF
-DLLVM_ENABLE_Z3_SOLVER=OFF
-DCOMPILER_RT_BUILD_BUILTINS=ON
-DLLVM_ENABLE_THREADS=ON
-DLLVM_OPTIMIZED_TABLEGEN=ON
-DLLVM_ENABLE_IDE=OFF
-DLLVM_BUILD_UTILS=ON
-DLLVM_INSTALL_UTILS=ON
-DLLVM_ENABLE_LIBCXX=ON
-DCMAKE_OSX_DEPLOYMENT_TARGET=11.2
-DCMAKE_OSX_SYSROOT=/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk
-DCOMPILER_RT_BUILD_CRT=OFF
-DCOMPILER_RT_BUILD_LIBFUZZER=OFF
-DCOMPILER_RT_BUILD_SANITIZERS=OFF
-DCOMPILER_RT_BUILD_XRAY=OFF
-DCOMPILER_RT_ENABLE_IOS=OFF
-DCOMPILER_RT_ENABLE_WATCHOS=OFF
-DCOMPILER_RT_ENABLE_TVOS=OFF
-DCMAKE_INSTALL_PREFIX=/Users/ohoskt/git/llvm/oh12/llvm-stage-1
-DLLVM_TARGETS_TO_BUILD=Native
'-DLLVM_ENABLE_PROJECTS=clang;lld;libcxx;libcxxabi;compiler-rt'
-DLLVM_BUILD_LLVM_DYLIB=OFF
-DLLVM_LINK_LLVM_DYLIB=OFF
/Users/ohoskt/git/llvm/oh12/llvm

/Users/ohoskt/git/llvm/oh12/llvm-stage-1-build
Running command: ninja install

Force-creating directory /Users/ohoskt/git/llvm/oh12/llvm-stage-2-build

/Users/ohoskt/git/llvm/oh12/llvm-stage-2-build
Running command: 
cmake -G Ninja
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
-DLLVM_ENABLE_ASSERTIONS=OFF
-DLLVM_ENABLE_TERMINFO=OFF
-DLLVM_INCLUDE_GO_TESTS=OFF
-DLLVM_ENABLE_Z3_SOLVER=OFF
-DCOMPILER_RT_BUILD_BUILTINS=ON
-DLLVM_ENABLE_THREADS=ON
-DLLVM_OPTIMIZED_TABLEGEN=ON
-DLLVM_ENABLE_IDE=OFF
-DLLVM_BUILD_UTILS=ON
-DLLVM_INSTALL_UTILS=ON
'-DLLVM_DISTRIBUTION_COMPONENTS=clang;libclang;lld;llvm-cov;llvm-profdata;llvm-ar;clang-resource-headers'
-DCLANG_LINKS_TO_CREATE=clang++
'-DLLD_SYMLINKS_TO_CREATE=ld.lld;wasm-ld'
-DLLVM_ENABLE_LIBCXX=ON
-DCMAKE_OSX_DEPLOYMENT_TARGET=11.2
-DCMAKE_OSX_SYSROOT=/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk
-DLIBCXX_USE_COMPILER_RT=ON
-DCMAKE_INSTALL_PREFIX=/Users/ohoskt/git/llvm/oh12/llvm-distribution
'-DLLVM_ENABLE_PROJECTS=clang;lld;libcxx;libcxxabi;compiler-rt'
-DCMAKE_C_COMPILER=/Users/ohoskt/git/llvm/oh12/llvm-stage-1/bin/clang
-DCMAKE_CXX_COMPILER=/Users/ohoskt/git/llvm/oh12/llvm-stage-1/bin/clang++
-DCMAKE_AR=/Users/ohoskt/git/llvm/oh12/llvm-stage-1/bin/llvm-ar
-DCMAKE_C_FLAGS=
-DCMAKE_CXX_FLAGS=-stdlib=libc++
-DCMAKE_EXE_LINKER_FLAGS=-stdlib=libc++
-DCMAKE_MODULE_LINKER_FLAGS=-stdlib=libc++
-DCMAKE_SHARED_LINKER_FLAGS=-stdlib=libc++
-DLLVM_BUILD_LLVM_DYLIB=OFF
-DLLVM_LINK_LLVM_DYLIB=OFF
/Users/ohoskt/git/llvm/oh12/llvm

/Users/ohoskt/git/llvm/oh12/llvm-stage-2-build
Running command: ninja install
```

编带debug信息版本时在二阶段cmake修改配置

```
-DCMAKE_BUILD_TYPE=RelWithDebInfo 
-DLLVM_ENABLE_ASSERTIONS=ON
```

### Linux

```shell
LLVM_FOLDER=/Users/ohoskt/git/llvm/oh12
git clone http://gitcode.com/openharmony/third_party_llvm-project $LLVM_FOLDER

cd kotlin-native/tools/llvm_builder/images/linux/
docker build --platform linux/amd64 -t kotlin-llvm-builder --file ./Dockerfile .

LLVM_FOLDER=/Users/hl/git/llvm/oh19
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
docker run --platform linux/amd64 --rm -it -v .:/output -v $LLVM_FOLDER:/llvm kotlin-llvm-builder --llvm-sources /llvm --install-path /output/llvm-12.0.1-x86_64-linux --distribution-components $DISTRIBUTION_COMPONENTS --save-temporary-files # --pack
```

## kotlin llvm-19.1.4

### Linux

```shell
cd

apt update
apt upgrade -y
apt install -y git docker ca-certificates curl

export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
curl -fsSL https://raw.githubusercontent.com/docker/docker-install/master/install.sh | sh

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

LLVM_FOLDER=$(realpath ~/kotlin-llvm-1914)
git clone --branch kotlin/llvm-19-apple --depth 3 --single-branch https://gitcode.com/linhandev/kotlin-llvm-project.git $LLVM_FOLDER
cd $LLVM_FOLDER
git checkout fb492d2475910b83cda3a68b4eee9e87d7e221c1
cd -

mkdir docker_image
cd docker_image
wget https://raw.githubusercontent.com/JetBrains/kotlin/refs/tags/v2.2.21/kotlin-native/tools/llvm_builder/images/linux/Dockerfile
# FROM docker.m.daocloud.io/ubuntu:20.04
wget https://raw.githubusercontent.com/JetBrains/kotlin/refs/tags/v2.2.21/kotlin-native/tools/llvm_builder/package.py
docker build -t kotlin-llvm-builder --file ./Dockerfile .
cd ..

mkdir output
cd output

DISTRIBUTION_COMPONENTS="clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers compiler-rt"
docker run --platform linux/amd64 --rm -it -v ./output:/output -v $LLVM_FOLDER:/llvm/ kotlin-llvm-builder --llvm-sources /llvm --install-path /output/ --save-temporary-files # --pack
```
