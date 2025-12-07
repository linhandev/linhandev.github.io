#!/usr/bin/env python3
import os
import re
import sys

# Configuration
WORKSPACE_ROOT = os.getcwd()
POSTS_DIR = os.path.join(WORKSPACE_ROOT, '_posts')
ASSETS_IMG_DIR = os.path.join(WORKSPACE_ROOT, 'assets', 'img', 'post')

# Regex for markdown images: ![alt](url "title")
MD_IMG_REGEX = re.compile(r'!\[.*?\]\((.*?)(?:\s+".*?")?\)')
# Regex for HTML images: <img src="url" ... />
HTML_IMG_REGEX = re.compile(r'<img\s+[^>]*src=["\'](.*?)["\'][^>]*>')

def get_referenced_images():
    referenced_images = set()
    for root, dirs, files in os.walk(POSTS_DIR):
        for file in files:
            if file.endswith('.md'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                urls = []
                urls.extend(MD_IMG_REGEX.findall(content))
                urls.extend(HTML_IMG_REGEX.findall(content))
                
                for url in urls:
                    url = url.strip()
                    # Skip external links
                    if url.startswith('http') or url.startswith('//') or url.startswith('mailto:'):
                        continue
                    
                    # Normalize path to be relative to workspace root
                    # Assuming absolute paths start with /
                    if url.startswith('/'):
                        # /assets/img/post/... -> assets/img/post/...
                        normalized_path = url.lstrip('/')
                    else:
                        # Relative path: resolve relative to the post file
                        # This is tricky because we need to know how the site is built, 
                        # but usually in Jekyll _posts, relative links might be relative to the source file location.
                        # However, standard practice in this repo seems to be absolute paths.
                        # We will try to resolve it relative to the file location.
                        rel_dir = os.path.relpath(root, WORKSPACE_ROOT)
                        normalized_path = os.path.normpath(os.path.join(rel_dir, url))
                    
                    # We are only interested in images under assets/img/post
                    if normalized_path.startswith('assets/img/post/'):
                        referenced_images.add(normalized_path)
                        
    return referenced_images

def get_existing_images():
    existing_images = set()
    if not os.path.exists(ASSETS_IMG_DIR):
        return existing_images
        
    for root, dirs, files in os.walk(ASSETS_IMG_DIR):
        for file in files:
            if file.startswith('.'): # Skip hidden files like .DS_Store
                continue
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, WORKSPACE_ROOT)
            existing_images.add(rel_path)
    return existing_images

def main():
    print("Checking for dangling images in assets/img/post...")
    referenced = get_referenced_images()
    existing = get_existing_images()
    
    dangling = existing - referenced
    
    if dangling:
        print(f"\nError: Found {len(dangling)} dangling image(s) in assets/img/post (not referenced in any post):")
        for img in sorted(dangling):
            print(f"  - {img}")
        print("\nPlease remove these images or reference them in a post.")
        sys.exit(1)
    else:
        print("No dangling images found.")
        sys.exit(0)

if __name__ == '__main__':
    main()
