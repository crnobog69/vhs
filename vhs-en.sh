#!/bin/bash

set -e

check_file() {
    if [ ! -f "$1" ]; then
        echo "File $1 not found!"
        exit 1
    fi
}

check_file "td-10sec.mp4"
check_file "oldFilm1080.mp4"

get_resolution() {
    local prompt="$1"
    local resolution
    while true; do
        read -p "$prompt" resolution
        if [[ $resolution =~ ^[0-9]+:[0-9]+$ ]]; then
            echo "$resolution"
            return
        else
            echo "Invalid input. Please enter in width:height format."
        fi
    done
}

main_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 td-10sec.mp4)

read -p "Do you want to keep the main video resolution ($main_resolution)? (yes/no): " keep_main_resolution

if [[ "$keep_main_resolution" != "yes" ]]; then
    main_resolution=$(get_resolution "Enter resolution for main video (width:height, e.g., 1280:720): ")
fi

read -p "Enter frames per second (e.g., 10, 15, 24): " fps

read -p "Do you want the overlay to use the main video resolution ($main_resolution)? (yes/no): " use_main_resolution

overlay_resolution="$main_resolution"
if [[ "$use_main_resolution" != "yes" ]]; then
    overlay_resolution=$(get_resolution "Enter resolution for overlay video (width:height, e.g., 1280:720): ")
fi

apply_filter() {
    local input_file="$1"
    local output_file="$2"
    local filter_choice="$3"

    case "$filter_choice" in
        1) ffmpeg -i "$input_file" -vf curves=vintage "$output_file" ;;
        2) ffmpeg -i "$input_file" -vf format=gray "$output_file" ;;
        3) cp "$input_file" "$output_file" ;;
        4) ffmpeg -i "$input_file" -vf "colorchannelmixer=rr=1:rg=0:rb=0:gr=0:gg=0:gb=0:br=0:bg=0:bb=0" "$output_file" ;;
        *) echo "Invalid filter choice!"; exit 1 ;;
    esac
}

echo "Scaling main video to resolution $main_resolution..."
ffmpeg -i td-10sec.mp4 -vf scale=$main_resolution td-scaled.mp4

echo "Reducing frames to $fps fps..."
ffmpeg -i td-scaled.mp4 -filter:v fps=fps=$fps td-fast.mp4

echo "Choose a filter:"
echo "1. Vintage"
echo "2. Black and White"
echo "3. Normal"
echo "4. Black and Red"
read -p "Enter number (1-4): " filter_choice

echo "Applying selected effect..."
apply_filter "td-fast.mp4" "td-filtered-fast.mp4" "$filter_choice"

echo "Scaling overlay to resolution $overlay_resolution..."
ffmpeg -i oldFilm1080.mp4 -vf scale=$overlay_resolution,setsar=1:1 oldFilm-scaled.mp4

echo "Adding overlay and keeping audio..."
ffmpeg -i "td-filtered-fast.mp4" -i oldFilm-scaled.mp4 -filter_complex "[0]format=rgba,colorchannelmixer=aa=0.25[fg];[1][fg]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2[out]" -map [out] -map 0:a -pix_fmt yuv420p -c:v libx264 -crf 18 -c:a copy touchdown-final.mp4

echo "Video successfully created: touchdown-final.mp4"

rm -f td-scaled.mp4 td-fast.mp4 td-filtered-fast.mp4 oldFilm-scaled.mp4

echo "Processing complete. Temporary files removed."