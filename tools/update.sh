#!/usr/bin/env bash
#
# Update the critical file from Chirpy's gem:
#
# Required:
#   - rubygems
#   - bundler
#   - jekyll-theme-chirpy

set -eu

THEME="jekyll-theme-chirpy"

THEME_PATH=""

BACKUP_PATH=".protect"

init() {
  if [[ -n $(git status . -s) ]]; then
    echo "Warning: Commit the stating files first!"
    exit -1
  fi

  bundle

  THEME_PATH="$(bundle info --path $THEME)"
}

_backup() {
  if [[ -d $BACKUP_PATH ]]; then
    rm -rf "$BACKUP_PATH"
  fi
  mkdir "$BACKUP_PATH"

  mv LICENSE README.md Gemfile Gemfile.lock tools "$BACKUP_PATH"
}

sync() {
  _gem="chirpy-gem.tar.gz"

  _backup

  rm -rf ./*

  cd "$THEME_PATH"

  tar --exclude=_includes \
    --exclude=_layouts \
    --exclude=_sass \
    --exclude=assets \
    --exclude=Gemfile \
    --exclude=README.md \
    --exclude=LICENSE \
    -zcf "$_gem" *

  cd -

  mv "$THEME_PATH/$_gem" . && tar zxf "$_gem"

  mv "$BACKUP_PATH"/* .

  rm -rf "$BACKUP_PATH"
  rm -f "$_gem"
}

main() {
  init

  sync

  if [[ -n $(git status . -s) ]]; then
    git add .
    git commit -m "[Automatic] Successfully update the theme files!"
    echo "Update success!"
  else
    echo "Already up to date."
  fi
}

main
