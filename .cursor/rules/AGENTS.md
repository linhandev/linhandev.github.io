# Agent Guide for Lin's Blog

This is a Jekyll static site using the [Chirpy theme](https://github.com/cotes2020/jekyll-theme-chirpy), hosted on GitHub Pages at https://linhandev.github.io.

## Repository Structure

```
├── _config.yml          # Site configuration
├── _data/               # Data files (19 .yml files)
├── _draft/              # Draft posts (not published)
├── _plugins/            # Custom Jekyll plugins
├── _posts/              # Published blog posts (organized by category folders)
├── _tabs/               # Navigation tabs (about, archives, categories, tags)
├── assets/              # Static assets (images, etc.)
├── tools/               # Build/utility scripts
└── .github/workflows/   # GitHub Actions (pages-deploy.yml)
```

## Post File to URL Mapping

Posts follow Jekyll's permalink configuration: `/posts/:title/`

### Path Pattern
```
_posts/{Category}/{YYYY-MM-DD}-{slug}.md  →  https://linhandev.github.io/posts/{slug}/
```

### Examples

| File Path | URL |
|-----------|-----|
| `_posts/LLVM/2026-01-21-Linkage.md` | https://linhandev.github.io/posts/Linkage/ |
| `_posts/Linux/2020-09-10-Arch-Install.md` | https://linhandev.github.io/posts/Arch-Install/ |
| `_posts/Linux/2021-12-13-Arch-Setup.md` | https://linhandev.github.io/posts/Arch-Setup/ |
| `_posts/KMP/2025-11-07-KN-Tricks.md` | https://linhandev.github.io/posts/KN-Tricks/ |
| `_posts/Tool/2021-01-13-Atom.md` | https://linhandev.github.io/posts/Atom/ |

### Key Points
- The **category folder** (e.g., `LLVM/`, `Linux/`, `KMP/`) does NOT appear in the URL
- The **date prefix** (`YYYY-MM-DD-`) is stripped from the URL
- Only the **slug** (filename without date and extension) becomes the URL path
- URLs always end with a trailing slash

## Post Frontmatter

Posts should have YAML frontmatter:

```yaml
---
title: Post Title
categories:
  - CategoryName
tags:
  - Tag1
  - Tag2
description: Optional description for SEO
---
```

## Heading Conventions

- Post content headings should start at `##` (h2), not `#` (h1)
- The post title from frontmatter renders as h1
- Use `##`, `###`, `####` for content sections

## IndexNow Integration

The site has IndexNow integration in GitHub Actions. When posts in `_posts/` are modified:
1. The workflow extracts the slug from the filename
2. Constructs the URL: `https://linhandev.github.io/posts/{slug}/`
3. Submits to IndexNow API for search engine indexing

API Key: `da5d430ecef74cf5ac9473d8bda82558`
Key Location: https://linhandev.github.io/da5d430ecef74cf5ac9473d8bda82558.txt

## Building Locally

```bash
bundle install
bundle exec jekyll serve
```

Site will be available at http://localhost:4000

## Deployment

Push to `main` or `master` branch triggers GitHub Actions workflow:
1. Build site with Jekyll
2. Run htmlproofer tests
3. Deploy to GitHub Pages
4. Submit changed posts to IndexNow
