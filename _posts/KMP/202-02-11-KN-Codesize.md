---
title: KN产物优化
categories:
  - KMP
tags:
  - KMP
  - KN
description:
published: false
---

## Sections

```shell
llvm-readelf -S libkn-release.so

There are 30 section headers, starting at offset 0x19f810:

Section Headers:
  [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            0000000000000000 000000 000000 00      0   0  0
  [ 1] .note.ohos.ident  NOTE            00000000000002e0 0002e0 00001c 00   A  0   0  8
  [ 2] .note.gnu.build-id NOTE           00000000000002fc 0002fc 000024 00   A  0   0  4
  [ 3] .dynsym           DYNSYM          0000000000000320 000320 004f68 18   A  5   1  8
  [ 4] .gnu.hash         GNU_HASH        0000000000005288 005288 000b30 00   A  3   0  8
  [ 5] .dynstr           STRTAB          0000000000005db8 005db8 006334 00   A  0   0  1
  [ 6] .rela.dyn         RELA            000000000000c0f0 00c0f0 01db80 18   A  3   0  8
  [ 7] .rela.plt         RELA            0000000000029c70 029c70 002af0 18  AI  3  24  8
  [ 8] .gcc_except_table PROGBITS        000000000002c760 02c760 00bbd0 00   A  0   0  4
  [ 9] .rodata           PROGBITS        0000000000038330 038330 003b79 00 AMS  0   0 16
  [10] .eh_frame_hdr     PROGBITS        000000000003beac 03beac 0052f4 00   A  0   0  4
  [11] .eh_frame         PROGBITS        00000000000411a0 0411a0 0181e4 00   A  0   0  8
  [12] .text             PROGBITS        0000000000069390 059390 0a1558 00 AXR  0   0 16
  [13] .init             PROGBITS        000000000010a8e8 0fa8e8 000014 00  AX  0   0  4
  [14] .fini             PROGBITS        000000000010a8fc 0fa8fc 000014 00  AX  0   0  4
  [15] .plt              PROGBITS        000000000010a910 0fa910 001cc0 00  AX  0   0 16
  [16] .tbss             NOBITS          000000000010c5d0 0fc5d0 000030 00 WAT  0   0  8
  [17] .fini_array       FINI_ARRAY      000000000011c5d0 0fc5d0 000008 00  WA  0   0  8
  [18] .data.rel.ro      PROGBITS        000000000011c5e0 0fc5e0 018420 00  WA  0   0 16
  [19] .init_array       INIT_ARRAY      0000000000134a00 114a00 000018 00  WA  0   0  8
  [20] .dynamic          DYNAMIC         0000000000134a18 114a18 0002a0 10  WA  5   0  8
  [21] .got              PROGBITS        0000000000134cb8 114cb8 000bb0 00  WA  0   0  8
  [22] .relro_padding    NOBITS          0000000000135868 115868 000798 00  WA  0   0  1
  [23] .data             PROGBITS        0000000000145868 115868 000df8 00 WAR  0   0  8
  [24] .got.plt          PROGBITS        0000000000146660 116660 000e68 00  WA  0   0  8
  [25] .bss              NOBITS          00000000001474c8 1174c8 000770 00 WAR  0   0  8
  [26] .comment          PROGBITS        0000000000000000 1174c8 00018d 01  MS  0   0  1
  [27] .symtab           SYMTAB          0000000000000000 117658 033078 18     29 7863  8
  [28] .shstrtab         STRTAB          0000000000000000 14a6d0 00011b 00      0   0  1
  [29] .strtab           STRTAB          0000000000000000 14a7eb 05501f 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  R (retain), p (processor specific)
```

- size列16进制，单位Byte
- NOBITS section只在运行时占内存，不在so中存储数据
- section内容格式
  - ![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-2.png)
  - typedef uint32_t Elf64_Word;

### .note.ohos.ident

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image.png)

说明厂商和ABI之类的信息

### .note.gnu.build-id

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-1.png)

```shell
file libkn-release.so 
# libkn-release.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (GNU/Linux), dynamically linked, BuildID[sha1]=aa154ceba666d3cc8a98ab8672c399326e9da50b, not stripped
```

### .dynsym

```shell
➜  kn_samples git:(dwarf) ✗ llvm-readelf --dyn-syms libkn-release.so

Symbol table '.dynsym' contains 847 entries:
   Num:    Value          Size Type    Bind   Vis       Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT   UND 
     1: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT   UND main
     2: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND __libc_start_main
     3: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND __cxa_begin_catch
     4: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND __cxa_end_catch
     5: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND _Unwind_Resume
     6: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetName
     7: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetMaxSupportedInstances
     8: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetEncoderBitrateRange
     9: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetVideoWidthRange
    10: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetVideoHeightRange
    11: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetVideoFrameRateRange
    12: 0000000000000000     0 FUNC    WEAK   DEFAULT   UND OH_AVCapability_GetVideoWidthAlignment
                ... ...
   481: 0000000000000000     0 FUNC    GLOBAL DEFAULT   UND __gxx_personality_v0
   482: 00000000000eaf94   200 FUNC    GLOBAL DEFAULT    12 avsGetTrackFormat
   483: 00000000000ec99c   224 FUNC    GLOBAL DEFAULT    12 getBitrateModeEnumValuesJson
   484: 00000000000f2bc4   224 FUNC    GLOBAL DEFAULT    12 getAVMetadataEnumValuesJson
   485: 00000000000f6084   184 FUNC    GLOBAL DEFAULT    12 abilityRuntimeStartOptionsCreateDestroy
   486: 00000000000fb044   200 FUNC    GLOBAL DEFAULT    12 avcencInfoSetAVBuffer
   487: 00000000000e9c38   192 FUNC    GLOBAL DEFAULT    12 avdDestroy
   488: 00000000000f3174   272 FUNC    GLOBAL DEFAULT    12 ohavmdBuilderSetAssetId
   489: 00000000000ec43c   224 FUNC    GLOBAL DEFAULT    12 getAVCLevelEnumValuesJson
   490: 00000000000edc9c   192 FUNC    GLOBAL DEFAULT    12 avbGetCapacity
   491: 00000000000ee9d4   336 FUNC    GLOBAL DEFAULT    12 avfGetIntBuffer
   492: 00000000000f96fc   192 FUNC    GLOBAL DEFAULT    12 arkuiDragEventGetTouchPointYToWindow
   493: 00000000000ef95c   192 FUNC    GLOBAL DEFAULT    12 avmemGetSize
   494: 00000000000f9abc   192 FUNC    GLOBAL DEFAULT    12 arkuiDragEventIsRemote
   495: 00000000000fb8d4   392 FUNC    GLOBAL DEFAULT    12 hiLogPrint
```
- ndx：这个符号属于哪个section，0-UND，65521-ABS（value是绝对地址，不需要看section），65522-COMMON（未初始化常量，value是对齐）
- 常见符号类型：
  - GLOBAL DEFAULT UND，WEAK DEFAULT UND：依赖其他so的符号。区别是default的符号ld解析的时候一定要求在其他so找到实现，否则崩溃；weak的找不到ld不崩溃，符号函数会是空指针
  - GLOBAL DEFAULT 12：这个so开放给其他so调用的符号
  - WEAK DEFAULT 12：因为ndx 12，so里有这个符号的实现。但是bind是weak的，如果其他so有同名的，bind是default的符号就会被其他so抢占，用那边的实现

一个符号在 .dynsym 存储的内容

```cpp
typedef struct {
  Elf64_Word   st_name;    // Name, 符号名在 .dynstr 段 + 这个偏移量开始，\0结尾的一段
  unsigned char st_info;   // Bind (high 4 bits) + Type (low 4 bits)
  unsigned char st_other;  // Bis (low 2 bits)
  Elf64_Section st_shndx;  // Ndx: section index (or 0-UND/ABS/COMMON)
  Elf64_Addr   st_value;   // address or value
  Elf64_Xword  st_size;    // size of symbol, bytes
} Elf64_Sym;
```

找符号名

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-5.png)

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-6.png)

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-7.png)


### .dynstr

一堆字符串，\0分割，用于保存符号名，so名等

### .gnu.hash

![alt text](../../assets/img/post/202-02-11-KN-Codesize/image-8.png)

- 用于加速动态符号查找的hash表
  - 避免o(n)的顺序查找
  - bloom filter可以快速确定一个符号不存在，结束查找
- 只包含提供给其他so调用的符号，不包含整个dynsym
  - symbase是482，第1个有定义的符号
- 对dynsym中的符号顺序有要求
  - 所有开给其他so调用的接口都放在最后

```shell
mkdir -p /tmp/ohos-helloworld && cd /tmp/ohos-helloworld

cat > main.cpp << 'EOF'
#include <iostream>

void __attribute__((noinline)) test_callee() {
    std::cout << "test_callee\n";
}

void __attribute__((noinline)) __attribute__((visibility("hidden"))) test_dead_code() {
    std::cout << "test_callee\n";
}
EOF

SYSROOT="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot"
CLANG="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/aarch64-unknown-linux-ohos-clang++"
RESOURCE_DIR="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4"
CLANG_LIB="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos"

"$CLANG" --sysroot "$SYSROOT" main.cpp -O3 -shared -fPIC -target aarch64-linux-ohos -L"$CLANG_LIB" -resource-dir "$RESOURCE_DIR" -o main.so

echo "Built: $(pwd)/main"
```


跨语言dce

## 参考资料
[美团技术团队 - Android对so体积优化的探索与实践](https://tech.meituan.com/2022/06/02/meituans-technical-exploration-and-practice-of-android-so-volume-optimization.html)