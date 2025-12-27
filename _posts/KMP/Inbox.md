---
title: Inbox
published: false
---

换二进制

![alt text](<../../assets/img/post/2025-11-07-KN-Debug-Build-Speedup copy/2025-12-24T13:41:18.323Z-image.png>)


编译命令

```shell
~/.konan/dependencies/llvm-1201-macos-aarch64/bin/clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  -O3 \
  -fomit-frame-pointer \
  ~/test.cpp \
  -target aarch64-linux-ohos \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  && objdump -d a.out > temp


~/.konan/dependencies/llvm-1201-macos-aarch64/bin/clang++ \
  --sysroot /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/sysroot \
  --target=aarch64-linux-ohos \
  -O3 \
  -fomit-frame-pointer \
  -fPIC \
  -shared \
  -L/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos \
  -resource-dir /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/lib/clang/15.0.4 \
  build/out.Codegen.ll \
  -o output.so
```

llvm-dis：bc -> ll
llvm-as：ll -> bc