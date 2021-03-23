---
title: 深度学习笔记
author: Lin Han
date: '2021-02-06 15:02 +8'
categories:
  - DL
tags:
  - Andrew
  - TODO
math: true
published: true
---

# 前言
从高中毕业的假期第一次看吴恩达的 Machine Learning 课程到现在已经过去4年了，虽然对深度学习一直很感兴趣也做过一些相关的项目，但是自知水平很差。回顾之前的一些经历，深感没有扎实的理论基础，面对深度学习这样一个发展迅速，分支众多的技术很难很好的掌握，应用就更别提了。因此希望开几个系列，手撸机器学习和深度学习的重要算法和网络结构，希望对技术有更扎实的掌握。

# 有用的资料
## 课程
- [Deep Learning Specialization](https://www.coursera.org/specializations/deep-learning)

吴恩达DeepLearning.ai出品的课程，有一定的理论深度而且没什么废话，深度学习的很多内容估计会根据这门课程总结。
- https://www.92python.com/view/251.html

# 符号
一些符号约定，在手写深度学习的时候一个很有用的技巧是看矩阵在做乘法加法之类的操作时维度能不能对的上，因此注意看矩阵变量都是什么维度。上标$$^{()}$$都表示第几条训练数据，$$^{[]}$$都表示第几层
- m：数据集中有多少条数据，一般是说训练集，需要强调的时候会写$$m_{train}$$
- $$n_{x}$$：输入数据的特征数量
- $$n_{y}$$：输出的数量(比如在分类问题中是公有多少类)
- $$n^{[l]}_{h}$$：全连接网络第l层节点的数量
- $$L$$：网络总层数
- $$x^{(i)}\in \mathbb{R}^{n_{x}\times 1}$$：第i条训练数据，$$n_{x}$$行，1列，每条训练数据，无论是单独写还是放在数组里都是竖着的
- $$X\in {\mathbb{R}}^{n_{x}\times m}$$：输入数据矩阵，特征数行，数据条数列。在所有的Ｘ和激活函数的输出Ａ数组中，一条数据都是竖着的。
- $$y^{(i)}\in {\mathbb{R}}^{n_{y}\times 1}$$：第ｉ条数据的输出，$$n_{y}$$行１列，所有数据的输出和输入一样，无论单独写还是在数组里都是竖着的
- $$Y\in {\mathbb{R}}^{n_{y}\times m}$$：输出矩阵，$$n_{y}$$行ｍ列
- $$W^{[l]} \in \mathbb{R}^{n^{[l-1]}_{h} \times n^{[l]}_{h}}$$：计算的时候是 $$W^{[l]}\times a^{[l-1]} + b^{[l]}$$，所以$$W^{[l]}$$是$$n^{[l]} \times n^{[l-1]}的$$。$$W^{l}$$中的一行是第l层中一个节点的权重，所以$$W^{l}$$中的行和第l层的节点个数相同，$$W^{l}$$中的列和第l-1层中的节点个数相同。


- $$b^{[l]} \in \mathbb{R}$$：
- $$\hat{y} \in \mathbb{R}^{n_{y}}$$：
- $$a^{[L]} \in \mathbb{R}$$：

![scale_drives_dl](/assets/img/post/DL/DL-Notes/scale-drives-dl.png)

# 关于图像
不同的bb格式：
- yolo
- voc
- coco
x,y一般是宽和高
cv2.imread()进来是HWC
PIL Image.read() 之后 asarray 是
通常框架输入是 CWH

# 激活函数
- sigmoid：$$sigmoid(x) = \frac{1}{1+e^{-x}}$$

# 损失函数
