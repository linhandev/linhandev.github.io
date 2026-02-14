# Git hooks

- **pre-commit**: Rewrites relative image paths in staged markdown (e.g. `../../assets/img/post/...`) to root-relative (`/assets/img/post/...`) so Jekyll and HTML-Proofer work correctly.

## Enable hooks (one-time)

From the repo root:

```bash
git config core.hooksPath .githooks
```

After this, the pre-commit hook runs automatically on every commit.
