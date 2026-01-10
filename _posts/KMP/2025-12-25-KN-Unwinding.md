---
title: Kotlin/Native 回栈
categories:
  - KN
tags:
  - KN
  - KMP
  - Hacking
published: false
---

Kotlin_getCurrentStackTrace


## 保留fp

- x29 (Frame Pointer / FP)：当前函数的栈地址
- x30 (Link Register / LR)：当前函数的返回地址，[bl](https://developer.arm.com/documentation/ddi0596/2020-12/Base-Instructions/BL--Branch-with-Link-)指令跳到当前函数时会写x30，[ret](https://developer.arm.com/documentation/ddi0596/2020-12/Base-Instructions/RET--Return-from-subroutine-)指令从当前函数退出时默认返回x30里存的地址

进入函数时x29是上一个函数的栈地址，x30是当前函数的返回地址，把这个信息写到当前函数的栈内存，函数执行完时恢复x29，x30寄存器值。在不调用其他函数的叶节点中回栈可以直接用sp和x30，所以叶节点不需要维护x29的指令。

有三个选项控制fp行为，第三个是cc1的，前两个都是在控制第三个

- -f[no-]omit-frame-pointer
- -m[no-]omit-leaf-frame-pointer
- -mframe-pointer=none/no-leaf/all

```cpp
#include <cstdlib>

__attribute__((noinline)) int test_callee() {
        return 0;
}

__attribute__((noinline)) int test_caller() {
	int a = test_callee();
	volatile int x = std::rand();
	return a + x;
}

int main() {
	int a = test_caller();
	return a;
}
```

deveco的llvm 15，o0和o3默认都带fp

str和stur都是存寄存器数据到一个寄存器中的地址+偏移量，汇编代码中写的偏移量都是byte，但是二进制里str的偏移量是多少个存放数据的寄存器长度，stur是实际多少byte。stur控制偏移粒度更细，能表示的范围更小。

```ts
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ \
  -O0 \
  ~/test.cpp \
  -target aarch64-linux-ohos && objdump -d a.out > temp

0000000000001930 <_Z11test_calleev>:                   // 叶节点没有fp操作
    1930: 2a1f03e0     	mov	w0, wzr                // mov: 移动；w0: 32位返回值寄存器；wzr: 零寄存器（始终为0）
    1934: d65f03c0     	ret                            // ret: 从函数返回（从x30/lr加载返回地址）

0000000000001938 <_Z11test_callerv>:
    1938: d10083ff     	sub	sp, sp, #0x20              // sub: 减法；sp: 栈指针寄存器（栈地址从高往低分配，在栈上分配32字节）
    193c: a9017bfd     	stp	x29, x30, [sp, #0x10]      // stp: 存储双字；x29: 帧指针（fp）；x30: 链接寄存器（lr，返回地址）；将fp和lr保存到栈上
    1940: 910043fd     	add	x29, sp, #0x10             // add: 加法；设置帧指针指向栈上保存的寄存器位置
    1944: 97fffffb     	bl	0x1930 <_Z11test_calleev>  // bl: 带链接的分支；函数调用（将返回地址保存到x30/lr，跳转到给定的地址）
    1948: b81fc3a0     	stur	w0, [x29, #-0x4]       // stur: 无缩放偏移存储寄存器；将test_callee的返回值存储到栈上的局部变量
    194c: 94000041     	bl	0x1a50 <rand@plt>          // 调用rand函数
    1950: b9000be0     	str	w0, [sp, #0x8]             // str: 存储寄存器指令；将rand的返回值存储到栈上偏移0x8的位置
    1954: b85fc3a8     	ldur	w8, [x29, #-0x4]       // ldur: 无缩放偏移加载寄存器；w8: 通用32位寄存器；从栈上加载之前保存的test_callee返回值
    1958: b9400be9     	ldr	w9, [sp, #0x8]             // ldr: 加载寄存器指令；w9: 通用32位寄存器；从栈上加载rand的返回值
    195c: 0b090100     	add	w0, w8, w9                 // 将w8和w9相加，结果存入w0（作为返回值）
    1960: a9417bfd     	ldp	x29, x30, [sp, #0x10]      // ldp: 加载双字指令；从栈上恢复保存的帧指针和链接寄存器
    1964: 910083ff     	add	sp, sp, #0x20              // 恢复栈指针（释放32字节）
    1968: d65f03c0     	ret                            // 从函数返回，去往x30/lr的地址

000000000000196c <main>:
    196c: d10083ff     	sub	sp, sp, #0x20
    1970: a9017bfd     	stp	x29, x30, [sp, #0x10]
    1974: 910043fd     	add	x29, sp, #0x10
    1978: b81fc3bf     	stur	wzr, [x29, #-0x4]
    197c: 97ffffef     	bl	0x1938 <_Z11test_callerv>
    1980: b9000be0     	str	w0, [sp, #0x8]
    1984: b9400be0     	ldr	w0, [sp, #0x8]
    1988: a9417bfd     	ldp	x29, x30, [sp, #0x10]
    198c: 910083ff     	add	sp, sp, #0x20
    1990: d65f03c0     	ret


/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ -O3 ~/test.cpp -target aarch64-linux-ohos && objdump -d a.out > temp

0000000000001928 <_Z11test_calleev>:
    1928: 2a1f03e0     	mov	w0, wzr                    // 将0移动到w0（返回0）
    192c: d65f03c0     	ret                            // 从函数返回

0000000000001930 <_Z11test_callerv>:
    1930: d10083ff     	sub	sp, sp, #0x20              // 在栈上分配32字节空间
    1934: a9017bfd     	stp	x29, x30, [sp, #0x10]      // 保存帧指针和链接寄存器到栈上
    1938: 910043fd     	add	x29, sp, #0x10             // 设置帧指针
    193c: 94000035     	bl	0x1a10 <rand@plt>          // 调用rand函数
    1940: b81fc3a0     	stur	w0, [x29, #-0x4]       // 将rand的返回值存储到局部变量，这个变量代码里写了volatile必须写到内存
    1944: b85fc3a0     	ldur	w0, [x29, #-0x4]       // 将局部变量的值加载回w0
    1948: a9417bfd     	ldp	x29, x30, [sp, #0x10]      // 恢复帧指针和链接寄存器
    194c: 910083ff     	add	sp, sp, #0x20              // 恢复栈指针
    1950: d65f03c0     	ret                            // 从函数返回

0000000000001940 <main>:
    1940: 17fffffa     	b	0x1928 <_Z11test_callerv>  // 尾调用优化，caller直接返回调用main的函数，main不创建栈帧

```

上面o3带fp汇编命令219行，加上 -fomit-frame-pointer 后汇编命令少2行，不再处理caller的x29

```ts
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ -O3 -fomit-frame-pointer ~/test.cpp -target aarch64-linux-ohos && objdump -d a.out > temp

0000000000001920 <_Z11test_calleev>:
    1920: 2a1f03e0     	mov	w0, wzr
    1924: d65f03c0     	ret

0000000000001928 <_Z11test_callerv>:
    1928: f81f0ffe     	str	x30, [sp, #-0x10]!
    192c: 94000035     	bl	0x1a00 <rand@plt>
    1930: b9000fe0     	str	w0, [sp, #0xc]
    1934: b9400fe0     	ldr	w0, [sp, #0xc]
    1938: f84107fe     	ldr	x30, [sp], #0x10
    193c: d65f03c0     	ret

0000000000001940 <main>:
    1940: 17fffffa     	b	0x1928 <_Z11test_callerv>
```

也可以强制给叶节点加上fp操作

```ts
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ -O3 -mno-omit-leaf-frame-pointer ~/test.cpp -target aarch64-linux-ohos && objdump -d a.out > temp

0000000000001930 <_Z11test_calleev>:
    1930: a9bf7bfd     	stp	x29, x30, [sp, #-0x10]!
    1934: 910003fd     	mov	x29, sp
    1938: 2a1f03e0     	mov	w0, wzr
    193c: a8c17bfd     	ldp	x29, x30, [sp], #0x10
    1940: d65f03c0     	ret

0000000000001944 <_Z11test_callerv>:
    1944: d10083ff     	sub	sp, sp, #0x20
    1948: a9017bfd     	stp	x29, x30, [sp, #0x10]
    194c: 910043fd     	add	x29, sp, #0x10
    1950: 94000038     	bl	0x1a30 <rand@plt>
    1954: b81fc3a0     	stur	w0, [x29, #-0x4]
    1958: b85fc3a0     	ldur	w0, [x29, #-0x4]
    195c: a9417bfd     	ldp	x29, x30, [sp, #0x10]
    1960: 910083ff     	add	sp, sp, #0x20
    1964: d65f03c0     	ret

0000000000001968 <main>:
    1968: a9bf7bfd     	stp	x29, x30, [sp, #-0x10]!
    196c: 910003fd     	mov	x29, sp
    1970: a8c17bfd     	ldp	x29, x30, [sp], #0x10
    1974: 17fffff4     	b	0x1944 <_Z11test_callerv>
```

o3和o0都会在ir中加入 "frame-pointer"="non-leaf" 属性

```shell
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ \
  --sysroot \
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  -O3 \
  -c \
  -emit-llvm \
  -o output.bc \
  ~/test.cpp \
  -target aarch64-linux-ohos &&
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/llvm-dis output.bc

o0

define dso_local noundef i32 @_Z11test_callerv() #1 {

attributes #1 = { mustprogress noinline optnone "frame-pointer"="non-leaf" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fix-cortex-a53-835769,+neon,+v8a" }

o3

define dso_local noundef i32 @_Z11test_callerv() local_unnamed_addr #1 {

attributes #1 = { mustprogress noinline "frame-pointer"="non-leaf" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fix-cortex-a53-835769,+neon,+v8a" }
```

当手动修改ir，删除所有 "frame-pointer"="non-leaf" 属性，观察到_start，_start_c这种函数还是有fp操作，但是自己写的 _Z11test_callerv 没有。o0和o3都是

```shell
rm output.bc &&
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/llvm-as output.ll &&
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  -O3 \
  output.bc \
  -target aarch64-linux-ohos \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/aarch64-linux-ohos \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  -o output &&
objdump -d output > temp


0000000000001764 <_start>:
    1764: d503245f     	bti	c
    1768: d280001d     	mov	x29, #0x0               // =0
    176c: d280001e     	mov	x30, #0x0               // =0
    1770: 910003e0     	mov	x0, sp
    1774: d503201f     	nop
    1778: 10009581     	adr	x1, 0x2a28 <_DYNAMIC>
    177c: 927cec1f     	and	sp, x0, #0xfffffffffffffff0
    1780: 14000001     	b	0x1784 <_start_c>

0000000000001784 <_start_c>:
    1784: d503237f     	pacibsp
    1788: d100c3ff     	sub	sp, sp, #0x30
    178c: a9027bfd     	stp	x29, x30, [sp, #0x20]
    1790: 910083fd     	add	x29, sp, #0x20
    1794: f81f83a0     	stur	x0, [x29, #-0x8]

0000000000001920 <_Z11test_calleev>:
    1920: 2a1f03e0     	mov	w0, wzr
    1924: d65f03c0     	ret

0000000000001928 <_Z11test_callerv>:
    1928: f81f0ffe     	str	x30, [sp, #-0x10]!
    192c: 94000035     	bl	0x1a00 <rand@plt>
    1930: b9000fe0     	str	w0, [sp, #0xc]
    1934: b9400fe0     	ldr	w0, [sp, #0xc]
    1938: f84107fe     	ldr	x30, [sp], #0x10
    193c: d65f03c0     	ret
```

kn codegen阶段后的ir dump

```kotlin
@file:OptIn(kotlin.experimental.ExperimentalNativeApi::class)

fun fpfpTestFunction() {
    println("This is a test function.")
    var sum = 0
    var product = 1
    for (i in 1..100) {
        sum += i
        if (i % 2 == 0) {
            product *= i
            if (product > 1000000) {
                product /= 2
            }
        }
    }
    val result = sum + product
    println("Computed result: $result")
}

@CName("subtract_numbers")
fun subtractNumbers(a: Int, b: Int): Int {
    fpfpTestFunction()
    return 0
}
```

kuikly 2.0.21 + oh llvm 12 debug:

```ts
define void @"kfun:#fpfpTestFunction(){}"() #9 !dbg !13 {
prologue:
  %sum = alloca i32, align 4
  call void @llvm.dbg.declare(metadata i32* %sum, metadata !15, metadata !DIExpression()), !dbg !16
  %product = alloca i32, align 4
  call void @llvm.dbg.declare(metadata i32* %product, metadata !17, metadata !DIExpression()), !dbg !18
  %inductionVariable = alloca i32, align 4
  %i = alloca i32, align 4
  call void @llvm.dbg.declare(metadata i32* %i, metadata !19, metadata !DIExpression()), !dbg !20
  %result = alloca i32, align 4
  call void @llvm.dbg.declare(metadata i32* %result, metadata !21, metadata !DIExpression()), !dbg !22
  %0 = alloca %struct.ObjHeader*, i32 4, align 8
  %1 = bitcast %struct.ObjHeader** %0 to i8*
  call void @llvm.memset.p0i8.i32(i8* nocapture writeonly %1, i8 0, i32 32, i1 immarg false) #5
  br label %locals_init

...

attributes #9 = { "frame-pointer"="non-leaf" "target-cpu"="cortex-a57" "target-features"="+aes,+fp,+neon,+sha2,+sve,+asimd" }

0000000000053400 <subtract_numbers>:
   53400: d10143ff      sub     sp, sp, #0x50
   53404: a9037bfd      stp     x29, x30, [sp, #0x30]
   53408: f90023f3      str     x19, [sp, #0x40]
   5340c: 9100c3fd      add     x29, sp, #0x30 
   53410: b9001fa0      str     w0, [x29, #0x1c]
   53414: b9001ba1      str     w1, [x29, #0x18]
```

kuikly 2.0.21 + oh llvm 12 release，ir中没有frame-pointer属性

```ts
define i32 @"kfun:#subtractNumbers(kotlin.Int;kotlin.Int){}kotlin.Int"(i32 %0, i32 %1) #9 {
prologue:
  br label %locals_init

...

attributes #9 = { "target-cpu"="cortex-a57" "target-features"="+aes,+fp,+neon,+sha2,+sve,+asimd" }

0000000000053400 <subtract_numbers>:
   53400: d10143ff     	sub	sp, sp, #0x50
   53404: a9037bfd     	stp	x29, x30, [sp, #0x30]
   53408: f90023f3     	str	x19, [sp, #0x40]
   5340c: 9100c3fd     	add	x29, sp, #0x30
   53410: b9001fa0     	str	w0, [x29, #0x1c]
   53414: b9001ba1     	str	w1, [x29, #0x18]
...

```

Kotlin中控制是否设置frame-pointer类型的逻辑：https://github.com/Tencent-TDS/KuiklyBase-kotlin/blob/kuikly-base/2.0.20/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/llvm/LlvmAttributes.kt#L38

kuikly的实现ohos在release build下不会添加frame-pointer属性，如果有根据fp回栈的需求需要patch让ohos release模式下返回true。


检查是否支持fp回栈：`hiperf record -p $(pgrep application) -s fp -f 1000 -d 5 -e hw-cpu-cycles,hw-instructions -o /data/local/tmp/perf.data`
