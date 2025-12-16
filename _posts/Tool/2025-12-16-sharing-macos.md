---
title: 共享MacOS
categories:
  - MacOS
tags:
  - MacOS
  - Tool
description: 
---

xcode：不要使用 xcode-select 指定默认xcode版本，在 ~/.zshrc 中设置 export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer/ 选定自己的xcode，用过 xcode-select -p 打印当前生效的xcode路径

java：/usr/libexec/java_home -V

打开远程登陆功能，创建用户，设置密码

sudo sysadminctl -addUser <username> -password -


brew install bore-cli
bore local 22 --to bore.pub

ssh username@bore.pub -p xxx



- [jetbrains gateway](https://www.jetbrains.com/remote-development/gateway/download/download-thanks.html?code=GW&platform=macM1)只支持linux
    ![alt text](/assets/img/post/2025-12-16-sharing-macos/2025-12-16T09:09:48.588Z-image.png)
- intellj idea要pro版本才支持完整的remote开发体验