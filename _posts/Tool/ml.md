# 梯度下降

损失对每个可学习参数的导数

学习率

## Batch Gradient Decent

- 每次更新用到整个batch

- 收敛速度慢

- 容易卡到局部最优解

## Stochastic Gradient Decent

- 每次更新只用一条数据

- 损失曲线比较震荡

- 更容易跳出局部最优解

## Mini-batch Gradient Decent

- 每次更新用到一批数据

## Momentum

- 之前batch的梯度每个iter$\times \gamma$累加
  
  - 小球下坡的时候加入了惯性
  
  - $\gamma$一般接近1，惯性比当前位置的梯度影响更大
  
  - 一开始的梯度很可能很大，可以逐渐提升$\gamma$

- 更容易越过局部最优解和鞍点

- 减少震荡

![no_momentum](https://paddlepedia.readthedocs.io/en/latest/_images/sgd_no_momentum.png)

![momentum](https://paddlepedia.readthedocs.io/en/latest/_images/sgd_momentum.png)

## Nesterov Accelerated Gradient

- 正常的momentum流程是计算当前位置的梯度，之后主要根据积累的梯度进行更新

- Nesterov的流程是
  
  - 首先算如果只根据累积的梯度更新的话，更新后的位置梯度是多少
  
  - 之后根据累积的梯度（棕色）和如果只用累积梯度更新后位置的梯度（红色）实际更新起点位置的梯度

![momentum](https://paddlepedia.readthedocs.io/en/latest/_images/momentum.png)

- 让下降过程更平滑

- 犯错之后改正比根据当前情况预测判断更准

## Adaptive Gradient

- 有一个全局学习率，之后对于每一个参数，实际用的学习率是$全局学习率/\sqrt{这个参数之前所有梯度历史的平方和}$
  
  - 更新多的参数学习率低
  
  - 更新少的参数学习率高

- 陡峭的地方实际学习率更小，更新更慢；平缓的地方实际学习率更大，更新更快

- 对学习率选择的依赖更低

- 学习率单调递减，后期学习率会降到很低基本是提前终止了训练





# 激活函数

评价

- 梯度爆炸

- 梯度消失

- 坏死

- 饱和

- 计算复杂度，有幂运算更慢
