#!/bin/bash

# Vars
JEKYLL_MARKDOWN_FILE=$1
JEKYLL_IMAGE_DIR=$2
HUGO_BLOG_DIR=$3

HUGO_CONTENT_DIRNAME=$(basename "$JEKYLL_MARKDOWN_FILE" | tr 'A-Z' 'a-z' | tr '_' '-' | sed 's/...$//')
HUGO_CONTENT_PARENT_DIR="$HUGO_BLOG_DIR"
HUGO_CONTENT_ROOT_DIR="$HUGO_CONTENT_PARENT_DIR/$HUGO_CONTENT_DIRNAME"
HUGO_CONTENT_IMAGE_DIR="$HUGO_CONTENT_ROOT_DIR/images"

# Copy the Jekyll markdown file (remove lines 3-7, replace "### " with "## ", and replace "[그림 " with "[Figure ")
echo "Processing markdown file $JEKYLL_MARKDOWN_FILE to Hugo..."
mkdir -p "$HUGO_CONTENT_ROOT_DIR"

cat "$JEKYLL_MARKDOWN_FILE" \
    | sed '3,7d' \
    | sed 's/### /## /g' \
    | sed 's/\[그림 /\[Figure /g' \
    | sed 's/\[파일 /\[File /g' \
    | sed 's/\[Console /\[Shell /g' \
    | sed 's/\[공식 /\[Formula /g' \
    | sed 's/{% highlight \(.*\) %}/```\1 {caption="", linenos=table}/g' \
    | sed 's/{% endhighlight %}/```/g' \
    | gsed -E 's/!\[(.*)\]\(.*\/(.*)\.PNG\).*width="([^"]*)".*/{{< figure caption="\1" src="images\/\L\2.png" width="\3" >}}/; s/_/-/g;' \
    | gsed -E 's/!\[(.*)\]\(.*\/(.*)\.PNG\).*/{{< figure caption="\1" src="images\/\L\2.png" width="900px" >}}/; s/_/-/g;' \
    > "$HUGO_CONTENT_ROOT_DIR/index.md"

# Copy Jekyll image files (only if the image directory is not empty)
if [ -n "$JEKYLL_IMAGE_DIR" ]; then
    echo "Copying image files from Jekyll to Hugo..."
    mkdir -p "$HUGO_CONTENT_IMAGE_DIR"
    cp -r "$JEKYLL_IMAGE_DIR"/* "$HUGO_CONTENT_IMAGE_DIR/"

    # After copying, check for any .pptx files and rename them to images.pptx
    if compgen -G "$HUGO_CONTENT_IMAGE_DIR/*.pptx" > /dev/null; then
        for pptx_file in "$HUGO_CONTENT_IMAGE_DIR"/*.pptx; do
            mv "$pptx_file" "$HUGO_CONTENT_IMAGE_DIR/images.pptx"
            echo "Renamed $HUGO_CONTENT_IMAGE_DIR to images.pptx"
        done
    else
        echo "No .pptx file found to rename."
    fi

    # Rename the files to lowercase and replace underscores with hyphens
    echo "Renaming image files to lowercase and replacing underscores with hyphens..."
    for img_file in "$HUGO_CONTENT_IMAGE_DIR"/*; do
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
