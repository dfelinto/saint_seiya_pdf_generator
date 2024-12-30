#!/bin/bash

# Parse the tiles argument (mandatory)
tiles=""
while getopts ":t:" opt; do
  case $opt in
    t) tiles=$OPTARG ;;
    *) echo "Usage: $0 -t <tiles>"; exit 1 ;;
  esac
done

# Validate the tiles parameter
if [[ "$tiles" != "1" && "$tiles" != "4" && "$tiles" != "9" ]]; then
  echo "Invalid tiles option. Use 1, 4, or 9."
  exit 1
fi

BUILD=build
CROPPED_IMAGES_DIR=$BUILD/cropped_images
RECTANGLES_DIR=$BUILD/rectangles
PDF_DIR=$BUILD/pdf_output
ASSEMBLED_PAGES=$BUILD/assembled_pages

# Ensure output directories exist
mkdir -p $CROPPED_IMAGES_DIR $RECTANGLES_DIR $PDF_DIR $ASSEMBLED_PAGES

# Check if we need to process images
skip_processing=true

if [ "$(find "$CROPPED_IMAGES_DIR" -type f -name '*.jpg' | wc -l)" -eq 0 ]; then
  echo "cropped_images folder is empty. Processing images..."
  skip_processing=false
fi

if [ "$(find "$RECTANGLES_DIR" -type f -name '*.png' | wc -l)" -eq 0 ]; then
  echo "rectangles folder is empty. Processing images..."
  skip_processing=false
fi

# Only process images if necessary
if [ "$skip_processing" = false ]; then
  echo "Cropping and splitting images..."
  
  # List all images in the input folder
  for img in $(find input/ -type f \( -iname "*.jpg" -o -iname "*.png" \) | sort -V); do
    if [ -f "$img" ]; then
      echo "Processing $img"

      # 1. Crop the image to 2232x3117 with a top margin of 129 and left margin of 124
      cropped="$CROPPED_IMAGES_DIR/cropped_${img##*/}"
      magick "$img" -crop 2232x3117+124+129 "$cropped"

      # 2. Split the cropped image into 9 rectangles (3x3 grid)
      rect_prefix="$RECTANGLES_DIR/rect_${img##*/}"
      rect_width=$((2232 / 3))   # Correct width for each rectangle
      rect_height=$((3117 / 3))  # Correct height for each rectangle

      for row in {0..2}; do
        for col in {0..2}; do
          x_offset=$((col * rect_width))
          y_offset=$((row * rect_height))
          rect_path="${rect_prefix}_${row}_${col}.png"

          # Crop each rectangle precisely
          magick "$cropped" -crop ${rect_width}x${rect_height}+${x_offset}+${y_offset} "$rect_path"

          # Check file size and delete if too small
          min_size=100000  # Minimum size in bytes
          file_size=$(wc -c < "$rect_path")
          if (( file_size < min_size )); then
            rm "$rect_path"
          fi
        done
      done
    fi
  done
else
  echo "Skipping cropping and splitting; images already present."
fi

# 3. Create the PDF with specified tiles per page
output_pdf="$PDF_DIR/saint_seiya_${tiles}.pdf"

# Define tile layout based on the tiles parameter
case $tiles in
  1) layout="1x1"; page_width=744; page_height=1039 ;;
  4) layout="2x2"; page_width=1488; page_height=2078 ;;
  9) layout="3x3"; page_width=2232; page_height=3117 ;;
esac

# Ensure rectangles folder has images
image_list=($(find $RECTANGLES_DIR -type f -name '*.png' | sort -V))
image_count=${#image_list[@]}

# Check if there are any images to process
if (( image_count == 0 )); then
  echo "No images found in rectangles folder. Exiting."
  exit 1
fi

# Calculate the number of pages required, rounded up
images_per_page=$((tiles))
page_count=$(( (image_count + images_per_page - 1) / images_per_page ))

# Print the message before generating the PDF
echo "Generating $page_count pages, with ${layout//x/×} tiles."

# Generate pages with a black background and fill rows from top to bottom

for ((page=0; page<page_count; page++)); do
  echo "... page $((page + 1)) / $page_count"
  start=$((page * images_per_page))
  montage_input=()

  # Collect images for this page
  for ((i=start; i<start+images_per_page && i<image_count; i++)); do
    montage_input+=("${image_list[i]}")
  done

  # Add empty placeholders if fewer images are on this page
  while (( ${#montage_input[@]} < images_per_page )); do
    montage_input+=("xc:black")
  done

  # Explicitly quote filenames in the montage command
  montage "${montage_input[@]}" \
    -tile "$layout" -geometry 744x1039+0+0 -background black \
    "$ASSEMBLED_PAGES/page_${page}.png"
done


echo "Combining all the pages"

image_files=$(find "$ASSEMBLED_PAGES" -name 'page_*.png' | sort -V | tr '\n' ' ')
magick $image_files -quality 85 -define pdf:compress=jpeg "$output_pdf"

echo "Processing complete! Check the cropped_images, rectangles, and pdf_output folders."
