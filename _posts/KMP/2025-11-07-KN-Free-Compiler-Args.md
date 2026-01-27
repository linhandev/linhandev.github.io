---
title: Konan编译选项
categories:
  - KN
tags:
  - KN
description: 
---

-Xtemporary-files-dir：将类似out.bc这种编译过程中的临时文件写到一个指定路径，这样文件不在tmp下，编译完成后会保留，方便查看。如 `-Xtemporary-files-dir=${project.buildDir.resolve("tmpfile").absolutePath}`

