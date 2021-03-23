---
title: 逻辑回归
author: Lin Han
date: '2021-02-07 00:01 +8'
categories:
  - DL
tags:
  - Andrew
  - TODO
math: true
published: false
---

逻辑回归是一种二分类方法
对于一条训练数据
$$
z^{(i)}=wx^{(i)}+b  \\

a^{(i)} = \sigma(z^{(i)}) = \frac{1}{1+e^{-z^{(i)}}} \\

\hat{y^{(i)}}=a^{(i)} \\

Loss(a^{(i)},y^{(i)}) = -[ y^{(i)}log(a^{(i)}) + (1-y^{(i)})log(1-a^{(i)}) ]\\

J(w,b) = \frac{1}{m}\sum_{i=1}^{m}Loss(y^{(i)}, \hat{y}^{(i)})
$$
Loss一般不用BCE，会让问题非凸
![loss](/assets/img/post/ML/DNN/2020-2-9-Logistic-Regression/loss.png)
Loss是针对一条数据的，Cost是针对整个训练集的

目标是找到最小的w,b
![gd](/assets/img/post/ML/DNN/2020-2-9-Logistic-Regression/gd.png)
反向从后往前求导

$$
\frac{dLoss(a,y)}{da} = -\frac{y}{a} + \frac{1-y}{1-a} \\


\begin{aligned}
\frac{d\sigma(z)}{dz} &= -(1+e^{-z})^{-2}e^{-z}*-1 \\
&= e^{-z}*(1+e^{-z})^{-2} \\
&= (1+e^{-z}-1) * (1+e^{-z})^{-2} \\
&= \frac{1}{1+e^{-z}}(1-\frac{1}{1+e^{-z}}) \\
&= \sigma(z)(1-\sigma(z))
\end{aligned}
$$
$$
\begin{aligned}
\frac{dLoss(a,y)}{dz} &= \frac{dLoss(a,y)}{da} \frac{da}{dz} \\
&= (-\frac{y}{a} + \frac{1-y}{1-a}) * a(1-a) \\
&= a(1-y) + (a-1)*y \\
&= a-y \\

\frac{dLoss(a,y)}{dw_{t}} &= x_{t} * \frac{dLoss(a,y)}{dz} \\


J(w,b) &= \frac{1}{m}\sum_{i=1}^{m}Loss(\hat{y}^{(i)}, y^{(i)}) \\

\frac{dJ(w,b)}{dw_{y}} &= \frac{1}{m}\sum_{i=1}^{m}\frac{dLoss(\hat{y}^{(i)}, y^{(i)})}{dw_{y}}
\end{aligned}
$$


$$
$$
![](/assets/img/post/2020-1-15-逻辑回归-f496a590.png)

## 计算图

## 矩阵化
通常深度学习算法都需要在大量的数据上进行运算，因此加速很关键。将一些用for进行的计算转换成矩阵乘法的格式非常适合用SIMD技术对他进行加速

给一个 n 对数相乘的例子，测速

py实现技巧
- 在写神经网络代码时注意数组维度，可以避免很多错误
- 不要用rank1数组，5个数字的数组写成 (5,1) 的，不要用 (5,)的
np.random.randn(5)
np.random.randn(5,1)
-

# 简单神经网络

![](/assets/img/post/2020-1-15-神经网络基础-12f08b7c.png)
第ｉ层的权重　$W^{[i]}$ 　是 $(n_{i},n_{i-1})$ 　的，因为　X　或者　A　永远都是竖着的，所以　W　里面横着的一行一定和前一列节点一样长，行数一定和下一层的节点数一样多。$y=WX+b$ 所以b一定和y大小一样，是 $(n_{i},1)$ 的。


![](/assets/img/post/2020-1-15-神经网络基础-1497fd8a.png)

深而细的网络比浅而粗的网络一般效果要好。
![](/assets/img/post/2020-1-15-神经网络基础-6657ff5b.png)


![](/assets/img/post/2020-1-15-神经网络基础-5a931eb2.png)


High Bias - Underfit
High Variance - Overfit

Dropout
一定概率mute掉一层里的一些节点，最后所有的a都要除以dropout概率， 这样不会因为dropout 0.8，a就变小到 0.8a
