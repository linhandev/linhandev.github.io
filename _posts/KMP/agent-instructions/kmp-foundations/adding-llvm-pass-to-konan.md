# Agent Guide: Adding an LLVM Pass to Kotlin Native Compiler

This guide explains how to integrate a new LLVM optimization or instrumentation pass into the Kotlin Native compiler, using the GCOV profiling pass as a reference example. This guide primarily applies to Kotlin 2.0 using the legacy pass manager, on 2.2 with the new pass manager there's simpler ways.

## Table of Contents
1. [Overview](#overview)
2. [Implementation Steps](#implementation-steps)
3. [Pipeline Architecture](#pipeline-architecture)
4. [Testing Your Pass](#testing-your-pass)
5. [Advanced Topics](#advanced-topics)

---

## Overview

### What is an LLVM Pass?

An LLVM pass transforms or analyzes LLVM IR. Common types:
- **Optimization passes**: Improve code performance/size
- **Instrumentation passes**: Add runtime profiling/debugging code
- **Analysis passes**: Collect information about code

### Integration Points

To add a pass to Kotlin Native:
1. **C++ Layer**: Expose LLVM pass via C API
2. **Kotlin Layer**: Create pipeline class and phase
3. **Configuration**: Add compiler option (optional)
4. **Linker**: Add required runtime libraries (if needed)

---

## Implementation Steps

### Step 1: Add C API Extension for the Pass

**File**: `kotlin-native/libllvmext/src/main/include/CAPIExtensions.h`

Add declaration:
```cpp
void LLVMAddYourPassName(LLVMPassManagerRef PM);
```

**File**: `kotlin-native/libllvmext/src/main/cpp/CAPIExtensions.cpp`

Add include and implementation:
```cpp
#include <llvm/Transforms/Instrumentation.h>  // Or appropriate header

void LLVMAddYourPassName(LLVMPassManagerRef PM) {
  unwrap(PM)->add(createYourPassLegacyPass());
}
```

**Important Notes**:
- Use the **legacy pass** API (createXxxLegacyPass), not new pass manager
- Find the correct header in LLVM source: `llvm/include/llvm/Transforms/...`
- No need to modify `llvm.def` - CAPIExtensions.h is already in the headers list

**Example** (GCOV pass):
```cpp
#include <llvm/Transforms/Instrumentation.h>

void LLVMAddGCOVProfilingPass(LLVMPassManagerRef PM) {
  unwrap(PM)->add(createGCOVProfilerPass());
}
```

### Step 2: Create Pipeline Class in Kotlin

**File**: `kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/OptimizationPipeline.kt`

Add after existing pipeline classes:

```kotlin
class YourPassPipeline(config: LlvmPipelineConfig, logger: LoggingContext? = null) :
        LlvmOptimizationPipeline(config, logger) {
    
    override fun configurePipeline(
        config: LlvmPipelineConfig, 
        manager: LLVMPassManagerRef, 
        builder: LLVMPassManagerBuilderRef
    ) {
        // Call your C API function
        LLVMAddYourPassName(manager)
    }

    override val pipelineName = "Your pass description"
    
    // Optional: Add preprocessing if needed (like ThreadSanitizer does)
    override fun executeCustomPreprocessing(config: LlvmPipelineConfig, module: LLVMModuleRef) {
        // Example: Set function attributes
        getFunctions(module)
            .filter { LLVMIsDeclaration(it) == 0 }
            .forEach { /* modify function */ }
    }
}
```

**Example** (GCOV):
```kotlin
class GCOVProfilingPipeline(config: LlvmPipelineConfig, logger: LoggingContext? = null) :
        LlvmOptimizationPipeline(config, logger) {
    override fun configurePipeline(config: LlvmPipelineConfig, manager: LLVMPassManagerRef, builder: LLVMPassManagerBuilderRef) {
        LLVMAddGCOVProfilingPass(manager)
    }

    override val pipelineName = "GCOV profiling instrumentation"
}
```

### Step 3: Register the Phase

**File**: `kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/driver/phases/Bitcode.kt`

Add phase definition:
```kotlin
internal val YourPassPhase = optimizationPipelinePass(
        name = "YourPassName",
        description = "Description of what your pass does",
        pipeline = ::YourPassPipeline,
)
```

### Step 4: Add to Execution Pipeline

**Same file** (`Bitcode.kt`), in `runBitcodePostProcessing()` function:

```kotlin
internal fun <T : BitcodePostProcessingContext> PhaseEngine<T>.runBitcodePostProcessing() {
    val optimizationConfig = createLTOFinalPipelineConfig(...)
    
    useContext(OptimizationState(context.config, optimizationConfig)) {
        val module = this@runBitcodePostProcessing.context.llvmModule
        
        // Add your pass execution here
        // IMPORTANT: Order matters!
        
        // Instrumentation passes should run BEFORE optimizations
        if (shouldRunYourPass(context)) {
            it.runPhase(YourPassPhase, module)
        }
        
        // Standard optimization pipeline
        it.runPhase(MandatoryBitcodeLLVMPostprocessingPhase, module)
        it.runPhase(ModuleBitcodeOptimizationPhase, module)
        it.runPhase(LTOBitcodeOptimizationPhase, module)
        
        // Sanitizers run AFTER optimizations
        when (context.config.sanitizer) {
            SanitizerKind.THREAD -> it.runPhase(ThreadSanitizerPhase, module)
            // ...
        }
    }
}
```

**CRITICAL: Pass Execution Order**

1. **Before optimizations**: Instrumentation passes (profiling, coverage, custom instrumentation)
2. **Mandatory passes**: Required transformations
3. **Optimization passes**: Performance improvements
4. **After optimizations**: Sanitizers, final transformations

**Why order matters**:
- Instrumentation before optimization: Prevents optimization from breaking instrumentation
- Sanitizers after optimization: Sanitizer instrumentation shouldn't be optimized away

### Step 5: Add Configuration Option (Optional)

**File**: `kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/BinaryOptions.kt`

Add your option:
```kotlin
object BinaryOptions : BinaryOptionRegistry() {
    // ... existing options ...
    
    val yourOption by booleanOption()
    // or
    val yourOption by option<YourEnum>()
    
    // ...
}
```

**File**: Update `runBitcodePostProcessing()` to use the option:
```kotlin
val yourOptionEnabled = context.config.configuration.get(BinaryOptions.yourOption) ?: false
if (yourOptionEnabled) {
    it.runPhase(YourPassPhase, module)
}
```

**Usage**:
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -Xbinary=yourOption=true
```

### Step 6: Link Runtime Libraries (If Needed)

Some passes require runtime libraries (e.g., GCOV needs libclang_rt.profile.a, sanitizers need libclang_rt.{asan,tsan}.a).

**Important**: Kotlin Native LLVM distribution may not have OHOS-specific compiler-rt libraries. Use **DevEco Studio SDK's LLVM** for OHOS targets.

**File**: `native/utils/src/org/jetbrains/kotlin/konan/target/Linker.kt`

**For OHOS**, add to `OhosLinker`:

```kotlin
override fun provideCompilerRtLibrary(libraryName: String, isDynamic: Boolean): String? {
    // Check DevEco Studio SDK first
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
    val clangdir = File("$absoluteLlvmHome/lib/clang/").listFiles.firstOrNull()?.absolutePath ?: return null
    val libdir = File("$clangdir/lib/").listFiles.firstOrNull()?.absolutePath ?: return null
    val targetSpecificLib = File("$libdir/libclang_rt.$libraryName-aarch64.a")
    return if (targetSpecificLib.exists) targetSpecificLib.absolutePath else "$libdir/libclang_rt.$libraryName.a"
}
```

Add linking logic in `finalLinkCommands()`:
```kotlin
override fun LinkerArguments.finalLinkCommands(): List<Command> {
    // ... existing code ...
    
    return listOf(Command(absoluteLinker).apply {
        // ... existing flags ...
        
        if (yourCondition) {
            val runtimeLib = provideCompilerRtLibrary("your_lib_name")
            if (runtimeLib != null) {
                +runtimeLib
            }
        }
        
        // ... rest of command ...
    })
}
```

---

## Pipeline Architecture

### Pass Manager Structure

Kotlin Native uses LLVM's Legacy Pass Manager:

```
LLVMPassManager
    ├─ Analysis Passes (TargetLibraryInfo, etc.)
    ├─ Your Custom Passes
    └─ Optimization Passes (via PassManagerBuilder)
```

### Pipeline Configuration

`LlvmPipelineConfig` controls:
- Target triple (e.g., `aarch64-linux-ohos`)
- CPU model and features
- Optimization level (NONE, DEFAULT, AGGRESSIVE)
- Code generation settings
- Relocation mode

### Existing Pipelines (Reference Examples)

1. **MandatoryOptimizationPipeline**: Required transformations
   - ObjC ARC contract pass
   - Visibility adjustments

2. **ModuleOptimizationPipeline**: Standard optimizations
   - Function and module passes
   - Similar to `clang -O2`

3. **LTOOptimizationPipeline**: Link-time optimizations
   - Internalization
   - Global DCE
   - LTO passes

4. **ThreadSanitizerPipeline**: Instrumentation example
   - Adds thread sanitizer instrumentation
   - Sets function attributes
   - Good reference for instrumentation passes

5. **GCOVProfilingPipeline**: Code coverage instrumentation
   - Adds coverage counters
   - Requires debug metadata
   - Links profile runtime library

---

## Testing Your Pass

### Verify Pass is Running

**Method 1: Check bitcode output**
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -g \
  -Xtemporary-files-dir=/tmp/test_temp

# Disassemble and inspect
llvm-dis /tmp/test_temp/out.bc -o /tmp/test_temp/out.ll

# Search for your pass's artifacts
grep -i "your_pass_symbol" /tmp/test_temp/out.ll
```

**Method 2: Enable timing**
```bash
kotlinc-native test.kt -target ohos_arm64 -o test -g \
  -Xtime-phases
```

This shows time spent in each compilation phase.

**Method 3: Add logging**
```kotlin
class YourPassPipeline(config: LlvmPipelineConfig, logger: LoggingContext? = null) :
        LlvmOptimizationPipeline(config, logger) {
    
    override fun configurePipeline(...) {
        logger?.log { "Running Your Pass on module" }
        LLVMAddYourPassName(manager)
    }
    
    override val pipelineName = "Your pass"
}
```

### Verify Pass Output

**Check for expected transformations**:
```bash
# Count specific IR instructions
grep -c "@your_global_var" out.ll

# Find function calls added by your pass
grep "call.*your_runtime_function" out.ll

# Verify function attributes
grep "attributes.*your_attribute" out.ll
```

### Test on Device

1. Compile with your pass enabled
2. Deploy to OHOS device
3. Run and verify behavior
4. Check runtime artifacts (e.g., .gcda files for coverage)

---

## Advanced Topics

### Pass Dependencies

If your pass requires analysis results:

```cpp
void LLVMAddYourPass(LLVMPassManagerRef PM) {
  // Add required analysis passes first
  unwrap(PM)->add(createTargetTransformInfoWrapperPass(...));
  
  // Then add your pass
  unwrap(PM)->add(createYourPass());
}
```

### Debug Metadata Requirements

Some passes require debug information:

```kotlin
// In GCOVProfilingPipeline, GCOV needs llvm.dbg.cu metadata
// The pass checks: if (!CUNode) return false;

// Ensure compilation includes debug info:
kotlinc-native test.kt -target ohos_arm64 -o test -g
```

### Function Attributes

Set attributes on functions before/during pass execution:

```kotlin
override fun executeCustomPreprocessing(config: LlvmPipelineConfig, module: LLVMModuleRef) {
    getFunctions(module)
        .filter { LLVMIsDeclaration(it) == 0 }  // Only non-declarations
        .forEach { function ->
            addLlvmFunctionEnumAttribute(function, LlvmFunctionAttribute.YourAttribute)
        }
}
```

### Conditional Execution

Make your pass optional via configuration:

```kotlin
// In BinaryOptions.kt
val yourFeature by booleanOption()

// In Bitcode.kt runBitcodePostProcessing()
val featureEnabled = context.config.configuration.get(BinaryOptions.yourFeature) ?: false
if (featureEnabled) {
    it.runPhase(YourPassPhase, module)
}
```

---

## Complete Example: GCOV Profiling Pass

### 1. C API Extension (CAPIExtensions.cpp)

```cpp
#include <llvm/Transforms/Instrumentation.h>

void LLVMAddGCOVProfilingPass(LLVMPassManagerRef PM) {
  unwrap(PM)->add(createGCOVProfilerPass());
}
```

### 2. Pipeline Class (OptimizationPipeline.kt)

```kotlin
class GCOVProfilingPipeline(config: LlvmPipelineConfig, logger: LoggingContext? = null) :
        LlvmOptimizationPipeline(config, logger) {
    override fun configurePipeline(
        config: LlvmPipelineConfig, 
        manager: LLVMPassManagerRef, 
        builder: LLVMPassManagerBuilderRef
    ) {
        LLVMAddGCOVProfilingPass(manager)
    }

    override val pipelineName = "GCOV profiling instrumentation"
}
```

### 3. Phase Registration (Bitcode.kt)

```kotlin
internal val GCOVProfilingPhase = optimizationPipelinePass(
        name = "GCOVProfiling",
        description = "Insert GCOV profiling instrumentation",
        pipeline = ::GCOVProfilingPipeline,
)
```

### 4. Conditional Execution (Bitcode.kt)

```kotlin
internal fun <T : BitcodePostProcessingContext> PhaseEngine<T>.runBitcodePostProcessing() {
    // ...
    useContext(OptimizationState(context.config, optimizationConfig)) {
        val module = this@runBitcodePostProcessing.context.llvmModule
        
        // GCOV runs BEFORE optimizations
        val coverageEnabled = context.config.configuration.get(BinaryOptions.coverage) ?: false
        if (coverageEnabled) {
            it.runPhase(GCOVProfilingPhase, module)
        }
        
        it.runPhase(MandatoryBitcodeLLVMPostprocessingPhase, module)
        // ... rest of pipeline
    }
}
```

### 5. Configuration Option (BinaryOptions.kt)

```kotlin
object BinaryOptions : BinaryOptionRegistry() {
    // ... existing options ...
    val coverage by booleanOption()
}
```

### 6. Link Runtime Library (Linker.kt - OhosLinker)

```kotlin
// Add provideCompilerRtLibrary if not exists
override fun provideCompilerRtLibrary(libraryName: String, isDynamic: Boolean): String? {
    // Use DevEco Studio SDK for OHOS libraries
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
    return null
}

// In finalLinkCommands()
if (codeCoverage) {
    val profileLib = provideCompilerRtLibrary("profile")
    if (profileLib != null) {
        +profileLib
        +"-lhilog_ndk.z"  // OHOS system libs
        +"-lunwind"
    }
}
```

### 7. Pass Configuration Parameter (LinkerArguments)

```kotlin
class LinkerArguments(
    // ... existing parameters ...
    val codeCoverage: Boolean = false,
)

// When creating LinkerArguments (in Linker.kt):
LinkerArguments(
    // ... existing args ...
    codeCoverage = config.configuration.get(BinaryOptions.coverage) ?: false,
)
```

---

## Advanced Techniques

### Weak Symbol Detection

Use weak symbols to make runtime code conditional on instrumentation presence:

```cpp
// In runtime C++ code
extern "C" void __llvm_gcov_init(void*, void*) __attribute__((weak));

__attribute__((constructor(101)))
static void MaybeInitialize() {
    if (__llvm_gcov_init == nullptr) {
        return;  // Instrumentation not present, skip
    }
    // Initialize resources needed by instrumentation
}
```

**Benefits**:
- No overhead when instrumentation disabled
- Single runtime binary works for both cases
- Automatic detection

### Conditional Linker Arguments

Add linker arguments only when feature is enabled:

```kotlin
// In LinkerArguments data class
class LinkerArguments(
    // ... existing ...
    val yourFeature: Boolean = false,
)

// In OhosLinker.finalLinkCommands()
if (yourFeature) {
    val lib = provideCompilerRtLibrary("your_runtime")
    if (lib != null) +lib
}

// When creating LinkerArguments
LinkerArguments(
    // ... existing ...
    yourFeature = config.configuration.get(BinaryOptions.yourFeature) ?: false,
)
```

---

## Build and Test

### After Implementation

```bash
# 1. Build compiler
cd /Users/hl/git/kmp/KuiklyBase-kotlin
./gradlew :kotlin-native:dist

# 2. Test compilation
kotlin-native/dist/bin/kotlinc-native test.kt \
  -target ohos_arm64 \
  -o test \
  -g \
  -Xbinary=yourOption=true \
  -Xtemporary-files-dir=/tmp/test_temp

# 3. Verify pass ran
llvm-dis /tmp/test_temp/out.bc -o - | grep -c "your_pattern"

# 4. Test on device (if applicable)
```

### Verify Instrumentation Symbols

```bash
# For executables
llvm-nm test.kexe | grep your_symbol

# For shared libraries
llvm-nm libtest.so | grep your_symbol | wc -l

# Check specific symbols
llvm-nm test.kexe | grep -E "init|writeout|flush"
```

---

## Common Patterns

### Instrumentation Pass Pattern
```kotlin
// Runs before optimizations
// Adds code to track runtime behavior
// Examples: GCOV, sanitizers, profilers

class InstrumentationPipeline(...) : LlvmOptimizationPipeline(...) {
    override fun configurePipeline(...) {
        LLVMAddInstrumentationPass(manager)
    }
    
    // Often needs function attributes
    override fun executeCustomPreprocessing(...) {
        getFunctions(module)
            .filter { !isDeclaration(it) }
            .forEach { addAttribute(it) }
    }
}
```

### Optimization Pass Pattern
```kotlin
// Runs during optimization pipeline
// Improves code quality/size/speed
// Examples: inlining, DCE, constant folding

class OptimizationPipeline(...) : LlvmOptimizationPipeline(...) {
    override fun configurePipeline(...) {
        LLVMAddOptimizationPass(manager)
    }
    
    // Usually no preprocessing needed
}
```

### Analysis Pass Pattern
```kotlin
// Collects information, doesn't transform
// Used by other passes
// Examples: alias analysis, dependency analysis

class AnalysisPipeline(...) : LlvmOptimizationPipeline(...) {
    override fun configurePipeline(...) {
        LLVMAddAnalysisPass(manager)
    }
}
```

---

## Troubleshooting

### Pass Not Running

**Check**:
1. Is the phase registered in Bitcode.kt?
2. Is `it.runPhase(YourPhase, module)` called?
3. Is the condition check correct?
4. Are there build errors?

**Debug**:
```kotlin
override fun configurePipeline(...) {
    println("DEBUG: Running YourPass")  // Will show in compiler output
    LLVMAddYourPass(manager)
}
```

### Pass Runs But No Effect

**Possible causes**:
1. Pass is running too late (after optimizations removed your targets)
2. Pass requires metadata/attributes that aren't present
3. Pass has internal conditions not met (e.g., GCOV needs debug info)

**Debug**:
- Check LLVM pass source code for requirements
- Add logging before/after pass execution
- Compare IR before and after: `LLVMDumpModule(module)`

### Linking Errors

**Missing runtime library**:
```
ld.lld: error: undefined symbol: __your_runtime_function
```

**Solution**: Add the required compiler-rt library or system library to linker flags.

**Library not found**:
```
ld.lld: error: cannot open libclang_rt.your_lib.a
```

**Solution**: 
- Check library exists in LLVM distribution
- Use DevEco Studio SDK for OHOS-specific libraries
- Build library from compiler-rt source if needed

---

## Reference: ThreadSanitizer Implementation

ThreadSanitizer is a good reference for instrumentation passes:

**CAPIExtensions.cpp**:
```cpp
#include <llvm/Transforms/Instrumentation/ThreadSanitizer.h>

void LLVMAddThreadSanitizerPass(LLVMPassManagerRef PM) {
  unwrap(PM)->add(createThreadSanitizerLegacyPassPass());
}
```

**OptimizationPipeline.kt**:
```kotlin
class ThreadSanitizerPipeline(config: LlvmPipelineConfig, logger: LoggingContext? = null) :
        LlvmOptimizationPipeline(config, logger) {
    override fun configurePipeline(...) {
        LLVMAddThreadSanitizerPass(manager)
    }

    override fun executeCustomPreprocessing(config: LlvmPipelineConfig, module: LLVMModuleRef) {
        // Set sanitize_thread attribute on all functions
        getFunctions(module)
                .filter { LLVMIsDeclaration(it) == 0 }
                .forEach { addLlvmFunctionEnumAttribute(it, LlvmFunctionAttribute.SanitizeThread) }
    }

    override val pipelineName = "Thread sanitizer instrumentation"
}
```

**Bitcode.kt**:
```kotlin
when (context.config.sanitizer) {
    SanitizerKind.THREAD -> it.runPhase(ThreadSanitizerPhase, module)
    // ...
}
```

---

## Checklist for Adding a Pass

- [ ] C++ function added to CAPIExtensions.h/cpp
- [ ] Pipeline class created in OptimizationPipeline.kt
- [ ] Phase registered in Bitcode.kt
- [ ] Phase execution added to runBitcodePostProcessing()
- [ ] Configuration option added (if needed)
- [ ] Runtime libraries linked (if needed)
- [ ] LinkerArguments updated with new parameters (if needed)
- [ ] Tested: pass runs and transforms IR
- [ ] Tested: compiled code works on target device
- [ ] Tested: backward compatibility (default behavior unchanged)

---

## Summary

**Minimal Steps** (no configuration, always-on pass):
1. Add C API in CAPIExtensions.h/cpp
2. Create pipeline class in OptimizationPipeline.kt
3. Register phase in Bitcode.kt
4. Add to runBitcodePostProcessing()
5. Build and test

**Full Implementation** (with configuration and libraries):
1-4. Same as above
5. Add option to BinaryOptions.kt
6. Update condition in runBitcodePostProcessing()
7. Add library linking in Linker.kt
8. Update LinkerArguments and call sites
9. Build and test

**Remember**:
- Order matters: instrumentation before optimization
- Use legacy pass API, not new pass manager
- CAPIExtensions.h is auto-included, no llvm.def needed
- Test on device to verify runtime behavior
- Use -Xtemporary-files-dir to inspect intermediate IR
