# Building LLVM for Kotlin/Native

This guide provides detailed instructions for building LLVM specifically for use with Kotlin/Native, based on the analysis of KMP blog posts.

## Overview

KN uses LLVM through Kotlin project's own build scripts located at `kotlin-native/tools/llvm_builder`. The build process follows a two-stage approach and can be customized for different platforms and requirements.

## Understanding the Build Process

### Two-Stage Build
1. **Stage 1**: Build LLVM tools using the host compiler
2. **Stage 2**: Build LLVM distribution using the tools from Stage 1

This approach ensures consistent toolchain usage throughout the build process.

### Build Script Characteristics
- The script primarily assembles cmake and ninja command parameters
- After determining parameters, subsequent incremental builds can use commands directly
- `build-targets` parameter controls component selection:
  - Without parameter: builds all components
  - With parameter: builds only components listed in `distribution-components` (faster, smaller output)

### Zsh Variable Handling
Note that in zsh, variables with spaces are treated as single strings, requiring `var=(a b c)` syntax for multiple parameters.

## Modifying Build Scripts

### Adding Compile Commands Support
Include `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` option to generate `compile_commands.json` files, which facilitate IDE code navigation.

### Multi-Xcode Environment Adaptation
Modify the `detect_xcode_sdk_path()` function to ensure stability across multiple Xcode installations:

```diff
def detect_xcode_sdk_path():
  """
  Get an absolute path to macOS SDK.
  """
- return subprocess.check_output(['xcrun', '--show-sdk-path'],
+ return subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'],
    universal_newlines=True).rstrip()
```

## Building Specific LLVM Versions

### OHOS LLVM 12 (master-llvm12-backup branch)

**Repository**: https://gitcode.com/openharmony/third_party_llvm-project/tree/master-llvm12-backup
**Compatible with**: KN 2.0 build scripts

#### Prerequisites (Mac ARM)
```bash
brew install ninja cmake wget ccache
# Verified with cmake 4.2.1 and ninja 1.13.2
```

#### Build Process (Mac ARM)
```bash
LLVM_FOLDER=/Users/hl/git/llvm/oh12
git clone http://gitcode.com/openharmony/third_party_llvm-project $LLVM_FOLDER

cd kotlin-native/tools/llvm_builder

export DEVELOPER_DIR=/Applications/Xcode-14.3.1.app/Contents/Developer/
DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
python3 package.py \
  --distribution-components $DISTRIBUTION_COMPONENTS \
  --llvm-sources $LLVM_FOLDER \
  --save-temporary-files # --pack for release
```

#### Incremental Builds
```bash
cd llvm-stage-2-build
ninja install-distribution
```

#### Stage 1 Build Command (Automatically Generated)
```bash
cmake -G Ninja \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
-DLLVM_ENABLE_ASSERTIONS=OFF \
-DLLVM_ENABLE_TERMINFO=OFF \
-DLLVM_INCLUDE_GO_TESTS=OFF \
-DLLVM_ENABLE_Z3_SOLVER=OFF \
-DCOMPILER_RT_BUILD_BUILTINS=ON \
-DLLVM_ENABLE_THREADS=ON \
-DLLVM_OPTIMIZED_TABLEGEN=ON \
-DLLVM_ENABLE_IDE=OFF \
-DLLVM_BUILD_UTILS=ON \
-DLLVM_INSTALL_UTILS=ON \
-DLLVM_ENABLE_LIBCXX=ON \
-DCMAKE_OSX_DEPLOYMENT_TARGET=11.2 \
-DCMAKE_OSX_SYSROOT=/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk \
-DCOMPILER_RT_BUILD_CRT=OFF \
-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
-DCOMPILER_RT_BUILD_XRAY=OFF \
-DCOMPILER_RT_ENABLE_IOS=OFF \
-DCOMPILER_RT_ENABLE_WATCHOS=OFF \
-DCOMPILER_RT_ENABLE_TVOS=OFF \
-DCMAKE_INSTALL_PREFIX=/Users/hl/git/llvm/oh12/llvm-stage-1 \
-DLLVM_TARGETS_TO_BUILD=Native \
'-DLLVM_ENABLE_PROJECTS=clang;lld;libcxx;libcxxabi;compiler-rt' \
-DLLVM_BUILD_LLVM_DYLIB=OFF \
-DLLVM_LINK_LLVM_DYLIB=OFF \
/Users/hl/git/llvm/oh12/llvm
```

#### Stage 2 Build Command (Automatically Generated)
```bash
cmake -G Ninja \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
-DLLVM_ENABLE_ASSERTIONS=OFF \
-DLLVM_ENABLE_TERMINFO=OFF \
-DLLVM_INCLUDE_GO_TESTS=OFF \
-DLLVM_ENABLE_Z3_SOLVER=OFF \
-DCOMPILER_RT_BUILD_BUILTINS=ON \
-DLLVM_ENABLE_THREADS=ON \
-DLLVM_OPTIMIZED_TABLEGEN=ON \
-DLLVM_ENABLE_IDE=OFF \
-DLLVM_BUILD_UTILS=ON \
-DLLVM_INSTALL_UTILS=ON \
'-DLLVM_DISTRIBUTION_COMPONENTS=clang;libclang;lld;llvm-cov;llvm-profdata;llvm-ar;clang-resource-headers' \
-DCLANG_LINKS_TO_CREATE=clang++ \
'-DLLD_SYMLINKS_TO_CREATE=ld.lld;wasm-ld' \
-DLLVM_ENABLE_LIBCXX=ON \
-DCMAKE_OSX_DEPLOYMENT_TARGET=11.2 \
-DCMAKE_OSX_SYSROOT=/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk \
-DLIBCXX_USE_COMPILER_RT=ON \
-DCMAKE_INSTALL_PREFIX=/Users/hl/git/llvm/oh12/llvm-distribution \
'-DLLVM_ENABLE_PROJECTS=clang;lld;libcxx;libcxxabi;compiler-rt' \
-DCMAKE_C_COMPILER=/Users/hl/git/llvm/oh12/llvm-stage-1/bin/clang \
-DCMAKE_CXX_COMPILER=/Users/hl/git/llvm/oh12/llvm-stage-1/bin/clang++ \
-DCMAKE_AR=/Users/hl/git/llvm/oh12/llvm-stage-1/bin/llvm-ar \
-DCMAKE_C_FLAGS= \
-DCMAKE_CXX_FLAGS=-stdlib=libc++ \
-DCMAKE_EXE_LINKER_FLAGS=-stdlib=libc++ \
-DCMAKE_MODULE_LINKER_FLAGS=-stdlib=libc++ \
-DCMAKE_SHARED_LINKER_FLAGS=-stdlib=libc++ \
-DLLVM_BUILD_LLVM_DYLIB=OFF \
-DLLVM_LINK_LLVM_DYLIB=OFF \
/Users/hl/git/llvm/oh12/llvm
```

### Debug Build Configuration
To build with debug information, modify the Stage 2 cmake configuration:
```
-DCMAKE_BUILD_TYPE=RelWithDebInfo 
-DLLVM_ENABLE_ASSERTIONS=ON
```

### Linux Docker Build
```bash
LLVM_FOLDER=/Users/hl/git/llvm/oh12
git clone http://gitcode.com/openharmony/third_party_llvm-project $LLVM_FOLDER

cd kotlin-native/tools/llvm_builder/images/linux/
docker build --platform linux/amd64 -t kotlin-llvm-builder --file ./Dockerfile .

DISTRIBUTION_COMPONENTS=(clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers)
docker run --platform linux/amd64 --rm -it -v .:/output -v $LLVM_FOLDER:/llvm kotlin-llvm-builder --llvm-sources /llvm --install-path /output/llvm-12.0.1-x86_64-linux --distribution-components $DISTRIBUTION_COMPONENTS --save-temporary-files
```

### Kotlin LLVM 19.1.4 Build

#### Linux Setup
```bash
apt update && apt upgrade -y
apt install -y git docker ca-certificates curl

# Install Docker
export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
curl -fsSL https://raw.githubusercontent.com/docker/docker-install/master/install.sh | sh

# Add Docker repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### LLVM 19.1.4 Build Process
```bash
LLVM_FOLDER=$(realpath ~/kotlin-llvm-1914)
git clone --branch kotlin/llvm-19-apple --depth 3 --single-branch https://gitcode.com/linhandev/kotlin-llvm-project.git $LLVM_FOLDER
cd $LLVM_FOLDER
git checkout fb492d2475910b83cda3a68b4eee9e87d7e221c1
cd -

mkdir docker_image
cd docker_image
wget https://raw.githubusercontent.com/JetBrains/kotlin/refs/tags/v2.2.21/kotlin-native/tools/llvm_builder/images/linux/Dockerfile
wget https://raw.githubusercontent.com/JetBrains/kotlin/refs/tags/v2.2.21/kotlin-native/tools/llvm_builder/package.py
docker build -t kotlin-llvm-builder --file ./Dockerfile .
cd ..

mkdir output
cd output

DISTRIBUTION_COMPONENTS="clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers compiler-rt"
docker run --platform linux/amd64 --rm -it -v ./output:/output -v $LLVM_FOLDER:/llvm/ kotlin-llvm-builder --llvm-sources /llvm --install-path /output/ --save-temporary-files
```

## Component Selection

### Key Distribution Components
- `clang`: The C language family frontend
- `libclang`: C interface to Clang libraries
- `lld`: The LLVM linker
- `llvm-cov`: LLVM coverage tool
- `llvm-profdata`: LLVM profile data tool
- `llvm-ar`: LLVM archiver
- `clang-resource-headers`: Clang resource headers
- `compiler-rt`: Compiler runtime libraries

## Build Optimization Tips

### Faster Builds
1. **Selective components**: Use `--distribution-components` to build only needed components
2. **Incremental builds**: Use `--save-temporary-files` to keep intermediate files
3. **Parallel builds**: Ensure sufficient system resources for parallel compilation

### Memory and Storage Considerations
- Stage 1 build requires significant disk space for intermediate files
- Distribution build produces final artifacts
- Debug builds require more space than release builds

## Troubleshooting

### Common Issues
1. **Missing dependencies**: Ensure all prerequisites (ninja, cmake, etc.) are installed
2. **Xcode path issues**: Verify DEVELOPER_DIR is set correctly
3. **Insufficient disk space**: LLVM builds require substantial temporary space
4. **Architecture mismatches**: Use `--platform linux/amd64` for Docker builds on ARM systems

### Verification
After successful build:
1. Check that required components exist in the installation directory
2. Verify executables can run: `./bin/clang --version`
3. Confirm that required libraries are present for KN integration

## Integration with KN

### Path Configuration
Ensure KN can locate the custom LLVM build:
- Set appropriate paths in KN build configuration
- Verify that `libclang_rt.profile.a` is available for coverage builds
- Confirm that all required components are accessible

### Version Compatibility
- Match LLVM version requirements with KN version
- Test with sample projects before full deployment
- Verify that all needed features (sanitizers, coverage, etc.) work properly