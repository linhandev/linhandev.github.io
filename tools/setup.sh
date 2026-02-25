git config core.hooksPath .githooks
if command -v git-lfs &>/dev/null; then
  git lfs install
  git lfs pull
else
  echo "Git LFS is not installed. Install with:"
  echo "  brew:     brew install git-lfs"
  echo "  apt:      sudo apt install git-lfs"
  echo "  pacman:   sudo pacman -S git-lfs"
  echo "Then run this script again."
fi