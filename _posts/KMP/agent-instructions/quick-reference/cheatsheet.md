# KMP/OHOS Quick Reference Cheatsheet

## Common Commands

### Kotlin Native Build
```bash
# Incremental build (most common)
./gradlew :kotlin-native:dist

# Full build with platform libraries
./gradlew :kotlin-native:dist :kotlin-native:platformLibs:ohos_arm64Install

# Stop daemon (when needed)
./gradlew --stop
```

### Compilation for OHOS
```bash
# Basic compilation
kotlin-native/dist/bin/kotlinc-native test.kt -target ohos_arm64 -o test -g

# With temporary files preservation for debugging
kotlinc-native test.kt -target ohos_arm64 -o test -g -Xtemporary-files-dir=/tmp/kn_test_temp
```

### OHOS Device Deployment
```bash
# Push executable to device
hdc std -t <device-id> file send test.kexe /data/test.kexe

# Execute on device
hdc std -t <device-id> shell "chmod 755 /data/test.kexe && /data/test.kexe"
```

### View HiLog by tag
```bash
# Stream device logs for a specific tag only (-x excludes others)
hdc shell hilog -T CAPI_TEST -x
```
Replace `CAPI_TEST` with your `LOG_TAG` (e.g. from OH_LOG_Print).

## Key Directories
- **Compiler binaries**: `kotlin-native/dist/bin/`
- **Platform libraries**: `kotlin-native/dist/konan/targets/ohos_arm64/`
- **OHOS SDK**: `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/`

## Troubleshooting Quick Fixes
- **Platform libraries missing**: Run `./gradlew :kotlin-native:platformLibs:ohos_arm64Install`
- **Gradle daemon issues**: Run `./gradlew --stop`
- **Linking errors**: Add required OHOS system libraries to linker flags

## Frequently Used Flags
- `-g`: Include debug information
- `-Xtemporary-files-dir=`: Specify directory for temporary files
- `-verbose`: Enable verbose output
- `-Xprint-ir`: Print LLVM IR
- `-Xprint-bitcode`: Print bitcode

## Architecture Targets
- `macos_arm64`: macOS on Apple Silicon
- `ohos_arm64`: OHOS on ARM64
- `linux_x64`: Linux on x86_64
