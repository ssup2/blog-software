#!/bin/bash

# Vars
JEKYLL_MARKDOWN_FILE=$1
JEKYLL_IMAGE_DIR=$2
HUGO_BLOG_DIR=$3

HUGO_CONTENT_DIR="$HUGO_BLOG_DIR"
HUGO_IMAGE_DIR="$HUGO_BLOG_DIR/images"

# Copy the Jekyll markdown file (remove lines 3-7, replace "### " with "## ", and replace "[그림 " with "[Figure ")
echo "Processing markdown file $JEKYLL_MARKDOWN_FILE to Hugo..."
mkdir -p "$HUGO_CONTENT_DIR"
awk 'NR < 3 || NR > 7' "$JEKYLL_MARKDOWN_FILE" | sed 's/^### /## /g' | sed 's/\[그림 /\[Figure /g' > "$HUGO_CONTENT_DIR/index.md"

# Copy Jekyll image files (only if the image directory is not empty)
if [ -n "$JEKYLL_IMAGE_DIR" ]; then
    echo "Copying image files from Jekyll to Hugo..."
    mkdir -p "$HUGO_IMAGE_DIR"
    cp -r "$JEKYLL_IMAGE_DIR"/* "$HUGO_IMAGE_DIR/"

    # After copying, check for any .pptx files and rename them to images.pptx
    if compgen -G "$HUGO_IMAGE_DIR/*.pptx" > /dev/null; then
        for pptx_file in "$HUGO_IMAGE_DIR"/*.pptx; do
            mv "$pptx_file" "$HUGO_IMAGE_DIR/images.pptx"
            echo "Renamed $pptx_file to images.pptx"
        done
    else
        echo "No .pptx file found to rename."
    fi

    # Rename the files to lowercase and replace underscores with hyphens
    echo "Renaming image files to lowercase and replacing underscores with hyphens..."
    for img_file in "$HUGO_IMAGE_DIR"/*; do
        if [ -f "$img_file" ]; then
            # Get the file path with lowercase and underscores replaced by hyphens
            new_img_file=$(echo "$img_file" | tr 'A-Z' 'a-z' | tr '_' '-')
            mv "$img_file" "$new_img_file"
            echo "Renamed $img_file to $new_img_file"
        fi
    done
else
    echo "No image directory provided, skipping image copy..."
fi
