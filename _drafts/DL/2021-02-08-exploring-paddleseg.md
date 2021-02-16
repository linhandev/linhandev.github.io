---
title: "PaddleSeg代码解析"
author: "Lin Han"
date: "2021-02-08 13:06 +8"
categories: []
tags: []
math: true
---

paddleseg/
├── core # 最高层的脚本，训练，验证和推理
│   ├── infer.py
│   ├── __init__.py
│   ├── predict.py
│   ├── train.py
│   └── val.py
├── cvlibs # 训练基础设施
│   ├── callbacks.py
│   ├── config.py # 项目配置
│   ├── __init__.py
│   ├── manager.py
│   └── param_init.py
├── datasets # 数据集下载脚本
│   ├── ade.py
│   ├── cityscapes.py
│   ├── dataset.py
│   ├── __init__.py
│   ├── optic_disc_seg.py
│   └── voc.py
├── __init__.py
├── models # 模型库
│   ├── ann.py
│   ├── attention_unet.py
│   ├── backbones
│   │   ├── hrnet.py
│   │   ├── __init__.py
│   │   ├── mobilenetv3.py
│   │   ├── resnet_vd.py
│   │   └── xception_deeplab.py
│   ├── bisenet.py
│   ├── danet.py
│   ├── deeplab.py
│   ├── dnlnet.py
│   ├── emanet.py
│   ├── fast_scnn.py
│   ├── fcn.py
│   ├── gcnet.py
│   ├── gscnn.py
│   ├── hardnet.py
│   ├── __init__.py
│   ├── isanet.py
│   ├── layers
│   │   ├── activation.py
│   │   ├── attention.py
│   │   ├── __init__.py
│   │   ├── layer_libs.py
│   │   ├── nonlocal2d.py
│   │   └── pyramid_pool.py
│   ├── losses
│   │   ├── binary_cross_entropy_loss.py
│   │   ├── bootstrapped_cross_entropy.py
│   │   ├── cross_entropy_loss.py
│   │   ├── dice_loss.py
│   │   ├── edge_attention_loss.py
│   │   ├── gscnn_dual_task_loss.py
│   │   └── __init__.py
│   ├── ocrnet.py
│   ├── pspnet.py
│   ├── u2net.py
│   ├── unet_plusplus.py
│   └── unet.py
├── transforms # 数据增强方法
│   ├── functional.py
│   ├── __init__.py
│   └── transforms.py
└── utils # 类似下载，可视化，计时，进度条等基础功能
    ├── download.py
    ├── env
    │   ├── __init__.py
    │   ├── seg_env.py
    │   └── sys_env.py
    ├── __init__.py
    ├── logger.py
    ├── metrics.py
    ├── progbar.py
    ├── timer.py
    ├── utils.py
    └── visualize.py

10 directories, 68 files
