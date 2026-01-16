---
title: Kotlin/Native 覆盖率
categories:
  - KN
tags:
  - KN
  - KMP
  - Hacking
---

KN的这行代码跑没跑到？

## 相关项目

- JaCoCo：https://www.jacoco.org/jacoco/trunk/doc/flow.html
    - java bytecode插桩；只识别至少执行了一次，不记次数；byte array记录执行情况 + 离线分析
    - 文档声称影响：30% codesize，10%性能
    
    ![alt text](../../assets/img/post/2026-01-10-KN-Coverage/2026-01-16T09:50:22.410Z-image.png)
    
- Kover：https://github.com/Kotlin/kotlinx-kover
    - Collection of code coverage through JVM tests (**JS and native targets are not supported yet**).
    - 随kotlin 1.6发布，更好的kmp集成，发布时是针对kotlin inline之类的语法做了优化，[当前默认agent已经切到了jacoco](https://github.com/Kotlin/kotlinx-kover/issues/720)
- rust coverage：https://rustc-dev-guide.rust-lang.org/llvm-coverage-instrumentation.html
    - 基于llvm sourcebased，使用文档没写实现
- llvm
    - gcov
        - 基于dwarf，兼容gnu gcc
    - source based
        - clang前端从c代码直接生成mapping信息，不基于dwarf，llvm主推
        - https://llvm.org/docs/CoverageMappingFormat.html
        - https://llvm.org/docs/InstrProfileFormat.html
        - https://clang.llvm.org/docs/SourceBasedCodeCoverage.html
            
            ![alt text](../../assets/img/post/2026-01-10-KN-Coverage/2026-01-16T09:52:16.811Z-image.png)
            

## 技术选型

基于什么，哪里动刀

1. 红色：发明部分轮子，Kotlin IR上插桩
   - 优点
     - KMP所有后端，jvm/wasm/js/native 一套工具
     - 插桩位置更靠近kotlin代码，覆盖率和源码的对应关系更好
   - 缺点
     - 需要进行Control Flow Graph分析（KN编译器应该已有），设计插桩策略+实现（参考kover/jacoco），进行离线结果分析/源码对应（分析可能可以复用jacoco）
2. 绿色：llvm gcov，LLVM IR上插桩
   - 优点
     - 成熟的native profile工具，接入简单
   - 缺点 
     - LLVM IR离Kotlin代码更远，已经经过了一些处理，如Kotlin的inline，一些高级语法难以对应到源码

![alt text](../../assets/img/post/2026-01-10-KN-Coverage/2026-01-16T09:52:33.358Z-image.png)

https://excalidraw.com/#json=aaQDMU02N7k53sisqFP_Z,HG6qXqnoE3cvnF9dwZHk1Q

- Kover作为为KMP开发的框架也没做到Kotlin IR上，Kotlin IR上实现难度应该较高
- LLVM gcov可以只根据dwarf信息解析到代码，sourcebased实现需要在Konan前端加Code Coverage Map生成，成本较高
- 综上选择 gcov 看看效果

## LLVM gcov

1. 编译插桩：GCOVProfilerPass

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

  插桩前

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

2. 链接runtime：libclang_rt.profile.a，腾讯的LLVM 12没打出这个a，用的DevEco里15的版本。这里版本是错配的但是使用中还没发现问题

  PGO的runtime也在这个a里（_*llvm_profile**），做覆盖率统计主要就用到统计结果写盘相关的实现

  ```cpp
  T InstProfClzll
  T InstProfPopcountll
  T InstrProfGetRangeRepValue
  T InstrProfIsSingleValRange
  T __gcov_dump # 手动触发结果写盘
  T __gcov_fork
  T __gcov_reset # 重置内存中的结果
  T __llvm_get_function_addr
  T __llvm_orderfile_dump
  T __llvm_orderfile_write_file
  T __llvm_profile_begin_counters
  T __llvm_profile_begin_data
  ... ...
  T __llvm_profile_write_file
  T __llvm_write_binary_ids
  T getFirstValueProfRecord
  T getValueProfDataSize
  T getValueProfRecordHeaderSize
  T getValueProfRecordNext
  T getValueProfRecordNumValueData
  T getValueProfRecordSize
  T getValueProfRecordValueData
  T initBufferWriter
  T llvm_delete_reset_function_list
  T llvm_gcda_emit_arcs
  T llvm_gcda_emit_function
  T llvm_gcda_end_file
  T llvm_gcda_start_file
  T llvm_gcda_summary_info
  T llvm_gcov_init
  T llvm_register_reset_function
  T llvm_register_writeout_function
  T llvm_reset_counters
  T llvm_writeout_files
  T lprofApplyPathPrefix
  T lprofBufferIOFlush
  ... ...
  T lprofUnlockFileHandle
  T lprofWriteData
  T lprofWriteDataImpl
  T serializeValueProfDataFrom
  T serializeValueProfRecordFrom
  ```

3. hap集成
    1. 合适的时机触发dump
        
        ```cpp
        extern "C" void __gcov_dump(void) __attribute__((weak));
        
        if (__gcov_dump) {
            __gcov_dump();
        }
        ```
        
    2. 写到有权限的沙箱路径
        1. GCOV_PREFIX=有权限的路径
        2. GCOV_PREFIX_STRIP=99 去除所有前缀，在设置的路径平铺，⚠️ 可能导致碰撞
            1. --hash-filenames 在文件名中添加hash
            2. 设好dwarf信息后减少strip的前缀数量
4. 覆盖率解析
   - gcno：Control Flow Graph和代码的对应关系，只有代码位置没有代码内容
   - gcda：运行时CFG中每条边的执行次数
   - 理论上有这俩就能解出来每行有没有执行，但是工具没这种选项一定要有代码

  ```bash
  # 每行是否覆盖的json报告
  python -m gcovr --html --html-details --output temp/coverage.html --root /source/root/ \
    --gcov-ignore-errors=source_not_found \
    --gcov-ignore-errors=output_error \
    --gcov-ignore-errors=no_working_dir_found /path/to/gcda,gcno

  # html报告
  python -m gcovr --json --root ./source/root/ \
    --gcov-ignore-errors=source_not_found \
    --gcov-ignore-errors=output_error \
    --gcov-ignore-errors=no_working_dir_found /path/to/gcda,gcno
  ```

## edge case

- inline
  https://youtu.be/jNu5LY9HIbw?t=278 （jacoco 24年已经[支持了](https://github.com/jacoco/jacoco/pull/1670)）
  ![alt text](../../assets/img/post/2026-01-10-KN-Coverage/2026-01-16T10:02:31.117Z-image.png)

- 异常

- lambda

- chained call



## TODO
- 是否可以控制插桩代码的范围
- 补全edge case，分析原因，解决方法
