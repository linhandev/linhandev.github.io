---
title: numpy之类科学计算相关
author: Lin Han
date: 03-02-2021 20:59 +8
categories: [Tool, Linux]
tags: []
math: true
public: false
---
```python
np.ones([1,3]) * np.ones([3,1]) # 报错，np之间的*是element-wise操作，要求dim一样
np.linalg.norm(x,ord = 2,axis=1,keepdims=True) # 横向x**2的平均数开根号
```
