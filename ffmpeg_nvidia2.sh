#!/bin/bash

function cleanup {
    echo -e "\nCtrl+C detected. Performing cleanup..."
    # Add any cleanup commands here
    exit 0
}

trap cleanup SIGINT

source_path=""
dest_path="./"
max_size=800
bitrate=1500
maxrate=2000
bufsize=4000


encode_video()
{
	local input_file="$1"
    local output_video="$2"

	echo "Executing: $input_file $output_video"
		
	if [ ! -f "$output_video" ]; then
		ffmpeg -vaapi_device /dev/dri/renderD128 -i "$input_file" -vf 'format=nv12,hwupload' -c:v av1_vaapi -b:v "$bitrate"k -maxrate "$maxrate"k -bufsize "$bufsize"k "$output_video"
		else
			echo "$output_video ALREADY exist"
		fi
}

check_file_size() {

	
    local file="$1"

    if [ -f "$file" ]; then
        # Get the file size in bytes
        local size=$(stat -c%s "$file")
        echo "File size of '$file': $size bytes"
    else
        echo "Error: '$file' does not exist or is not a file."
    fi
}


encode_directory() 
{
	local _sourcepath="$1"

    echo "PROCESSING $_sourcepath"
	
	 # Check if the directory exists
    if [ ! -d "$_sourcepath" ]; then
        echo "Error: '$_sourcepath' is not a valid directory."
        return 1
    fi


	# Loop through each file in the directory
	for item in "$_sourcepath"/*; do
		# Check if it's a file or directory
		if [ -d "$item" ]; then
			encode_directory "$item"
        elif [ -f "$item" ]; then
            echo "$item is a file"
			filename="$(basename "$item")"
			size=$(stat -c%s "$item")
			
			filename_without_extension="${filename%.*}"
			output_video="$dest_path""$filename_without_extension"".av1.mp4"
			
			if [ "$size" -gt "$max_size" ]; then
				encode_video "$item" "$output_video"
			fi
		else
            echo "$item is neither a file nor a directory"
        fi
	done
}


# Assign parameters to variables
start=""
end=""
source_path=""
dest_path="./"
max_size=800
bitrate=1500
maxrate=2000
bufsize=4000

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -start)
            start="$2"
            shift 2
            ;;
        -end)
            end="$2"
            shift 2
            ;;
		-source)
            source_path="$2"
            shift 2
            ;;
        -dest)
            dest_path="$2"
            shift 2
            ;;
		-size)
            max_size="$2"
            shift 2
            ;;
		-bitrate)
            bitrate="$2"
            shift 2
            ;;
		-maxrate)
            maxrate="$2"
            shift 2
            ;;
		-bufsize)
            bufsize="$2"
            shift 2
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if all required parameters have been provided
if [ -z "$start" ] || [ -z "$end" ]; then
    echo "Usage: $0 -start <start> -end <end>"
    exit 1
fi

# Check if both parameters are integers
if ! [[ "$start" =~ ^-?[0-9]+$ && "$end" =~ ^-?[0-9]+$ ]]; then
    echo "Error: Both start and end must be integers."
    exit 1
fi

# Check if end is greater than start
if [ "$end" -le "$start" ]; then
    echo "Error: End value '$end' must be greater than start value '$start'."
    exit 1
fi

if [ -z "$source_path" ]; then
    echo "Usage: $0 -source <source_path>"
    exit 1
fi

# Check if the directory exists
if [ ! -d "$source_path" ]; then
	echo "Error: '$source_path' is not a valid directory."
	return 1
fi

# Check if size is an integers
if ! [[ "$max_size" =~ ^-?[0-9]+$  ]]; then
#    max_size=$((800 * 1024 * 1024))  # 800 MB in bytes
	echo "max_size not an int: $max_size"
	max_size=800	
fi

if ! [[ "$bitrate" =~ ^-?[0-9]+$ || "$maxrate" =~ ^-?[0-9]+$ || "$bufsize" =~ ^-?[0-9]+$ ]]; then
#    max_size=$((800 * 1024 * 1024))  # 800 MB in bytes
	echo "bitrate not an int: $bitrate"
	echo "maxrate not an int: ""$maxrate"
	echo "bufsize not an int: ""$bufsize"
	bitrate=1500
	maxrate=2000
	bufsize = 4000	
fi

max_size=$((max_size * 1024 * 1024)) 

echo "START = $start"
echo "END = $end"
echo "SOURCE = $source_path"
echo "DEST = $dest_path"
echo "MAX SIZE = $max_size"
echo "bitrate = $bitrate"
echo "maxrate = $maxrate"
echo "bufsize = $bufsize"

encode_directory "$source_path"


function cleanup {
    echo -e "\nCtrl+C detected. Performing cleanup..."
    # Add any cleanup commands here
    exit 0
}

trap cleanup SIGINT


# Assign parameters to variables
start=""
end=""

source_path="./backup/"
dest_path="./"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -start)
            start="$2"
            shift 2
            ;;
        -end)
            end="$2"
            shift 2
            ;;
        -source)
            source_path="$2"
            shift 2
            ;;
        -dest)
            dest_path="$2"
            shift 2
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if all required parameters have been provided
if [ -z "$start" ] || [ -z "$end" ]; then
    echo "Usage: $0 -start <start> -end <end>"
    exit 1
fi



# Check if both parameters are integers
if ! [[ "$start" =~ ^-?[0-9]+$ && "$end" =~ ^-?[0-9]+$ ]]; then
    echo "Error: Both start and end must be integers."
    exit 1
fi

# Check if end is greater than start
if [ "$end" -le "$start" ]; then
    echo "Error: End value '$end' must be greater than start value '$start'."
    exit 1
fi

echo "START = ""$start"
echo "END = ""$end"


 
#for i in {042..056}; do
for i in $(seq "$start" "$end"); do

#	output_video="InTheCrack.E$i.HEVC.mp4"

	output_file="$i.txt"
	input_file="$source_path""$i*.wmv"
#	input_file="InTheCrack.E$i.HEVC.mp4"
#	input_file="InTheCrack.E$i.*640x480.mp4"
	output_video="$dest_path""InTheCrack.E$i.hevc.nvidia.mp4"
#	output_video="InTheCrack.E0$i.hevc.mp4"

	echo "Executing: $input_file $output_file $output_video"
	
	if [ ! -f $output_video ]; then
		printf -- "file '%s'\n" $input_file > $output_file
#		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v h264_nvenc -preset:v fast $output_video
#		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v h264_nvenc -preset p1 $output_video
#		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v h264_nvenc -preset p1 -tune ll -b:v 5M -bufsize 5M -maxrate 10M -qmin 0 -g 250 -bf 3 -b_ref_mode middle -temporal-aq 1 -rc-lookahead 20 -i_qfactor 0.75 -b_qfactor 1.1 $output_video
#		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v hevc_nvenc -cq 23 -preset p5 $output_video
#		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v hevc_nvenc -cq 40 -preset p1 $output_video
		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v hevc_nvenc -b:v 1500k -maxrate 2000k -bufsize 4000k  $output_video
		
#		ffmpeg -f concat -safe 0 -i $output_file -c:v hevc_nvenc -cq 23 -preset p5 $output_video
		
	else
		echo "$output_video ALREADY exist"
	fi
done
