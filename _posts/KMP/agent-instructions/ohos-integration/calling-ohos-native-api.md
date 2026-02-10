# Calling OHOS System C APIs from Native Code

How to discover, use, and debug OHOS system C APIs in a native module (e.g. NAPI shared library in a HAP). Examples: **OH_LOG_Print** (HiLog), **OH_HiTrace**.

## Finding the API profile (signature, header, library)

**Where to look:** The OHOS NDK sysroot shipped with DevEco Studio.

- **Typical sysroot path (macOS):**  
  `$DEVECO_DIR/Contents/sdk/default/openharmony/native/sysroot` and `$DEVECO_DIR/Contents/sdk/default/hms/native/sysroot`
  e.g. `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot`

- **Headers:** `sysroot/usr/include/`  
  - Subdirectories often match kit or module names, e.g. `hilog/`, `hitrace/`, `napi/`.

- **Libraries:** `sysroot/usr/lib/<arch>/`  
  - Architectures: `arm-linux-ohos`, `aarch64-linux-ohos`, `x86_64-linux-ohos`.  
  - NDK libs are usually named `lib<module>_ndk.z.so` (e.g. `libhilog_ndk.z.so`). The header’s `@library` may say `libhilog.so`; for app NDK development use the `*_ndk.z.so` variant.
  - Note: @library in headers may be wrong; use nm to confirm the lib has the symbol; if not, glob *.so in sysroot and nm each to find the right one.

OH_LOG_Print: Header `sysroot/usr/include/hilog/log.h`, declaration `int OH_LOG_Print(LogType type, LogLevel level, unsigned int domain, const char *tag, const char *fmt, ...);`, library **libhilog_ndk.z.so** (link in CMake).

## Usage documents and examples

Doc on official website takes precedence over header file content should they contradict.

- **HarmonyOS doc URL convention (direct API page):**  
  Reference pages for native C APIs follow a predictable pattern.  
  **Base:** `https://developer.huawei.com/consumer/cn/doc/`  
  **Page path:** `harmonyos-references/capi-<header-slug>-h`  
  **Anchor:** `#<api_lowercase>` (optional; links to a specific API on the page).

  - **Header → slug:** Use the header **basename** (no directory). Replace underscores with hyphens and append `-h`.  
    Example: `native_interface_bundle.h` → `capi-native-interface-bundle-h`.
  - **API → anchor:** C API symbol in **lowercase**, underscores unchanged.  
    Example: `OH_NativeBundle_GetAbilityResourceInfo` → `oh_nativebundle_getabilityresourceinfo`.

  **Full example:**  
  `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/capi-native-interface-bundle-h#oh_nativebundle_getabilityresourceinfo`  
  (API `OH_NativeBundle_GetAbilityResourceInfo` from `native_interface_bundle.h`).

- **Site wide search:**  
  Huawei Developer:  
  `https://developer.huawei.com/consumer/cn/doc/search?type=all&val=<api_name>`  
  e.g. `val=oh_log_print` or `val=OH_LOG_Print`.

- **In-header documentation:**  
  Headers use Doxygen-style `@brief`, `@param`, `@return`, `@since`, and often **sample code** in the file comment (e.g. in `hilog/log.h`: define `LOG_DOMAIN`, `LOG_TAG`, then call `OH_LOG_Print` or macros like `OH_LOG_INFO`).

- **Example code:**  
  - In your project: e.g. the entry module’s `entry/src/main/cpp/napi_init.cpp` in a DevEco native sample.  
  - OpenHarmony GitHub: search `openharmony` org for API/module name for native tests/demos.

## Headers to include and libs to link

**Include:**  
Use the path as in the sysroot, without the sysroot prefix. The build is configured to use the NDK sysroot as include path.

```c
#include "hilog/log.h"
#include <hitrace/trace.h>
```

**Define before including (for HiLog):**  
`LOG_DOMAIN` and `LOG_TAG` are optional but recommended; if not defined, the header defaults `LOG_TAG` to `NULL`.

```c
#define LOG_TAG "MyModule"
#include "hilog/log.h"
```

**Link:**  
In the native module’s `CMakeLists.txt`, add the NDK library (name as in sysroot):

```cmake
target_link_libraries(entry PUBLIC libace_napi.z.so libhilog_ndk.z.so libhitrace_ndk.z.so)
```

Rule: header often says `lib<name>.so`; in NDK sysroot use **lib<name>_ndk.z.so** when that variant exists (e.g. hilog, hitrace). Some modules ship only **lib<name>.so** (e.g. **libohhicollie.so** for HiCollie).

## OH_LOG_Print (HiLog) example

**Call signature (from log.h):**

```c
int OH_LOG_Print(LogType type, LogLevel level, unsigned int domain, const char *tag, const char *fmt, ...);
```

Parameters: type (e.g. LOG_APP), level (LOG_DEBUG/INFO/WARN/ERROR/FATAL), domain (unsigned int), tag (string), fmt (printf-style). Privacy: OHOS redacts log args as `<private>` by default; use `%{public}d` / `%{public}s` to show values; `%{private}d` is explicit private.

- `%{public}d`: Public integer.
- `%{public}s`: Public string.
- `%{private}d`: Explicitly private (default behavior).

**Example:**

```c
int id = 123;
// Will print: "User ID: <private>"
OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "User ID: %d", id);

// Will print: "User ID: 123"
OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "User ID: %{public}d", id);
```

View HiLog on device: `hdc shell hilog -T <TAG> -x`. See [hdc-commands.md](./hdc-commands.md#logs-hilog).

## OH_HiTrace example

Header `<hitrace/trace.h>`, library `libhitrace_ndk.z.so`. APIs: OH_HiTrace_BeginChain(name, flags), OH_HiTrace_EndChain(), OH_HiTrace_GetId(), OH_HiTrace_GetChainId(&id).

```c
#include <hitrace/trace.h>

void TraceExample() {
    // Start a chain
    HiTraceId id = OH_HiTrace_BeginChain("MyTraceChain", HITRACE_FLAG_DEFAULT);
    
    // Check if valid
    if (OH_HiTrace_IsIdValid(&id)) {
        // Log the Chain ID (use %{public}llu for visibility)
        uint64_t chainId = OH_HiTrace_GetChainId(&id);
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "Current Chain ID: %{public}llu", (unsigned long long)chainId);
    }
    
    // Create a span
    HiTraceId spanId = OH_HiTrace_CreateSpan();
    
    // ... perform operations ...
    
    // End the chain
    OH_HiTrace_EndChain();
}
```

## HiCollie (stuck/jank detection)

Header `hicollie/hicollie.h`, library **libohhicollie.so** (no `_ndk.z` variant). Syscap: SystemCapability.HiviewDFX.HiCollie. @since 12 (SetTimer/CancelTimer/StuckDetectionWithTimeout @since 18).

- **OH_HiCollie_Init_StuckDetection(task)** / **OH_HiCollie_Init_StuckDetectionWithTimeout(task, timeout)**: Must be called from a **non-main thread** (HICOLLIE_WRONG_THREAD_CONTEXT otherwise). `timeout` 3–15 s. Task runs periodically on HiCollie’s thread.
- **OH_HiCollie_Report(isSixSecond)**: Allowed **only** from inside the StuckDetection task callback; otherwise WRONG_THREAD_CONTEXT or REMOTE_FAILED. On emulator, Report may return HICOLLIE_REMOTE_FAILED (29800002); try a real device.
- **OH_HiCollie_Init_JankDetection(beginFunc, endFunc, param)**: Must be called from a non-main thread. Pass pointers to your begin/end stub functions (both set or both null). Call `beginFunc("eventName")` / `endFunc("eventName")` around each event.
- **OH_HiCollie_SetTimer(param, &id)** / **OH_HiCollie_CancelTimer(id)**: Use before/after time-consuming work. Do not call from appspawn or native process. Use `HICOLLIE_FLAG_NOOP` to avoid log/recovery on timeout. `param.name` non-empty, `param.timeout` in seconds.

```cmake
target_link_libraries(entry PUBLIC libace_napi.z.so libhilog_ndk.z.so libohhicollie.so)
```

## Pitfalls

Permission denied: (1) Missing/wrong permission in app (module.json5, capability/sandbox)—check API docs and add. (2) Wrong device type—some APIs are PC-only; on phone they still return denied; try on target device type.

API not available at runtime: APIs have @since in docs. Check device: `hdc shell param get const.ohos.apiversion`. If runtime API level < @since, app can crash.
