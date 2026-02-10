# Agent Instructions Index

This directory contains structured guides for agents working with Kotlin Native compiler development, particularly for OHOS (OpenHarmony) targets. Each guide focuses on a specific aspect of the development workflow.

## Guides

### [working-with-clang.md](./kmp-foundations/working-with-clang.md)
**Building C/C++ Programs for OHOS**

Guide for building C/C++ programs targeting OHOS devices using Clang. Covers compiler locations, sysroot configuration, target architecture selection, and build processes including multi-stage compilation (IR → Object → Executable). Essential for understanding the native compilation toolchain used by Kotlin Native.

### [building-ohos-hap-from-cli.md](./ohos-integration/building-ohos-hap-from-cli.md)
**Building OHOS HAP from Command Line**

How to build an OpenHarmony/HarmonyOS HAP from the CLI when the app includes a Kotlin/Native shared library. References the L33 task block in `kotlinApp/build.gradle.kts` (publish binaries, startHarmonyApp). Covers one-command Gradle flow, required `gradle.properties`, HAP output location, and optional manual hvigor steps.

### [calling-ohos-native-api.md](./ohos-integration/calling-ohos-native-api.md)
**Calling OHOS System C APIs from Native Code**

How to discover and use OHOS NDK C APIs: where to find API profile (headers, libs in sysroot), usage docs and examples, what to include and link, debugging, checking HiLog output, and building/running the HAP. Uses **OH_LOG_Print** (HiLog) as the running example.

### [running-exe-on-ohos.md](./ohos-integration/running-exe-on-ohos.md)
**Deploying and Running Executables on OHOS Devices**

Instructions for deploying and executing binaries on OHOS devices using HDC (OHOS Device Connector). Includes device connection verification, architecture detection, file transfer, permission management, and runtime execution. Use this guide after building executables to test them on actual devices.

### [ohos-device-layout.md](./ohos-integration/ohos-device-layout.md)
**OHOS Device Layout — Where to Find .so**

Where system and application native shared libraries (`.so`) live on OHOS/HarmonyOS devices. Use when you need to **find .so on device** (e.g. system libs like NDK, chipset SDK, app install paths). Tables for `/system/lib64/`, `/system/lib64/ndk/`, `/data/app/.../libs/`, `/vendor/lib64/`, etc.

### [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md)
**Building and Testing Kotlin Native Compiler for OHOS**

Complete workflow for building the Kotlin Native compiler and testing it with OHOS targets. Covers build prerequisites, incremental vs. clean builds, compilation testing, debugging techniques, and common issues. Essential reference for compiler development and iteration cycles.

### [adding-llvm-pass-to-konan.md](./kmp-foundations/adding-llvm-pass-to-konan.md)
**Adding LLVM Passes to Kotlin Native Compiler**

Comprehensive guide for integrating new LLVM optimization or instrumentation passes into the Kotlin Native compiler. Includes C++ API extensions, Kotlin pipeline classes, phase registration, configuration options, runtime library linking, and testing strategies. Uses GCOV profiling pass as a reference example.

### [llvm-runtime-libraries.md](./kmp-foundations/llvm-runtime-libraries.md)
**LLVM Compiler-RT Libraries for OHOS**

Guide for working with LLVM's compiler-rt runtime libraries on OHOS targets. Covers library locations, finding libraries at runtime, required OHOS system libraries, and common linking errors. Essential for passes that require runtime support (sanitizers, profiling, coverage).

## Quick Reference

**Build C/C++ for OHOS**: [working-with-clang.md](./kmp-foundations/working-with-clang.md)  
**Build OHOS HAP from CLI**: [building-ohos-hap-from-cli.md](./ohos-integration/building-ohos-hap-from-cli.md)  
**Call OHOS native API**: [calling-ohos-native-api.md](./ohos-integration/calling-ohos-native-api.md)  
**View HiLog by tag**: `hdc shell hilog -T <TAG> -x` (see [calling-ohos-native-api.md](./ohos-integration/calling-ohos-native-api.md#viewing-hilog-on-device))  
**Deploy to Device**: [running-exe-on-ohos.md](./ohos-integration/running-exe-on-ohos.md)  
**Find .so on device**: [ohos-device-layout.md](./ohos-integration/ohos-device-layout.md)  
**Build Kotlin Native**: [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md)  
**Add LLVM Pass**: [adding-llvm-pass-to-konan.md](./kmp-foundations/adding-llvm-pass-to-konan.md)  
**LLVM Runtime Libraries**: [llvm-runtime-libraries.md](./kmp-foundations/llvm-runtime-libraries.md)

## Workflow Order

1. **Setup**: Ensure DevEco Studio and OHOS SDK are installed
2. **Build Compiler**: Follow [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md) to build Kotlin Native
3. **Modify Compiler**: Use [adding-llvm-pass-to-konan.md](./kmp-foundations/adding-llvm-pass-to-konan.md) if adding new LLVM passes
4. **Test Native Code**: Use [working-with-clang.md](./kmp-foundations/working-with-clang.md) to build test programs
5. **Deploy & Run**: Use [running-exe-on-ohos.md](./ohos-integration/running-exe-on-ohos.md) to test on devices
