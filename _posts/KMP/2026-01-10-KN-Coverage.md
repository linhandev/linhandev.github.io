---
title: Kotlin/Native 测试覆盖率统计
categories:
  - KN
tags:
  - KN
  - KMP
  - Kotlin Native
  - Test Coverage
  - 覆盖率
description: 探索 Kotlin/Native 代码覆盖率实现方案，对比 Kotlin IR 插桩与 LLVM IR 插桩两种技术路线，详细介绍基于 LLVM gcov 的覆盖率检测实现，包括编译插桩、运行时集成、覆盖率解析工具（llvm-cov、gcovr、lcov）的使用方法。
---
所以KN的这行代码跑没跑到？

## 相关项目

- JaCoCo：https://www.jacoco.org/jacoco/trunk/doc/flow.html
  - java bytecode上插桩；只识别至少执行了一次，不记次数；byte array记录执行情况 + 离线分析
  - 文档声称影响：30% codesize，10%性能
    ![alt text](/assets/img/post/2026-01-10-KN-Coverage/2026-01-16T09:50:22.410Z-image.png)
- Kover：https://github.com/Kotlin/kotlinx-kover
  - Collection of code coverage through JVM tests (**JS and native targets are not supported yet**).
  - 随kotlin 1.6发布，卖点是更好的KMP集成和对kotlin inline之类的语法做了针对性优化
    - [当前默认agent已经切到了jacoco](https://github.com/Kotlin/kotlinx-kover/issues/720)，更好的kotlin插桩支持后续都会在jacoco的agent中实现，第二个卖点已经没了
- Rust Coverage：https://rustc-dev-guide.rust-lang.org/llvm-coverage-instrumentation.html
  - 基于llvm sourcebased方案
- llvm
  - gcov
    - 基于dwarf，兼容gnu gcc
  - source based
    - clang前端从c代码直接生成mapping信息，不基于dwarf，llvm主推的方式
    - Kotlin 社区[曾实现过](https://github.com/JetBrains/kotlin/commit/4f77434ea57fea4a2f8b49abf9c495447c34f15a)基于source based的覆盖率，因为CoverageMappingFormat格式不稳定升级负担等原因回滚掉了
    - https://llvm.org/docs/CoverageMappingFormat.html
    - https://llvm.org/docs/InstrProfileFormat.html
    - https://clang.llvm.org/docs/SourceBasedCodeCoverage.html
      ![alt text](/assets/img/post/2026-01-10-KN-Coverage/2026-01-16T09:52:16.811Z-image.png)
    - 版本历史
      [这里](https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/ProfileData/Coverage/CoverageMapping.h#L1440)定义的版本枚举


      | Version | First LLVM release                                     | Commit                                                                                                                                                                                     |
      | ------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
      | 1       | LLVM 3.8 (initial format)                              | [\[PGO\] Minor refactoring /NFC](https://github.com/llvm/llvm-project/commit/1054a85a28682da0a9049a07979b130dce50b1c9)                                                                     |
      | 2       | LLVM 3.9 (MD5 name ref, name section compression)      | [\[PGO\] Enable compression in pgo instrumentation](https://github.com/llvm/llvm-project/commit/a82d6c0a4b95177289d0d79d28382ad874b073c2)                                                  |
      | 3       | LLVM 6.0 (gap regions / column end encoding)           | [\[Coverage\] Use gap regions to select better line exec counts](https://github.com/llvm/llvm-project/commit/ad8f637bd83aeeca7321d6c74b3d7787587c0d55)                                     |
      | 4       | LLVM 11.0 (named function records, zlib filename list) | [Reland: \[Coverage\] Revise format to reduce binary size](https://github.com/llvm/llvm-project/commit/dd1ea9de2e3e3ac80a620f71411a9a36449f2697)                                           |
      | 5       | LLVM 12.0 (branch regions)                             | [\[Coverage\] Add support for Branch Coverage in LLVM Source-Based Code Coverage](https://github.com/llvm/llvm-project/commit/9f2967bcfe2f7d1fc02281f0098306c90c2c10a5)                    |
      | 6       | LLVM 13.0 (compilation directory in filename list)     | [\[Coverage\] Store compilation dir separately in coverage mapping](https://github.com/llvm/llvm-project/commit/5fbd1a333aa1a0b70903d036b98ea56c51ae5224)                                  |
      | 7       | LLVM 18.1 (MC/DC: decision regions, extended branches) | [Reland: \[InstrProf\]\[compiler-rt\] Enable MC/DC Support in LLVM Source-based Code Coverage (1/3)](https://github.com/llvm/llvm-project/commit/f95b2f1acf1171abb0d00089fd4c9238753847e3) |

## 技术选型

基于什么，哪里动刀

1. 红色：发明部分轮子，Kotlin IR上插桩
   - 优点
     - KMP所有后端，jvm/wasm/js/native 可以共用一套工具
     - 插桩位置更靠近 Kotlin 代码，覆盖率和源码的对应关系更好
   - 缺点
     - 需要进行 Control Flow Graph 分析（KN编译器中已有），插桩策略（参考jacoco）+实现（KCP，难度较大），进行离线结果分析/源码对应（考虑复用jacoco组件）
2. 绿色：llvm gcov，LLVM IR上插桩，dwarf对应到源码
   - 优点
     - 成熟的native profile工具，接入简单
   - 缺点
     - LLVM IR 离 Kotlin 代码更远，已经经过了一些处理，如 Kotlin IR 上的的inline，一些高级语法难以对应到源码
3. 蓝色+绿色：llvm sourcebased，LLVM IR上插桩，CoverageMapping对应到源码
   - 优点
     - 成熟的native profile工具
     - 源码对应关系是和dwarf独立的另一套数据，便于针对 Kotlin 语法进行调整
   - 缺点
     - 需要实现根据 Kotlin IR 给 LLVM IR 添加 __llvm_coverage_mapping ，工作量大，升级 LLVM 复杂
       ![alt text](/assets/img/post/2026-01-10-KN-Coverage/image.png)
       https://excalidraw.com/#json=aaQDMU02N7k53sisqFP_Z,HG6qXqnoE3cvnF9dwZHk1Q

- Kover作为JB专门为KMP开发的框架也没做到Kotlin IR上，Kotlin IR上实现难度应该较高
- LLVM gcov可以只根据dwarf信息解析到代码，sourcebased实现需要在Konan前端加Code Coverage Map生成，成本较高
- 综上选择 gcov 看看效果

## KN 接入 LLVM gcov

参考实现：

- kotlin工程：https://github.com/linhandev/KuiklyBase-kotlin/commits/gcov/ 分支最后一笔
- 开启覆盖率需要在KMP工程中添加两个编译选项
  ```
  freeCompilerArgs += "-Xadd-light-debug=enable"
  freeCompilerArgs += "-Xbinary=coverage=true"
  ```
- 大规模项目编译时，bc到o代码生成阶段gcov相关的函数寄存器优化耗时极长，跳过相关步骤后构建耗时大致为不开插桩时的一倍
  ![alt text](/assets/img/post/2026-01-10-KN-Coverage/image-1.png)

## LLVM gcov 原理

以C代码为例

```cpp
#include <stdlib.h>

int main() {
    bool isOdd;
    if (rand() % 3 == 0) {
        isOdd = true;
    } else {
        isOdd = false;
    }
    return 0;
}
```

### LLVM IR插桩

首先在llvm ir上运行 GCOVProfilerPass，插桩前

```llvm
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca i8, align 1
  store i32 0, i32* %1, align 4
  %3 = call i32 @rand()
  %4 = srem i32 %3, 2
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %7

6:
  store i8 1, i8* %2, align 1
  br label %8

7:
  store i8 0, i8* %2, align 1
  br label %8

8:
  ret i32 0
}
```

插桩后

```llvm
@__llvm_gcov_ctr = internal global [2 x i64] zeroinitializer

... ...

; Function Attrs: noinline norecurse optnone mustprogress
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca i8, align 1
  store i32 0, i32* %1, align 4
  %3 = call i32 @rand()
  %4 = srem i32 %3, 2
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %9

6:                                                ; preds = %0
  %7 = load i64, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 0), align 8
  %8 = add i64 %7, 1
  store i64 %8, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 0), align 8
  store i8 1, i8* %2, align 1
  br label %12

9:                                                ; preds = %0
  %10 = load i64, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 1), align 8
  %11 = add i64 %10, 1
  store i64 %11, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 1), align 8
  store i8 0, i8* %2, align 1
  br label %12

12:                                               ; preds = %9, %6
  ret i32 0
}

```

IR中多了一个@__llvm_gcov_ctr数组，包含两个int64，分别统计走if和走else bb的次数

### 链接runtime

链接 libclang_rt.profile.a，应当优先使用跟插桩pass同一个LLVM版本中的静态库。腾讯的LLVM 12没打出这个a，用DevEco里15的静态库版本是错配的，但是这种混搭使用中还没发现问题。PGO的runtime也在这个a里（_*llvm_profile**），做覆盖率统计主要就用到统计结果写盘相关的实现

```cpp
T __gcov_dump # 手动触发结果写盘
T __gcov_fork
T __gcov_reset # 重置内存中的结果
```

### hap集成

在合适的时机触发dump

```cpp
extern "C" void __gcov_dump(void) __attribute__((weak));

if (__gcov_dump) {
    __gcov_dump();
}
```

要写到有权限的沙箱路径

- GCOV_PREFIX=有权限的路径
- GCOV_PREFIX_STRIP=99 去除所有前缀，在设置的路径平铺，⚠️ 可能导致碰撞
  - \-\-hash-filenames 在文件名中添加hash
  - 设好dwarf信息后减少strip的前缀数量

## 覆盖率解析

- gcno：coverage note，Control Flow Graph和代码的对应关系，只有代码的绝对路径位置没有代码内容
- gcda：coverage data，运行时CFG中每条边的执行次数

注意：

- 理论上有这俩就能解出来每行有没有执行，实际一些工具在设计上一定要求提供代码，没有代码时推荐lcov
- 上面那笔参考实现 gcno 是写到执行 gradlew 命令时的当前目录，gcda 是写到 /data/app/el2/100/base/[bundle名]/files/gcov/。电脑上使用 `hdc file recv [手机路径] [电脑路径]` 将gcda下载到电脑上
- exe/so中链接插了覆盖率桩的静态库，打静态库时就会出gcno，链接一个这样的库就会多生成一个gcda。ie：有几个gcno就会有几个gcda，一一对应
- 运行多次程序，一个gcno可以对应多个gcda；但是不会有一个gcda对应多个gcno，有几个gcno一次运行就会生成几个gcda

### llvm-cov

llvm自带工具，输出格式不是很好看/进行后续处理，不太推荐用这个

解析时把gcno和gcda放在一个文件夹，要求盘上在打包时原位置有代码

```shell
ls
# libc2k.gcda libc2k.gcno
gcov -b -f libc2k.gcda
```

部分输出，包含行/分支/函数覆盖，其中

- \-: 代表不认为这一行是代码，如注释，label等
- #####: 代表认为这行是代码，而且没有被执行
- 数字代表统计到这行执行了多少次
- branch x taken 统计分支覆盖率

```
        -:    0:Source:/Users/hl/git/sample/kn_samples/switchLib/src/commonMain/kotlin/SwitchFunction.kt
        -:    0:Graph:libc2k.gcno
        -:    0:Data:libc2k.gcda
        -:    0:Runs:1
        -:    0:Programs:1
        -:    1:package com.example.switchlib
        -:    2:
function kfun:com.example.switchlib#processValue(){}kotlin.String called 1 returned 100% blocks executed 56%
        2:    3:fun processValue(): String {
        -:    4:    val value = 3
        -:    5:    return when (value) {
        1:    6:        1 -> "One"
branch  0 taken 0%
branch  1 taken 100%
        1:    7:        2 -> "Two"
branch  0 taken 0%
branch  1 taken 100%
        1:    8:        3 -> "Three"
branch  0 taken 100%
branch  1 taken 0%
    #####:    9:        3 -> "Three again"
branch  0 never executed
branch  1 never executed
    #####:   10:        5 -> "Five"
branch  0 never executed
branch  1 never executed
    #####:   11:        else -> "Other"
        1:   12:    }
        1:   13:}
        -:   14:
function kfun:com.example.switchlib#processValueCond(){}kotlin.String called 1 returned 100% blocks executed 56%
        2:   15:fun processValueCond(): String {
        -:   16:    val value = 3
        -:   17:    return when {
        1:   18:        value == 1 -> "One"
branch  0 taken 0%
branch  1 taken 100%
        1:   19:        value == 2 -> "Two"
branch  0 taken 0%
branch  1 taken 100%
        1:   20:        value == 3 -> "Three"
branch  0 taken 100%
branch  1 taken 0%
    #####:   21:        value == 3 -> "Three again"
branch  0 never executed
branch  1 never executed
    #####:   22:        value == 5 -> "Five"
branch  0 never executed
branch  1 never executed
    #####:   23:        else -> "Other"
        1:   24:    }
        1:   25:}
```

### gcovr

[gcovr](https://github.com/gcovr/gcovr)基于gcov，支持的输出格式比较多，html格式看起来比较方便，json报告后续接处理流程比较方便，跟llvm-cov一样把gcno，gcda放在一个文件夹，要求盘上有代码

html报告，绿色100%执行，黄色有分支被部分执行，红色没执行，白色的是不认为是代码（注释这种）

```bash
python -m gcovr --html --html-details --output out/coverage.html --root [项目源码文件夹] \
  --gcov-ignore-errors=source_not_found \
  --gcov-ignore-errors=output_error \
  --gcov-ignore-errors=no_working_dir_found [包含gcno，gcda文件的路径]
```

![alt text](/assets/img/post/2026-01-10-KN-Coverage/2026-01-27T19:03:42.631Z-image.png)

json报告中有行/分支/函数覆盖率

```shell
python -m gcovr --json --root [项目源码文件夹] \
  --gcov-ignore-errors=source_not_found \
  --gcov-ignore-errors=output_error \
  --gcov-ignore-errors=no_working_dir_found [包含gcno，gcda文件的路径]
```

```json
{
    "file": "switchLib/src/commonMain/kotlin/SwitchFunction.kt",
    "lines": [
        {
            "line_number": 3,
            "function_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "count": 2,
            "branches": [],
            "gcovr/md5": "81015be1cd4ce43c21880ee229b5e1f7"
        },
        {
            "line_number": 6,
            "function_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "count": 1,
            "branches": [
                {
                    "branchno": 0,
                    "count": 0,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                },
                {
                    "branchno": 1,
                    "count": 1,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                }
            ],
            "gcovr/md5": "9198419fd3b61d1b13355cc8c716c729"
        },
        {
            "line_number": 7,
            "function_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "count": 1,
            "branches": [
                {
                    "branchno": 0,
                    "count": 0,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                },
                {
                    "branchno": 1,
                    "count": 1,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                }
            ],
            "gcovr/md5": "8a04fefbaaf29f7620e152b5629ee660"
        },
        {
            "line_number": 8,
            "function_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "count": 1,
            "branches": [
                {
                    "branchno": 0,
                    "count": 1,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                },
                {
                    "branchno": 1,
                    "count": 0,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                }
            ],
            "gcovr/md5": "a63ff6c3b1086e8e98c4ee7f3815c643"
        },
        {
            "line_number": 9,
            "function_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "count": 0,
            "branches": [
                {
                    "branchno": 0,
                    "count": 0,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                },
                {
                    "branchno": 1,
                    "count": 0,
                    "fallthrough": false,
                    "throw": false,
                    "source_block_id": 0
                }
            ],
            "gcovr/md5": "08b111aa51c291b9037756035641d8cc"
        },
        ... ...
    ],
    "functions": [
        {
            "demangled_name": "kfun:com.example.switchlib#processValue(){}kotlin.String",
            "lineno": 3,
            "execution_count": 1,
            "blocks_percent": 56.0
        },
        {
            "demangled_name": "kfun:com.example.switchlib#processValueCond(){}kotlin.String",
            "lineno": 15,
            "execution_count": 1,
            "blocks_percent": 56.0
        }
    ]
}
```

### lcov

lcov主要在gcov的基础上扩展了报告展示和运行数据合并，不要求盘上有代码

```
lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
     --ignore-errors format,empty,inconsistent \
     --function-coverage \
     --branch-coverage \
     --capture \
     --directory . \
     --output-file coverage.info
```

- \-\-gcov-tool：指定gcov工具路径，建议跟插桩用同一个llvm，使用llvm工具链gcov不是一个exe，是llvm-cov下的一个模式，这个选项可以传一个脚本，内容 `/path/to/llvm-cov gcov "$@"`
- \-\-capture：从 --directory 下找所有gcda和gcno数据进行解析

结果中

- SF：Source File，源码路径
- FNL：Function Line，函数0在第15行定义
- FNA：Function Name，函数0，checksum 1，函数符号名 kfun:com.example.switchlib#processValueCond(){}kotlin.String
- FNF：Functions Found，共发现2个函数
- FNH：Functions Hit，共执行2个函数
- BRDA：Branch Data，第6行，第0组（一组就是一个分支），分支1，执行1次
- BRF：Branches Found，共发现20个分支
- BRH：Branch Hit，覆盖了其中6个
- DA：Data，行号:执行次数
- LF：Lines Found，共发现18行代码
- LH：Lines Hit，共覆盖其中12行

```
TN:
SF:/Users/hl/git/sample/kn_samples/switchLib/src/commonMain/kotlin/SwitchFunction.kt
FNL:0,15
FNA:0,1,kfun:com.example.switchlib#processValueCond(){}kotlin.String
FNL:1,3
FNA:1,1,kfun:com.example.switchlib#processValue(){}kotlin.String
FNF:2
FNH:2
BRDA:6,0,0,0
BRDA:6,0,1,1
BRDA:7,0,0,0
BRDA:7,0,1,1
BRDA:8,0,0,1
BRDA:8,0,1,0
BRDA:9,0,0,-
BRDA:9,0,1,-
BRDA:10,0,0,-
BRDA:10,0,1,-
BRDA:18,0,0,0
BRDA:18,0,1,1
BRDA:19,0,0,0
BRDA:19,0,1,1
BRDA:20,0,0,1
BRDA:20,0,1,0
BRDA:21,0,0,-
BRDA:21,0,1,-
BRDA:22,0,0,-
BRDA:22,0,1,-
BRF:20
BRH:6
DA:3,2
DA:6,1
DA:7,1
DA:8,1
DA:9,0
DA:10,0
DA:11,0
DA:12,1
DA:13,1
DA:15,2
DA:18,1
DA:19,1
DA:20,1
DA:21,0
DA:22,0
DA:23,0
DA:24,1
DA:25,1
LF:18
LH:12
end_of_record
```

lcov合并多次执行的报告

```
lcov --add-tracefile coverage.info \
     --add-tracefile coverage.info \
     --ignore-errors format,inconsistent \
     --function-coverage \
     --branch-coverage \
     --output-file coverage_merged.info
```

一波解析多次运行的覆盖率，生成合并的报告。其中两个run文件夹里都要同时包含gcno，gcda

```
tree .
.
├── coverage.info
├── run1
│   ├── libc2k.gcda
│   └── libc2k.gcno
└── run2
    ├── libc2k.gcda
    └── libc2k.gcno

lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
     --ignore-errors format,empty,inconsistent \
     --function-coverage \
     --branch-coverage \
     --capture \
     --directory run1/ \
     --directory run2/ \
     --output-file coverage.info
```

如果两次运行的程序完全一样，gcno完全一样，可以用一个gcno+多个gcda生成合并报告

```
tree .

.
├── coverage.info
├── libc2k.gcno
├── run1
│   └── libc2k.gcda
├── run2
│   └── libc2k.gcda
└── run3
    └── libc2k.gcda

lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
    --ignore-errors format,empty,inconsistent \
    --function-coverage \
    --branch-coverage \
    --capture \
    --build-directory . \
    --directory run1 \
    --directory run2 \
    --directory run3 \
    --output-file coverage.info
```

## LLVM Source-Based 覆盖率数据结构

> 源码基于 LLVM 19 (`develop-19.1.4-OH`)，文件路径均为 `llvm-project` 下的相对路径

Source-based coverage 的核心设计是**静态映射与动态计数分离**：编译期在二进制中嵌入映射数据（哪个源码 region 对应第几号 counter），运行时只填充 counter 值，报告时用函数名 hash 做关联键把两边拼起来。

### 示例代码（2 TU）

以下文所有"具体示例"均基于这个 2 TU 的 C demo：

```c
// math.c (TU1)
int abs_value(int x) {
    if (x >= 0) {
        return x;
    } else {
        return -x;
    }
}
```

```c
// main.c (TU2)
int abs_value(int x);

int main() {
    int result = abs_value(-5);
    return result;
}
```

```bash
# 编译 (每 TU 独立)
clang -fprofile-instr-generate -fcoverage-mapping -c math.c -o math.o
clang -fprofile-instr-generate -fcoverage-mapping -c main.c -o main.o
# 链接
clang math.o main.o -o demo -lclang_rt.profile_osx
# 运行
LLVM_PROFILE_FILE=demo.profraw ./demo
# 合并
llvm-profdata merge demo.profraw -o demo.profdata
# 报告
llvm-cov report ./demo -instr-profile=demo.profdata
```

运行结果（`abs_value(-5)` 走 else 分支）：

```
Filename       Regions   Missed   Cover    Functions   Lines   Cover
main.c              1        0   100%             1       4   100%
math.c              4        1    75%             1       7    86%
TOTAL               5        1    80%             2      11    91%
```

### 编译期数据表（二进制内嵌 sections）

#### `__llvm_covmap` — TU 级文件名表

- `Version` — `uint32` — 覆盖率映射格式版本，当前 V6（`InstrProfData.inc:713`）。MC/DC（LLVM 17+）没有 bump 版本号，直接在 V6 内通过新增 RegionKind 实现。定义在 `llvm/include/llvm/ProfileData/Coverage/CoverageMapping.h:1440`
- `FilenamesSize` — `uint32` — 文件名表原始大小
- `NRecords` — `uint32` — 旧版遗留，恒为 0
- `CoverageMappingSize` — `uint32` — 旧版遗留，恒为 0
- `Filenames` — `string[]` — 本 TU 引用到的所有源文件路径列表，可 zlib 压缩。格式：`<num> <uncompressed-len> <compressed-len> <data>`。由 `CoverageFilenamesSectionWriter::write()` 生成（`CoverageMappingWriter.cpp`）
- `FilenamesRef` — `uint64` — 文件名表内容的 MD5 hash，作为外键被 covfun 引用

**数量关系**：每 TU 1 条。全局变量名 `__llvm_coverage_mapping`，使用 `PrivateLinkage`（各 TU 互不冲突）。链接后 section 内有 N 个（N = 链接的 .o 数）。

**具体示例**：demo 二进制中 `__llvm_covmap` section 有 2 个 `__llvm_coverage_mapping`（各 0x31=49 字节）：

```
[TU1: math.o]  Version=6  Filenames=["/tmp/cov_demo/math.c"]
[TU2: main.o]  Version=6  Filenames=["/tmp/cov_demo/main.c"]
```

两个 TU 的 Filenames 内容不同，所以 FilenamesRef hash 不同，covfun 据此区分"我属于哪个 TU 的文件名表"。

#### `__llvm_covfun` — 每函数覆盖率映射记录

- `NameRef` — `uint64` — 函数名的 MD5 hash（`IndexedInstrProf::ComputeHash`），**外键** → `__llvm_prf_data.NameRef` 和 `__llvm_prf_names`
- `FuncHash` — `uint64` — 函数 CFG hash，报告时用于校验 covfun 和 profdata 匹配同一函数。**外键** → `__llvm_prf_data.FuncHash`
- `FilenamesRef` — `uint64` — **外键** → `__llvm_covmap.FilenamesRef`，定位本函数所属的文件名表
- `IsUsed` — `bool` — 是否存在对应的 `__profc_` 全局变量。为 false 时表示未插桩函数（如编译器生成的），llvm-cov 跳过
- `CoverageMapping` — `bytes` — 二进制编码的映射数据，内含 CounterExpression 数组和 CounterMappingRegion 数组（见下文嵌套结构）

**数量关系**：每函数 1 条。全局变量名 `__covrec_<NameHash>`，使用 `LinkOnceODRLinkage` + COMDAT 便于链接器去重。

**具体示例**：demo 二进制中有 2 条 covfun 记录：


| 函数        | NameRef              | FuncHash             | FilenamesRef                 |
| ----------- | -------------------- | -------------------- | ---------------------------- |
| `abs_value` | `0x37f56dece2ec5a02` | `0x000000a792613611` | hash("/tmp/cov_demo/math.c") |
| `main`      | `0xdb956436e78dd5fa` | `0x0000000000000018` | hash("/tmp/cov_demo/main.c") |

`llvm-cov export` 解码后 `abs_value` 的 6 个 region（JSON 格式 `[行始, 列始, 行终, 列终, count, falseCount, fileID, kind]`）：

```json
"regions": [
  [1,22, 7,2, 1,0, 0,0],   // CodeRegion  counter[0]=1  函数体
  [2,9, 2,15,1,0, 0,0],    // CodeRegion  counter[0]=1  if 条件区域
  [2,16,2,17,0,0, 0,3],    // GapRegion   count=0        ) 和 { 之间间隙
  [2,17,4,6, 0,0, 0,0],    // CodeRegion  counter[1]=0   then 分支 (return x;)
  [4,6, 4,12,1,0, 0,3],    // GapRegion   count=1        else 行间隙
  [4,12,6,6, 1,0, 0,0]     // CodeRegion  expr[0]=1     else 分支 (return -x;)
]
"branches": [
  [2,9, 2,15, 0,1, 0,0,4]  // BranchRegion  trueCount=counter[1]=0, falseCount=expr[0]=1
]
```

注意 `then` 分支 count=0（`x=-5 < 0` 没走 then），`else` 分支 count=1（走了 else）。else 的 count 来自 expression（counter[0] - counter[1] = 1-0 = 1），**没有自己的 probe**。

`main` 只有 1 个 region：`[3,12, 6,2, 1,0, 0,0]` — 函数体，counter[0]=1，无分支。

**CoverageMapping 内嵌结构**（二进制编码，ULEB128）：

##### CounterExpression（每函数 0~K 条）

由 `CounterExpressionBuilder` 构造（`CoverageMappingGen.cpp:902`），用于减少实际 counter 数量：

- `Kind` — `enum {Add, Subtract}` — 表达式类型
- `LHS` — `Counter` — 左操作数（可引用另一个 counter 或 expression）
- `RHS` — `Counter` — 右操作数

**具体示例**：`abs_value` 有 1 条 expression：

```
expr[0] = Subtract(counter[0], counter[1])
// 即: else_count = 函数入口次数 - then次数
```

`main` 无 expression（只有 1 个 counter，无需派生）。

##### CounterMappingRegion（每函数 1~M 条）

由 `CounterCoverageMappingBuilder` 遍历 AST 时收集（`CoverageMappingGen.cpp:222`）：

- `Count` — `Counter` — 本 region 的计数器。`Counter` 有三种 Kind：`Zero`（恒零）、`CounterValueReference`（直接引用 `__profc_[index]`）、`Expression`（引用 CounterExpression 表）
- `FalseCount` — `Counter` — 仅 `BranchRegion`/`MCDCBranchRegion` 使用，false 分支计数
- `FileID` — `uint32` — **外键** → `__llvm_covmap.Filenames` 数组下标
- `ExpandedFileID` — `uint32` — 仅 `ExpansionRegion` 使用，宏展开后的文件 ID
- `LineStart` — `uint32` — 源码起始行
- `ColumnStart` — `uint16` — 源码起始列
- `LineEnd` — `uint32` — 结束行（相对 LineStart 的偏移）
- `ColumnEnd` — `uint16` — 结束列
- `Kind` — `enum RegionKind` — region 类型（见下）
- `MCDCParams` — `std::variant` — 仅 MC/DC region 携带，见下文

**具体示例**：`abs_value` 的 region→counter 映射关系：


| Region    | 源码位置       | Kind | Count 引用 | 解析后值 |
| --------- | -------------- | ---- | ---------- | -------- |
| 函数体    | L1:22 → L7:2  | Code | counter[0] | 1        |
| if 条件   | L2:9 → L2:15  | Code | counter[0] | 1        |
| 间隙      | L2:16 → L2:17 | Gap  | zero       | 0        |
| then 分支 | L2:17 → L4:6  | Code | counter[1] | 0        |
| else 间隙 | L4:6 → L4:12  | Gap  | zero       | 0        |
| else 分支 | L4:12 → L6:6  | Code | expr[0]    | 1        |

`main` 的 region：


| Region | 源码位置      | Kind | Count 引用 | 解析后值 |
| ------ | ------------- | ---- | ---------- | -------- |
| 函数体 | L3:12 → L6:2 | Code | counter[0] | 1        |

**RegionKind 枚举**（`CoverageMapping.h:223`）：


| Kind                 | 用途                                                               |
| -------------------- | ------------------------------------------------------------------ |
| `CodeRegion`         | 普通可执行代码区域                                                 |
| `GapRegion`          | 间隙区域（如`}` 收尾），仅当某行没有其他 region 时才影响行计数显示 |
| `ExpansionRegion`    | 宏展开映射，ExpandedFileID 指向展开后的虚拟文件                    |
| `SkippedRegion`      | 预处理器跳过的代码（`#if 0` 等）                                   |
| `BranchRegion`       | 叶子级布尔表达式，Count=True 次数，FalseCount=False 次数           |
| `MCDCDecisionRegion` | MC/DC 决策点（复合布尔表达式整体），携带 DecisionParameters        |
| `MCDCBranchRegion`   | MC/DC 条件点（复合表达式中的单个条件），携带 BranchParameters      |

##### MC/DC 参数（MCDCTypes.h）

MC/DC（Modified Condition/Decision Coverage）验证复合布尔表达式中每个条件是否能**独立**影响决策结果。例：`if (a && (b || c))` 需要验证 a、b、c 各自都能翻转结果。

**DecisionParameters**（`MCDCDecisionRegion` 携带）：

- `BitmapIdx` — `uint` — **外键** → `__llvm_prf_bits` bitmap 的字节偏移
- `NumConditions` — `uint16` — 本决策包含的条件个数

**BranchParameters**（`MCDCBranchRegion` 携带）：

- `ID` — `ConditionID (int16)` — 条件编号（0, 1, 2...）
- `Conds` — `ConditionID[2]` — true/false 路径分别评估的条件 ID

**具体示例**：本 demo 未启用 MC/DC（`-fcoverage-mcdc`），所以无 MC/DC region。若 `abs_value` 的 if 条件改为 `if (a && b)` 并启用 MC/DC，则会有：

```
MCDCDecisionRegion: BitmapIdx=0, NumConditions=2  (a, b 两个条件)
MCDCBranchRegion:   ID=0, Conds=[-1, 1]            (条件 a: true→条件b, false→决策结束)
MCDCBranchRegion:   ID=1, Conds=[0, -1]            (条件 b: true→决策为true, false→决策为false)
```

#### `__llvm_prf_cnts` — 计数器数组（probe）

- `GlobalName` — `__profc_<funcname>` — 每函数一个全局变量
- `Data` — `uint64[NumCounters+1]` — 零初始化计数器数组。index 0 = 函数入口计数，index 1~N = 各控制流分支计数

**这就是 probe**。运行时被 `inc qword ptr [__profc_func + index*8]` 直接递增，不是函数调用。Counter index 由 `CodeGenPGO::ComputeRegionCounts` 遍历 AST 时分配（`CodeGenPGO.cpp:208`），只在控制流分支点分配（if-then, for-body, while-cond, &&/|| 右侧等），不是每条语句一个。

**数量关系**：每函数 1 条。

**具体示例**：demo 二进制中 `__llvm_prf_cnts` section（24 字节 = 2 函数 × 各自 counter 数组）：

```
__profc_abs_value:  uint64[2]  ← NumCounters=2
  [0] = 1   函数入口计数    (abs_value 被调 1 次)
  [1] = 0   then 分支计数   (x=-5 < 0, 没走 then)

__profc_main:       uint64[1]  ← NumCounters=1
  [0] = 1   函数入口计数    (main 执行 1 次)
```

编译后 .o 中全为 0，运行后变为上面的值。else 分支没有 counter——它的 count = counter[0] - counter[1] = 1，通过 expression 在报告时推算。

#### `__llvm_prf_data` — 每函数元数据

定义在 `llvm/include/llvm/ProfileData/InstrProfData.inc:74`（`INSTR_PROF_DATA` 宏）：

- `NameRef` — `uint64` — 函数名 MD5 hash，**外键** → `__llvm_covfun.NameRef`（关联键）
- `FuncHash` — `uint64` — CFG hash，**外键** → `__llvm_covfun.FuncHash`（校验匹配）
- `CounterPtr` — `IntPtrT` — 相对偏移，运行时 `Data_ + CounterPtr` 解析为 `__profc_` 数组地址。**外键** → `__llvm_prf_cnts`
- `BitmapPtr` — `IntPtrT` — 相对偏移，指向 `__llvm_prf_bits` 中的 MC/DC bitmap。**外键** → `__llvm_prf_bits`
- `FunctionPointer` — `IntPtrT` — 函数地址
- `Values` — `IntPtrT` — value profiling 节点指针（PGO 用，覆盖率不使用）
- `NumCounters` — `uint32` — counter 数组长度
- `NumValueSites` — `uint16[2]` — value profile 站点数
- `NumBitmapBytes` — `uint32` — MC/DC bitmap 大小

**数量关系**：每函数 1 条。全局变量名 `__profd_<funcname>`。

**具体示例**：demo 二进制中 `__llvm_prf_data` section（2 条，各 64 字节）：

```
__profd_abs_value:
  NameRef       = 0x37f56dece2ec5a02   ← 与 covfun.NameRef 一致 (join key)
  FuncHash      = 0x000000a792613611   ← 与 covfun.FuncHash 一致
  CounterPtr    = 0xffffffffffffffe8   ← 相对偏移 -24, 指向 __profc_abs_value
  BitmapPtr     = 0x0000000000000000   ← 无 MC/DC
  FuncPtr       = 0x0000000100000a54   ← abs_value 函数地址
  NumCounters   = 2
  NumBitmapBytes = 0

__profd_main:
  NameRef       = 0xdb956436e78dd5fa   ← 与 covfun.NameRef 一致
  FuncHash      = 0x0000000000000018   ← 与 covfun.FuncHash 一致
  CounterPtr    = 0xffffffffffffffb8   ← 相对偏移 -72, 指向 __profc_main
  FuncPtr       = 0x0000000100000a14   ← main 函数地址
  NumCounters   = 1
  NumBitmapBytes = 0
```

CounterPtr 是相对 `__profd_` 结构体基址的偏移。例如 abs_value 的 `__profd_` 在 `0x10000C018`，`-24` 指向 `0x10000C000` = `__profc_abs_value` 数组起始。

#### `__llvm_prf_names` — 压缩函数名表

- `Data` — `bytes` — 所有函数名经 `collectPGOFuncNameStrings()` 压缩后的字节串

**数量关系**：每 module 1 条。全局变量名 `__llvm_prf_nm`。llvm-cov 报告时用 NameRef (MD5 hash) 在此反查函数名。

**具体示例**：demo 二进制中 `__llvm_prf_names` section（33 字节，两个 TU 的名字拼接）：

```
[TU1: math.o]  19 bytes  zlib压缩  → 解压后 "abs_value"
[TU2: main.o]  14 bytes  zlib压缩  → 解压后 "main"
```

llvm-cov 用 `NameRef=0x37f56dece2ec5a02` 在此查到 `"abs_value"`，用 `0xdb956436e78dd5fa` 查到 `"main"`。

#### `__llvm_prf_bits` — MC/DC bitmap

- `Data` — `uint8[NumBitmapBytes]` — MC/DC test vector bitmap，每个 bit 记录一种条件值组合是否出现过

**数量关系**：每函数 0~1 条，仅 `-fcoverage-mcdc` 启用时存在。被 `__profd_.BitmapPtr` 引用，被 `CounterMappingRegion.DecisionParameters.BitmapIdx` 定位。

**具体示例**：本 demo 未启用 MC/DC，section 为空（`NumBitmapBytes=0`）。

### 运行时产物

#### `.profraw` — 原始 profile 文件

由 `InstrProfilingFile.c` 的 `lprofWriteDataImpl()` 在 atexit 时写出。将二进制中的 `__llvm_prf_data` 结构体 + `__llvm_prf_cnts` 计数器值 + `__llvm_prf_names` 压缩名 + `__llvm_prf_bits` bitmap 打包为一个文件：

- `Header` — 17 个 `uint64` 字段：magic、version、BinaryIdsSize、NumData、NumCounters、NamesSize、CountersDelta、NamesDelta 等
- `Binary IDs`
- `__llvm_prf_data` 结构体数组 — 从二进制 `__llvm_prf_data` section 直接 dump
- `uint64` 计数器值 — 从 `__llvm_prf_cnts` section 直接 dump
- `uint8` MC/DC bitmap — 从 `__llvm_prf_bits` section 直接 dump
- 压缩函数名 — 从 `__llvm_prf_names` section 直接 dump

magic 定义在 `InstrProfData.inc:703`：`0xff6c70726f667281`（`\xff l p r o f r \x81`，末字节 `\x81`=129 区分 64 位平台，32 位为 `'R'`+129）。version 定义在 `InstrProfData.inc:711`：`INSTR_PROF_RAW_VERSION = 10`。

**数量关系**：每次运行 1 个。可用 `LLVM_PROFILE_FILE` 环境变量控制路径。

**具体示例**：demo 运行后 `demo.profraw`（224 字节）：

```
Header (17 × uint64 = 136 bytes):
  Magic           = 0xff6c70726f667281   ← "lprofr" + 平台标记
  Version         = 10                    ← INSTR_PROF_RAW_VERSION
  BinaryIdsSize   = 0
  NumData         = 2                     ← 2 个函数 (abs_value + main)
  NumCounters     = 3                     ← 2 + 1 = 3 个 counter
  NamesSize       = 33                    ← 压缩函数名总长度
  CountersDelta  = (counters_begin - data_begin)
  ...

Data 段 (2 × 64 bytes):
  __profd_abs_value 结构体    (NameRef=0x37f56dece2ec5a02, NumCounters=2)
  __profd_main 结构体         (NameRef=0xdb956436e78dd5fa, NumCounters=1)

Counters 段 (3 × 8 = 24 bytes):
  1, 0, 1    ← abs_value[0]=1, abs_value[1]=0, main[0]=1

Names 段 (33 bytes):
  zlib压缩的 "abs_value" + "main"
```

#### `.profdata` — 合并后的 IndexedProfile

由 `llvm-profdata merge` 生成（`llvm-profdata.cpp:mergeInstrProfile()`）：

- `Header` — version + variant flags（IR_PROF, CSIR_PROF, INSTR_ENTRY 等）
- `OnDiskChainedHashTable` — 以函数名 hash 为 key，计数器数组为 value 的磁盘哈希表
- `Profile Summary` — 热度阈值信息
- `Binary IDs` / `VTable names` / `Temporal traces`（可选）

**数量关系**：多个 `.profraw` 合并为 1 个 `.profdata`，计数器值按 NameHash+FuncHash 匹配后相加。

**具体示例**：`llvm-profdata show demo.profdata`：

```
Instrumentation level: Front-end
Total functions: 2
Maximum function count: 1
Maximum internal block count: 0
```

`llvm-cov` 报告时，从 `.profdata` 按 NameHash 查到 counter 数组（如 `abs_value → [1, 0]`），再从二进制 covfun 解码出 region→counter 映射，最终拼出每行执行次数。

### 表关联关系


| 父表                    | 子表                           | 基数  | 关联键                | 关联方式                                 |
| ----------------------- | ------------------------------ | ----- | --------------------- | ---------------------------------------- |
| `__llvm_covmap`         | `__llvm_covfun`                | 1:N   | FilenamesRef (hash)   | covfun 通过 hash 找到所属 TU 的文件名表  |
| `__llvm_covfun`         | `__llvm_prf_data`              | 1:1   | NameRef + FuncHash    | 报告时用这两个 hash 做关联，确认同一函数 |
| `__llvm_prf_data`       | `__llvm_prf_cnts` (`__profc_`) | 1:1   | CounterPtr (相对偏移) | 运行时`Data_ + CounterPtr` 解析          |
| `__llvm_prf_data`       | `__llvm_prf_bits`              | 1:0/1 | BitmapPtr (相对偏移)  | 仅 MC/DC 启用                            |
| `__llvm_prf_names`      | `__llvm_prf_data`              | 1:N   | NameRef (hash)        | 用 hash 反查函数名字符串                 |
| covfun Region.Count     | `__profc_` 数组                | N:1   | counter index         | Region 引用第几号 counter slot           |
| covfun Region.BitmapIdx | `__llvm_prf_bits`              | N:1   | 字节偏移              | MC/DC 决策点定位 bitmap 位置             |

**核心关联路径**：`llvm-cov` 报告时，对每个函数：

1. 从 `.profdata` 按 NameHash 查到计数器值数组
2. 从二进制 `__llvm_covfun` 解码出 region→counter 映射
3. 用 NameRef + FuncHash 确认两边是同一函数
4. 对每个 region，用 Count 中的 counter index 从 `.profdata` 取值，或用 expression 计算派生值
5. 结果：每行/region/branch 的执行次数

## edge case

- inline
  https://youtu.be/jNu5LY9HIbw?t=278 （jacoco 24年已经[支持了](https://github.com/jacoco/jacoco/pull/1670)）
  ![alt text](/assets/img/post/2026-01-10-KN-Coverage/2026-01-16T10:02:31.117Z-image.png)
- 异常
- lambda
- chained call

## TODO

- 是否可以控制插桩代码的范围
- 补全edge case，分析原因，解决方法

## Related

- [2023 LLVM Dev Mtg - Using Clang's source-based code coverage at scale](https://www.youtube.com/watch?v=RlySdMe3Eg0)
