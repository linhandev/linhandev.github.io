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
