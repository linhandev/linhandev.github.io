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
- HDC available (see [hdc-commands.md](./hdc-commands.md))
- Executable built for the correct target architecture (see [working-with-clang.md](../kmp-foundations/working-with-clang.md) for build instructions)

## Device Connection Check

Before deploying and running executables, verify that an OHOS device is connected using `hdc list targets`. If no devices are shown, check USB/network, developer mode, and HDC service

## Target Architecture Detection

OHOS supports two architectures:

- **x86_64-linux-ohos**: Used for x86 emulators
- **aarch64-linux-ohos**: Used for ARM64 emulators and real devices

To determine which architecture your device uses, run:

```bash
hdc shell uname -a
```

This will output system information including the architecture. Use the appropriate target architecture when building your executable (see [working-with-clang.md](../kmp-foundations/working-with-clang.md)).

## Device Deployment

Use HDC for file transfer and shell (see [hdc-commands.md](./hdc-commands.md)). Deployment workflow:

1. **Check device connection:** `hdc list targets`
2. **Determine target architecture:** `hdc shell uname -a`
3. **Build executable** for the target architecture (see [working-with-clang.md](../kmp-foundations/working-with-clang.md))
4. **Send to device:** `hdc file send main /data/local/tmp/main`
5. **Set permissions:** `hdc shell chmod 777 /data/local/tmp/main`
6. **Run executable:** `hdc shell LD_LIBRARY_PATH=/data/local/tmp/ /data/local/tmp/main` (set `LD_LIBRARY_PATH` if you need to load libraries from a specific path)

## Common Issues and Solutions

### Issue: HDC connection failed
**Solution**: Check USB/network, developer mode, and HDC service (see [hdc-commands.md](./hdc-commands.md#service-and-targets)); run `hdc list targets` to verify the device is detected.

### Issue: Wrong target architecture
**Solution**: Use `hdc shell uname -a` to get device architecture (see [hdc-commands.md](./hdc-commands.md#shell)); rebuild with the correct `-target` and `-L` for that architecture.

### Issue: Permission denied when running executable
**Solution**: Ensure execute permissions (`hdc shell chmod 777 <path>`, see [hdc-commands.md](./hdc-commands.md#shell)) and that the path is writable (e.g. `/data/local/tmp/`).
- **If still denied**: On not rooted ohos phones (not simulators), execution from `/data/local/tmp` is blocked by SELinux or security policy even with correct file permissions. The filesystem may not have `noexec`; the block is policy-level. In that case there is no standard alternative folder that is both writable via `hdc file send` and allowed to execute: `/data/` and `/mnt/` root are typically not writable by the shell user. Options: use a rooted/developer image, an OpenHarmony emulator, or run native code inside an app (e.g. .so in HAP) instead of a standalone exe.

### Issue: Library not found at runtime
**Solution**:
- Set `LD_LIBRARY_PATH` to the directory containing required libraries
- Ensure libraries are also deployed to the device
- Check that libraries match the target architecture
- **Where system/app .so live on device:** see [ohos-device-layout.md](./ohos-device-layout.md) (e.g. `/system/lib64/ndk/` for NDK libs).

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

**Accessing app storage via hdc shell**: Paths used inside the app map to device paths: e.g. `/data/storage/el2/base/files/` in-app is `/data/app/el2/100/base/<bundle_name>/files/` when accessed via `hdc shell`. Get the bundle name from the project’s `AppScope/app.json5`.

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

Use `hdc shell "..."` to run with env vars (see [hdc-commands.md](./hdc-commands.md#shell)), e.g. `hdc shell "export MY_VAR=value && /data/local/tmp/executable"` or with GCOV: `hdc shell "cd /data/local/tmp && GCOV_PREFIX=/data/local/tmp/gcov GCOV_PREFIX_STRIP=99 ./executable"`. Environment variables set in the shell **only affect that shell session**, not app processes.

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
- Deploy to `/data/local/tmp/` (see [hdc-commands.md](./hdc-commands.md))
- Run via `hdc shell`; environment set in the shell command

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

1. Check device: `hdc list targets`
2. Architecture: `hdc shell uname -a`
3. Build (see [working-with-clang.md](../kmp-foundations/working-with-clang.md)), e.g. for aarch64:
   ```bash
   clang++ --sysroot <SYSROOT> main.cpp -target aarch64-linux-ohos -L<CLANG_LIB_DIR> -resource-dir <RESOURCE_DIR> -o main
   ```
4. Deploy and run (see [hdc-commands.md](./hdc-commands.md)): `hdc file send main /data/local/tmp/main`, then `hdc shell chmod 777 /data/local/tmp/main`, then `hdc shell /data/local/tmp/main`

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
- For building C/C++ programs, see [working-with-clang.md](../kmp-foundations/working-with-clang.md)
