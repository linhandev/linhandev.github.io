# Calling OHOS System C APIs from Native Code

This guide describes how to discover, use, and debug OHOS (OpenHarmony/HarmonyOS) system C APIs in a native module (e.g. NAPI shared library in a HAP). **OH_LOG_Print** (HiLog) and **OH_HiTrace** are used as concrete examples throughout.

---

## 1. Finding the API profile (signature, header, library)

**Where to look:** The OHOS NDK sysroot shipped with DevEco Studio.

- **Typical sysroot path (macOS):**  
  `$DEVECO_DIR/Contents/sdk/default/openharmony/native/sysroot`  
  e.g. `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot`

- **Headers:** `sysroot/usr/include/`  
  - Subdirectories often match kit or module names, e.g. `hilog/`, `hitrace/`, `napi/`.

- **Libraries:** `sysroot/usr/lib/<arch>/`  
  - Architectures: `arm-linux-ohos`, `aarch64-linux-ohos`, `x86_64-linux-ohos`.  
  - NDK libs are usually named `lib<module>_ndk.z.so` (e.g. `libhilog_ndk.z.so`). The header’s `@library` may say `libhilog.so`; for app NDK development use the `*_ndk.z.so` variant.

**Example — OH_LOG_Print:**

- **Header:** `sysroot/usr/include/hilog/log.h`
- **Declaration:**  
  `int OH_LOG_Print(LogType type, LogLevel level, unsigned int domain, const char *tag, const char *fmt, ...);`
- **Library:** Header says `@library libhilog.so`; in the NDK sysroot the actual file is **`libhilog_ndk.z.so`** (link this in CMake).

Note: The @library field in headers may be wrong, use nm to confim the lib actually contains a public symbol with expected name. If not, do a search globbing all so in the sysroot and use nm to list symbols provided by a so.

**System capability (optional):**  
`native/ndk_system_capability.json` in the SDK maps NDK library names to `SystemCapability.*` (e.g. `hilog_ndk` → `SystemCapability.HiviewDFX.HiLog`). Useful for understanding permissions/capabilities.

---

## 2. Usage documents and examples

- **Official API docs:**  
  Huawei Developer:  
  `https://developer.huawei.com/consumer/cn/doc/search?type=all&val=<api_name>`  
  e.g. `val=oh_log_print` or `val=OH_LOG_Print`.

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

- **In-header documentation:**  
  Headers use Doxygen-style `@brief`, `@param`, `@return`, `@since`, and often **sample code** in the file comment (e.g. in `hilog/log.h`: define `LOG_DOMAIN`, `LOG_TAG`, then call `OH_LOG_Print` or macros like `OH_LOG_INFO`).

- **Example code:**  
  - In your project: e.g. the entry module’s `entry/src/main/cpp/napi_init.cpp` in a DevEco native sample.  
  - OpenHarmony GitHub: search the `openharmony` org for the API or module name (e.g. `hilog`, `hitrace`) for native unit tests or demos; C API examples may be in `native` or `ndk` trees.

---

## 3. Headers to include and libs to link

**Include:**  
Use the path as in the sysroot, without the sysroot prefix. The build is configured to use the NDK sysroot as include path.

```c
#include "hilog/log.h"
#include <hitrace/trace.h>
```

**Define before including (for HiLog):**  
`LOG_DOMAIN` and `LOG_TAG` are optional but recommended; if not defined, the header defaults `LOG_TAG` to `NULL`.

```c
#ifndef LOG_TAG
#define LOG_TAG "MyModule"
#endif
#ifndef LOG_DOMAIN
#define LOG_DOMAIN 0x0201   // hex, 0x0–0xFFFF
#endif
#include "hilog/log.h"
```

**Link:**  
In the native module’s `CMakeLists.txt`, add the NDK library (name as in sysroot):

```cmake
target_link_libraries(entry PUBLIC libace_napi.z.so libhilog_ndk.z.so libhitrace_ndk.z.so)
```

Rule of thumb: header `@library` often says `lib<name>.so`; in the NDK sysroot the file is usually **`lib<name>_ndk.z.so`** (e.g. `libhilog_ndk.z.so`).

---

## 4. Example: using OH_LOG_Print (HiLog)

**Call signature (from log.h):**

```c
int OH_LOG_Print(LogType type, LogLevel level, unsigned int domain, const char *tag, const char *fmt, ...);
```

**Parameters:**

- `type`: e.g. `LOG_APP` (app logs).
- `level`: `LOG_DEBUG`, `LOG_INFO`, `LOG_WARN`, `LOG_ERROR`, `LOG_FATAL`.
- `domain`: unsigned int (e.g. `LOG_DOMAIN`).
- `tag`: string (e.g. `LOG_TAG`).
- `fmt`: printf-style format string.

**Privacy Note (Important):**
By default, **OHOS redacts variable arguments** in logs, showing them as `<private>`.
To make them visible, you must use the `%{public}` prefix in your format specifiers.

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

**Viewing HiLog on device:** `hdc shell hilog -T <TAG> -x` (use your `LOG_TAG` as `<TAG>`). See [hdc-commands.md](./hdc-commands.md#logs-hilog).

---

## 5. Example: using OH_HiTrace

**Header:** `<hitrace/trace.h>`
**Library:** `libhitrace_ndk.z.so`

**Common APIs:**

- `OH_HiTrace_BeginChain(const char *name, int flags)`: Starts a tracing chain.
- `OH_HiTrace_EndChain()`: Ends the current chain.
- `OH_HiTrace_GetId()`: Gets the current chain ID (struct `HiTraceId`).
- `OH_HiTrace_GetChainId(const HiTraceId *id)`: Extracts the 64-bit chain ID from the struct.

**Usage Example:**

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

---

## 6. Example: using OH_AVRecorder

**Header:**
```c
#include <multimedia/player_framework/avrecorder.h>
#include <multimedia/player_framework/avrecorder_base.h>
#include <native_window/external_window.h>
```

**Library:** `libavrecorder.so`, `libnative_window.so`

**Common APIs:**

- `OH_AVRecorder_Create()`: Creates a recorder instance.
- `OH_AVRecorder_Prepare(recorder, &config)`: Prepares the recorder with configuration.
- `OH_AVRecorder_Start(recorder)`: Starts recording.
- `OH_AVRecorder_GetInputSurface(recorder, &window)`: Gets the input surface for video recording.

**Usage Example:**

```c
#include <multimedia/player_framework/avrecorder.h>
#include <multimedia/player_framework/avrecorder_base.h>
#include <native_window/external_window.h>
#include <fcntl.h>

void TestAVRecorder() {
    // 1. Create Recorder
    OH_AVRecorder *recorder = OH_AVRecorder_Create();
    
    // 2. Set Callbacks (optional but recommended)
    OH_AVRecorder_SetStateCallback(recorder, OnStateChange, nullptr);
    OH_AVRecorder_SetErrorCallback(recorder, OnError, nullptr);

    // 3. Configure
    OH_AVRecorder_Config config;
    config.audioSourceType = AVRECORDER_MIC;
    config.videoSourceType = AVRECORDER_SURFACE_YUV;
    
    // ... set profile settings (bitrate, codecs, etc.) ...
    config.profile.audioBitrate = 48000;
    config.profile.audioChannels = 2;
    config.profile.audioCodec = AVRECORDER_AUDIO_AAC;
    config.profile.audioSampleRate = 48000;
    config.profile.audioChannels = 2; // Fixed duplicate in my thought, code is fine
    config.profile.fileFormat = AVRECORDER_CFT_MPEG_4;
    config.profile.videoBitrate = 1000000;
    config.profile.videoCodec = AVRECORDER_VIDEO_AVC;
    config.profile.videoFrameWidth = 640;
    config.profile.videoFrameHeight = 480;
    config.profile.videoFrameRate = 30;

    // File URL: Use "fd://" pattern with a file descriptor
    // Note: path must be writable by the app
    int fd = open("/data/storage/el2/base/hap/entry/files/test.mp4", O_RDWR | O_CREAT | O_TRUNC, 0666);
    char url[256];
    snprintf(url, sizeof(url), "fd://%d", fd);
    config.url = url;
    config.fileGenerationMode = AVRECORDER_APP_CREATE;

    // 4. Prepare
    OH_AVErrCode ret = OH_AVRecorder_Prepare(recorder, &config);
    if (ret == AV_ERR_OK) {
        // 5. Get Input Surface (if video source is surface)
        OHNativeWindow *window = nullptr;
        OH_AVRecorder_GetInputSurface(recorder, &window);
        
        // 6. Start
        OH_AVRecorder_Start(recorder);
        
        // ... record ...
        
        // 7. Stop and Release
        OH_AVRecorder_Stop(recorder);
    }
    
    OH_AVRecorder_Release(recorder);
    if (fd >= 0) close(fd);
}
```

---

## 5. Tips for Specific APIs

### Permission denied: two common causes

When an API returns a permission-denied (or similar) error:

1. **Missing or wrong permission** — You may not have requested the correct permission in the app (e.g. in `module.json5` or the capability/sandbox config). Check the API docs for required permissions and add them.
2. **Wrong device type** — Some APIs are intended only for certain device types (e.g. PC). Calling such an API on a different device (e.g. phone) can still return permission denied even when the correct permission is applied. If permissions look correct, try the same call on the target device type (e.g. PC emulator or device) to confirm.

**Checking device API level / device type:** Use `hdc shell param get const.ohos.apiversion` and `hdc shell param get const.product.devicetype`. See [hdc-commands.md](./hdc-commands.md#device-properties-param).

### BundleManager (OH_NativeBundle)

*   **Permissions**: Some APIs like `OH_NativeBundle_GetAbilityResourceInfo` require system permissions (e.g., `ohos.permission.GET_ABILITY_INFO`). If called from a normal application, they may return error code `201` (`BUNDLE_MANAGER_ERROR_CODE_PERMISSION_DENIED`). That is not considered a successful call.
*   **Opaque Structs**: For APIs returning opaque structs (e.g., `OH_NativeBundle_AbilityResourceInfo`), check if there is a `GetSize` function (e.g., `OH_NativeBundle_GetSize`). This size is needed to iterate over arrays of these structs if the API returns a pointer to the first element but specifies a count.
    *   Example iteration:
        ```c
        int structSize = OH_NativeBundle_GetSize();
        for (size_t i = 0; i < count; i++) {
            OH_NativeBundle_AbilityResourceInfo* item = 
                (OH_NativeBundle_AbilityResourceInfo*)((char*)array + i * structSize);
            // Use item...
        }
        ```
