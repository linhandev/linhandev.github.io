---
title: Jekyll折腾笔记
author: Lin Han
date: 2019-08-08 11:33:00 +0800
categories: [Tool]
tags: [Blog, Jekyll]
math: true
image: /assets/img/sample/devices-mockup.png
---
这个Post记录Github Page的折腾过程。目标是用比较**简单**和**鲁棒**的方法**快速**部署一个**功能齐全**的博客。首先一点背景知识：[Jekyll](https://jekyllrb.com/)是一个从文字生成静态网站的工具，ruby编写。Github Page 是 Github 推出的静态网站托管服务，每个用户有一个Repo可以放静态网页文件，Github提供免费托管，用户可以通过一个网址访问。这里注意Github Page托管的是静态网页，不是Jekyll主题的那些文件(所以也是可以自己写一个静态的网页扔到Github上展示的，不一定要用Jekyll)。这两者组合就可以零成本部署一个个人博客。

# 主题选择
一个博客最明显的特征应该就是主题，选择一个功能丰富的主题可以省去自己一点点添加功能的麻烦。有很多Jekyll主题列表网站比如
- https://jekyllthemes.dev/
- http://jekyllthemes.org/
- http://themes.jekyllrc.org/
里面的主题大多数是免费的，可以上去逛一逛。

我们要做的事情，使用Jekyll将主题文件编译成静态网站并在Github上托管，其中编译这一步有三种实现方式：
1. Github 编译
2. Github Action 编译
3. 本地编译

这块有点复杂，自己也没完全研究明白。个人理解大致上是第一种和第二种都是使用Github Action进行的编译，只是第一种是用Github官方提供的Action脚本和ruby环境，包含的gem包比较少，所以大部分的主题会因为缺依赖编译失败。第二种自己写Action可以自己写GemFile，构建一个自己的环境，应该可以编译所有主题，但是操作起来蛮复杂。最恶心的是Github Action不会提供详细的 Jekyll 编译报错，这样如果出错只能看到是Jekyll编译失败了，不好Debug具体是什么问题。本地编译个人认为是最靠谱的，环境装起来并不复杂，能看到完整报错，本地编译完成就可以看到效果，不需要推到Github看效果，直接推静态网页上Github不需要写复杂的编译Action，而且推完基本立即生效，Action编译还是比较慢的，大概1~5分钟。

# 安装环境
这里记Arch Linux的步骤，其他系统参考官方[安装文档](https://jekyllrb.com/docs/installation/)
```shell
sudo pacman -S ruby base-devel
```
安装的过程中遇到小问题，pacman下清华源几个文件一直失败。解决的方法是上清华源的网站，直接下载对应的安装包文件之后安装。装好ruby之后换源，安装jekyll，bundle需要的gem包。
```shell
# 添加 TUNA 源并移除默认源
gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/ --remove https://rubygems.org/
# 列出已有源
gem sources -l
# 应该只有 TUNA 一个
gem install jekyll bundler
bundle
jekyll # 测试安装是否正确
# 头两行输出应该是
# A subcommand is required.
# jekyll 4.2.0 -- Jekyll is a blog-aware, static site generator in Ruby
```
如果上面最后一行输出的是找不到 jekyll 命令，那应该是可执行文件路径里没有gem中的bin文件夹，仔细看看gem安装的输出应该针对这个问题有提示，把路径添加到PATH变量里就行。比如我这Manjaro下路径是 ~/.gem/ruby/2.7.0/bin
```shell
export PATH=$PATH:~/.gem/ruby/2.7.0/bin # 先试一下路径对不对
jekyll
# 如果输出正确了就把这行写到 ~/.bashrc 里，这样打开一个新命令行依旧有效
echo 'export $PATH=$PATH:~/.gem/ruby/2.7.0/bin' >> ~/.bashrc # 必需单引号，双引号变量会替换成值
```
到这应该就配置好环境了，尝试编译网站，默认的静态网站输出路径是 _site
```shell
jekyll build
```

git push --set-upstream origin gh-page

# 评论
给文章添加评论功能有很多种方案，但是所有添加评论的方案都不可能是纯静态的，所以光靠Github Page是实现不了。一些可能的方法包括
- 用Github的hook
- 自己搭建一个评论服务器
- 用第三方的评论服务
这里选择的是第三方服务[hyvor](https://talk.hyvor.com/)，比较了几家这个价格最合适。直接将评论的代码插入到文章模板最下面就行

todo:补上具体步骤

# 自定义域名
配置完Github Page直接就有一个域名可以用，但是如果你希望用自己的域名也可以。在 Setting 里面设置域名，之后将这个域名解析到 username.github.io 就可以。但是用自己的域名 enforce HTTPS 会复杂一些。

在从自定义域名转换回 Github 给的免费域名过程中遇到一点麻烦，输入免费域名总是直接跳转到之前解析的自己的域名，之后页面显示Github的404。 后来翻文档发现需要清浏览器cache，清除之后就好使了。

# 搜索
跟评论一样，搜索也需要是静态的，大概有两种方式，可以通过谷歌或者百度的站内搜索实现，也可以将文章的信息写入js，在js中直接实现搜索，这样不依赖任何服务。

js实现可以直接使用lunr.js，缺点是lunr.js目前没有中文支持，所有中文内容一概搜不到。教程参考

# 目录
文章比较长的时候有一个目录是很方便的，这个 项目的目录只能放在文章最顶上，不能和页面一起滚，但是用起来十分简单，而且是纯liquid的所以不需要gem。

# 图床
在markdown中插入图只要按照  格式就可以，在本地类似Typora的编译器或者网页中都能正常显示，问题是这个链接怎么搞。其实有github page就不需要图床了，直接在github page里开个一文件夹，图片文件放进去，push上去之后就有链接了。但是这种方法难免有点复杂，有很多免费的图床可以用，我这选择的是国内可以使用，基本没有数量限制的sm.ms。

# 数学公式
