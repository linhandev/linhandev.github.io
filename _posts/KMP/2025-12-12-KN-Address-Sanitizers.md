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

> One of the first Internet-spread computer worms was the Internet Worm in 1988, which exploited a buffer overrun. More than thirty years later, we are still seeing attacks that exploit this type of programming bug. -- Detecting memory safety violations, Arm Developer Manual


|                                  | ASAN                | HWASAN                              | MemDebug           | GWP-ASan                                                          |
| -------------------------------- | ------------------- | ----------------------------------- | ------------------ | ----------------------------------------------------------------- |
| 全名                             | Address Sanitizer   | Hardware-Assisted Address Sanitizer | Memory Debug       | Google-Wide Profiling</br>GWP-ASan Will Provide Allocation SANity |
| 部分检测依赖插桩                 | ✅                   | ✅                                   | ❌                  | ❌                                                                 |
| 开销                             | cpu，内存 200%      | cpu 200% 内存 10～35%               | cpu，内存  10～20% | cpu，内存 < 5%，可调                                              |
| 基本原理                         | Shadow Memory，红区 | Shadow Memory，指针Tag              |                    | page电网                                                          |
| heap-buffer-overflow             | ✅                   |                                     |                    |                                                                   |
| stack-buffer-overflow            | ✅                   |                                     |                    |                                                                   |
| stack-buffer-underflow           | ✅                   |                                     |                    |                                                                   |
| heap-use-after-free              | ✅                   |                                     |                    |                                                                   |
| stack-use-after-scope            | ✅                   |                                     |                    |                                                                   |
| attempt-free-nonallocated-memory | ✅                   |                                     |                    |                                                                   |
| double-free                      | ✅                   |                                     |                    |                                                                   |

|  |  |  |  |  |

[鸿蒙san文档](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-stability-address-sanitizer-overview)


asan
- 被投毒（poison）的内存叫红区（redzone），哪里有毒的信息记在影子内存（shadow memory）里
- 1 影子内存byte对8个应用内存byte，分配的正常内存8 byte对齐，如malloc 13 bytes
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-17T09:41:36.909Z-image.png)
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T01:37:16.744Z-image.png)
- 插桩：栈内存前后插入红区，读写内存前根据sm校验是否合法
- 运行时：malloc分配的堆内存前后poison，free/delete释放的堆内存整个加锁放入大小固定的FIFO队列
- 性能开销：sm操作
- 内存开销：8 byte对齐导致的空洞，前后的红区，释放后的隔离区，申请的内存8 byte向上取整和的1/8用于sm

-fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls # TODO：noinline


hwasan

128G = 2 ^ 7 * 2 ^ 10 (kb) * 2 ^ 10 (mb) * 2 ^ 10 (gb) = 2 ^ 37 bytes。64位寻址高位是用不到的

[Detecting-memory-safety-violations](https://developer.arm.com/documentation/102433/0200/Detecting-memory-safety-violations?lang=en)

- 拿到的地址是带tag的
  ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T02:42:47.734Z-image.png)
  ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T03:04:50.882Z-image.png)
- llvm实现tag 8位，地址分配16 byte对齐，开启后分配返回的指针带tag
  - 实际1～15bytes：sm中保存实际分配的byte数，应用内存最后一个byte保存tag
  - 实际分配16bytes：sm中保存tag
  - <15的tag不匹配可能是越界

calloc/malloc/free
jemalloc
new delete

### GWP

GWP-ASan的实现通常被描述为[电网](https://linux.die.net/man/3/efence)。性能方面为了减小开销只随机sample部分内存分配进行防护，检查通过mmu硬件进行开销较小，分配和释放内存时会回栈有一些开销，总体性能开销～5%。内存方面开销来自分配guard页和空洞，开销是固定可调的。

- 一次申请超过1 page的内存不会防护

If word references are made to un-aligned buffers, you will see a bus error (SIGBUS) instead of a segmentation fault.
操作了不允许的页SIGSEGV



KN 对象/数组分配

对象的地址可以给堆或者栈上的变量

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:03:01.128Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:02:34.508Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:01:15.587Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:00:15.675Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:58.596Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:49.198Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:39.963Z-image.png)