---
title: KN Cinterop静态库Codesize优化
categories:
  - KMP
tags:
  - KMP
  - KN
  - Cinterop
  - StaticLib
  - Codesize
description: 介绍 KN 通过 cinterop 引入静态库时如何避免死代码进入最终 so：用 --exclude-libs 不导出静态库符号，并用 -ffunction-sections/-fdata-sections 编译静态库以配合 --gc-sections 做链接期死代码删除。
---

KN项目可以通过cinterop引入动态/静态库，引入的静态库会被链接进KN的产物so中，链接时能做的codesize优化比较有限，可能引入一些死代码。如果cinterop引入的静态库只提供给KN调用，可以使用不导出+gc-section的方式删除死代码。

## demo项目

[https://github.com/linhandev/kn_samples/tree/static-cinterop-codesize](https://github.com/linhandev/kn_samples/tree/static-cinterop-codesize)

```
kn_samples/
├── add/                         # 带静态库 cinterop 的 Kotlin 库
│   ├── build.gradle.kts         # ohosArm64、cinterop add 静态库，发布到 maven-repo
│   └── src/
│       ├── nativeInterop/add/
│       │   ├── add.h
│       │   ├── add.c            # 功能实现
│       │   ├── add.def          # cinterop 定义
│       │   └── libadd.a         # 构建脚本中用 clang 从 add.c 打出的静态库
│       └── nativeMain/kotlin/
│           └── PlaceHolder.kt   # 占位，否则构建配置写起来很麻烦
│
├── src/nativeMain/kotlin/       # 出 so 的 KN 工程，调用 add 里的 cinterop 库，@CName 导出接口给 c 调用
│   └── Add.kt                   # @CName("add_c_name")，内部调用 add 的 addcfun
│
├── c-caller/                    # C 驱动，调上面 KN 的 so
│   └── main.c                   # 链接 libc2k.so，调用 add_c_name()
│
├── maven-repo/                  # 仓库内 Maven（add 的 klib 发布到这方便查看）
├── build.gradle.kts             # 根工程：ohosArm64，依赖 add，产出 libc2k.so
├── settings.gradle.kts          # include("add")，maven-repo 放在仓库首位
└── run.sh                       # 构建静态库 → 发布 add klib → 构建 c2k → 构建 C 驱动 → 部署
```

先看看静态库怎么进的KN产物
1. 打出 libadd.a
2. cinterop [def配置](https://kotlinlang.org/docs/native-definition-file.html#include-a-static-library)
    ```
    package = add
    headers = add.h
    staticLibraries = libadd.a
    libraryPaths = src/nativeInterop/add
    ```
3. 打出klib
   1. 可以看到静态库文件被包进去了
     ```shell
     ./kn_samples/maven-repo/com/example/add-ohosarm64/1.0-SNAPSHOT/default
      ├── linkdata
      │   ├── module
      │   └── package_add
      │       └── 0_add.knm
      ├── manifest
      ├── resources
      └── targets
          └── ohos_arm64
              ├── included
              │   └── libadd.a
              ├── kotlin
              └── native
                  └── cstubs.bc
     ```
    2. manifest中有 `staticLibraries=libadd.a` ，应该是根据这个在出kn的so时加的链接 libadd.a 选项
4. 引入这个klib依赖，kotlin代码中调用，打出kn的so。最终的链接选项中链入了 libadd.a
     ```shell
      /Users/ohoskt/.konan/dependencies/llvm-1201-macos-aarch64/bin/ld.lld
      --sysroot=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot
      -export-dynamic
      -z
      relro
      --build-id
      --eh-frame-hdr
      -dynamic-linker
      /lib/ld-musl-aarch64.so.1
      -o
      /Users/ohoskt/git/sample/kn_samples/build/bin/ohosArm64/releaseShared/libc2k.so
      /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/Scrt1.o
      /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/crti.o
      /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/crtn.o
      --hash-style=gnu
      -L/Users/ohoskt/.konan/dependencies/llvm-1201-macos-aarch64/lib/aarch64-linux-ohos
      -L/Users/ohoskt/.konan/dependencies/llvm-1201-macos-aarch64/lib/aarch64-linux-ohos/c++
      -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos
      --gc-sections
      -S
      -shared
      --soname=libc2k.so
      /private/var/folders/0v/kpcstls94gd53xpxw5frkddh0000gn/T/konan_temp15306597006144440165/libc2k.so.o
      /var/folders/0v/kpcstls94gd53xpxw5frkddh0000gn/T/included11769682759184190092/libadd.a
      --exclude-libs=libadd.a
      -Bstatic
      -Bdynamic
      -ldl
      -lm
      -lpthread
      -lc++
      -lc++abi
      --defsym
      __cxa_demangle=Konan_cxa_demangle
      -lc
      -lunwind
      -lqos
      -lhitrace_ndk.z
      -lhilog_ndk.z
     ```

## 问题场景

下面来构建一个有死代码的场景，在 add.c 中加一个 deadFun，libadd.a 中会多一个 GLOBAL DEFAULT 的符号

```shell
➜  kn_samples git:(static-cinterop-published) ✗ llvm-readelf -s add/src/nativeInterop/add/libadd.a 

File: add/src/nativeInterop/add/libadd.a(add.o)

Symbol table '.symtab' contains 6 entries:
   Num:    Value          Size Type    Bind   Vis       Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT   UND 
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT   ABS add.c
     2: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT     2 $x.0
     3: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT     3 $d.1
     4: 0000000000000000    32 FUNC    GLOBAL DEFAULT     2 addCFun
     5: 0000000000000020     4 FUNC    GLOBAL DEFAULT     2 deadFun
➜  kn_samples git:(static-cinterop-published) ✗ 
```

最终kn的so也会导出这个符号

```shell
➜  kn_samples git:(static-cinterop-published) ✗ llvm-readelf --dyn-syms build/bin/ohosArm64/releaseShared/libc2k.so

Symbol table '.dynsym' contains 199 entries:
   Num:    Value          Size Type    Bind   Vis       Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT   UND 
     1: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT   UND main
                ... ...
   133: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND _Unwind_RaiseException
   134: 00000000000b2a70   200 FUNC    GLOBAL DEFAULT    12 add_c_name # @CName，kotlin的so开给c调的函数
                ... ...
   174: 00000000000c200c    32 FUNC    GLOBAL DEFAULT    12 addCFun # 静态库中给kotlin调的函数
                ... ...
   183: 00000000000c202c     4 FUNC    GLOBAL DEFAULT    12 deadFun # 静态库中的死代码，
                   ... ...
➜  kn_samples git:(static-cinterop-published) ✗ 
```

实际的场景 deadFun 可能是静态库中没有用到的一些功能，打进kn的so会增加包体积，相关的死代码和有被调用的代码进入一个page的话，会被一起交换进物理内存，增加内存占用

## 优化方案

> 优化方案的一个关键假设是这些静态库中提供给kotlin代码调用的方法**全都不需要**再从kn的so开放出去，给其他 c/cpp 调用。
>   - kn打包出的头文件不会包含这种静态库里的接口，如果有调用大概率引用了静态库的头文件
>   - 也可以通过查看hap中所有其他的so的动态符号表是否有Ndx=UND，Name在静态库中有定义的符号大概确认（通过dlopen dlsym调用不会体现在符号表中，所以这种方式也不能100%确认）
> 最终的收益和静态库中实际有多少死代码强相关

在链接时进行死代码删除的效果通常比编译时差。编译时在llvm ir上进行dce可以做到粒度非常细，比如函数中有一个一定走不到的else分支可以将这个分支的代码删除。链接时的 --gc-sections 选项只能删除elf中整个没用的section，最细的粒度只能到函数级进不到函数的实现中。链接时要进行有效的死代码移除需要两点：

1. 精确的gc root
2. 尽可能小的elf section

对一个so来说动态符号表中 GLOBAL/WEAK DEFAULT 的，开放给其他so调用的函数明显是要保留完整实现的，这些函数递归往下用到的所有其他函数和数据也都要保留。因此导出过多的符号会导致so中存在无效代码。当然也要注意正确性，如果实际用到了的符号没有导出，调用时会发生无法catch的崩溃。在cinterop静态库的场景下可以在def中添加 --exclude-libs 控制静态库中的符号不从最终的so中导出

```
package = add
headers = add.h
staticLibraries = libadd.a
libraryPaths = src/nativeInterop/add
linkerOpts = --exclude-libs=libadd.a
```

这个选项在最终出so的ld步骤上生效，简单尝试时也可以在编出so的应用工程中添加

```kotlin
kotlin {
    ohosArm64("ohosArm64") {
        compilations.getByName("main") {
            defaultSourceSet.dependencies {
                implementation("com.example:add-ohosarm64:1.0-SNAPSHOT")
            }
        }
        binaries {
            sharedLib {
                baseName = "c2k"
+                linkerOpts("--exclude-libs=libadd.a")
            }
        }
    }
}
```

在 dynsym 中看不到 addCFun 和 deadFun 后，会发现他们仍在 symtab 中，deadFun 仍没被删除。这是因为在静态库中这两个符号被打包到了同一个.text section中，这样 addCFun 有用就是这个section有用，保留这个 section 就导致 deadFun 被保留。针对这种情况需要在编译静态库时添加 -ffunction-sections 和 -fdata-sections，让所有函数和一些全局/静态变量被打进独立的section，可以独立进行删除。

```diff
# Build the static library for add (used by the published cinterop klib)
cd add/src/nativeInterop/add
"${LLVM_BIN}/clang" \
    --sysroot "${SYSROOT}" \
    --target=aarch64-linux-ohos \
    -O3 -fPIC \
+    -ffunction-sections -fdata-sections \
    -c add.c -o add.o
```

开启两个section选项后可以看到有多个 .text.函数名 的section，说明选项生效

```shell
➜  kn_samples git:(static-cinterop-codesize) ✗ llvm-readelf -S '/Users/ohoskt/git/sample/kn_samples/add/src/nativeInterop/add/libadd.a'

File: /Users/ohoskt/git/sample/kn_samples/add/src/nativeInterop/add/libadd.a(add.o)
There are 9 section headers, starting at offset 0x1c0:

Section Headers:
  [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            0000000000000000 000000 000000 00      0   0  0
  [ 1] .strtab           STRTAB          0000000000000000 000150 00006f 00      0   0  1
  [ 2] .text             PROGBITS        0000000000000000 000040 000000 00  AX  0   0  4
  [ 3] .text.addCFun     PROGBITS        0000000000000000 000040 000008 00  AX  0   0  4
  [ 4] .text.deadFun     PROGBITS        0000000000000000 000048 000004 00  AX  0   0  4
  [ 5] .comment          PROGBITS        0000000000000000 00004c 000059 01  MS  0   0  1
  [ 6] .note.GNU-stack   PROGBITS        0000000000000000 0000a5 000000 00      0   0  1
  [ 7] .llvm_addrsig     LLVM_ADDRSIG    0000000000000000 000150 000000 00   E  8   0  1
  [ 8] .symtab           SYMTAB          0000000000000000 0000a8 0000a8 18      1   5  8
```

cmake中选项通过 `target_compile_options(add PRIVATE -ffunction-sections -fdata-sections)` 添加
