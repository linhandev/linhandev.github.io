# Running Executables on OHOS Devices

Deploy and run executables on OHOS using HDC. See [hdc-commands.md](./hdc-commands.md), [working-with-clang.md](../kmp-foundations/working-with-clang.md) for build.

## Prerequisites

- OHOS device connected via USB or network
- HDC available (see [hdc-commands.md](./hdc-commands.md))
- Executable built for the correct target architecture (see [working-with-clang.md](../kmp-foundations/working-with-clang.md) for build instructions)

## Device connection

`hdc list targets`. If none: check USB/network, developer mode, HDC service.

## Target architecture

x86_64-linux-ohos (x86 emulators), aarch64-linux-ohos (ARM64 emulators/real devices). Determine device:

```bash
hdc shell uname -a
```

Use that target when building. Deployment:

1. **Check device connection:** `hdc list targets`
2. **Determine target architecture:** `hdc shell uname -a`
3. **Build executable** for the target architecture (see [working-with-clang.md](../kmp-foundations/working-with-clang.md))
4. **Send to device:** `hdc file send main /data/local/tmp/main`
5. **Set permissions:** `hdc shell chmod 777 /data/local/tmp/main`
6. Run: `hdc shell LD_LIBRARY_PATH=/data/local/tmp/ /data/local/tmp/main`

## Common issues

HDC connection failed: Check USB/network, developer mode, HDC; `hdc list targets`.
Wrong target: `hdc shell uname -a`, rebuild with correct -target and -L.
Permission denied: chmod 777, writable path (e.g. /data/local/tmp). On non-rooted phones execution from /data/local/tmp can be blocked by SELinux; no standard writable+executable folder via hdc. Options: rooted/developer image, emulator, or run inside app (.so in HAP).
Library not found: Set LD_LIBRARY_PATH, deploy libs, match architecture. .so locations: [ohos-device-layout.md](./ohos-device-layout.md).

## HarmonyOS App Storage Permissions

**Context**: When running code within a HarmonyOS application (HAP), permissions differ from standalone executables.

HAP: accessible /data/storage/el2/base/files/, cache/, temp/. Not: /data/local/tmp/, /data/app/. Standalone: /data/local/tmp/ rw. App path mapping via hdc: Paths used inside the app map to device paths: e.g. `/data/storage/el2/base/files/` in-app is `/data/app/el2/100/base/<bundle_name>/files/` when accessed via `hdc shell`. Get the bundle name from the project’s `AppScope/app.json5`.

## Environment variables (executables)

`hdc shell "export VAR=value && /data/local/tmp/executable"`. Shell env only affects that session, not app processes.

## Environment for .so in HAP

Set in app C++ code:

```cpp
// In app's native entry point (napi_init.cpp or similar)
__attribute__((constructor(101)))  // Run early, before .so global constructors
static void InitEnvironment() {
    setenv("MY_VAR", "value", 1);
}
```
Shell env doesn't transfer to app; set in code.

## .so vs executables

Executables: deploy to /data/local/tmp/, run via hdc shell; env in shell. .so in HAP: in libs/arm64-v8a/, loaded by app; env in C++; never unloaded until app killed. Impact: atexit()/destructor may not run in HAP; use manual triggers.

## Complete workflow

1. Check device: `hdc list targets`
2. Architecture: `hdc shell uname -a`
3. Build (see [working-with-clang.md](../kmp-foundations/working-with-clang.md)), e.g. for aarch64:
   ```bash
   clang++ --sysroot <SYSROOT> main.cpp -target aarch64-linux-ohos -L<CLANG_LIB_DIR> -resource-dir <RESOURCE_DIR> -o main
   ```
4. Deploy: hdc file send main /data/local/tmp/main; hdc shell chmod 777 /data/local/tmp/main; hdc shell /data/local/tmp/main

## Validated: PLT and weak symbols (2026-01-28)

Linking with -lweak only: .dynsym shows GLOBAL DEFAULT UND, not WEAK. At runtime: resolves to WEAK; before dlopen(GLOBAL) PLT→WEAK; after dlopen still WEAK (PLT doesn't update). Runtime behavior matters; .dynsym may show GLOBAL for undefined that resolve to WEAK.
