# Agent Instructions Index

This directory contains structured guides for agents working with Kotlin Native compiler development, particularly for OHOS (OpenHarmony) targets. Each guide focuses on a specific aspect of the development workflow.

## Guides

### [working-with-clang.md](./working-with-clang.md)
**Building C/C++ Programs for OHOS**

Guide for building C/C++ programs targeting OHOS devices using Clang. Covers compiler locations, sysroot configuration, target architecture selection, and build processes including multi-stage compilation (IR → Object → Executable). Essential for understanding the native compilation toolchain used by Kotlin Native.

### [running-exe-on-ohos.md](./running-exe-on-ohos.md)
**Deploying and Running Executables on OHOS Devices**

Instructions for deploying and executing binaries on OHOS devices using HDC (OHOS Device Connector). Includes device connection verification, architecture detection, file transfer, permission management, and runtime execution. Use this guide after building executables to test them on actual devices.

### [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md)
**Building and Testing Kotlin Native Compiler for OHOS**

Complete workflow for building the Kotlin Native compiler and testing it with OHOS targets. Covers build prerequisites, incremental vs. clean builds, compilation testing, debugging techniques, and common issues. Essential reference for compiler development and iteration cycles.

### [adding-llvm-pass-to-konan.md](./adding-llvm-pass-to-konan.md)
**Adding LLVM Passes to Kotlin Native Compiler**

Comprehensive guide for integrating new LLVM optimization or instrumentation passes into the Kotlin Native compiler. Includes C++ API extensions, Kotlin pipeline classes, phase registration, configuration options, runtime library linking, and testing strategies. Uses GCOV profiling pass as a reference example.

## Quick Reference

**Build C/C++ for OHOS**: [working-with-clang.md](./working-with-clang.md)  
**Deploy to Device**: [running-exe-on-ohos.md](./running-exe-on-ohos.md)  
**Build Kotlin Native**: [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md)  
**Add LLVM Pass**: [adding-llvm-pass-to-konan.md](./adding-llvm-pass-to-konan.md)

## Workflow Order

1. **Setup**: Ensure DevEco Studio and OHOS SDK are installed
2. **Build Compiler**: Follow [working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md) to build Kotlin Native
3. **Modify Compiler**: Use [adding-llvm-pass-to-konan.md](./adding-llvm-pass-to-konan.md) if adding new LLVM passes
4. **Test Native Code**: Use [working-with-clang.md](./working-with-clang.md) to build test programs
5. **Deploy & Run**: Use [running-exe-on-ohos.md](./running-exe-on-ohos.md) to test on devices
