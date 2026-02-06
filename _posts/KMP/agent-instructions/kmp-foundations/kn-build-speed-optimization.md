# Kotlin/Native Build Speed Optimization Guide

This guide consolidates best practices and techniques for optimizing Kotlin/Native build speeds based on analysis of the KMP blog posts.

## Understanding the Build Process

KN builds involve multiple phases:
1. **Gradle tasks**: Coarse-grained operations like compileKotlin and link tasks
2. **Konan phases**: Internal compilation steps transforming Kotlin to native code
3. **LLVM passes**: Optimization pipelines (especially in release builds)

## Gradle Task Optimization

### Profile Your Builds
- Use `./gradlew :app:linkPlCheckDebugSharedOhosArm64 --profile` to identify bottlenecks
- `--scan` provides more detailed information but uploads data to servers
- Look for tasks that are not UP-TO-DATE, FROM-CACHE, or SKIPPED

### Minimize Task Triggers
The goal is to modify one line of code and:
1. Trigger as few gradle tasks as possible
2. Optimize the performance of frequently triggered tasks

KN builds typically trigger at least two tasks: `compileKotlin` and `link`. When modifying a module C that's depended on by modules B and A, all three modules' compileKotlin tasks will re-execute.

## Incremental Compilation Setup

Incremental compilation only affects the link task, not compileKotlin tasks. It dramatically reduces linking time by caching components.

### Enabling Per-Klib Caching
Add `ohos` to the `cacheableTargets` in your kotlin/kotlin-native/konan.properties file:

```
cacheableTargets=macos_x64,macos_arm64,ios_x64,ios_arm64,ios_arm32,ios_simulator_arm64,tvos_x64,tvos_arm64,tvos_simulator_arm64,wasm32,linux_x64,mingw_x64,android_native_arm32,android_native_arm64,android_native_x64,android_native_x86,ohos
```

### Enabling Per-File Caching
Add this to your application's gradle.properties:

```
kotlin.incremental.native=true
```

This enables per-file caching for all cacheable targets.

### Cache Locations
- Per-klib cache: `$KONAN_DATA_DIR/kotlin-native-prebuilt-[platform]-[version]/klib/cache/ohos_arm64STATIC-pl`
- Per-file cache: `[gradle-project]/build/kotlin-native-ic-cache/debugShared/ohos_arm64-gSTATIC-pl`

## Common Issues with Incremental Builds

1. **Linker command fails - "command too long"**
   - All static cache files are passed as absolute paths to ld
   - Solution: Use ld's `@/path/to/command.txt` format where each line is a linker input

2. **Unstable linking performance**
   - Reading many small .a cache files can be inefficient
   - macOS and Linux have OS-level optimizations for this
   - Performance typically stabilizes after 2-3 debug builds

3. **Duplicate symbol errors**
   - Known issue KT-81760
   - Usually caused by duplicate function definitions in the same package
   - Temporary solution: Add `--allow-multiple-definition` linker option

4. **Increased binary size**
   - Static caching can cause binary bloat since optimizations happen at link time
   - Solution: Use linker options like `--gc-section` with proper compilation flags (`-ffunction-section` and `-fdata-section`)

## Advanced Configuration

### Granular Control Options
- To disable caching: `kotlin.native.cacheKind.ohosArm64=none`
- To control parallelism: `kotlin.native.parallelThreads=0` (sets to CPU core count)

### Partial Linkage (PL) Feature
- PL allows calling non-existent interfaces in dependencies without compile-time errors
- Can cause runtime issues; use header_cache target to check compatibility:

```kotlin
sharedLib("check") {
    freeCompilerArgs += listOf("-produce", "header_cache", "-Xpartial-linkage=enable", "-Xpartial-linkage-loglevel=error", "-opt")
}
```

## Debug Build Optimization Strategies

### Minimize Top-Level Project Code
Top-level project compileKotlin tasks don't support incremental compilation and run on every debug build. Consider:
- Moving frequently modified code to lower-level modules
- Splitting large modules into smaller ones with more specific dependencies
- Restructuring dependencies to reduce rebuild scope

### Optimize Dependency Chains
Make frequently built projects as small as possible while minimizing unnecessary dependencies that trigger rebuilds.

## Performance Monitoring

### Phase-Level Profiling
Add `-Xprofile-phases` to compiler args to get timing information for each konan phase. A Python script can parse the output and generate detailed statistics.

### LLVM Pass Profiling
For detailed LLVM optimization pipeline analysis, Kotlin needs patching to enable proper timing output. The Global Variable Optimizer passes often show significant execution times and may warrant investigation.

## Best Practices Summary

1. **Always enable incremental compilation** for faster debug builds
2. **Structure projects** to minimize rebuild scope when code changes
3. **Profile regularly** to identify bottlenecks in your specific codebase
4. **Monitor cache effectiveness** and troubleshoot common issues
5. **Consider trade-offs** between build speed, binary size, and code organization