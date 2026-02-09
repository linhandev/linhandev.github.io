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
- **If still denied**: On not rooted ohos phones (not simulators), execution from `/data/local/tmp` is blocked by SELinux or security policy even with correct file permissions. The filesystem may not have `noexec`; the block is policy-level. In that case there is no standard alternative folder that is both writable via `hdc file send` and allowed to execute: `/data/` and `/mnt/` root are typically not writable by the shell user. Options: use a rooted/developer image, an OpenHarmony emulator, or run native code inside an app (e.g. .so in HAP) instead of a standalone exe.

### Issue: Library not found at runtime
**Solution**:
- Set `LD_LIBRARY_PATH` to the directory containing required libraries
- Ensure libraries are also deployed to the device
- Check that libraries match the target architecture

### Issue: HarmonyOS App Storage Permissions

**Context**: When running code within a HarmonyOS application (HAP), permissions differ from standalone executables.

**Accessible Paths for HAP**:
```
✅ /data/storage/el2/base/files/       # App's files directory (read/write)
✅ /data/storage/el2/base/cache/       # App's cache directory
✅ /data/storage/el2/base/temp/        # App's temp directory
❌ /data/local/tmp/                    # NOT accessible to app process
❌ /data/app/                          # Read-only (app installation)
```

**For standalone executables** (shell/test):
```
✅ /data/local/tmp/                    # Read/write
```

**Accessing app storage via hdc shell**: There's a mapping relationship between code path within app and accessing from hdc, /data/storage/el2/base/files/pgoprofraw within app is accessible in hdc at /data/app/el2/100/base/[application bundle name， eg: com.example.application]/files/pgoprofraw. You can find application bundle name in /path/to/harmonyProject/AppScope/app.json5.

```json
{
  "app": {
    "bundleName": "com.example.nativecppdemo", # this would be the bundle name
    ...
  }
}
```

---

## Environment Variables

### Setting Environment for Executables

**In shell**:
```bash
hdc shell "export MY_VAR=value && /data/local/tmp/executable"
```

**With GCOV or instrumented code**:
```bash
hdc shell "cd /data/local/tmp && GCOV_PREFIX=/data/local/tmp/gcov GCOV_PREFIX_STRIP=99 ./executable"
```

**Important**: Environment variables set in shell **only affect that shell session**, not app processes.

### Setting Environment for Shared Libraries in Apps

**For .so loaded by HarmonyOS app**, environment must be set in **app's C++ code**:

```cpp
// In app's native entry point (napi_init.cpp or similar)
__attribute__((constructor(101)))  // Run early, before .so global constructors
static void InitEnvironment() {
    setenv("MY_VAR", "value", 1);
}
```

**Why**: Shell environment doesn't transfer to app processes. Must be set programmatically.

---

## Shared Libraries (.so) vs Executables (.kexe)

### Deployment Differences

**Executables**:
- Deploy to `/data/local/tmp/`
- Run directly via `hdc shell`
- Environment set in shell command

**Shared Libraries in HAP**:
- Bundle in app's `libs/arm64-v8a/`
- Loaded by app process (not shell)
- Environment must be set in app's C++ code
- Lifecycle: Never unloaded (stays in memory until app killed)

### Lifecycle Implications

**Executables**:
```
Start → Run → Exit
           ↓
    Destructors run, cleanup happens
```

**Shared Libraries in HAP**:
```
App Start → .so loads (constructors run)
    ↓
App Runs → .so stays loaded
    ↓
App Backgrounds → .so STILL loaded (no dlclose)
    ↓
App Killed → Process terminated (destructors may NOT run)
```

**Impact**: Code that relies on `atexit()` or `__attribute__((destructor))` may not execute in HAP environments. Use manual triggers instead.

---

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

## Validated Behaviors

### PLT Resolution and Weak Symbols (Validated 2026-01-28)

When testing weak vs global symbol resolution with dlopen on OHOS:

**Observation**: When linking only with a weak library (`-lweak`), the undefined symbol in the caller's dynamic symbol table shows as `GLOBAL DEFAULT UND`, not `WEAK`. However, at runtime:
- The symbol correctly resolves to the WEAK definition
- If the function is called before `dlopen` of a GLOBAL library, PLT resolves to WEAK
- After `dlopen` of GLOBAL library, subsequent calls still use the WEAK symbol (PLT doesn't update)

**Key Point**: The symbol binding in `.dynsym` for undefined symbols may show GLOBAL even when they will resolve to WEAK symbols at runtime. The runtime behavior is what matters.

**Test Command**:
```bash
# Build and deploy libraries and test program
# Link test with -lweak only, then dlopen libglobal.so
# First call returns 2 (WEAK), second call after dlopen still returns 2 (WEAK)
```

## Additional Resources

- OHOS Native Development Documentation
- DevEco Studio User Guide
- For building C/C++ programs, see [working-with-clang.md](./working-with-clang.md)
