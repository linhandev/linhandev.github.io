git checkout main

jekyll build

git add *
git commit -m "modify"
git push

curl -H 'Content-Type:text/plain' --data-binary @_site/overview/url.txt "http://data.zz.baidu.com/urls?site=https://linhandev.github.io&token=dpk3OOLJVr4bmarA"

git checkout gh-page
mv _site .site
rm -rf *
mv .site/* .
rm -rf .site

git add *
git commit -m "add"
git push

git checkout main
