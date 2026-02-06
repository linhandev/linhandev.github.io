# Kotlin/Native Debugging Techniques

This guide outlines effective debugging strategies for Kotlin/Native applications based on the analysis of KMP blog posts.

## Understanding Debugging Challenges

KN debugging involves multiple layers:
1. **Kotlin/Native compiler debugging**: Debugging the compilation process itself
2. **Runtime debugging**: Debugging the compiled application on device
3. **Mixed C/KN debugging**: Debugging interactions between C and Kotlin code

## Compiler Debugging

### Debugging Gradle Tasks
1. Clone the Kotlin project
2. Open in IntelliJ IDEA
3. Configure a Gradle run configuration for the task you want to debug
4. Set breakpoints in the Kotlin compiler code
5. Run the configuration in debug mode

### Debugging Gradle Commands
1. Stop any existing daemons: `./gradlew --stop`
2. Add debug flag to your gradle command: `./gradlew :kotlin-native:dist -Dorg.gradle.debug=true`
3. The command will pause waiting for a debugger connection
4. Create a remote JVM debug configuration in your IDE
5. Attach to the waiting process

### Debugging Direct Commands
For commands that bypass Gradle (like direct konanc calls):

1. Modify the `bin/run_konan` script to add debug options
2. Insert `-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005` into the java command
3. Create a remote debug configuration in your IDE
4. Run the modified command and attach the debugger

## Runtime Debugging

### Enabling Debug Information
Runtime debugging requires that debug information is preserved in the compiled binaries:

1. **Patch the Kotlin project** to preserve debug info:
   ```kotlin
   if (project.findProperty("kotlin.native.isNativeRuntimeDebugInfoEnabled") == "true") {
     args += "-Xbinary=stripDebugInfoFromNativeLibs=false"
   }
   ```

2. **Set the property** in your gradle.properties or local.properties:
   ```
   kotlin.native.isNativeRuntimeDebugInfoEnabled=true
   ```

3. **Add compiler args** to preserve debug info:
   ```
   -Xbinary=stripDebugInfoFromNativeLibs=false
   ```

4. **Configure DevEco Studio** to not strip debug info during build:
   ```json
   {
     "name": "debug",
     "nativeLib": {
       "debugSymbol": {
         "strip": false,
         "exclude": []
       }
     }
   }
   ```

### Verification Steps
- Check debug info in the built so file: `dwarfdump libkn.so | grep '/kotlin-native/runtime/src/'`
- Confirm the file isn't stripped: `file libkn.so` should show "not stripped"

## Address Sanitizers for Debugging

KN integrates with several sanitizer tools for memory safety:

### Types of Sanitizers
- **ASAN (Address Sanitizer)**: Comprehensive memory error detection
- **HWASAN (Hardware-Assisted ASAN)**: ARM-specific with lower memory overhead
- **GWP-ASAN**: Sampling-based with minimal performance impact

### Integration Approach
KN connects to LLVM sanitizer capabilities in two steps:
1. Run relevant LLVM passes to instrument the IR
2. Link the appropriate runtime libraries

## Debug Information Path Management

### Problem Statement
DWARF debug information contains absolute paths from the build machine, which can cause issues when debugging on different machines or after code moves.

### Solutions

#### Using -Xdebug-prefix-map
Maps debug source paths:
```
-Xdebug-prefix-map=/real/path/prefix/=/virtual/unified/prefix
```

- Apply to the project that produces the final .so file
- Can be repeated for multiple path mappings
- Must align path endings (both with / or both without)

#### Using -Xklib-relative-path-base
Makes klib debug paths relative to a base directory:
```
-Xklib-relative-path-base=${project.rootDir}
```

### Recommended Combined Approach
1. Use relative paths when building klib:
   ```kotlin
   compilerOptions {
       freeCompilerArgs.add("-Xklib-relative-path-base=${project.rootDir}")
   }
   ```

2. Replace gradle daemon path prefix when building final so:
   ```kotlin
   compilerOptions {
     val gradleUserHome = project.gradle.gradleUserHomeDir.absolutePath
     val gradleVersion = project.gradle.gradleVersion
     val daemonPath = "$gradleUserHome/daemon/$gradleVersion"

     freeCompilerArgs.add("-Xdebug-prefix-map=$daemonPath=/workspace")
   }
   ```

## Debugging Runtime Issues

### Common Runtime Problems
- Stack overflow
- Use-after-free
- Double-free
- Invalid memory access

### Detection Methods
Different sanitizers detect different types of issues:
- **ASAN**: heap-buffer-overflow, stack-buffer-overflow, heap-use-after-free, double-free
- **HWASAN**: Similar to ASAN but with hardware assistance
- **GWP-ASAN**: double-free, use_after_free, invalid free, buffer underflow

## Production Issue Investigation

### Release Build Debugging
For production crashes:
1. Build with debuggable release settings (symbols included but optimized)
2. Use addr2line to translate crash addresses: `llvm-addr2line -fCe libkn.so cf2ec3`
3. Extract debug symbols separately: `llvm-objcopy --only-keep-debug libkn.so libkn.debug`

### Automated Symbolication
Create a script to batch-process crash addresses:

```python
import subprocess

so_name = "libkn.debug"
addresses = input("Plz input addresses:\n")
addresses = addresses.strip().split(" ")
addresses = [addr for addr in addresses if addr and len(addr) != 0]

for address in addresses:
    cmd = ["./llvm-addr2line", "-fCe", so_name, address]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        res = result.stdout.strip().split("\n")
        print(f"{address}\tfile://{res[1]}\t{res[0]}")
    except subprocess.CalledProcessError as e:
        print(f"Error running command for address {address}: {e.stderr}")
```

## Debugging Best Practices

1. **Use appropriate sanitizers** during development to catch memory issues early
2. **Preserve debug information** in development builds
3. **Match build and debug environments** as closely as possible
4. **Test with realistic data sizes** to catch performance issues
5. **Verify path mappings** work across different development environments
6. **Regular profiling** to identify performance bottlenecks before they become issues

## Useful Tools

- **dwarfdump**: Inspect debug information in binaries
- **addr2line**: Translate addresses to source locations
- **llvm-objcopy**: Manipulate debug symbol files
- **Various sanitizers**: Catch memory safety issues