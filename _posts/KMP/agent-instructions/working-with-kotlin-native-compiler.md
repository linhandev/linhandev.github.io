# Agent Guide: Building and Testing Kotlin Native Compiler for OHOS

This guide covers the complete workflow for building the Kotlin Native compiler and testing it with OHOS targets.

## Table of Contents
1. [Build Prerequisites](#build-prerequisites)
2. [Build Process](#build-process)
3. [Testing Compiled Code](#testing-compiled-code)
4. [Common Issues and Solutions](#common-issues-and-solutions)
5. [Development Workflow](#development-workflow)

---

## Build Prerequisites

### Required Tools
- **JDK**: Java 17+ (Temurin JDK recommended)
- **Gradle**: included via wrapper
- **OHOS SDK**: DevEco Studio with OHOS SDK installed
- **Kotlin Native Source**: Cloned repository

### Environment Setup

**OHOS SDK Location** (macOS):
```
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/
```

**Key Directories**:
- Native toolchain: `native/llvm/`
- Sysroot: `native/sysroot/`
- Compiler-rt libraries: `native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos/`

---

## Build Process

### Full Build Command

```bash
cd /Users/hl/git/kmp/KuiklyBase-kotlin

# Stop any running Gradle daemon
./gradlew --stop

# Full build: compiler + platform libraries
./gradlew :kotlin-native:dist :kotlin-native:platformLibs:ohos_arm64Install
```

### Build Output Locations

After successful build:
- **Compiler binaries**: `kotlin-native/dist/bin/`
  - `kotlinc-native` - Main compiler
  - `cinterop` - C interop tool
  - `klib` - Library tool
  
- **Platform libraries**: `kotlin-native/dist/konan/targets/ohos_arm64/`
  - `native/` - Platform-specific native libraries
  - `kotlin/` - Kotlin standard library for OHOS

### Incremental Build (After Code Changes)

```bash
# If you modified Kotlin code in backend:
./gradlew :kotlin-native:dist

# If platform libs are missing:
./gradlew :kotlin-native:platformLibs:ohos_arm64Install
```

### Clean Build (When Needed)

**WARNING**: Clean build is expensive (7+ minutes). Only use when necessary:

```bash
./gradlew --stop
./gradlew clean
./gradlew :kotlin-native:dist :kotlin-native:platformLibs:ohos_arm64Install --rerun-tasks
```

**When to use clean build**:
- After reverting commits that changed build configuration
- After gradle.properties changes affecting runtime
- After modifying build scripts
- When incremental build produces errors
- After changing llvm JNI related code and incremental build produces error

**When NOT to use clean**:
- After simple code changes in Kotlin/C++ files
- For routine development

---

## Testing Compiled Code

### Basic Compilation Test

```bash
# Create test file
cat > test.kt << 'EOF'
fun main(args: Array<String>) {
    println("Hello from Kotlin Native on OHOS!")
    if (args.isNotEmpty()) {
        println("Args: ${args.joinToString()}")
    }
}
EOF

# Compile for OHOS arm64
kotlin-native/dist/bin/kotlinc-native test.kt \
  -target ohos_arm64 \
  -o test \
  -g
```

### Compilation Output

**Success produces**:
- `test.kexe` - Executable (ELF 64-bit LSB for aarch64-linux-ohos)

**File verification**:
```bash
file test.kexe
# Output: test.kexe: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), 
#         dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, with debug_info
```

### Testing with Temporary Directory

Preserve intermediate files for debugging:

```bash
mkdir -p /tmp/kn_test_temp

kotlinc-native test.kt \
  -target ohos_arm64 \
  -o test \
  -g \
  -Xtemporary-files-dir=/tmp/kn_test_temp

# Inspect intermediate files
ls /tmp/kn_test_temp/
# Files: out.bc, test.kexe.o, etc.
```

### Inspecting LLVM IR

```bash
# Disassemble bitcode to readable LLVM IR
llvm-dis /tmp/kn_test_temp/out.bc -o /tmp/kn_test_temp/out.ll

# Search for specific symbols
grep -n "define.*main" /tmp/kn_test_temp/out.ll

# Count functions
grep -c "^define " /tmp/kn_test_temp/out.ll
```

---

## Common Issues and Solutions

### Issue 1: Platform Libraries Missing

**Error**:
```
error: compilation failed: Error parsing file kotlin-native/dist/konan/targets/ohos_arm64/native/compiler_interface.bc
```

**Solution**:
```bash
./gradlew :kotlin-native:platformLibs:ohos_arm64Install
```

### Issue 2: Gradle Daemon Issues

**Symptoms**:
- "Daemon has been stopped" errors
- Inconsistent build results
- Cached configuration issues

**Solution**:
```bash
./gradlew --stop
# Wait 2-3 seconds
./gradlew :kotlin-native:dist
```

### Issue 3: Linking Errors (undefined symbols)

**Error**:
```
ld.lld: error: undefined symbol: OH_LOG_Print
ld.lld: error: undefined symbol: _Unwind_Backtrace
```

**Cause**: Missing OHOS system libraries for debug builds

**Solution**: Add to kotlin-native/konan/konan.properties linkerKonanFlags.ohos_arm64
```
-lhilog_ndk.z -lunwind
```

### Issue 4: Compiler-rt Library Not Found

**Error**:
```
ld.lld: error: cannot open libclang_rt.profile.a: No such file or directory
```

**Solution**: Use DevEco Studio SDK's LLVM for OHOS-specific libraries:
```kotlin
override fun provideCompilerRtLibrary(libraryName: String, isDynamic: Boolean): String? {
    val devecoSdkBase = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm"
    if (File(devecoSdkBase).exists) {
        val devecoClangDir = File("$devecoSdkBase/lib/clang/").listFiles.firstOrNull()?.absolutePath
        if (devecoClangDir != null) {
            val ohosLib = File("$devecoClangDir/lib/aarch64-linux-ohos/libclang_rt.$libraryName.a")
            if (ohosLib.exists) {
                return ohosLib.absolutePath
            }
        }
    }
    // Fallback to Kotlin Native LLVM
    // ...
}
```

### Issue 5: Debug Info Conflicts

**Error**:
```
DICompileUnit not listed in llvm.dbg.cu
fatal error: error in backend: Broken module found
```

**Cause**: Runtime libraries with debug info may introduce issue

**Solution**: Disable runtime debug info in `gradle.properties`:
```properties
# Comment out or set to false
#kotlin.native.isNativeRuntimeDebugInfoEnabled=true
```
After this change gradle stop clean and rebuilt with --rerun-tasks

### Issue 6: Warnings Treated as Errors

**Error**:
```
e: warnings found and -Werror specified
```

**Solution**: Fix the warnings or temporarily disable -Werror. Common warnings:
- Unnecessary safe calls: `?.` on non-nullable types
- Use `.exists` not `.exists()` for `kotlin.io.File` (property, not function)
- Use `.listFiles` not `.listFiles()` for `kotlin.io.File` (property, not function)
- Note: `java.io.File` uses `.exists()` and `.listFiles()` (methods with parentheses)

**Kotlin File API Gotchas**:
```kotlin
// WRONG (for kotlin.io.File):
val exists = File("path").exists()  // Error: expression of type Boolean cannot be invoked
val files = File("path").listFiles()  // Error: expression of type List<File> cannot be invoked

// CORRECT (for kotlin.io.File):
val exists = File("path").exists  // Property access
val files = File("path").listFiles  // Property access

// For java.io.File (used in some parts):
import java.io.File as JFile
val exists = JFile("path").exists()  // Method call
val files = JFile("path").listFiles()  // Method call
```

---

## Kotlin Native Configuration System

### Binary Options Pattern

Kotlin Native uses `-Xbinary=name=value` for runtime configuration (similar to sanitizer):

**Add new binary option**:

1. In `BinaryOptions.kt`:
```kotlin
object BinaryOptions : BinaryOptionRegistry() {
    val yourFeature by booleanOption()  // For true/false
    // or
    val yourOption by option<YourEnum>()  // For enum values
}
```

2. Access in code:
```kotlin
val enabled = config.configuration.get(BinaryOptions.yourFeature) ?: false
```

3. Usage:
```bash
kotlinc-native test.kt -Xbinary=yourFeature=true
```

### Finding Configuration Parsing

**Locate where arguments are parsed**:
1. Argument definition: `compiler/cli/cli-common/.../K2NativeCompilerArguments.kt`
2. Parsing logic: `kotlin-native/backend.native/.../SetupConfiguration.kt`
3. Configuration keys: `kotlin-native/backend.native/.../KonanConfigurationKeys.kt`

**Pattern to find parsing**:
```bash
# Find where an argument is used
grep -r "arguments\.yourArgName" kotlin-native/backend.native/
```

---

## Development Workflow

### Typical Development Cycle

1. **Make code changes** (Kotlin/C++/headers)

2. **Incremental build**:
```bash
./gradlew :kotlin-native:dist
```

3. **Test compilation**:
```bash
kotlin-native/dist/bin/kotlinc-native test.kt -target ohos_arm64 -o test -g
```

4. **Deploy to device** (see AGENT_INSTRUCTIONS.md for hdc commands)

5. **Iterate**:
   - If compilation fails → check error, fix code, rebuild
   - If linking fails → check library dependencies
   - If runtime fails → check device logs

### Gradle Task Reference

| Task                                            | Purpose                   | Duration         |
| ----------------------------------------------- | ------------------------- | ---------------- |
| `:kotlin-native:dist`                           | Build compiler            | ~30s incremental |
| `:kotlin-native:platformLibs:ohos_arm64Install` | Build OHOS platform libs  | ~1 min           |
| `:native:kotlin-native-utils:build`             | Build linker utils        | ~15s             |
| `:kotlin-native:libllvmext:build`               | Build LLVM C++ extensions | ~10s             |
| `clean`                                         | Clean all build artifacts | ~5s              |
| Full build from scratch                         | All of the above          | ~7-10 min        |

### Build Optimization Tips

1. **Use incremental builds** - Don't clean unless necessary
2. **Stop daemon between major changes** - `./gradlew --stop`
3. **Build only what changed**:
   - Changed C++ → `:kotlin-native:libllvmext:build :kotlin-native:dist`
   - Changed Kotlin backend → `:kotlin-native:dist`
   - Changed linker → `:native:kotlin-native-utils:build :kotlin-native:dist`
4. **Use `--rerun-tasks`** only when gradle cache is suspected to be wrong

### Debugging Compilation

**Enable verbose output**:
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -g -verbose
```

**Print LLVM IR**:
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -Xprint-ir
```

**Print bitcode**:
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -Xprint-bitcode
```

**Disable optimization phases** (for faster iteration):
```bash
kotlinc-native test.kt -target ohos_arm64 -o test \
  -Xdisable-phases=LTOBitcodeOptimization,ModuleBitcodeOptimization
```

---

## Architecture Overview

### Compilation Pipeline

```
Kotlin Source (.kt)
    ↓
Kotlin IR (frontend)
    ↓
LLVM IR Generation (backend)
    ↓
LLVM Bitcode (.bc)
    ↓
LLVM Optimization Passes
    ↓
Bitcode Linking (with runtime/stdlib)
    ↓
Object File (.o) via clang
    ↓
Executable (.kexe) via ld.lld
```

### Key Components

- **Frontend**: Kotlin IR generation
- **Backend**: `kotlin-native/backend.native/`
  - IR to LLVM IR translation
  - Optimization pipeline
  - Bitcode generation
- **Linker**: `native/utils/src/.../Linker.kt`
  - Links object files
  - Platform-specific flags
  - Library dependencies
- **LLVM Extensions**: `kotlin-native/libllvmext/`
  - C++ code for LLVM pass integration
  - Exposed to Kotlin via cinterop

---

## Testing Checklist

After implementing a change, verify:

- [ ] Compiler builds successfully
- [ ] Simple Kotlin file compiles for OHOS target
- [ ] Generated executable has correct architecture (aarch64)
- [ ] Executable runs on OHOS device (if device available)
- [ ] No new linker errors introduced
- [ ] Backward compatibility maintained (old code still compiles)
- [ ] File sizes are reasonable (check for bloat)

---

## Advanced: Cross-Target Testing

### Test on macOS (Fast Local Testing)

```bash
kotlinc-native test.kt -target macos_arm64 -o test -g
./test.kexe
```

### Then Test on OHOS (Device Required)

```bash
kotlinc-native test.kt -target ohos_arm64 -o test -g
# Deploy and run (see AGENT_INSTRUCTIONS.md)
```

This two-stage approach catches issues early without needing device access.

---

## Summary

**Build Commands**:
```bash
# Incremental build (most common)
./gradlew :kotlin-native:dist

# Full build (when needed)
./gradlew --stop
./gradlew :kotlin-native:dist :kotlin-native:platformLibs:ohos_arm64Install

# Clean build (rarely needed)
./gradlew --stop
./gradlew clean
./gradlew :kotlin-native:dist :kotlin-native:platformLibs:ohos_arm64Install --rerun-tasks
```

**Test Compilation**:
```bash
kotlin-native/dist/bin/kotlinc-native test.kt -target ohos_arm64 -o test -g
```

**Remember**:
- Use incremental builds for speed
- Only clean when absolutely necessary
- Check dist/bin/ for compiled binaries
- Use -Xtemporary-files-dir to preserve intermediate files
- OHOS requires hilog_ndk and unwind for debug builds
