# Agent Guide: Running Executables on OHOS Devices

This document provides instructions for deploying and running executables on OHOS (OpenHarmony) devices using HDC (OHOS Device Connector). Update this if during execution more information concerning this topic is learned and can be useful for future sessions.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Device Connection Check](#device-connection-check)
3. [Target Architecture Detection](#target-architecture-detection)
4. [Device Deployment](#device-deployment)
5. [Common Issues and Solutions](#common-issues-and-solutions)
6. [Example: Complete Workflow](#example-complete-workflow)

## Prerequisites

- OHOS device connected via USB or network
- `hdc` tool available (OHOS Device Connector, similar to Android's `adb`)
- Executable built for the correct target architecture (see [working-with-clang.md](./working-with-clang.md) for build instructions)

## Device Connection Check

Before deploying and running executables, verify that an OHOS device is connected:

```bash
hdc list targets
```

This command will list all connected devices. If no devices are shown, ensure:
- Device is connected via USB or network
- Device is in developer mode
- HDC service is running (try `hdc kill` then `hdc start` if needed)

## Target Architecture Detection

OHOS supports two architectures:

- **x86_64-linux-ohos**: Used for x86 emulators
- **aarch64-linux-ohos**: Used for ARM64 emulators and real devices

To determine which architecture your device uses, run:

```bash
hdc shell uname -a
```

This will output system information including the architecture. Use the appropriate target architecture when building your executable (see [working-with-clang.md](./working-with-clang.md)).

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

3. **Build executable** for the target architecture (see [working-with-clang.md](./working-with-clang.md))

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

### Issue: HDC connection failed
**Solution**:
- Check USB connection or network settings
- Verify device is in developer mode
- Try `hdc kill` then `hdc start`
- Run `hdc list targets` to verify device is detected

### Issue: Wrong target architecture
**Solution**: 
- Use `hdc shell uname -a` to determine the device architecture
- Rebuild the executable with the correct `-target` flag matching the device architecture
- Ensure the `-L` library path points to the correct architecture directory

### Issue: Permission denied when running executable
**Solution**:
- Ensure executable has execute permissions: `hdc shell chmod 777 <path>`
- Check that the path is writable: `/data/local/tmp/` is typically safe

### Issue: Library not found at runtime
**Solution**:
- Set `LD_LIBRARY_PATH` to the directory containing required libraries
- Ensure libraries are also deployed to the device
- Check that libraries match the target architecture

## Example: Complete Workflow

```bash
# 1. Check device connection
hdc list targets

# 2. Determine architecture
hdc shell uname -a

# 3. Build executable (example for aarch64)
# See working-with-clang.md for detailed build instructions
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
- For building C/C++ programs, see [working-with-clang.md](./working-with-clang.md)
