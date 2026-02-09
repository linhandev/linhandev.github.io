# Agent Guide: Building C/C++ Programs for OHOS (OpenHarmony)

This document provides instructions for building C/C++ programs targeting OHOS devices using Clang. For deploying and running executables on devices, see [running-exe-on-ohos.md](../ohos-integration/running-exe-on-ohos.md). Update this if during execution more information concerning this topic is learned and can be useful for future llvm sessions.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Key Paths and Locations](#key-paths-and-locations)
3. [Target Architecture Detection](#target-architecture-detection)
4. [Build Process](#build-process)
5. [Common Issues and Solutions](#common-issues-and-solutions)

## Prerequisites

- DevEco Studio installed (provides OHOS SDK)
- LLVM toolchain (typically comes with DevEco Studio or Konan dependencies)

## Key Paths and Locations

### Clang Compiler Location

There are two common locations for the Clang compiler:

**Option 1: DevEco Studio LLVM**
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/clang++
```

**Option 2: Konan Dependencies**
```bash
~/.konan/dependencies/llvm-1201-macos-aarch64/bin/clang++
```
**Note**: Version number (1201) may vary. Check your `~/.konan/dependencies/` directory for the actual version. If this version doesn't exist, a version that can cross compile to OHOS target typically comes with "ohos" in the folder name.

**Important**: If the user doesn't specify which Clang to use, ask them whether they want to use the DevEco Studio version or the Konan version.

### Sysroot Location
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot
```
**Note**: Path may vary based on DevEco Studio installation location. The sysroot contains system headers and libraries for OHOS.

### Resource Directory
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4
```
**Note**: Clang version (15.0.4) may vary. Check your DevEco Studio SDK directory.

### Clang Runtime Libraries
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/<TARGET_ARCH>
```
This directory contains runtime libraries that need to be linked with `-L` flag. Replace `<TARGET_ARCH>` with the appropriate architecture (see [Target Architecture Detection](#target-architecture-detection)).

## Target Architecture Detection

OHOS supports two architectures:

- **x86_64-linux-ohos**: Used for x86 emulators
- **aarch64-linux-ohos**: Used for ARM64 emulators and real devices

To determine which architecture your device uses, run:

```bash
hdc shell uname -a
```

This will output system information including the architecture. Use the appropriate target architecture in your build commands:
- For x86 emulators: `-target x86_64-linux-ohos`
- For ARM64 emulators and real devices: `-target aarch64-linux-ohos`

## Build Process

### Basic Build Command Structure

```bash
clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  source.cpp \
  -target <TARGET_ARCH> \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/<TARGET_ARCH> \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  -o output
```

Replace `<TARGET_ARCH>` with either `x86_64-linux-ohos` or `aarch64-linux-ohos` based on your device (see [Target Architecture Detection](#target-architecture-detection)).

### Multi-Stage Build (IR -> Object -> Executable)

For better control and debugging, split the build into stages:

#### Stage 1: Emit LLVM IR
```bash
clang++ \
  --sysroot <SYSROOT> \
  -emit-llvm -S \
  source.cpp \
  -target <TARGET_ARCH> \
  -resource-dir <RESOURCE_DIR> \
  -o source.ll
```

#### Stage 2: Compile IR to Object File
```bash
clang++ \
  --sysroot <SYSROOT> \
  -c source.ll \
  -target <TARGET_ARCH> \
  -resource-dir <RESOURCE_DIR> \
  -o source.o
```

#### Stage 3: Link Object to Executable
```bash
clang++ \
  --sysroot <SYSROOT> \
  source.o \
  -target <TARGET_ARCH> \
  -L<CLANG_LIB_DIR> \
  -resource-dir <RESOURCE_DIR> \
  -o executable
```

### Important Compiler Flags

- `--sysroot <PATH>`: Specifies the system root directory
- `-target <TARGET_ARCH>`: Target architecture and OS (either `x86_64-linux-ohos` or `aarch64-linux-ohos`)
- `-resource-dir <PATH>`: Clang resource directory
- `-L<PATH>`: Library search path (for runtime libraries)

## Common Issues and Solutions

### Issue: Cannot find sysroot
**Solution**: Verify DevEco Studio installation path and SDK location.

### Issue: Library linking errors
**Solution**: Ensure `-L` flag points to correct clang runtime library directory matching your target architecture.

### Issue: Wrong target architecture
**Solution**: 
- Use `hdc shell uname -a` to determine the device architecture
- Ensure the `-target` flag matches the device architecture
- Ensure the `-L` library path points to the correct architecture directory

## Example: Build Workflow

```bash
# 1. Determine architecture (if device available)
# See ohos-integration/running-exe-on-ohos.md for device connection and architecture detection

# 2. Build (example for aarch64)
clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  main.cpp \
  -target aarch64-linux-ohos \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  -o main
```

## Additional Resources

- OHOS Native Development Documentation
- DevEco Studio User Guide
- For deploying and running executables, see [running-exe-on-ohos.md](../ohos-integration/running-exe-on-ohos.md)