---
title: MetaDataKlib
categories:
  - KN
tags:
published: false
---

```shell
ohoskt:kn_samples hl$ ./gradlew :lib:publishToMavenLocal --rerun-tasks 

> Task :lib:compileKotlinIosArm64
konanc -g -enable-assertions -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib -module-name com.example:lib -no-endorsed-libs -nostdlib -output /Users/hl/git/sample/kn_samples/lib/build/classes/kotlin/iosArm64/main/klib/lib.klib -produce library -Xshort-module-name=lib -target ios_arm64 -Xfragment-refines=iosArm64Main:iosMain,iosMain:appleMain,appleMain:nativeMain,nativeMain:commonMain -Xfragment-sources=commonMain:/Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt -Xfragments=iosArm64Main,iosMain,appleMain,nativeMain,commonMain -Xmulti-platform /Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt

> Task :lib:compileCommonMainKotlinMetadata
konanc -g -enable-assertions -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.iconv -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.posix -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.zlib -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.builtin -library /Users/hl/git/sample/kn_samples/lib/build/kotlinTransformedMetadataLibraries/commonMain/org.jetbrains.kotlin-kotlin-stdlib-2.0.21-KBA-014-commonMain-I9Ctmg.klib -manifest /Users/hl/git/sample/kn_samples/lib/build/tmp/compileCommonMainKotlinMetadata/inputManifest -module-name com.example:lib_commonMain -no-default-libs -no-endorsed-libs -nopack -nostdlib -output /Users/hl/git/sample/kn_samples/lib/build/classes/kotlin/metadata/commonMain/klib/lib_commonMain -produce library -Xshort-module-name=lib_commonMain -target ios_arm64 -Xcommon-sources=/Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt -Xmetadata-klib -Xmulti-platform /Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt

> Task :lib:compileKotlinOhosArm64
konanc -g -enable-assertions -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib -module-name com.example:lib -no-endorsed-libs -nostdlib -output /Users/hl/git/sample/kn_samples/lib/build/classes/kotlin/ohosArm64/main/klib/lib.klib -produce library -Xshort-module-name=lib -target ohos_arm64 -Xfragment-refines=ohosArm64Main:nativeMain,nativeMain:commonMain -Xfragment-sources=commonMain:/Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt -Xfragments=ohosArm64Main,nativeMain,commonMain -Xmulti-platform /Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt

BUILD SUCCESSFUL in 849ms
```

```shell
konanc 
-g 
-enable-assertions 
-library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib 
-library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.iconv 
-library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.posix 
-library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.zlib 
-library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/commonized/2.0.21-KBA-014/(ios_arm64, ohos_arm64)/org.jetbrains.kotlin.native.platform.builtin 
-library /Users/hl/git/sample/kn_samples/lib/build/kotlinTransformedMetadataLibraries/commonMain/org.jetbrains.kotlin-kotlin-stdlib-2.0.21-KBA-014-commonMain-I9Ctmg.klib 
-manifest /Users/hl/git/sample/kn_samples/lib/build/tmp/compileCommonMainKotlinMetadata/inputManifest 
-module-name com.example:lib_commonMain 
-no-default-libs 
-no-endorsed-libs 
-nopack 
-nostdlib 
-output /Users/hl/git/sample/kn_samples/lib/build/classes/kotlin/metadata/commonMain/klib/lib_commonMain 
-produce library 
-Xshort-module-name=lib_commonMain 
-target ios_arm64 
-Xcommon-sources=/Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt 
-Xmetadata-klib 
-Xmulti-platform /Users/hl/git/sample/kn_samples/lib/src/commonMain/kotlin/com/example/lib/Lib.kt
```

```shell
➜  kn_samples git:(metadataklib) ✗ ./gradlew :app:linkAppDebugSharedOhosArm64 --rerun-tasks 

> Task :app:compileKotlinOhosArm64
konanc -g -enable-assertions -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib -library /Users/hl/.gradle/caches/modules-2/files-2.1/com.example/lib-ohosarm64/1.0.0/a95d62b8062207f70ec350b5df89a619de021f4a/lib.klib -module-name com.example:app -no-endorsed-libs -nostdlib -output /Users/hl/git/sample/kn_samples/app/build/classes/kotlin/ohosArm64/main/klib/app.klib -produce library -Xshort-module-name=app -target ohos_arm64 -Xfragment-refines=ohosArm64Main:nativeMain,nativeMain:commonMain -Xfragment-sources=commonMain:/Users/hl/git/sample/kn_samples/app/src/commonMain/kotlin/com/example/app/App.kt -Xfragments=ohosArm64Main,nativeMain,commonMain -Xmulti-platform /Users/hl/git/sample/kn_samples/app/src/commonMain/kotlin/com/example/app/App.kt

> Task :app:linkAppDebugSharedOhosArm64
konanc -g -enable-assertions -Xinclude=/Users/hl/git/sample/kn_samples/app/build/classes/kotlin/ohosArm64/main/klib/app.klib -library /Users/hl/.konan/kotlin-native-prebuilt-macos-aarch64-2.0.21-KBA-014/klib/common/stdlib -library /Users/hl/.gradle/caches/modules-2/files-2.1/com.example/lib-ohosarm64/1.0.0/a95d62b8062207f70ec350b5df89a619de021f4a/lib.klib -no-endorsed-libs -nostdlib -output /Users/hl/git/sample/kn_samples/app/build/bin/ohosArm64/appDebugShared/libapp.so -produce dynamic -target ohos_arm64 -Xmulti-platform -Xexternal-dependencies=/var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/kotlin-native-external-dependencies9710807829555306033.deps
/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/bin/clang++ -B/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/bin -fno-stack-protector -target aarch64-linux-ohos --sysroot=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot -fPIC -mcpu=cortex-a57 -I/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/include/libcxx-ohos/include/c++/v1 -I/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/include -I/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/include/aarch64-linux-ohos -std=c++17 /var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/api.cpp -emit-llvm -c -o /var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/api.bc
/var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/api.cpp:419:1: warning: non-void function does not return a value in all control paths [-Wreturn-type]
}
^
1 warning generated.
/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/bin/clang++ -cc1 -emit-obj -x ir -fno-emulated-tls -triple aarch64-linux-ohos -O0 -mrelocation-model pic /var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/out.bc -o /var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/libapp.so.o
/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/bin/ld.lld --sysroot=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot -export-dynamic -z relro --build-id --eh-frame-hdr -dynamic-linker /lib/ld-musl-aarch64.so.1 -o /Users/hl/git/sample/kn_samples/app/build/bin/ohosArm64/appDebugShared/libapp.so /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/Scrt1.o /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/crti.o /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos/crtn.o --hash-style=gnu -L/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/lib/aarch64-linux-ohos -L/Users/hl/.konan/dependencies/llvm-1201-macos-aarch64/lib/aarch64-linux-ohos/c++ -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot/usr/lib/aarch64-linux-ohos -shared --soname=libapp.so /private/var/folders/mg/qbkhn6ns57z230mv90bz43nr0000gp/T/konan_temp3189856967062286341/libapp.so.o -Bstatic -Bdynamic -ldl -lm -lpthread -lc++ -lc++abi --defsym __cxa_demangle=Konan_cxa_demangle -lc -lunwind -lqos -lhitrace_ndk.z -lhilog_ndk.z

BUILD SUCCESSFUL in 3s
3 actionable tasks: 3 executed
➜  kn_samples git:(metadataklib) ✗ 
```

```shell

```

