# LLVM Compiler-RT Libraries for OHOS

## Overview

compiler-rt provides runtime support libraries for sanitizers, profiling, and other instrumentation. OHOS: dynamic from DevEco SDK sysroot; static prefer Kotlin Native LLVM.


## Library Locations

### DevEco Studio SDK (Use This for OHOS)

**Base Path**:
```
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/
```

**Library Path**:
```
lib/clang/15.0.4/lib/aarch64-linux-ohos/
```

**Available Libraries**:
- `libclang_rt.profile.a` - GCOV/coverage profiling
- `libclang_rt.asan.a` - Address Sanitizer (if supported)
- `libclang_rt.tsan.a` - Thread Sanitizer (if supported)

### Kotlin Native LLVM

**Path**:

Kotlin 2.0: ~/.konan/dependencies/llvm-1201-macos-aarch64/lib/clang/12.0.1/lib/
Kotlin 2.2: ~/.konan/dependencies/llvm-19.1.7-aarch64-macos-ohos-2/lib/clang/19/lib/

**Note**: The oh llvm 12 only has Darwin (macOS/iOS) libraries, **NOT OHOS**.


## Finding Libraries at Runtime

### Pattern for OhosLinker

```kotlin
override fun provideCompilerRtLibrary(libraryName: String, isDynamic: Boolean): String? {
    require(!isDynamic) { "Dynamic compiler rt libraries are unsupported" }
    
    // Try DevEco Studio SDK first (has OHOS libraries)
    val devecoSdkBase = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm"
    if (File(devecoSdkBase).exists) {
        val clangDir = File("$devecoSdkBase/lib/clang/").listFiles.firstOrNull()?.absolutePath
        if (clangDir != null) {
            val ohosLib = File("$clangDir/lib/aarch64-linux-ohos/libclang_rt.$libraryName.a")
            if (ohosLib.exists) {
                return ohosLib.absolutePath
            }
        }
    }
    
    // Fallback to Kotlin Native LLVM (won't have OHOS libs)
    val clangdir = File("$absoluteLlvmHome/lib/clang/").listFiles.firstOrNull()?.absolutePath ?: return null
    val libdir = File("$clangdir/lib/").listFiles.firstOrNull()?.absolutePath ?: return null
    val targetSpecificLib = File("$libdir/libclang_rt.$libraryName-aarch64.a")
    return if (targetSpecificLib.exists) targetSpecificLib.absolutePath else "$libdir/libclang_rt.$libraryName.a"
}
```


## Required OHOS System Libraries

When linking instrumented code for OHOS, additional system libraries are required:

### For Debug Builds (`-g`)

```kotlin
if (debug) {
    +"-lhilog_ndk.z"  // OHOS logging (OH_LOG_Print, etc.)
    +"-lunwind"       // Stack unwinding (_Unwind_Backtrace, etc.)
}
```

### For Coverage/Profiling

```kotlin
if (codeCoverage) {
    val profileLib = provideCompilerRtLibrary("profile")
    if (profileLib != null) {
        +profileLib
        // May also need hilog and unwind depending on runtime code
    }
}
```


## Common Errors and Solutions

### Error: Library not found

```
ld.lld: error: cannot open libclang_rt.profile.a: No such file or directory
```

**Cause**: Looking in wrong LLVM distribution

**Solution**: Ensure `provideCompilerRtLibrary` falls back to DevEco Studio SDK for OHOS targets

### Error: Undefined symbols

```
ld.lld: error: undefined symbol: OH_LOG_Print
ld.lld: error: undefined symbol: _Unwind_Backtrace
```

**Cause**: Missing OHOS system libraries

**Solution**: Add to linker flags:
```kotlin
+"-lhilog_ndk.z"
+"-lunwind"
```

Alternatively, add to `konan.properties`, this doesn't require a rebuild thus is a lot faster:
```properties
linkerKonanFlags.ohos_arm64 = ... -lhilog_ndk.z -lunwind
```


## Verification

### Check Library Path

```bash
# Verify library exists
ls /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos/libclang_rt.profile.a
```

### Check Linker Command

When compiling with coverage, verify linker command includes:
```
/Applications/DevEco-Studio.app/.../libclang_rt.profile.a
-lhilog_ndk.z
-lunwind
```

### Check Final Binary

```bash
# Verify symbols are present
llvm-nm test.kexe | grep __llvm_profile
# or for GCOV:
llvm-nm test.kexe | grep __llvm_gcov
```


## Summary

| Library Type | OHOS Source | Kotlin Native LLVM |
|--------------|-------------|-------------------|
| profile (GCOV) | ✅ DevEco Studio SDK | ❌ Not available |
| asan | ✅ DevEco Studio SDK | ❌ Not available |
| tsan | ✅ DevEco Studio SDK | ❌ Not available |
| darwin libs | ❌ Not applicable | ✅ Available |

**Key Point**: Always fallback to **DevEco Studio SDK first** for OHOS compiler-rt libraries.
