---
title: KN 地址越界检测
categories:
  - KN
tags:
  - KN
  - KMP
  - ASAN
  - HWASAN
  - GWP-ASAN
description: 
published: false
---

|                                  | ASAN              | HWASAN                              | MemDebug           | GWP-ASan                                                          |
| -------------------------------- | ----------------- | ----------------------------------- | ------------------ | ----------------------------------------------------------------- |
| 全名                             | Address Sanitizer | Hardware-Assisted Address Sanitizer | Memory Debug       | Google-Wide Profiling</br>GWP-ASan Will Provide Allocation SANity |
| 部分检测依赖插桩                 | ✅                 | ✅                                   | ❌                  | ❌                                                                 |
| 开销                             | cpu，内存 200%    | cpu 200% 内存 10～35%               | cpu，内存  10～20% | cpu，内存 < 5%，可调                                              |
| 基本原理                         | Shadow Memory     | Shadow Memory，指针Tag              |                    |                                                                   |
| heap-buffer-overflow             | ✅                 |                                     |                    |                                                                   |
| stack-buffer-overflow            | ✅                 |                                     |                    |                                                                   |
| stack-buffer-underflow           | ✅                 |                                     |                    |                                                                   |
| heap-use-after-free              | ✅                 |                                     |                    |                                                                   |
| stack-use-after-scope            | ✅                 |                                     |                    |                                                                   |
| attempt-free-nonallocated-memory | ✅                 |                                     |                    |                                                                   |
| double-free                      | ✅                 |                                     |                    |                                                                   |

|  |  |  |  |  |
[鸿蒙地址越界检测相关文档](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-stability-address-sanitizer-overview)


异常类型

- 空间
  - heap buffer under/overflow
  - stack buffer under/overflow
- 时间
  - heap use after free
  - stack use after scope (return?)
  - double free
  - free nonallocated memory

asan： heap-buffer-overflow stack-buffer-overflow stack-buffer-underflow heap-use-after-free stack-use-after-scope attempt-free-nonallocated-memory double-free 

hwasan：stack-buffer-overflow/underflow stack-use-after-return heap-buffer-overflow heap-buffer-underflow heap-use-after-free double-free

gwpasan：double free use_after_free invalid free left invalid free right buffer underflow 

堆栈分配方法
- 堆
  - calloc/malloc/free
  - jemalloc
  - new delete
- 栈
  - alloc

### Asan

- 被投毒（poison）的内存叫红区（redzone），哪里有毒的信息记在影子内存（shadow memory）里
- 1 shadow memory byte对应8个normal memory byte，分配的正常内存8 byte对齐，如malloc 13 bytes
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-17T09:41:36.909Z-image.png)

插桩：分配栈内存时前后poison，读写内存前根据sm进行校验
运行时：分配堆内存时前后poison，释放的堆内存整个加锁在FIFO队列中等一段时间

### GWP

GWP-ASan的实现通常被描述为[电网](https://linux.die.net/man/3/efence)。性能方面为了减小开销只随机sample部分内存分配进行防护，检查通过mmu硬件进行开销较小，分配和释放内存时会回栈有一些开销，总体性能开销～5%。内存方面开销来自分配guard页。性能和内存的开销是固定可调的。

- 一次申请超过1 page的内存不会防护

If word references are made to un-aligned buffers, you will see a bus error (SIGBUS) instead of a segmentation fault.
操作了不允许的页SIGSEGV





故障模式：

认为关键是申请和使用方，踩到的是谁的内存不关键

|        | C指针                   | KN指针                                                                                               |
| ------ | ----------------------- | ---------------------------------------------------------------------------------------------------- |
| C使用  | 正常san                 | 1. KN栈内存没发现获取指针方式，给不到C <br> 2. KN堆内存溢出到内存池外 <br> 3. KN堆内存溢出到内存池内 |
| KN使用 | konan接llvm san插桩pass | 同C使用                                                                                              |

可能的问题：
1. konan调llvm 12的插桩pass，和15的rt组合是不是会有兼容问题？

