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




### Shadow Memory

- 被投毒（poison）的内存叫红区（redzone），哪里有毒的信息记在影子内存（shadow memory）里
- 1 shadow memory byte对应8个normal memory byte，分配的正常内存8 byte对齐，如malloc 13 bytes
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-17T09:41:36.909Z-image.png)

插桩：分配栈内存时前后poison，读写内存前根据sm进行校验
运行时：malloc分配的堆内存前后poison，free/delete释放的堆内存整个加锁在FIFO队列中等一段时间

### GWP

GWP-ASan的实现通常被描述为[电网](https://linux.die.net/man/3/efence)，内存池大小固定，内存开销也是固定的


If word references are made to un-aligned buffers, you will see a bus error (SIGBUS) instead of a segmentation fault.
操作了不允许的页SIGSEGV