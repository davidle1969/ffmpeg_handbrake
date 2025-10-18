#!/bin/bash

function cleanup {
    echo -e "\nCtrl+C detected. Performing cleanup..."
    # Add any cleanup commands here
    exit 0
}

format_integer() {
    local number="$1"  # The integer to format
    local width="$2"   # Desired width (total number of digits)

    # Use printf to format the number with leading zeros
    printf "%0${width}d\n" "$number"
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
if [ "$end" -lt "$start" ]; then
    echo "Error: End value '$end' must be greater than start value '$start'."
    exit 1
fi

echo "START = ""$start"
echo "END = ""$end"


 
#for x in {002..042}; do
for x in $(seq "$start" "$end"); do

	i=$(format_integer "$x" "3")

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
		ffmpeg -hwaccel cuda -hwaccel_output_format cuda -f concat -safe 0 -i $output_file -c:v hevc_nvenc -b:v 1400k -maxrate 1800k -bufsize 3600k  $output_video
		
#		ffmpeg -f concat -safe 0 -i $output_file -c:v hevc_nvenc -cq 23 -preset p5 $output_video
		
	else
		echo "$output_video ALREADY exist"
	fi
done
