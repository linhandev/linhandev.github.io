---
title: Arch Linux 安装后配置
categories:
  - Linux
tags:
  - Linux
  - Arch
pin: true
---

这篇记录一些新做 Arch Linux 系统之后常用的设置和常装的软件。

# btrfs

如果用了 btrfs 可以考虑保留一个刚安装完系统的快照。这里默认子卷的结构按照[安装教程](https://linhandev.github.io/posts/Arch-install/#btrfs)。snapper 默认要用 dbus，如果还在 chroot 里需要重启进系统跑下面的命令。

![image](https://user-images.githubusercontent.com/29757093/155235420-f2d24eec-2e0c-4bc3-a0f6-e789eba1e6d8.png)

```shell
su root
pacman -S snapper
umount /.snapshots
rm -rf /.snapshots
snapper -c root create-config /
vim /etc/snapper/configs/root
# ALLOW_USERS='[用户名]'
# todo 最后的期限限制
chmod a+rx /.snapshots # 让所有用户对镜像都有读写权限

systemctl start snapper-timeline.timer
systemctl enable snapper-timeline.timer
systemctl start snapper-cleanup.timer
systemctl enable snapper-cleanup.timer
systemctl start grub-btrfs.path # 开机grub里可以选重启到哪个快照
systemctl enable grub-btrfs.path

snapper -c root list
snapper -c root create --description BeforeGui
```

快照会创建在/.snapshot 路径下，下面文件夹名字是这个快照的编号

![image](https://user-images.githubusercontent.com/29757093/155236257-7c9becf3-2ab6-42a2-b561-25a742fc9ffa.png)

可以看到虽然快照下有 home 目录，/home 里面也有东西，但是快照里 home 是空的。

全系统 rollback。Arch 推荐从启动盘进行全系统 rollback，首先重启进入启动盘

```shell
mount /dev/[btrfs的任意一个分区] /mnt
less /mnt/@snapshots/*/info.xml # 查看所有镜像的信息
# 下面需要删除当前的文件，可以把当前的文件mv到另一个地方，我一般直接删除
# mv /mnt/@ /mnt/@.old
rm -rf /mnt/@
btrfs subvol snapshot /mnt/@.snapshots/[要rollback到的snapshot编号]/snapshot /mnt/@
reboot
```

# 权限

sudo 使用非常广泛，但是通常在个人电脑的场景下 sudo 的用途只是让一个用户可以作为 root 执行命令，就这个使用场景来说 sudo 比较杀鸡用牛刀。doas 不一定比 sudo 安全，但是精简很多

```shell
su root
pacman -S opendoas
# 允许 用户名 作为root执行命令，persist是一次输入密码之后一段时间内不会重新要密码
echo "permit persist [用户名] as root" >> /etc/doas.conf
# 用 doas 替换 sudo
cd /usr/bin
mv sudo sudo-bk
ln -s doas sudo
sudo #
doas ls # 测试配置是否正确
```

我这么用了大概小一年的时间，基本没有遇到必须用 sudo，doas 不行的情况。如果遇到可以通过修改 /usr/bin/sudo 软链接或者直接重装 sudo 进行暂时恢复。

# 包管理

## yay

yay 是个很有用的包管理工具，使用方法跟 Arch 自带的 pacman 基本完全相同，主要是加入了对 AUR 的支持。在 AUR 里基本能找到所有常用的软件。下面的命令安装 yay

```shell
cd
doas pacman -Syyu # 全系统更新
doas pacman -S git
git clone https://aur.archlinux.org/yay.git # 下载yay代码
cd yay
makepkg -si # 编译并安装
yay # 测试安装，更新所有的包

doas vim /etc/makepkg.conf # 把 PKGEXT .pkg.tar 后面的 .zst 或者 .xz 之类的后缀去掉，这样本地编译的包不需要压缩直接安装，快一些
```

本地编译代码通常都需要 base-devel。如果从源码编译的过程中报一些类似缺少 fakeroot，build utils 之类的错，跑下面的命令装一下

```shell
doas pacman -S base-devel
```

基本用法，注意包名是区分大小写的，一般都是小写

```shell
yay package_name # 不写 -S 的时候是进行搜索，从搜索结果中选具体装哪个
yay -S pkg_name # 写 -S 和 pacman 一样是直接安装这个包
yay -R pkg_name # 删除一个包
yay -Q # 列出所有已安装的包
yay -Q | grep pacma* # -Q应该是不支持通配符，用 grep 和 * 比较方便
```

yay 和 pacman 都默认不在任何情况下自动清理下载的安装包，所以这些文件可能越积越多。清理 pacman 和 yay 的 cache 可以用

```shell
yay -Scc
```

<!-- TODO: mamba -->

[参考](https://herbort.me/posts/automatically-cleaning-pacman-and-yay-cache-in-arch-linux/)

## 镜像测速

全球有很多 pacman 软件库的镜像，选一个快的能节省不少下载时间。reflector 可以按速度对镜像排序，也可以定时执行

```shell
doas pacman -S reflector rsync curl
doas cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
doas reflector --latest 20 --country China --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

一般镜像的速度不会变得很频繁，但是 reflector 也是可以定时更新镜像列表的。首先把参数写入配置文件

```shell
echo """
--latest 20
--country China
--protocol https
--sort rate
--save /etc/pacman.d/mirrorlist
""" | doas tee /etc/xdg/reflector/reflector.conf
doas systemctl enable reflector
doas systemctl start reflector.timer
doas systemctl enable reflector.timer
```

默认配置是每周执行一次，可以在配置文件里指定这个周期，比如把 OnCalendar 改成 daily，之后需要重新加载配置文件

```shell
doas vim /usr/lib/systemd/system/reflector.timer
doas systemctl daemon-reload
doas systemctl status reflector.timer # Trigger: 可以看到还有多久下次执行
```

![image](https://user-images.githubusercontent.com/29757093/152112943-c3214b28-4915-46d7-9f3d-e5ba63e33584.png)

# 密码管理

[pass](https://www.passwordstore.org/)是一个不错的选择，加密基于 gpg，生态丰富，在不同平台和浏览器上都有 gui 或插件。

```shell
yay -S pass qtpass # 密码管理工具和gui
```

此外[passff](https://github.com/passff/passff)是一个在 Firefox, LibreWolf 中自动填充密码的浏览器插件，需要安装[插件](https://addons.mozilla.org/en-US/firefox/addon/passff/)和一个[本地 app](https://github.com/passff/passff-host)

本地 app 安装用下面的命令，用哪个浏览器最后写哪个就行

```shell
curl -sSL github.com/passff/passff-host/releases/latest/download/install_host_app.sh | bash -s -- [firefox|librewolf|host app支持其他浏览器，但是貌似还没有插件]
```

# 浏览器

## Firefox

LibreWolf 是基于 Firefox 的一个关注隐私的浏览器，用起来体验和 Firefox 差别不大。默认关浏览器后就清 cookie 所以网站会要求重新登陆，结合密码管理插件并不很影响使用体验。大多数 Firefox 的设置都是在的，可以根据自己的需要开启，比如保存浏览历史或者针对一些/所有网站关浏览器不清除 cookie。

```shell
yay -S librewolf-bin
```

## Chrome

chromium 阵营 Brave 和 Vivaldi 貌似风评都不是很好，有一个开源的选择 ungoogled-chromium。不过默认设置和 chrome 差不多，想要一些隐私保护的功能都要自己开，用 web store 也不是很方便。

```shell
yay -S ungoogled-chromium
```

# 中文输入法

如果中文都显示成麻将那是缺少中文自体，在系统语言中添加中文

```shell
doas vi /etc/locale.gen
# 按 / 搜索，输入 zh_CN.UTF8 UTF8，回车找到这一行
# 将这一行前面的 # 去掉
# 输入 :wq 保存并退出

doas locale-gen
```

安装中文字体

```shell
doas pacman -S noto-fonts-cjk
```

安装 fcitx5

```shell
doas pacman -Rs $(pacman -Qsq fcitx) # 删除已有fcitx
doas pacman -S fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-chinese-addons
```

```shell
mkdir ~/.config/fcitx5
```

修改 `~/.config/fcitx5/profile`

```shell
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=pinyin

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=pinyin
# Layout
Layout=

[GroupOrder]
0=Default
```

对于 wayland 图形系统，在 `~/.pam_environment` 中添加

```shell
GTK_IM_MODULE DEFAULT=fcitx5
QT_IM_MODULE DEFAULT=fcitx5
XMODIFIERS DEFAULT=@im=fcitx5
```

对于 x 图形系统，在 `~/.xprofile` 和 `~/.xinitrc`中添加

```shell
export XIM="fcitx5"
export XIM_PROGRAM="/usr/bin/fcitx5"
export GTK_IM_MODULE="fcitx5"
export QT_IM_MODULE="fcitx5"
export XMODIFIERS="@im=fcitx5"
export QT_QPA_PLATFORM="xcb"
export GDK_BACKEND="x11"
```

安装完成，启动 fcitx。可以在命令行输入

```shell
xfce4-appfinder
```

之后打 fcitx5，就可以启动。或者直接在命令行输入

```shell
fcitx5
```

<!--
皮肤
https://github.com/hrko/fcitx-skin-material
(TODO:material color)
-->

# 声音

Linux 的[声音系统](https://wiki.archlinux.org/title/Sound_system)分两层，驱动和声音服务器(Sound Server)。驱动有两个选择，ALSA 和 OSS。ALSA Arch 安装自带，OSS 因为闭源过了一段时间整体上看赶不上 ALSA。

<!-- https://linuxhint.com/pulseaudio_arch_linux/ -->

```shell
doas pacman -S pulseaudio pavucontrol
```

pulse audio 默认的配置在蓝牙设备连接之后不会自动切换到蓝牙设备，每次都需要打开 audio mixer 手动选。修改配置开启自动切换

```shell
echo "load-module module-switch-on-connect" | doas tee -a /etc/pulse/default.pa
```

重启 pulse audio 比较麻烦，可以登出一下重新进来。

## 蓝牙

<!-- https://www.jeremymorgan.com/tutorials/linux/how-to-bluetooth-arch-linux/ -->

```shell
doas pacman -Sy bluez bluez-utils blueman
doas systemctl start bluetooth.service
doas systemctl enable bluetooth.service
yay -S pulseaudio-bluetooth
```

打开 bluetooth manager 会自动在面板上添加一个 widget。如果蓝牙是关闭状态搜索 bluetooth adapter 可以打开。

<!-- ### 降噪
https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Modules/#module-echo-cancel
https://askubuntu.com/questions/18958/realtime-noise-removal-with-pulseaudio

麦克
https://fedoramagazine.org/real-time-noise-suppression-for-video-conferencing/
https://www.linuxuprising.com/2020/09/how-to-enable-echo-noise-cancellation.html
https://www.reddit.com/r/linux/comments/2yqfqp/just_found_that_pulseaudio_have_noise/
https://askubuntu.com/questions/18958/realtime-noise-removal-with-pulseaudio
https://www.linuxuprising.com/2021/02/noisetorch-is-real-time-microphone.html

Remove Background Noise Using Audacity and Kdenli
 https://www.youtube.com/watch?v=3nMkMn4--5w -->

<!-- ## jack 低延迟 -->

<!-- https://madskjeldgaard.dk/posts/audio-setup-arch-2021/ -->

<!-- ```shell
yay -S reaper-bin sws supercollider sc3-plugins jack2 mpv sox qjackctl pulseaudio-bluetooth pulseaudio-jack pulseaudio njconnect flac cadence alsa-firmware alsa-plugins alsa-utils

doas pacman -S realtime-privileges
doas groupadd realtime
doas usermod -a -G realtime $USER

cat /proc/sys/vm/swappiness
doas sysctl vm.swappiness=10

yay -S tuned
doas systemctl start tuned.service

# Rule for when switching to battery
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0" RUN+="/usr/bin/tuned-adm profile laptop-battery-powersave"
# Rule for when switching to AC
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1" RUN+="/usr/bin/tuned-adm profile latency-performance"

alias cpu-max='tuned-adm profile latency-performance'
alias cpu-balanced='tuned-adm profile balanced'
alias cpu-min='tuned-adm profile laptop-battery-powersave'

git clone https://codeberg.org/rtcqs/rtcqs.git
cd rtcqs
./rtcqs.py
```

```shell
doas systemctl --user stop pulseaudio.socket
doas systemctl --user stop pulseaudio.service
doas systemctl start tuned.service

doas sysctl vm.swappiness=10
cat /proc/sys/vm/swappiness

cpu-max
```

```shell
doas systemctl stop tuned.service
doas systemctl --user start pulseaudio.socket
doas systemctl --user start pulseaudio.service

doas sysctl vm.swappiness=60
cat /proc/sys/vm/swappiness

cpu-balanced
``` -->

<!-- ```shell
doas pacman -S pulseaudio pavucontrol
yay -S xfce4-pulseaudio-plugin
``` -->

# shell

## zsh

```shell
doas pacman -S zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

# 快捷键

在 app finder 里搜 keyboard 可以找到键盘设置，一些有用的快捷键

```shell
xfce4-terminal --drop-down # 从屏幕顶部滑下来一个命令行，比较方便，一般可能会设成Alt + `
xfce4-appfinder # 打开程序搜索
thunar # 文件浏览器
xkill # 强制关闭，对付卡死的窗口
```

还有一个设置在 window manager 里，正常关闭一个窗口也比较有用

<!-- ## 通知插件 -->

<!-- ## panel
[恢复默认](https://askubuntu.com/questions/224006/resetting-xfce-panels-to-default-settings)
网络，性能监控 -->

# 软件

## 百度网盘

百度网盘有 deb 的包但是 debtap 过来跑不起来，这个包是 web 版的封装，有 4G 上传大小的限制。

```shell
yay -S baidunetdisk-electron
```

另一个选择是 baidupcs，个人感觉在 Arch Linux 上比官方客户端好用

```shell
yay -S baidupcs
```

<!-- "TODO: baidupcs登陆和使用" -->

## 微信

deepin-wine-wechat 依赖 Multilib 里的一些 32 位库，Arch Linux 默认不搜索 Multilib，开了之后才能安装

```shell
doas vim /etc/pacman.conf
```

找到下面两行，把前面的 # 删掉

```shell
#[multilib]
#Include = /etc/pacman.d/mirrorlist
```

之后更新本地仓库，安装微信

```shell
yay
yay -S deepin-wine-wechat # 之后一路回车选择默认就行
```

在不用时间不同地点从腾讯下载微信可能得到的安装包不是完全相同的，通常哈希值校验失败不是大问题。下面这行安装可以跳过哈希校验

```shell
yay -S --mflags --skipinteg deepin-wine-wechat
```

## 腾讯会议

是一个旧版本的腾讯会议 ubuntu 包，主要的缺点是不能接受别人在屏幕上标画，个人没有遇到其他使用上的问题。

```shell
yay -S wemeet-bin
```

## 录屏

```shell
yay -S simplescreenrecorder
```

## 虚拟机

做 Windows 虚拟机首先需要一个 Windows iso，可以从[微软官网](https://www.microsoft.com/en-us/software-download/windows11)或[msdn](https://next.itellyou.cn/)下。msdn 的 BT 链接可以先用百度网盘的离线下载下到网盘，之后下到本地。

host 这边选择用 qemu 做虚拟机，更新系统安装软件

```shell
doas pacman -Syy
# 如果更新linux内核版本了需要重启才能生效

doas pacman -S archlinux-keyring
doas pacman -S qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat
doas pacman -S ebtables iptables
doas systemctl start libvirtd
```

默认 virt-manager 可能需要 root 权限才能运行，修改 /etc/libvirt/libvirtd.conf，让他可以在用户权限下运行

```shell
doas vi /etc/libvirt/libvirtd.conf

# unix_sock_group = "libvirt"
# unix_sock_rw_perms = "0770"

newgrp libvirt
doas usermod -a -G libvirt $(whoami)
doas systemctl restart libvirtd
```

把下好的 iso 文件挪到 /var/lib/libvirt/images 文件夹下

```shell
doas mv [下载好的windows iso路径] /var/lib/libvirt/images
```

之后打开 Virtual Machine Manager，按照提示一步一步安装即可。

TODO:具体步骤截图

安装好 windows 后 host 和 client 的剪切板是不能共享的，有时候可能不太方便。可以在 windows 里装一个 spice-guest-tools，host 上不需要额外装软件就可以实现双向剪切板共享。下载地址： https://www.spice-space.org/download.html

![spice-clipboard](/assets/img/post/Linux/spice-clipboard.png)

点那个 spice-guest-tools 下载，之后安装。

<!-- "TODO: https://dausruddin.com/how-to-enable-clipboard-and-folder-sharing-in-qemu-kvm-on-windows-guest/#Solution_Clipboard_sharing" -->

如果只是偶尔在 host 和 guest 之间传个文件可以用[sharedrop.io](https://sharedrop.io)这种局域网传文件的工具或者上网盘绕一圈。如果传的比较频繁可以考虑装一个 samba。windows 和 mac 都内置了对 samba 的支持，linux 的 host 需要安装和配置一下。

```shell
doas pacman -S samba # 安装samba
```

```shell
cd /etc/samba
doas vi smb.conf
```

arch 上安装 samba 不带默认的配置文件，打开这个官方的[配置文件样例](https://git.samba.org/samba.git/?p=samba.git;a=blob_plain;f=examples/smb.conf.default;hb=HEAD)，粘到刚才 vi 的 smb.conf 里。

按照下面格式在文件末尾添加一个网络共享

```shell
[smbarch]
comment = smbarch
path = /absolute/path/to/share # 这里一定要用绝对路径，相对的不行
writable = yes
browsable = yes
create mask = 0700
directory mask = 0700
read only = no
guest ok = no
```

默认配置给的 log 路径 categories:

Linux
tags:

Arch

Manjaro

Software

Tutorial 是没有写入权限的，找到 log file 这一行改成下面这个路径

```shell
log file = /var/log/samba/%m.log
```

最后添加 samba 用户组，创建要分享的目录并修改权限

```shell
doas groupadd -r smbuser
doas usermod -aG smbuser $(whoami)

doas smbpasswd -a lin

mkdir /path/to/share
doas chown -R :smbuser ~/Desktop/samba/
doas chmod 1770 ~/Desktop/samba/
doas systemctl start smb
doas systemctl start nmb
```

之后在 windows 中右键我的电脑，点添加网络位置，地址按照 //ip/smbarch 这个格式写。host 的 ip 可以用 ip a 查到，不是环回的 127.0.0.1，而且是一个局域网地址，比如 192.168. ...这种

添加成功后输入用户名密码就能看到文件了。

## Docker

```shell
doas pacman -S docker # 安装
doas systemctl start docker.service # 启动
# doas systemctl enable docker.service # 开机自启
doas usermod -aG docker $USER # 添加组
```

<!-- "TODO: non root access" -->

完全删除

```shell
rm -rf /var/lib/docker
yay -R docker
```

```shell
FROM ubuntu

ARG USERNAME=lin
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

# [Optional] Set the default user. Omit if you want to keep the default as root.
USER $USERNAME
```

```shell
yay -S nvidia-container-toolkit
docker build . -t cuda
```

查看 cuda 版本

```shell
nvcc --version
```

```shell
docker pull
docker image ls
docker run
docker ps
docker restart
docker stop
docker commit [CONTAINER ID] [new name]
```

[gui docker](https://github.com/HarGit14/dorowu-docker-ubuntu-vnc-desktop)

# 压缩

## zip

```shell
doas pacman -S unzip zip
```

# 开发

## miniconda

从[miniconda 官网](https://docs.conda.io/en/latest/miniconda.html)下载对应的安装脚本，比如 x86 的机器安装脚本应该叫 `Miniconda3-latest-Linux-x86_64.sh`。之后进行安装

```shell
bash [刚下载的安装脚本]
```

按照指引安装就行。“Do you wish the installer to initialize Miniconda3 by running conda init? [yes|no]” 我会选 yes，启动比较方便。安装完成后需要退出当前的命令行重新开一个，看到 prompt 最前面有一个 (base) 就是安装成功了。

"TODO:基本使用"

基本使用

```shell
conda create -n [名字] python=3.9
conda activate [名字]
```

## micromamba

```shell
curl micro.mamba.pm/install.sh | zsh

cat > ~/.mambarc << EOF
channels:
  - conda-forge
always_yes: false
EOF

```

## vscode


# 手机

用 usb 在 Arch 和 Android 之间传文件需要 MTP(Media Transfer Protocol)的支持，Arch 默认是不装这个的。

"REF: https://linuxhint.com/connect-android-arch-linux/"

```shell
doas pacman -S mtpfs jmtpfs gvfs-mtp # android 4+ 需要第二个包
doas pacman -Sy gvfs-gphoto2 # 照片传输支持
```

清理 arch

https://averagelinuxuser.com/clean-arch-linux/

重启文件浏览器

thunar -q && thunar

https://linuxhint.com/guide_linux_audio/

<!-- # raid

fio --name TEST --eta-newline=5s --filename=temp.file --rw=read --size=100m --io_size=2g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting

fio --name TEST --eta-newline=5s --filename=temp.file --rw=write --size=100m --io_size=2g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting

fio --name TEST --eta-newline=5s --filename=temp.file --rw=read --size=100m --io_size=2g --blocksize=2k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting

fio --name TEST --eta-newline=5s --filename=temp.file --rw=write --size=100m --io_size=2g --blocksize=2k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting -->

# 多内核

Arch 默认的 Linux 内核叫 linux，这个内核一直是最新的。Arch 还有其他几个内核选择

- linux-lts：长期支持，版本旧一点，比 linux bug 少
- linux-hardened：强调安全，一些包可能不能用
- linux-zen：最新内核，经过微调。更强调低延迟，更耗电，throughput 比 linux 差

```shell
uname -r # 查看当前内核版本

# 安装内核，用哪个装哪个
doas pacman -S linux-lts
doas pacman -S linux-hardened
doas pacman -S linux-zen
doas grub-mkconfig -o /boot/grub/grub.cfg # 重新生成grub配置文件
```

到这就完事了，切换内核需要重启，之后在 grub 界面进 advanced options，选想用的内核就行。

此外可以修改 grub 配置让 Arch 记住上次选择的内核，下次开机自动选择。

```shell
doas vim /etc/default/grub

# GRUB_DISABLE_SUBMENU=y # 禁用子菜单，所有内核都直接显示
# GRUB_DEFAULT=saved # 默认上次选择的内核
# GRUB_SAVEDEFAULT=true # 记录上次选择的内核
doas grub-mkconfig -o /boot/grub/grub.cfg # 之后还是要重新生成grub配置文件
```

![arch advanced options](/assets/img/post/Linux/arch-advanced-options.png)

参考：[Different Types of Kernel for Arch Ldockinux and How to Use Them](https://itsfoss.com/switch-kernels-arch-linux/)

"TODO:和虚拟机放一起"



# zram

`/etc/systemd/zram-generator.conf`

```shell
[zram0]
zram-size = ram
[zram1]
zram-size = ram
```

# Prime

```shell
yay -S nvidia-prime
prime-run steam
```

# rclone

rclone listremotes

rclone rcd --rc-web-gui --rc-pass [password]
