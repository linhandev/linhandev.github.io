# Agent Instructions: Building C/C++ Programs for OHOS (OpenHarmony)

This document provides instructions for building and running C/C++ programs targeting OHOS devices. Update this if during execution more information concering this topic is learned and can be useful for future llvm sessions.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Device Connection Check](#device-connection-check)
3. [Key Paths and Locations](#key-paths-and-locations)
4. [Target Architecture Detection](#target-architecture-detection)
5. [Build Process](#build-process)
6. [Device Deployment](#device-deployment)
7. [Common Issues and Solutions](#common-issues-and-solutions)

## Prerequisites

- DevEco Studio installed (provides OHOS SDK)
- LLVM toolchain (typically comes with DevEco Studio or Konan dependencies)
- OHOS device connected via USB or network
- `hdc` tool available (OHOS Device Connector, similar to Android's `adb`)

## Device Connection Check

Before building and deploying, verify that an OHOS device is connected:

```bash
hdc list targets
```

This command will list all connected devices. If no devices are shown, ensure:
- Device is connected via USB or network
- Device is in developer mode
- HDC service is running (try `hdc kill` then `hdc start` if needed)

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

## Device Deployment

### Using HDC (OHOS Device Connector)

HDC is similar to Android's ADB. Common commands:

#### Check Device Connection
```bash
hdc list targets
```

#### Send File to Device
```bash
hdc file send <local_file> <device_path>
```

#### Receive File from Device
```bash
hdc file recv <device_path> <local_file>
```

#### Execute Shell Command
```bash
hdc shell <command>
```

#### Set Permissions
```bash
hdc shell chmod 777 <device_path>
```

### Deployment Workflow

1. **Check device connection:**
   ```bash
   hdc list targets
   ```

2. **Determine target architecture:**
   ```bash
   hdc shell uname -a
   ```

3. **Build executable** for the target architecture

4. **Send to device:**
   ```bash
   hdc file send main /data/local/tmp/main
   ```

5. **Set permissions:**
   ```bash
   hdc shell chmod 777 /data/local/tmp/main
   ```

6. **Run executable:**
   ```bash
   hdc shell LD_LIBRARY_PATH=/data/local/tmp/ /data/local/tmp/main
   ```
   **Note**: Set `LD_LIBRARY_PATH` if you need to load libraries from a specific location.

## Common Issues and Solutions

### Issue: Cannot find sysroot
**Solution**: Verify DevEco Studio installation path and SDK location.

### Issue: Library linking errors
**Solution**: Ensure `-L` flag points to correct clang runtime library directory matching your target architecture.

### Issue: HDC connection failed
**Solution**:
- Check USB connection or network settings
- Verify device is in developer mode
- Try `hdc kill` then `hdc start`
- Run `hdc list targets` to verify device is detected

### Issue: Wrong target architecture
**Solution**: 
- Use `hdc shell uname -a` to determine the device architecture
- Ensure the `-target` flag matches the device architecture
- Ensure the `-L` library path points to the correct architecture directory

## Example: Complete Workflow

```bash
# 1. Check device connection
hdc list targets

# 2. Determine architecture
hdc shell uname -a

# 3. Build (example for aarch64)
clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  main.cpp \
  -target aarch64-linux-ohos \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  -o main

# 4. Deploy and run
hdc file send main /data/local/tmp/main
hdc shell chmod 777 /data/local/tmp/main
hdc shell /data/local/tmp/main
```

## Additional Resources

- OHOS Native Development Documentation
- DevEco Studio User Guide
- For code coverage instructions, see [CODE_COVERAGE_INSTRUCTIONS.md](CODE_COVERAGE_INSTRUCTIONS.md)