git checkout main

jekyll build

git add *
git commit -m "modify"
git push

git checkout gh-page
mv _site .site
rm -rf *
mv .site/* .
rm -rf .site

curl -H 'Content-Type:text/plain' --data-binary @overview/url.txt "http://data.zz.baidu.com/urls?site=https://blog.linhan.ml&token=dpk3OOLJVr4bmarA"

git add *
git commit -m "add"
git push

git checkout main
