---
title: KN 地址消毒
categories:
  - KN
tags:
  - KN
  - KMP
  - ASAN
  - HWASAN
  - GWP-ASAN
description: 
---


> One of the first Internet-spread computer worms was the Internet Worm in 1988, which exploited a buffer overrun. More than thirty years later, we are still seeing attacks that exploit this type of programming bug. -- Detecting memory safety violations, Arm Developer Manual

## 背景信息

|                  | ASAN                | HWASAN                              | MemDebug           | GWP-ASan                                                          |
| ---------------- | ------------------- | ----------------------------------- | ------------------ | ----------------------------------------------------------------- |
| 全名             | Address Sanitizer   | Hardware-Assisted Address Sanitizer | Memory Debug       | Google-Wide Profiling<br/>GWP-ASan Will Provide Allocation SANity |
| 部分检测依赖插桩 | ✅                   | ✅                                   | ❌                  | ❌                                                                 |
| 开销             | cpu，内存 200%      | cpu 200% 内存 10～35%               | cpu，内存  10～20% | cpu，内存 < 5%，可调                                              |
| 基本原理         | Shadow Memory，红区 | Shadow Memory，指针Tag              |                    | page电网                                                          |
|                  |                     |                                     |                    |                                                                   |


[鸿蒙san文档](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-stability-address-sanitizer-overview)

KN故障模式：认为关键是谁申请的内存，谁拿着指针做非法访问

|        | C指针                   | KN指针                                                                                             |
| ------ | ----------------------- | -------------------------------------------------------------------------------------------------- |
| C使用  | 正常san                 | 1. KN栈内存没发现获取指针方式，给不到C<br/>2. KN堆内存溢出到内存池外<br/>3. KN堆内存溢出到内存池内 |
| KN使用 | konan接llvm san插桩pass | 同C使用                                                                                            |

异常类型
- 空间
  - heap buffer under/overflow
  - stack buffer under/overflow
- 时间
  - heap use after free
  - stack use after scope (return?)
  - double free
  - free nonallocated memory

鸿蒙官网异常类型
- asan： heap-buffer-overflow stack-buffer-overflow stack-buffer-underflow heap-use-after-free stack-use-after-scope attempt-free-nonallocated-memory double-free 
- hwasan：stack-buffer-overflow/underflow stack-use-after-return heap-buffer-overflow heap-buffer-underflow heap-use-after-free double-free
- gwpasan：double free use_after_free invalid free left invalid free right buffer underflow 

堆栈分配方法
- 堆
  - calloc/malloc/free
  - jemalloc
  - new delete
- 栈
  - alloc


## san 原理

### Asan

- 被投毒（poison）的内存叫红区（redzone），哪里有毒的信息记在影子内存（shadow memory）里
- 1 shadow memory byte对应8个normal memory byte，分配的正常内存8 byte对齐，如malloc 13 bytes，05代表sm这个byte对应的应用8byte内存中前5byte是可以访问的，后3byte是不能访问的
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-17T09:41:36.909Z-image.png)
    ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T01:37:16.744Z-image.png)

- 插桩：分配栈内存时前后poison，读写内存前根据sm进行校验
- 运行时：分配堆内存时前后poison，释放的堆内存整个poison在FIFO队列中等一段时间

- 性能开销：sm操作
- 内存开销：8 byte对齐导致的空洞，前后的红区，释放后的隔离区，申请的内存8 byte向上取整和的1/8用于sm

### HWASAN

- [Detecting-memory-safety-violations](https://developer.arm.com/documentation/102433/0200/Detecting-memory-safety-violations?lang=en)
- [Arm Memory Tagging Extension Whitepaper](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Arm_Memory_Tagging_Extension_Whitepaper.pdf)

- 利用arm硬件寻址时的Top Byte Ignore功能：128G = 2 ^ 7 * 2 ^ 10 (kb) * 2 ^ 10 (mb) * 2 ^ 10 (gb) = 2 ^ 37 bytes。37 bit就能表示128G的内存地址空间，64位系统上寻址时高位是用不到的
- 分配内存时拿到的地址是带tag的，使用地址时检查地址中的tag和被访问地址的tag是不是一致
  ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T02:42:47.734Z-image.png)
  <!-- ![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T03:04:50.882Z-image.png) -->
- LLVM的hwasan实现tag是8位，也有shadow memory，1 sm byte对 16 应用byte。应用内存分配16 byte对齐
  - 分配
    - 分配了 n * 16 + 1～15 bytes：sm中保存实际分配的byte数，应用内存最后一个byte保存tag
    - 分配了 n * 16 bytes：sm中保存tag
  - 检查
    - 如果shadow byte值 \[1, 15\]：
      - 指针tag == shadow byte：视为完整16字节粒度的正常tag，有效
      - 指针tag != shadow byte：视为短粒度tag，检查访问地址是否在16字节粒度的前N字节内（N为shadow byte值），且指针tag是否与应用内存16 byte中最后一个byte存的tag匹配
        - 如果都满足：短粒度访问有效
        - 否则：无效
    - 否则（shadow byte值 > 15或为0）：
      - 如果指针tag与shadow byte匹配：有效
      - 如果指针tag与shadow byte不匹配：无效

```shell
┌─────────────────────────┐
│ Extract PtrTag (>>56)   │
│ Compute Shadow = Addr>>4│
│ Load MemTag from Shadow │
└────────────┬────────────┘
             ↓
      ┌─────▼──────┐
      │ PtrTag ==  │
      │  MemTag?   │
      └──┬─────┬───┘
    Yes  │     │ No
         │     ↓
         │  ┌──▼──────────┐
         │  │MemTag > 15? │ (Not short granule)
         │  └──┬─────┬────┘
         │ Yes │     │ No
         │     │     ↓
         │     │  ┌──▼────────────────────┐
         │     │  │ (Addr&15)+Size > Tag? │
         │     │  └──┬─────┬──────────────┘
         │     │ Yes │     │ No
         │     │     │     ↓
         │     │     │  ┌──▼──────────────┐
         │     │     │  │ Load Tag @Addr|15│
         │     │     │  │ PtrTag == Tag?  │
         │     │     │  └──┬─────┬────────┘
         │     │     │ Yes │     │ No
         ↓     ↓     ↓     ↓     ↓
      [OK]    [ ERROR ]  [OK]  [ERROR]
```
### GWP

GWP-ASan的实现通常被描述为[电网](https://linux.die.net/man/3/efence)。性能方面为了减小开销只随机sample部分内存分配进行防护，检查通过mmu硬件进行开销较小，分配和释放内存时会回栈有一些开销，总体性能开销～5%。内存方面开销来自分配guard页和空洞，开销是固定可调的。

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T03:59:24.624Z-image.png)

- 上下溢：如检查下溢时将数据分配到gwp内存池中向slot低地址方向对齐，这样指针-1的位置会访问到上一个不可读不可写不可执行的guard page，触发mmu异常信号
- uaf：释放内存时将这段内存所在的整个Slot设为不可读不可写不可执行，持续一段时间，uaf访问时触发mmu异常信号

- 一次申请超过1 page的内存不会防护

## DevEco LLVM san编译参数

开启hvigor详细日志查看cmake参数

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T06:21:57.769Z-image.png)

构建日志中搜 [cmake]

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T06:22:27.994Z-image.png)

对比DevEco中是否勾选asan，cmake选项差一个 `'-DOHOS_ENABLE_ASAN=ON'`

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T06:26:02.729Z-image.png)

对比 `.cxx/default/default/debug/arm64-v8a/compile_commands.json` 中具体cpp文件的编译命令，clang++多了几个选项

- asan:
  ```
  -shared-libasan
  -fsanitize=address
  -fno-omit-frame-pointer
  -fsanitize-recover=address
  ```
- hwasan:
  ```
  -shared-libasan
  -fsanitize=hwaddress
  -mllvm -hwasan-globals=0
  -fno-emulated-tls
  -fno-omit-frame-pointer
  ```
![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T06:29:59.512Z-image.png)

KN接入 LLVM 已有能力通常是两步：1. 调相关pass处理IR，2. 链接运行时库。编一个最简单的 int main() {} 比较差异

```shell
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ --target=aarch64-linux-ohos test.cpp -v -mllvm -debug-pass=Structure
# vs
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ --target=aarch64-linux-ohos test.cpp -v -mllvm -debug-pass=Structure -shared-libasan -fsanitize=address -fno-omit-frame-pointer -fsanitize-recover=address
```

比较输出中的ld命令

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2026-01-16T06:38:22.932Z-image.png)

KN接入san时应当参考KN使用的 LLVM 版本中的链接参数，其他版本的 LLVM 参数和 DevEco中的 LLVM 15可能不同

## KN 内存分配

### 分配过程

对象的地址可以赋给堆或者栈上的变量

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:03:01.128Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:02:34.508Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:01:15.587Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T06:00:15.675Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:58.596Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:49.198Z-image.png)

![alt text](../../assets/img/post/2025-12-12-KN-Address-Sanitizers/2025-12-30T05:59:39.963Z-image.png)

### 内存布局

> ！！！本章节基本是大模型走读KN runtime代码总结，缺乏验证！！！

对象：

| Offset                                                      | Field                   | Size      | Alignment   | Bit-Level Details                                                                                                                                                                                                                   |
| ----------------------------------------------------------- | ----------------------- | --------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0x00                                                        | **gc::GC::ObjectData**  | 8 bytes   | 8 bytes     | **GC Header**                                                                                                                                                                                                                       |
|                                                             | next_ (atomic pointer)  | 8 bytes   | 8 bytes     | 8 bytes for all 3 gc types                                                                                                                                                                                                          |
| 0x08                                                        | **KObject (ObjHeader)** | varies    | 8 bytes     | **Kotlin Object Data**                                                                                                                                                                                                              |
|                                                             | typeInfoOrMeta_         | 8 bytes   | 8 bytes     | **Bits 0-63**: Pointer to TypeInfo or MetaObjHeader                                                                                                                                                                                 |
| **Bits 0-1**: Tag bits (OBJECT_TAG_MASK)                    |
| 0x10+                                                       | **Object fields**       | N bytes   | **natural** | **⚠️ Fields use NATURAL alignment, NOT 8-byte!**: Boolean: 1 byte (1-byte aligned),Byte: 1 byte (1-byte aligned),Short: 2 bytes (2-byte aligned),Int/Float: 4 bytes (4-byte aligned),Long/Double/Reference: 8 bytes (8-byte aligned) |
| Compiler reorders by size (large→small) to minimize padding |
| END                                                         | **[Padding]**           | 0-7 bytes | —           | Pad entire object to 8-byte boundary                                                                                                                                                                                                |

```kotlin
class Example {
    val flag: Boolean    // 1 byte
    val count: Int       // 4 bytes  
    val ref: String?     // 8 bytes
}
```

| Offset    | Field            | Size    | Explanation                           |
| --------- | ---------------- | ------- | ------------------------------------- |
| 0x00      | ObjectData.next_ | 8 bytes | GC header                             |
| 0x08      | typeInfoOrMeta_  | 8 bytes | Object header                         |
| 0x10      | ref              | 8 bytes | Largest field first (8-byte aligned)  |
| 0x18      | count            | 4 bytes | Medium field (4-byte aligned, NOT 8!) |
| 0x1C      | flag             | 1 byte  | **Only 1 byte used** (1-byte aligned) |
| 0x1D      | [padding]        | 3 bytes | Pad to 8-byte boundary                |
|           |                  |         |                                       |
| **Total** | **32 bytes**     |         | 8 + 24 where instanceSize_ = 24       |

```kotlin
┌─────────────────────────────────────────────┐
│  HEAP (per-instance data)                   │
├─────────────────────────────────────────────┤
│  0x00: gc::GC::ObjectData                   │
│        - next_ (8 bytes)                    │
├─────────────────────────────────────────────┤
│  0x08: ObjHeader (KObject)                  │
│        - typeInfoOrMeta_ (8 bytes) ────┐    │
├─────────────────────────────────────────│────┤
│  0x10: [Object fields]                  │    │
│        - field1                         │    │
│        - field2                         │    │
│        - ...                            │    │
└─────────────────────────────────────────│────┘
                                          │
                    Points to             │
                        ▼                 │
┌─────────────────────────────────────────┴────┐
│  STATIC MEMORY (per-class metadata)          │
├──────────────────────────────────────────────┤
│  TypeInfo (shared by all instances):         │
│    - typeInfo_ (self-reference)              │
│    - extendedInfo_                           │
│    - unused_                                 │
│    - instanceSize_       ← Size of fields    │
│    - superType_                              │
│    - objOffsets_         ← GC scan info      │
│    - objOffsetsCount_                        │
│    - implementedInterfaces_                  │
│    - flags_                                  │
│    - classId_                                │
│    - associatedObjects                       │
│    - processObjectInMark                     │
│    - instanceAlignment_                      │
│    - vtable_[]           ← Virtual methods   │
└──────────────────────────────────────────────┘
```

```kotlin
TypeInfo
┌─────────────────────────────────────┐
│ gc::GC::ObjectData (8 bytes)        │
├─────────────────────────────────────┤
│ ObjHeader                            │
│   typeInfoOrMeta_ ────────┐         │
│                            │         │
├────────────────────────────┼─────────┤
│ [Object fields...]         │         │
└────────────────────────────┼─────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ TypeInfo       │
                    │   typeInfo_ ─┐ │  Self-reference
                    │              │ │
                    │   (ptr == ───┘ │  ptr->typeInfo_)
                    │   ...)         │
                    └────────────────┘

Meta
┌─────────────────────────────────────┐
│ gc::GC::ObjectData (8 bytes)        │
├─────────────────────────────────────┤
│ ObjHeader                            │
│   typeInfoOrMeta_ ─────┐            │
│                        │            │
├────────────────────────┼────────────┤
│ [Object fields...]     │            │
└────────────────────────┼────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │ ExtraObjectData          │
              │   typeInfo_ ──────────┐  │
              │   flags_              │  │  ptr != ptr->typeInfo_
              │   associatedObject_   │  │  (so it's detected as meta)
              │   weakReference...    │  │
              └───────────────────────┼──┘
                                      │
                                      ▼
                             ┌────────────────┐
                             │ TypeInfo       │
                             │   typeInfo_ ─┐ │
                             │              │ │
                             │   (...)    ──┘ │
                             └────────────────┘
```

数组

| Offset                                    | Field                    | Size      | Alignment   | Bit-Level Details                                                                                                                                                       |
| ----------------------------------------- | ------------------------ | --------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0x00                                      | **gc::GC::ObjectData**   | 8 bytes   | 8 bytes     | **GC Header**                                                                                                                                                           |
|                                           | next_ (atomic pointer)   | 8 bytes   | 8 bytes     | Same as HeapObject                                                                                                                                                      |
| 0x08                                      | **KArray (ArrayHeader)** | 16 bytes  | 8 bytes     | **Array Header** (fixed size)                                                                                                                                           |
|                                           | typeInfoOrMeta_          | 8 bytes   | 8 bytes     | **Bits 0-63**: Pointer to array TypeInfo                                                                                                                                |
| **Bits 0-1**: Tag bits                    |
| 0x10                                      | count_                   | 4 bytes   | 4 bytes     | **Bits 0-31**: Element count (uint32_t)                                                                                                                                 |
| 0x14                                      | objcFlags_ / padding     | 4 bytes   | 4 bytes     | **Bits 0-31**: ObjC flags if KONAN_OBJC_INTEROP, Otherwise: padding to 8-byte struct alignment                                                                          |
| 0x18                                      | **[Padding]**            | 0-7 bytes | E bytes     | Align to element size boundary                                                                                                                                          |
| AlignUp(sizeof(ArrayHeader), elementSize) |
| 0x18+                                     | **Array elements**       | E × count | **E bytes** | **⚠️ Elements use ELEMENT SIZE alignment, NOT 8-byte!** <br/> Each element size E = -typeInfo->instanceSize_ <br/> Elements are **tightly packed** with no extra padding |
| END                                       | **[Padding]**            | 0-7 bytes | —           | Pad entire array to 8-byte boundary                                                                                                                                     |

```kotlin
val flags = BooleanArray(5)  // 5 booleans
```

| Offset    | Field            | Size    | Explanation                  |
| --------- | ---------------- | ------- | ---------------------------- |
| 0x00      | ObjectData.next_ | 8 bytes | GC header                    |
| 0x08      | typeInfoOrMeta_  | 8 bytes | Array header                 |
| 0x10      | count_ = 5       | 4 bytes |                              |
| 0x14      | padding          | 4 bytes |                              |
| 0x18      | element[0]       | 1 byte  | **Only 1 byte per boolean!** |
| 0x19      | element[1]       | 1 byte  | No padding between elements  |
| 0x1A      | element[2]       | 1 byte  | Tightly packed               |
| 0x1B      | element[3]       | 1 byte  |                              |
| 0x1C      | element[4]       | 1 byte  |                              |
| 0x1D      | [padding]        | 3 bytes | Final 8-byte alignment       |
| **Total** | **32 bytes**     |         | AlignUp(24 + 5, 8) = 32      |

page：

| Constant              | OHOS Target          | Standard Target        |
| --------------------- | -------------------- | ---------------------- |
| kPageAlignment        | 8 bytes              | 8 bytes                |
| Cell size             | 8 bytes              | 8 bytes                |
| FixedBlockCell size   | 8 bytes              | 8 bytes                |
| NextFitPage::SIZE     | 128 KiB              | 256 KiB                |
| FixedBlockPage::SIZE  | 128 KiB              | 256 KiB                |
| ExtraObjectPage::SIZE | 64 KiB               | 64 KiB                 |
| MAX_BLOCK_SIZE        | 32 cells (256 bytes) | 128 cells (1024 bytes) |

SingleObjectPage

| Offset   | Field                         | Size         | Alignment | Description                                                 |
| -------- | ----------------------------- | ------------ | --------- | ----------------------------------------------------------- |
| 0x00     | **AnyPage<SingleObjectPage>** | **16 bytes** | 8 bytes   | **Base class**                                              |
| 0x00     | ├─ next_                      | 8 bytes      | 8 bytes   | std::atomic<SingleObjectPage*> for page list                |
| 0x08     | └─ allocatedSizeTracker_      | 8 bytes      | 8 bytes   | AllocatedSizeTracker::Page (size_t field)                   |
|          | └─ threadName_                | 24 bytes     | 8 bytes   | after libc++ small string optimization a string is 24 bytes |
| 0x10     | isAllocated_                  | 1 byte       | 1 byte    | Boolean: 0 = available, 1 = occupied                        |
| 0x11     | [padding]                     | 7 bytes      | —         | Pad to 8-byte boundary                                      |
| 0x18     | size_                         | 8 bytes      | 8 bytes   | Total page allocation size (size_t)                         |
| 0x20     | dataAddress                   | 8 bytes      | 8 bytes   | Tencent Code: cached uintptr_t of data_ address             |
| 0x28     | **alignas(8) struct**         | **0 bytes**  | 8 bytes   | **Alignment directive only**                                |
| 0x28     | ├─ data_[]                    | **N bytes**  | 8 bytes   | **Flexible array - object begins here ↓**                   |
|          |                               |              |           |                                                             |
| **0x28** | **Object Layout**             |              |           | **Within data_[] array:**                                   |
| 0x28     | ├─ gc::GC::ObjectData         | 8 bytes      | 8 bytes   | GC header: std::atomic<ObjectData*> next_                   |
| 0x30     | ├─ ObjHeader                  | 8 bytes      | 8 bytes   | TypeInfo* typeInfoOrMeta_ pointer                           |
| 0x38     | ├─ [Object fields...]         | varies       | natural   | Field data (1/2/4/8-byte aligned)                           |
| ???      | └─ [padding]                  | 0-7 bytes    | —         | Pad total object to 8-byte boundary                         |

