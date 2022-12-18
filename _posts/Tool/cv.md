PCA

m条数据，n个特征，n行m列矩阵

1. 每个特征减去这个特征的平均值

2. 求协方差矩阵

3. 求协方差矩阵的特征值和特征向量

4. 按照特征值从大到小排特征向量，前k行是矩阵P

5. Y=PX是降维之后的数据，丢掉的比例是没取的特征值的和
- 降维,计算更快

- 特征之间独立，更容易发现规律

- 降噪

- pca一定会丢掉一些信息

- P的选择不一定有很好的泛化效果，可能过拟合

- 感觉在结构化数据上效果会比较好，图像的话一个像素不代表固定的信息，这样感觉很不利于发现特征之间的相关性

convolution

提取特征，输出代表输入和卷积和代表特征的相似性，一个卷积核在整张图上算，复用权重

pooling

只用卷积，感受野扩大的速度太慢，池化可以扩大感受野

减小特征图大小，一些很相邻位置一个卷积核检出的信息可能有冗余

跳着卷积可能一些特征正好跨两次卷积位置分布，不利于发现这样的特征

normalization

每层都让数据分布有一些变化，叠加起来，高层输入的数据变化就会很剧烈，在不稳的地基上盖楼，不利于学习

- 每次都是新的分布，每次都要重新学习

- 高层落入饱和区

batch norm：纵向，针对一个mini batch内的一个特征

https://zhuanlan.zhihu.com/p/437446744

输入变为一个比较标准的分布，之后引入g和b避免norm过多的限制层输出的分布，一般在act之后用

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-08-15-35-image.png)

![](https://pic1.zhimg.com/80/v2-13bb64b6122e98421ea3528539c1bffc_720w.webp)

要求

- batch size较大

- shuffle

- 数据分布接近

滑动平均保留一个对训练集的均值和标准差的整体估计，在推理的时候用

- 降低了训练时层间的依赖

- 让loss更加平滑，看一个样本的同时也看到了mini batch内其他的样本，让网络有更好的泛化性能

在推理时bn可以和卷积融合

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-15-01-02-1671393647792.png)

layer norm：横向，针对一层所有的输入

![](https://pic1.zhimg.com/80/v2-2f1ad5749e4432d11e777cf24b655da8_720w.webp)

- 可以小bs

- 所有的输入经过同样的norm，他们都需要在同一个范围内，否则降低学习能力

weight norm：规范化一个神经元的权重

![](https://pic2.zhimg.com/80/v2-93d904e4fff751a0e5b940ab3c27b6d5_720w.webp)

- 不需要大bs

- 可以独立针对每一个神经元，不像ln层内统一

cosine norm：向量点积表示向量相似度，无界；向量夹角也可以表示相似度，有界

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-08-35-00-1671370496691.png)

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-08-33-54-1671370429784.png)

- 权重伸缩不变，权重都乘一个常量，norm结果一样
  
  - 不影响反向梯度传播，避免梯度消失和梯度爆炸，可以上更大的学习率

- 除wn外，数据伸缩不变

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-08-46-53-1671371209147.png)

hard max -> soft max：由只给一个最大值到给出每个类别的概率

指数函数求导方便，而且可以拉大不同输入之间的区别。可能导致数值溢出

多类别：很多类别，但是每条数据只属于一个类别，不均衡

多标签：很多标签，每条数据可以有多个标签，标签共现

https://zhuanlan.zhihu.com/p/56475281

过拟合：数据太少或者模型太复杂

- 数据增强

- 增加数据

- 正则化 regularization
  
  - L1：更稀疏，有更多0
  
  ![](https://pic4.zhimg.com/80/v2-67c5c82b342b9e4233c9bf16ca16d57b_720w.webp)
  
  - L2：取值更小，倾向放弃一些离群点
  
  ![](https://pic1.zhimg.com/80/v2-758e4538d8e8452be008d3b4cf8c54f0_720w.webp)

- 早停：验证损失不再下降终止训练

- Dropout：随机失活一定比例的神经元，训练网络稀疏，避免神经元之间的协同

- 多任务学习
  
  - 硬共享：直接分享参数
  
  - 软共享：一人一份参数，但是限制距离

- 多个模型投票

梯度消失和爆炸

反向梯度传播的时候是一个连乘

- 梯度小于1，一直乘消失，只更新深层，浅层基本不动

- 如果梯度大于1，一直乘爆炸。损失很跳，很大的权重导致出现na

解决

- 梯度剪切：不允许超过阈值的梯度，防止爆炸

- 正则化：限制很大的权重，限制很大的梯度

- 残差网络

- 归一化：把层的输出从饱和区拉回非饱和区

- 用ReLU这种非饱和区更大的激活函数

分割中边缘不好怎么解决

可能预先计算一个loss的权重，边缘位置给更高的loss。可以单独在网络中加入一个通路学习边缘位置，之后在高层和图片特征信息进行融合，最后联合给出分割结果

loss

BCE ![Understanding binary crossentropy / log loss a visual](https://miro.medium.com/max/1096/1*rdBw0E-My8Gu3f_BOB6GMA.png)

CE ![How to choose crossentropy loss function in Keras?  Knowledge Transfer](http://androidkt.com/wp-content/uploads/2021/05/Selection_098.png)

类别不均衡，可以根据1/类别出现频率给权重

Focal Loss ![](https://miro.medium.com/max/724/1*0iU1aPrrEydcIxyeqHLobg.png)

softmax loss = softmax + cross entropy

![](https://pic2.zhimg.com/80/v2-c3db01467ac0e926f64ba819be71d079_720w.webp)

![](https://pic4.zhimg.com/80/v2-19173d16aa9b7d655bbdea7ed43fc6eb_720w.webp)

logistic 在二分类问题上是凸的

![](https://pic3.zhimg.com/80/v2-d88c6c12d49c72bf99b2b5a23f98d012_720w.webp)

不是的分类不贡献loss，但是降低loss要是的分类更贴近1

![](https://pic3.zhimg.com/80/v2-9a41671bae385d60b4aec73450712f36_720w.webp)

预测和目标差的很大的时候容易反向的梯度很大，容易爆炸

![](https://pic1.zhimg.com/80/v2-ce83422099352b47b671598dc4cb8290_720w.webp)

零点不平滑，容易跳过最小值

![](https://pic1.zhimg.com/80/v2-c660c2f5cc622a44189937b87f9f8e24_720w.webp)

![](https://pic2.zhimg.com/80/v2-88f125f81ba05519c6ac92685713bf51_720w.webp)

![](https://pic1.zhimg.com/80/v2-3e7e3fc41f0ddf24bcbff2ddfeb0684c_720w.webp)

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-13-42-26-1671388942793.png)

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-13-43-00-1671388975665.png)

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-13-45-39-1671389135233.png)

![](https://pic3.zhimg.com/80/v2-3d243e01205e0daa8b9b5cea398cbe4a_720w.webp)

![](/home/lin/Desktop/git/blog/linhandev.github.io/assets/img/post/cv/2022-12-18-15-08-21-1671394099071.png)

EISeg最后proofread了一下



LiTS肝脏/肝脏肿瘤分割数据集

目标是用更少的权重取得更大的感受野

130训练，70提交测试，512x512xm

三个2.5D Res-UNet，分别训练

UNet跳转连接加了注意力，en/decoder里加了残差

两个竖着的面里用滑动窗口做推理，最后三个模型的结果投票

![](https://oli.cmu.edu/repository/webcontent/42d831d580020ca60119754e87e0e10c/_u1_motivation_introduction/_u1_m1_introduction/webcontent/1024px-Human_anatomy_planes.png)

![UNet — Line by Line Explanation. Example UNet Implementation | by ...](https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fmiro.medium.com%2Fmax%2F1200%2F1*f7YOaE4TWubwaFF7Z1fzNw.png&f=1&nofb=1&ipt=9a62978f3cb8092481dea3799e1c6c88af35efe6a0fbd823c2b467f71415a1ea&ipo=images)

双线性插值：大图中每个像素找小图中对应位置最近的四个点，按照距离加权平均

对不需要恢复到原始分辨率的任务，比如分类，直接加更高效。分割需要更多的精度信息选择concat

![](https://pic3.zhimg.com/80/v2-ac894dc1e42822c2cf7213899ac24062_720w.webp)



![](https://pic3.zhimg.com/80/v2-e2f8e2d02c3e18e90105dc907057362a_720w.webp)







http://cs231n.stanford.edu/





NMS

- 硬：和最高confidence的IOU大于阈值，去掉

- 软：不去掉，按照IOU降低box的confidence





is_symlink





韩霖，23岁，是辽宁大连人。本科就读于吉林大学计算机科学与技术学院，专业也是叫计算机科学与技术，现在是在纽约大学坦登工程学院读计算机工程硕士二年级，是明年5月毕业。我本硕都是学的计算机，当时选择这个方向是因为高中期间参加信息学竞赛接触了编程之后就觉得对这个非常感兴趣，我平时也很喜欢通过写代码的方式去解决一些生活中的问题和去帮助别人。

项目经历方面，我主要是在过去大概两年时间里作为百度飞桨的一个计算机视觉特别兴趣小组的成员参与了三个数据标注软件和一个深度学习套件的开发。这三个数据标注软件主要的目标都是用深度学习的方法去辅助数据标注，来降低标注过程中的工作量和提升标注质量。其中有两个是pyqt的桌面程序，一个叫EISeg，一个是给3d slicer写的一个插件，我都是主要开发者。第三个叫PaddleLabel，是一个web应用，这个项目的后端都是我写的，然后我也参与了一些前端的搭建。最后那个深度学习套件叫MedicalSeg，是一个在医学影像上进行分割的工具包，我主要是实现了一些预处理和后处理的pipeline和unet系列的几个模型。这四个项目中EISeg和PaddleLabel是通过PYPI进行分发的，他俩的下载量一个是4w7k多一个是刚过2w。

语言上我目前主要是用Python，信息竞赛期间用的c++，包括现在做题也更习惯用c++，但是用c++做大规模项目的经验还比较少。

个人能力上感觉我学习能力比较强，EISeg，PaddleLabel基本都是从头开始学习了PyQT和Web开发，这两个项目完成的都比较好，前天晚上百度那边还开了一个直播推广这两个项目。

沟通能力比较好，在做项目的过程中需要跟很多不同身份和知识背景的人沟通项目设计和实现之类的，感觉我都能比较清楚的简明的方式表达自己的意思。

最后我觉得华为是一个重视技术而且实力很强的公司，我也是非常希望能去华为工作，感觉在这个平台上会有机会做很多有意义的事情和不断提升自己。

