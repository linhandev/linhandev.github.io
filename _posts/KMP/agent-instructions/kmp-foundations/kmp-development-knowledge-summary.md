# KMP/OHOS Development Knowledge Summary

Summary of KMP/OHOS knowledge from blog analysis.

## Build Speed Optimization

### Gradle Task Optimization
- Use `./gradlew --profile` or `--scan` to analyze task execution times
- Focus on minimizing triggered gradle tasks when modifying code
- For incremental builds, aim to trigger as few gradle tasks as possible
- Top-level project compileKotlin tasks often can't be incremental and should be minimized

### Incremental Compilation
- Incremental compilation affects link tasks, not compileKotlin tasks
- Two types of static caching:
  - Per-klib cache: Dependencies packaged as .a files (entire klib)
  - Per-file cache: Source files packaged individually as .a files
- To enable per-klib cache: Add `ohos` to `konan.properties` file in cacheableTargets
- To enable per-file cache: Add `kotlin.incremental.native=true` to gradle.properties
- Common issues:
  - Linker command fails with "command too long" - resolved by using @command.txt format
  - Duplicate symbol errors - known upstream issue KT-81760
  - Cache files with 'pl' suffix relate to partial linkage feature

## Development Environment Setup

### Repository Locations
- Kotlin 2.0: https://github.com/Tencent-TDS/KuiklyBase-kotlin
- Kotlin 2.0 + patches: https://github.com/linhandev/KuiklyBase-kotlin/tree/kuikly-base/2.0.20-patch
- Kotlin 2.2: https://gitcode.com/CPF-KMP-CMP/kotlin/tree/develop-2.2.21-OH
- Kotlin master: https://github.com/jetbrains/kotlin

### Dependencies Installation
- Java: `brew install --cask temurin@21 zulu@8`
- Xcode: Download from https://xcodereleases.com
  - Xcode 15.0: `/Applications/Xcode-15.0.app` (for Tencent version)
  - Xcode 16.0: `/Applications/Xcode-16.4.app` (for Tencent version and normal 2.0 version)
  - Xcode 26.2: `/Applications/Xcode-26.2.app` (for 2.2 version)
  - Set via: `sudo xcode-select -s /Applications/Xcode-16.4.app/Contents/Developer/`

## Compiler Options

### Konan Compiler Options
- `-Xtemporary-files-dir`: Specifies directory for temporary compilation files (like out.bc), thus the file wont be auto deleted after compilation finishes. Useful for debugging compilation process
- `-Xdebug-prefix-map`: Maps debug source paths (e.g., `-Xdebug-prefix-map=/real/path/=/virtual/path/`)
- `-Xklib-relative-path-base`: Makes klib debug paths relative to a base directory

## Development Tricks

### Gradle/IDEA Related
- Configure concurrent dependency downloads in IDEA for faster sync
- For targeted debugging, build only specific components: `./gradlew :kotlin-native:dist`
- To repeatedly execute gradle tasks: `tasks.findByName("linkDebugSharedOhosArm64")?.outputs?.upToDateWhen { false }`

### Debugging Approaches
- **Gradle task debugging**: Use IDEA to debug gradle tasks by configuring gradle project and run command
- **Gradle command debugging**: Use `-Dorg.gradle.debug=true` and attach remote debugger
- **Direct command debugging**: Modify java commands to include debug options like `-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005`
- **Runtime debugging**: Enable runtime debug info with custom patches and compiler flags

### KN Tools
- **klib**: Utility for inspecting klib files
  - `klib info <path>`: Shows module information
  - `klib dump-ir <path>`: Dumps IR information

## Build Process

### Major Phases
- **Frontend**: PSI to IR conversion, special backend checks
- **Backend**: Lowering, code generation, linking
- **Linking**: Combining bitcode dependencies, generating final output

## Address Sanitizers

### Types and Characteristics
| Type | Full Name | Features | Overhead |
|------|-----------|----------|----------|
| ASAN | Address Sanitizer | Shadow memory, red zones | CPU 200%, Memory 200% |
| HWASAN | Hardware-Assisted ASAN | Pointer tagging, shadow memory | CPU 200%, Memory 10-35% |
| MemDebug | Memory Debug | No instrumentation dependency | Low |
| GWP-ASAN | Google-Wide Profiling ASAN | Page fence approach | CPU/Memory <5% |

### Principles
- **ASAN**: Uses shadow memory where 1 shadow byte represents 8 application bytes; poison regions around allocated memory
- **HWASAN**: Uses ARM's Top Byte Ignore feature to tag pointers and verify access consistency
- **GWP-ASAN**: Uses page fence technique with random sampling for protection

### KN Integration
- KN connects to LLVM sanitizer capabilities in two steps: 1) Run relevant passes to process IR, 2) Link runtime libraries
- DevEco enables ASAN via cmake option `-DOHOS_ENABLE_ASAN=ON`
- Relevant clang++ options: `-shared-libasan`, `-fsanitize=address`, `-fno-omit-frame-pointer`

## LLVM Building

### Two-Stage Process
- Stage 1: Build LLVM tools using host compiler
- Stage 2: Build LLVM distribution using stage 1 tools
- Script location: `kotlin-native/tools/llvm_builder`

### Master-LLVM12-Backup Branch
- Branch: https://gitcode.com/openharmony/third_party_llvm-project/tree/master-llvm12-backup
- Compatible with KN 2.0 build scripts
- Modifications may be needed for multi-Xcode environments

### Build Commands
```bash
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
python3 package.py \
  --distribution-components $DISTRIBUTION_COMPONENTS \
  --llvm-sources $LLVM_FOLDER \
  --save-temporary-files
```

## Debugging Techniques

### Debug Information Path Mapping
- DWARF debug info contains absolute paths from build machine
- Use `-Xdebug-prefix-map` to remap paths for debugging
- Use `-Xklib-relative-path-base` for klib path management
- Effective approach: Use relative paths when building klib, then remap daemon paths when building final so

## Code Coverage

### Implementation Options
- Kotlin IR instrumentation (complex but unified across backends)
- LLVM gcov instrumentation (simpler, uses established native tools)

### KN Integration with gcov
- Add compiler args: `-Xadd-light-debug=enable` and `-Xbinary=coverage=true`
- Links `libclang_rt.profile.a` runtime library
- Triggers coverage dump with `extern "C" void __gcov_dump(void)`

### Coverage Analysis Tools
- **llvm-cov**: Basic coverage analysis
- **gcovr**: Advanced reporting with HTML/JSON output
- **lcov**: Extended visualization and data merging capabilities

## Build Speed Profiling

### Three Dimensions of Build Time Analysis
1. **Gradle tasks**: Coarse-grained (compileKotlin, link tasks)
2. **Konan phases**: Internal konan compilation steps
3. **LLVM passes**: Optimization pipelines (Module and LTO)

### Profiling Methods
- **Gradle level**: Use `--profile` for local reports, `--scan` for detailed analysis
- **Konan phase level**: Add `-Xprofile-phases` compiler arg to show phase timing
- **LLVM pass level**: Requires patching Kotlin to enable timing statistics

### Performance Analysis Script
A Python script can parse build logs and generate statistics about phase execution times, counts, averages, and distributions.