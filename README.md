# Chirpy

TODO
- [ ] 实现 series

根据series字段分系列，根据part字段排序
文章开头放一个下拉菜单，这篇是一个series的一篇，点击展开文章列表
左侧加一个series栏，里面用tool展示所有series

- [ ] 找md ctrl b 直接星号的插件

更新需要保留文件：
- _posts
- _drafts
- README.md
- assets/img
- tools/build.sh
- _mdwriter.cson
- _config.yml

build.sh
```shell
jekyll build

git add *
git commit -m "modify"
git push

git checkout gh-page
mv _site .site
rm -rf *
mv .site/* .
rm -rf .site

git add *
git commit -m "add"
git push

git checkout main
```


<script src="https://utteranc.es/client.js"
  repo="linhandev/linhandev.github.io"
  issue-term="title"
  label="Comment"
  theme="github-dark"
  crossorigin="anonymous"
  async>
</script>


注意标题从 ## 开始，识别h2作为toc一级标题
