# Agent Instructions Index

Structured guides for Kotlin Native / OHOS. Format: LLM-oriented.

## Guides

[working-with-clang.md](./kmp-foundations/working-with-clang.md) — Build C/C++ for OHOS (Clang, sysroot, targets, IR→obj→exe).
[building-ohos-hap-from-cli.md](./ohos-integration/building-ohos-hap-from-cli.md) — Build HAP from CLI (ohpm, hvigor).
[hdc-commands.md](./ohos-integration/hdc-commands.md) — HDC: list targets, file send/recv, shell, hilog, param, install, aa start.
[calling-ohos-native-api.md](./ohos-integration/calling-ohos-native-api.md) — OHOS NDK C APIs: headers/libs, include/link, HiLog/HiTrace/HiCollie.
[running-exe-on-ohos.md](./ohos-integration/running-exe-on-ohos.md) — Deploy/run binaries (HDC, arch, permissions, .so vs exe).
[ohos-device-layout.md](./ohos-integration/ohos-device-layout.md) — Where .so live: /system/lib64/, /data/app/.../libs/, /vendor/lib64/.
[working-with-kotlin-native-compiler.md](./working-with-kotlin-native-compiler.md) — Build/test KN compiler, OHOS, incremental/clean.
[adding-llvm-pass-to-konan.md](./kmp-foundations/adding-llvm-pass-to-konan.md) — Add LLVM pass: C API, pipeline, phase, linker; GCOV example.
[llvm-runtime-libraries.md](./kmp-foundations/llvm-runtime-libraries.md) — compiler-rt for OHOS, DevEco SDK, hilog/unwind.

## Quick Reference

Build C/C++: working-with-clang. HAP: building-ohos-hap-from-cli. OHOS API: calling-ohos-native-api. HDC: hdc-commands (hilog: #logs-hilog). Deploy: running-exe-on-ohos. Find .so: ohos-device-layout. Build KN: working-with-kotlin-native-compiler. LLVM pass: adding-llvm-pass-to-konan. compiler-rt: llvm-runtime-libraries.

Workflow: 1) DevEco + OHOS SDK 2) Build compiler (working-with-kotlin-native-compiler) 3) Add pass if needed (adding-llvm-pass-to-konan) 4) Build test (working-with-clang) 5) Deploy (running-exe-on-ohos).
