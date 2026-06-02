---
title: KN Codesize优化
categories:
  - KMP
tags:
  - KMP
  - KN
  - Codesize
description:
---

## 编译参数调整

### KN 自带参数

- KN 为苹果手表 target 上了一个 smallBinary 选项，仅用于release build，效果是不进行部分 inline 和将 LLVM IR 上的优化级别从 o3 改为 oz。开启方式：`binaryOption("smallBinary", "true")`
- LLVM IR 上的 inline 会将比较小的函数复制到调用点，增加 codesize 换更好的运行性能，关闭 inline 或减小最大允许 inline 函数的行数阈值可以减小 codesize，开启方式：`binaryOption("inlineThreshold", "0")`
- kotlin 2.2 新上的实验特性8位字符串，开启后如果字符串中所有字符都是0～255范围会使用 latin-1 编码，可以通过这个选项减小 so 中字符串常量的大小，开启方式：`binaryOption("latin1Strings", "true")`

```shell
(default) ➜  ovCompose-sample git:(main) ✗ ls -l baseline.so sb.so sb-noinline.so sb-noinline-latin1.so                                                
-rwxr-xr-x@ 1 ohoskt  staff  13333168 Feb 26 00:29 baseline.so
-rwxr-xr-x@ 1 ohoskt  staff  12606928 Feb 26 01:16 sb-noinline-latin1.so
-rwxr-xr-x@ 1 ohoskt  staff  11919840 Feb 26 00:49 sb-noinline.so
-rwxr-xr-x@ 1 ohoskt  staff  12606928 Feb 26 00:32 sb.so
(default) ➜  ovCompose-sample git:(main) ✗ python 
Python 3.12.12 | packaged by conda-forge | (main, Jan 27 2026, 00:01:15) [Clang 19.1.7 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> (13333168 - 12606928) / 13333168
0.0544686754115751
>>> (13333168 - 11919840) / 13333168
0.1060009144113387
>>> 
```

ovcomposeSample 上用前两个选项不 inline+oz 优化级别可以用运行性能换到 10% 的 codesize 下降，latin1选项还需要研究


### --pack-dyn-relocs=relr

编译时无法得知运行时 so 会被加载到什么地址，因此在 PIE 的 exe 和 so 中会有 relative relocation，大概就是编译器告诉链接器在 so 里的 x 位置我写的地址是一个相对 so 开头的地址，加载这个 so 的时候麻烦把这些地址换成 so 的加载基地址 + 我写的这个 offset。relo 还有其他情况不过这种居多。

```
// REL
typedef struct {
  Elf64_Addr  r_offset; // where to apply relocation
  Elf64_Xword r_info;   // type + symbol index
} Elf64_Rel;

// RELA
typedef struct {
  Elf64_Addr  r_offset; // where to apply relocation
  Elf64_Xword r_info;   // type + symbol index // 这里rela记录的type是固定枚举，index也固定是0
  Elf64_Sxword r_addend;// addend // 和r_offset相同
} Elf64_Rela;

// RELR：只是一个word，没有结构体
Elf64_Xword;
```
RELR 格式中最低位是0的记录是相对 so 开头的地址，这个地址本身是一个relocation。最低位是1的记录是一个 bitmap，代表地址记录+多少个 word 的位置是一个 relocation。一个地址后面可以接多个bitmap，如

【地址 A】 【bitmap 1】 【bitmap 2】 【地址 B】 【bitmap 3】

对于非常稀疏的relocation也可以有连续地址

【地址 A】 【地址 B】 【bitmap 3】

llvm/lib/Object/ELF.cpp

```cpp
template <class ELFT>
std::vector<typename ELFT::Rel>
ELFFile<ELFT>::decode_relrs(Elf_Relr_Range relrs) const {
  // This function decodes the contents of an SHT_RELR packed relocation
  // section.
  //
  // Proposal for adding SHT_RELR sections to generic-abi is here:
  //   https://groups.google.com/forum/#!topic/generic-abi/bX460iggiKg
  //
  // The encoded sequence of Elf64_Relr entries in a SHT_RELR section looks
  // like [ AAAAAAAA BBBBBBB1 BBBBBBB1 ... AAAAAAAA BBBBBB1 ... ]
  //
  // i.e. start with an address, followed by any number of bitmaps. The address
  // entry encodes 1 relocation. The subsequent bitmap entries encode up to 63
  // relocations each, at subsequent offsets following the last address entry.
  //
  // The bitmap entries must have 1 in the least significant bit. The assumption
  // here is that an address cannot have 1 in lsb. Odd addresses are not
  // supported.
  //
  // Excluding the least significant bit in the bitmap, each non-zero bit in
  // the bitmap represents a relocation to be applied to a corresponding machine
  // word that follows the base address word. The second least significant bit
  // represents the machine word immediately following the initial address, and
  // each bit that follows represents the next word, in linear order. As such,
  // a single bitmap can encode up to 31 relocations in a 32-bit object, and
  // 63 relocations in a 64-bit object.
  //
  // This encoding has a couple of interesting properties:
  // 1. Looking at any entry, it is clear whether it's an address or a bitmap:
  //    even means address, odd means bitmap.
  // 2. Just a simple list of addresses is a valid encoding.

  Elf_Rel Rel;
  Rel.r_info = 0;
  Rel.setType(getRelativeRelocationType(), false);
  std::vector<Elf_Rel> Relocs;

  // Word type: uint32_t for Elf32, and uint64_t for Elf64.
  using Addr = typename ELFT::uint;

  Addr Base = 0;
  for (Elf_Relr R : relrs) {
    typename ELFT::uint Entry = R;
    if ((Entry & 1) == 0) {
      // Even entry: encodes the offset for next relocation.
      Rel.r_offset = Entry;
      Relocs.push_back(Rel);
      // Set base offset for subsequent bitmap entries.
      Base = Entry + sizeof(Addr);
    } else {
      // Odd entry: encodes bitmap for relocations starting at base.
      for (Addr Offset = Base; (Entry >>= 1) != 0; Offset += sizeof(Addr))
        if ((Entry & 1) != 0) {
          Rel.r_offset = Offset;
          Relocs.push_back(Rel);
        }
      Base += (CHAR_BIT * sizeof(Entry) - 1) * sizeof(Addr);
    }
  }

  return Relocs;
}
```
- 优化前：RELA 需要用 3 word 表达一个 relocation
- 优化后：RELR 用两个 word 表达一个 relocation，这样优化到原来的 1 / 3 = 33%。如果有连续的 relocation，最极端压缩比趋近100%

- 优化前：.rela.dyn 包含相对重定位和非相对重定位
- 优化后：.rela.dyn 只包含非相对重定位，.relr.dyn包含所有相对重定位

## KN 导出优化

TODO


## cinterop静态库相关最佳实践

kn的so中如果有链进去静态库，建议参考[这篇]({{ "/posts/Static-Cinterop-Codesize/" | relative_url }})
