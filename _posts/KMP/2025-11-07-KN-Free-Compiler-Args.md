---
title: Konan编译选项
categories:
  - KN
tags:
  - KN
description: 
---

## 编译期保留临时文件

- **`-Xtemporary-files-dir`**：将类似 `out.bc` 这种编译过程中的临时文件写到指定路径（不再只在系统 `tmp` 下），编译结束后仍会保留，便于查看。例如  
  `-Xtemporary-files-dir=${project.buildDir.resolve("tmpfile").absolutePath}`

## 调试信息 / 栈回溯

- **`-Xadd-light-debug=enable`**：打包时包含 DWARF 等信息。
- **`-Xbinary=sourceInfoType=libbacktrace`**：将 backtrace 一起打进kotlin的so，在应用中在线做回栈

---

## 打印 Kotlin/Native 后端调用的 clang / 链接器命令（kotlinc-native / Gradle 链接任务）

Kotlin/Native 在把 bitcode 编成目标文件、以及最终链接时，会通过 `org.jetbrains.kotlin.konan.exec.Command` 调外部工具；若对应编译阶段处于 **verbose**，会把**完整命令行**打到 **`stderr`**（`LoggingContext.log` → `System.err.println`）。

做法是使用 **`-Xverbose-phases=<阶段名>`**（可多次传入，每个阶段一条）。与 clang / ld 关系最直接的两类是：

| 阶段名 | 大致含义 |
|--------|----------|
| **`ObjectFiles`** | 将 LLVM bitcode 交给 **`clang++`**（或平台配置的编译器驱动）生成目标文件，日志里可见完整 clang 命令行。 |
| **`Linker`** | 执行最终 **链接**（`ld` / `lld` / 经 `clang` 驱动等，依目标平台而定），日志里可见完整链接命令行。 |

**Gradle（Kotlin Multiplatform）示例**——加到对应 native 目标的 `main` 编译上，例如 `linuxX64`、`macosArm64`、`ohosArm64` 等：

```kotlin
kotlin {
    ohosArm64 {
        compilations.named("main").configure {
            kotlinOptions.freeCompilerArgs += listOf(
                "-Xverbose-phases=ObjectFiles",
                "-Xverbose-phases=Linker",
            )
        }
    }
}
```

（若工程已迁移到 `compilerOptions { }` / `KotlinCommonCompilerToolOptions`，把同样的两个参数加进该编译任务的 `freeCompilerArgs` 即可。）

构建时在 **Gradle 控制台**里查看 **stderr** 输出即可看到上述命令（若只跑 Gradle，通常与任务日志混在一起）。

native test 中：// FREE_COMPILER_ARGS: -Xverbose-phases=ObjectFiles -Xtemporary-files-dir=/tmp/konanc-debug-tmpfiles

---

## 打印 **cinterop** 里调用的 clang 命令

**cinterop**（生成 C/ObjC 绑定与 `cstubs`）在 `runCmd(..., verbose = true)` 时会打印一行以 **`COMMAND:`** 开头的完整 clang 调用（输入里常见从 stdin 喂 `cstubs.c`）。

在 **Gradle** 的 `cinterops { ... }` 里对对应 interop 增加 **`-verbose`**（注意：这是 **cinterop** 的选项，不是上面的 `-Xverbose-phases`）：

```kotlin
compilations.getByName("main") {
    cinterops {
        register("mylib") {
            defFile(file("src/nativeInterop/cinterop/mylib/mylib.def"))
            extraOpts("-verbose")
        }
    }
}
```

---

## 在日志里 **dump cinterop 桥接代码**（Kotlin stub + 原生侧 bridge / wrapper）

- **`-Xdump-bridges`**：**仅 cinterop 支持**（不是 `kotlinc-native` 的通用参数）。为 `true` 时，在生成绑定时把 **Kotlin 桥接声明行数**、**原生侧桥接 / C wrapper 代码**按行打到日志（实现上走 `StubIrDriver` 里对 `context.log` 的调用；对应 `GENERATED KOTLIN:` / `GENERATED NATIVE:` 段落）。
- **必须同时开启 cinterop 的 `-verbose`**，否则 `StubIrContext` 里传入的 `log` 为空操作，**看不到**上述 dump（也看不到前面的 `COMMAND:`）。
- **不会写入单独文件**：dump 只走日志；完整生成的 stub 会先写入临时 `.c`/`.cpp`/`.m` 再交给 clang，默认不会在 `build/` 里留一份可读的 `.c` 副本（需要可自行重定向 Gradle 输出或配合 `-Xtemporary-files-dir` 等查看其它中间产物）。

**Gradle 示例**：

```kotlin
extraOpts("-verbose", "-Xdump-bridges")
```

将任务输出保存到文件便于检索：

```bash
./gradlew :yourModule:cinteropYourinteropYourTarget --rerun-tasks 2>&1 | tee cinterop-bridges.log
```


-Xprofile-phases
