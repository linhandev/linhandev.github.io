---
title: Manjaro折腾笔记
author: Lin Han
date: 2021-01-05T15:24:00.000Z
categories:
  - Linux
tags:
  - Manjaro
math: true
---

装软件的时候或多或少都会装上一些不用的东西，在加上一些其他的原因电脑容易越来越卡。个人比较喜欢干净所以最近重装了一次系统。觉得重要的地方做些记录。

# 镜像
首先万能的清华源有Manjaro的iso，下载稍快。Etcher非常适合做任何linux distro的iso，用起来很简单，一般都是一次成功。

# 开始安装
选驱动的时候不要选免费的，我这装了两回显卡驱动都不好使，休眠之后在唤醒屏幕不亮。

安装过程中我主要在格盘和装软件上有问题。
- 磁盘格式推荐ext4
- 如果软件依赖有冲突避免安装前换源

# 中文输入法
```shell
sudo pacman -S fcitx-googlepinyin
sudo pacman -S fcitx-im # 选择全部安装
sudo pacman -S fcitx-configtool # 安装图形化配置工具
# sudo pacman -S fcitx-skin-material
```
主要包括两部分，fcitx是小企鹅输入框架，所以要装fcitx的东西，如果装好之后打字的时候能看到输入框，但是框里面没有文字都是方框应该是缺中文语言包。 在开始菜单打fcitx启动之后就可以用了。

貌似所有qt4的软件都需要特殊设置，之前wps一般还是不能用fcitx的。在 /etc/profile 最后添加
```shell
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
```
但是最近WPS好像针对这个有更新，[TODO]确定一下

# vi
默认的vi键位很奇特，不熟悉的话会觉得很奇怪，一般vim对新手比较友好。
```shell
sudo pacman -S vim
```
之后可以在需要编辑东西的时候打vim或者直接在 /usr/bin 里把vi删了，用vim替代。
```shell
cd /usr/bin
sudo rm vi
ln -s vim vi
```

# yay
yay是一个十分好用的包管理工具，他是调用pacman的，命令行参数也基本一样，主要是多了aur的支持，aur里东西很多，基本用的上的软件都能找到。
```shell
sudo pacman -S yay # 安装yay
yay package_name # 如果是pacman是需要准确的包名，但是直接yay第一步是搜索，所以不需要准确
yay -S pkg_name # 和pacman一样是直接安装这个包
yay -R pkg_name # 删除一个包
yay  # 更新所有的包

vi /etc/makepkg.conf # PKGEXT 把后面的 .xz 去掉，这样本地编译的包不需要压缩直接安装，快很多
```
如果安装的过程中报一些找不到或者缺少fakeroot，build utils之类的binary，是因为缺少一些依赖，装上就好使。
```shell
sudo pacman -S base-devel
```

# 显卡相关
做深度学习和游戏开发都用到显卡，驱动也是给我折腾的死去活来。首先和驱动无关的一个软件，inxi 是查看硬件信息的，我的笔记本是一个集显一个独显(再买一定不买带集显的…..)
```shell
inxi -G
inxi -MCmdAGn
```
因为我之前已经折腾过很多次驱动，所以环境并不干净。清理环境的做法是暴力的在 添加删除软件 里面卸掉了所有名字带 nvidia optimus bumblebee 的软件，之后重启。因为有软件依赖这些东西所以一起被卸掉了，小心不要误删。

在 Manjaro 动驱动最推荐的方式是 mhwd

mhwd # 显示所有可以安装的驱动版本
sudo mhwd -i pci video-hybrid-intel-nvidia-440xx-prime # 到20年4月这个是最新的驱动
跑深度学习都需要cuda环境，之前centos+tensorflow的时候显卡是给我折腾的死去活来。这次也有点小问题但是找到了 optimus-manager ，感觉比单用bumblebee 好用。我也不是很在乎一个session的开着独显费电，一行代码搞定才省头发不是。介绍的原文在这
```shell
optimus-manager --switch nvidia  --no-confirm
optimus-manager --switch intel  --no-confirm
optimus-manager --status # 查看当前使用的显卡
```
在装cuda的时候遇到一个问题，提示 /tmp 分区的空间不够了。cuda编译过程中需要的暂存目录空间比较大。查网上的资料，cuda是可以指定这个 tempdir 的，但是编辑 buildfile 因为版本不同好像参数格式也不一样。于是尝试对 /tmp 目录做手脚。可以给 tmp 目录更大的空间，但是我这尝试了 umount 占用。于是直接简单粗暴发挥两块固态的优势，把平时存数据的固态mount 到 /tmp 上。

fdisk -l  # 先要知道要mount的盘叫什么
mount /dev/urdiskname /tmp # 注意替换盘的名称

# 亮度调节
装完显卡驱动之后终于能在本机上跑深度学习了，但是坑爹的是新的驱动下屏幕亮度调节坏了，又不想重装显卡驱动，因此通过命令行调节屏幕亮度。首先查看屏幕亮度的最大值
```shell
cat  /sys/class/backlight/intel_backlight/max_brightness
# 我这是7500
# 之后写入一个你觉得可以的值，范围是1到上面显示的最大值。注意这里可能需要却换到root执行，sudo在我这不好使
echo 800 >> /sys/class/backlight/intel_backlight/brightness
```
闪瞎双眼的亮度终于降下来了。。。

# 安装deb包
很多软件发布的时候都只提供deb和rpm这种主流distro的安装包，debtap可以作出arch的安装包之后就可以直接安装deb包了。大多数情况下是好使的
```shell
# 安装debtap
yay -S debtap

# 换源
sudo vi /usr/bin/debtap

替换：http://ftp.debian.org/debian/dists
https://mirrors.tuna.tsinghua.edu.cn/debian/dists

替换：http://archive.ubuntu.com/ubuntu/dists
https://mirrors.tuna.tsinghua.edu.cn/ubuntu/dists/

# 第一次用一般需要更新
sudo debtap -u

# 这一步会将deb的包转换成pacman的包
sudo debtap  xxxx.deb

# 利用pacman安装
sudo pacman -U x.tar.xz
```

# 磁盘挂载
https://www.cnblogs.com/along21/p/7410619.html
function md() {
        sudo mount /dev/nvme1n1p1 /data/
}

# 声音
发现电脑外放音量正常，但是插耳机或者连蓝牙都没声。肯定是驱动或者设置的问题，网上找到一个方案

echo "options snd-hda-intel model=auto" >> /etc/modprobe.d/alsa-base.conf
之后重启，插线应该就好使了。如果连接蓝牙之后还是在外放声音，打开Volume Control，里面的output device看看是不是设成 Headphone(Unplugged)，可能只是电脑没有把声音交给蓝牙耳机。

可能有时候看的视频声音特别小，这个插件可以让音量超过100%，慎用可能损坏硬件，但是如果你确定音量全程都很小问题不大
```shell
yay xfce4-pulseaudio-plugin
```

# 数学
mathpix可以截屏识别数学公式，打印的基本都没问题，手写的公整也可以。

```shell
yay mathpix
```
mathpix是需要截屏的，如果是想直接用鼠标写然后识别可以用myscript网页版

画函数图像可以用desmos

不同设备之间发送文字可以用 clipboard.ninja

# Conda


# 软件
freedownload manager下载很方便
