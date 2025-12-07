---
title: KMP Debug构建效率提升
categories:
  - KN
tags:
  - KN
  - KMP
  - 增量构建
  - Debug
  - 构建效率
description: 介绍KMP（Kotlin Multiplatform）项目中优化鸿蒙（HarmonyOS）Debug包构建效率的实用方法，包括排查Gradle任务，开启增量缓存机制，常见问题及解决方案。通过静态缓存和依赖优化，显著提升Debug构建速度，降低开发调试时间。
---

优化KMP打鸿蒙debug包耗时，优化目标约耗时1分钟

首先[Kotlin官方文档](https://kotlinlang.org/docs/native-improving-compilation-time.html#general-recommendations)覆盖的场景比较全，建议先按照这个排查。其中 kotlin.incremental.native 配置kuikly版本在鸿蒙上截止KBA-013版本暂不支持，下文会介绍如何开启

# gradle 任务排查

这段在官方文档基础上补充一点针对gradle构建任务进行排查的建议

通过在 ./gradlew 命令最后添加 --profile 或 --scan 可以收集各gradle task的执行耗时，使用scan获取的信息更详细，但需要将数据上传到develocity服务器。profile选项是纯本地的，也能展示基本的任务执行和耗时情况。针对gradle任务的优化目标是修改一行代码后

1. 尽可能少触发gradle任务

    Kotlin/Native 构建至少触发[两个gradle任务](https://github.com/JetBrains/kotlin/blob/master/docs/native/compilation-model.md) compileKotlin 和 link。按照KGP的规则，修改一个gradle子项目中的kotlin代码后所有依赖这个项目的其他子项目都会重新运行 compileKotlin 任务，且依赖会传递。如下图项目结构，修改模块C的代码后C，B和A的 compileKotlin 任务都会重新执行。有除此之外的gradle任务都是业务代码/项目依赖中配置的，可以检查下这些任务是否可以通过gradle cacheable task进行缓存。整改参考[gradle文档](https://docs.gradle.org/current/userguide/build_cache.html#sec:task_output_caching_details)和[gradle incremental build](https://docs.gradle.org/current/userguide/incremental_build.html#sec:stale_task_outputs)文档。
    ![alt text](../../assets/img/post/2025-11-07-kn-debug-build-speedup/2025-12-07T11:02:08.196Z-image.png)
    https://excalidraw.com/#json=BX4kEo4nkZLn3-0G6mM_i,0QDBIdOAHzVB-UsBwGf1Uw

2. 常被触发的gradle任务优化耗时

    这里主要的反模式是在顶层gradle项目中写或者生成大量代码。顶层gradle子项目的 compileKotlin 任务的每次debug build都会执行且这个任务不支持增量，导致debug build耗时长。将代码放到顶层项目中时应慎重，尤其是生成大量代码的场景。可以选择项目中几个常发生修改的位置修改后构建，观察触发的gradle任务，对触发频率高且耗时长的子项目进行优化

    如一些代码原来在上图的A模块中，如果这些代码实际不依赖B模块可以考虑挪到D，避开debug过程中触发cache miss概率高的依赖路径。或者如果模块A包含多个独立功能，可以考虑拆分模块A成几个小模块并分别配置依赖关系。总之让经常构建的项目尽可能小，必须很大的项目尽可能减少依赖少触发cache miss进行构建

# ohos debug build 开启增量缓存

增量缓存开/关时的构建流程大致如下图

![alt text](../../assets/img/post/2025-11-07-kn-debug-build-speedup/2025-12-07T11:01:44.083Z-image.png)

https://excalidraw.com/#json=PXibQdsrDjNMs4JYTh5lX,ION6xbv-rqLmeYglzdTO0w

这一功能只影响编译器后端的link任务，对 compileKotlin 任务没有影响。提速的原理大概是开启增量之前尽管工程中变化的源码很少，但K/N编译器后端每次都完整的将整个工程对应的llvm ir编译成so（图中1）。开启增量缓存后工程的源码和依赖都被编成独立的 .a 静态库（图中2）最后链接到一起（图中5），构建 .a 的范围只是工程中发生修改和依赖被修改文件的其他文件（图中3 4静态缓存没有重新构建），这一范围只是整个工程很小的一个子集，编译的工作量比全量编译显著变少而且实现上一个gradle子项目中的不同文件建立静态缓存有并行化，使得link gradle任务的速度显著提升

## 开启方式

// TODO：提供参考pr

静态缓存分两个类型

- 工程依赖的klib因为只会通过修改版本整个替换不会修改klib的内容，整个klib被打包成一个 .a
- 工程中的源码文件可以独立修改，每个文件被打包成一个 .a

构建缓存功能开启后就会给依赖的klib打per-klib缓存，项目源码的per-file缓存需要在项目中添加额外的配置开启

### 依赖klib缓存

在kotlin仓库konan.properties文件cacheableTargets中添加ohos，表示ohos上支持缓存，默认启用缓存功能，会给工程依赖打per-klib缓存

![image.png](/assets/img/post/2025-11-07-kn-debug-build-speedup/image.png)

per-klib缓存保存在kotlin编译器中，路径 `$KONAN_DATA_DIR/kotlin-native-prebuilt-macos-aarch64-[kotlin版本号]/klib/cache/ohos_arm64STATIC-pl`，其中KONAN_DATA_DIR如果没有设置默认为 ~/.konan。在上述文件夹中看到工程的依赖则项目则依赖klib缓存开启成功

### 工程源码缓存

在应用工程顶层gradle项目的gradle.properties中添加 `kotlin.incremental.native=true` 配置，会在打包所有支持缓存的target时（如上面截图中ios_arm64和ohos_arm64都配置了支持缓存）给项目中的源码打per-file缓存

![image.png](/assets/img/post/2025-11-07-kn-debug-build-speedup/image-1.png)

per-file缓存保存在构建命令所在gradle子项目的 `build/kotlin-native-ic-cache/debugShared/ohos_arm64-gSTATIC-pl` 中，每个文件夹是一个gradle子项目，子项目文件夹中有对应每个文件的文件夹

### 进阶配置

1. kotlin项目 konan.properties optInCacheableTargets配置项中如果配置了ohos，则ohos target支持静态缓存但默认关闭，需要在应用工程中添加 `kotlin.native.cacheKind.ohosArm64=static` 开启缓存功能
2. 使用静态缓存时如果遇到问题，可以在应用工程中配置 `kotlin.native.cacheKind.ohosArm64=none` 关闭缓存功能
3. 构建工程源码的静态cache时并行度默认为4，可以通过在应用工程中配置 `kotlin.native.parallelThreads=0` 配置并行度为cpu核数

## 常见问题

1. 链接命令失败，ld.lld报命令过长

    所有静态cache是以绝对路径形式传给ld的，ld对输入长度有限制而且命令过长会影响性能。ld接受 @/path/to/command.txt 格式的输入，文件中的每一行都被认为是一个链接命令的输入，如在 command.txt 中写

    ```kotlin
    opt1
    opt2
    opt3
    ```

    `ld.lld @/path/to/command.txt` 等价于 `ld.lld opt1 opt2 opt3`。因此通过将所有 .a 路径写入文件的方式传给ld。需要注意修改的代码是各target公共逻辑，ios的linker输入格式不同，实现需要区分平台

2. 链接命令耗时不稳定，有时很慢

    链接时需要读取大量小 .a 缓存文件，数量=工程中kt文件数+依赖klib数，这是典型的低效场景。不过MacOS（Unified Buffer Cache）和 Linux（Page Cache）系统层面针对频繁读取小文件场景都有优化，这种文件会直接被保存在内存中，避免大量低效磁盘IO。一般会观察到电脑重启后第一次debug build或电脑内存不足时link gradle任务很慢，执行2～3次debug build后时间基本保持稳定。ld.lld命令的耗时和工程规模有关不过应该在10s以下。这里如果希望进一步优化可以考虑将一个源码gradle子项目的所有 .a 在构建命令完成的空闲时间合并成一个 .a，每次构建时被修改的源码模块以per-file的形式传给ld，其他没有修改的源码模块都传per-klib的 .a，有效减少ld的输入文件规模

3. 链接命令失败，报 error: duplicate symbol: kfun: xxx，这个符号在两个 .a 中被重复定义

    上游社区已知问题 [KT-81760](https://youtrack.jetbrains.com/issue/KT-81760)。K/N编译出的函数名中中包含kotlin代码package名，函数名，参数和返回值，出现这一问题应该是在同一个package下重复定义相同的函数，这种写法使用哪个实现在不开启增量缓存时依赖声明依赖的顺序容易出错，上游社区也可能在新版本中加强校验。如果在项目工程源码中存在这种情况建议整改，如果引入的库之间有符号名冲突不好修改可以添加 [--allow-multiple-definition](https://www.man7.org/linux/man-pages/man1/ld.1.html) 链接选项使用链接时第一个遇到的定义，将相关的正确性校验延后到不开启cache的debug build或release build进行。更多冲突情况下的细节可以查看[这个demo](https://github.com/linhandev/kn_samples/tree/clashingDeclarations)

4. cache文件夹有pl结尾和没有pl结尾两个，有什么区别

    pl代表kotlin的[partial linkage](https://www.youtube.com/watch?v=ERHMsRvIQPQ)功能，这一功能默认开启，开启后当工程依赖的一个klib调用了另一个klib中不存在的接口时，编译不会报错而是在调用点放一个抛出异常，报 No function found for symbol xxx，把问题遗留到运行时。这是一个[demo](https://github.com/linhandev/kn_samples/tree/pl)。kotlin标准库是禁用pl功能的，所以这个库的缓存在kotlin编译器的一个不带pl的文件夹里

5. 开启增量构建后so体积膨胀

    当注释掉K/N编译器中O0和O0 LTO两条优化管线相关的代码跳过llvm ir上的编译优化时，是否启用静态cache产物so体积差异1%左右，不跳过这两个管线体积差异30%+，确定是llvm ir上编译优化质量变差导致的so体积膨胀。开启静态cache后编译成二进制的程序规模变小，函数定义看不到所有的调用点无法进行有效的死代码删除。下面打印的llvm o0管线中包含dce

    ```kotlin
    ➜  bin ./clang -O0 -c test.c -mllvm -print-pipeline-passes     
    function(ee-instrument<>),always-inline,function(loop(loop-idiom-vectorize)),coro-cond(coro-early,cgscc(coro-split),coro-cleanup,globaldce),function(annotation-remarks)

    ➜  bin ./clang -O0 -flto -c test.c -mllvm -print-pipeline-passes
    function(ee-instrument<>),always-inline,function(loop(loop-idiom-vectorize)),coro-cond(coro-early,cgscc(coro-split),coro-cleanup,globaldce),canonicalize-aliases,name-anon-globals,function(annotation-remarks),BitcodeWriterPass
    ```

    开启增量构建后链接阶段才能看到完整的程序，给ld.lld传入 --gc-section 类似llvm ir上的dce会删掉所有调用不到的二进制section，配合生成二进制时传入 -ffunction-section 和 -fdata-section 让每个函数/全局/静态变量放进一个独立的section可以做到和全局O0+O0 LTO近似的so体积

6. cache的粒度

    如前所述应用工程中的代码是按照文件进行的缓存，值得一提的是代码的静态缓存依赖关系也是以文件为粒度分析的，当修改一个文件，只有依赖被修改文件的文件会重建cache，而不是被修改文件所在包的所有文件和依赖这个包的所有包的所有文件。这个设计对规模很大的gradle子项目更友好，缺点是产生了非常多的小文件

7. 有关gradle build cache

    这和本节重点增量构建静态缓存不是一个概念，gradle build cache是当一个gradle任务的cache key和之前运行的一次完全相同时直接用之前执行的结果，跳过本地执行。build cache不只保留一次结果，所以比如代码中一个变量的值修改历史为 true，false，true，第三次虽然较第二次有修改，gradle 任务不是 UP TO DATE，但是和第一次取值相同会cache hit，gradle任务状态为 FROM CACHE。这种情况下直接从gradle build cache之前的执行记录中取出各步骤执行结果，per-file-cache文件夹下的 .a 和修改后的代码不是对应的

8. 开启cache后不生效

    控制是否要建cache的代码在下图位置，可以debug观察哪个条件没满足

    ![image.png](/assets/img/post/2025-11-07-kn-debug-build-speedup/image-2.png)

9. 一些更详细的控制选项：org.jetbrains.kotlin.incremental.IncrementalCompilationFeatures

10. 有关正确性校验

    跟so体积膨胀类似，无缓存debug build时基于整个ir进行正确性校验，开启静态缓存后ir变小一些问题会发现不了。不过是否开启静态缓存不停响Kotlin编译器前端对Kotlin语法的校验，而且后续肯定还会做release build，只是发现问题的时间可能比开启cache更晚，不存在最终漏过问题的风险

# 相关资料

- B站debug build效率提升：https://mp.weixin.qq.com/s/wOnyjYcka99eFJz8BWlu4Q
- Kotlin社区效率提升指导：[https://kotlinlang.org/docs/native-improving-compilation-time.html](https://kotlinlang.org/docs/native-improving-compilation-time.html)

android build：
- [https://www.youtube.com/watch?v=Qp-5stxpTz4](https://www.youtube.com/watch?v=Qp-5stxpTz4)
- [https://www.youtube.com/watch?v=C77WssXZEvo](https://www.youtube.com/watch?v=C77WssXZEvo)
- [https://medium.com/androiddevnotes/the-internals-of-android-apk-build-process-article-5b68c385fb20](https://medium.com/androiddevnotes/the-internals-of-android-apk-build-process-article-5b68c385fb20)
- [https://stuff.mit.edu/afs/sipb/project/android/docs/tools/building/index.html](https://stuff.mit.edu/afs/sipb/project/android/docs/tools/building/index.html)
- ![image.png](/assets/img/post/2025-11-07-kn-debug-build-speedup/image-3.png)