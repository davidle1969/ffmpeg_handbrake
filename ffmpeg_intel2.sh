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
extensions_array=""
encoder="vaapi"
codec="av1"
src_bitrate=0


encode_video()
{
	local input_file="$1"
    local output_video="$2"
#	local src_bitrate="$3"	

	echo "Executing: $input_file $output_video $src_bitrate"
		
	if [ ! -f "$output_video" ]; then
		if [[ "$encoder" == "qsv" ]]; then
		
			local Encoder="h264_qsv"
			case "$codec" in
				h264)
					Encoder="qsv_h264"
#					Encoder="h264_qsv"
#					preset="intel_qsv_h264"
					;;
				hevc)
					Encoder="qsv_h265"
#					Encoder="hevc_qsv"
#					preset="intel_qsv_hevc"
					;;
#				vp9)
#					Encoder="vp9_qsv"
#					preset="intel_qsv_vp9"
#					;;
				h265)
					Encoder="hevc_vaapi"
#					Encoder="hevc_qsv"
#					preset="intel_qsv_hevc"
					;;
				av1)
					Encoder="qsv_av1"
#					Encoder="av1_qsv"
#					preset="intel_qsv_av1"
					;;
				*)
#					Encoder = "copy"
					Encoder="qsv_h264"
					;;
			esac
			echo "Encoding with $encoder $Encoder"
			/media3/Multimedia/decoder/HandBrake/build/HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 -e "$Encoder" --vb "$src_bitrate" --multi-pass
#			/media3/Multimedia/decoder/HandBrake/build/HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 -e "$Encoder" --quality 22 --vb "$src_bitrate" --preset "Fast 1080p30" --multi-pass
#			ffmpeg -v verbose -hwaccel qsv -i "$input_file" -vf 'format=p010le,hwupload' -c:v "$encoder" -preset "$preset" -b:v "$bitrate"k -maxrate "$maxrate"k -bufsize "$bufsize"k "$output_video"
		else
			local Encoder="h264_vaapi"
			case "$codec" in
				h264)
					Encoder="h264_vaapi"
#					Encoder="h264_qsv"
#					preset="intel_qsv_h264"
					;;
				hevc)
					Encoder="hevc_vaapi"
#					Encoder="hevc_qsv"
#					preset="intel_qsv_hevc"
					;;
				h265)
					Encoder="hevc_vaapi"
#					Encoder="hevc_qsv"
#					preset="intel_qsv_hevc"
					;;
#				vp9)
#					Encoder="vp9_qsv"
#					preset="intel_qsv_vp9"
#					;;
				av1)
					Encoder="av1_vaapi"
#					Encoder="av1_qsv"
#					preset="intel_qsv_av1"
					;;
				*)
#					Encoder = "copy"
					Encoder="h264_vaapi"
					;;
			esac
			echo "Encoding with $encoder $Encoder"
			echo "Encoding with VAAPI"
			ffmpeg -vaapi_device /dev/dri/renderD128 -i "$input_file" -vf 'format=nv12,hwupload' -c:v "$Encoder" -b:v "$src_bitrate"k -maxrate "$maxrate"k -bufsize "$bufsize"k "$output_video"
			fi
		
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
			addon="$codec.mp4"
			if [[ "$encoder" == "vaapi" ]]; then
				addon="va.$addon"
			else
				addon="qsv.$addon"
			fi
			
			echo "addon $addon"
			
		
			if [[ "$item" != *".$addon" ]]; then
 				filename="$(basename "$item")"
				src_size=$(get_filesize "$item")
				echo "$item is a file $src_size"
				src_bitrate="$bitrate"
				
				echo "bitrate0 equals $src_bitrate"
				
				get_bitrate "$item"
				
				if [ -n "$src_bitrate" ]; then
					if [[ "$src_bitrate" -gt "$bitrate" ]]; then
						src_bitrate="$bitrate"
					fi
				else
					src_bitrate="$bitrate"
				fi
				echo "$item is a bitrate3 $src_bitrate"
				
				filename_without_extension="${filename%.*}"
				output_video="$dest_path""$filename_without_extension.$addon"
				
				file_extension="${filename##*.}"
				
				found=0
				for element in "${extensions_array[@]}"; do
					if [[ "$element" == "$file_extension" ]]; then
						found=1
						break
					fi
				done

				if [[ "$src_size" -gt "$max_size" || "$found" -eq 1 ]]; then
					encode_video "$item" "$output_video" "$src_bitrate"
				fi
			else
				echo "The filename $item contains .$addon"
			fi
		else
			echo "$item is neither a file nor a directory"
		fi
	done
}

get_bitrate()
{
	local input="$1" 
#	src_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input")
#	echo "$input is a bitrate1 $src_bitrate"
	# Check if bitrate is N/A or empty
#    if [[ "$src_bitrate" == "N/A" || -z "$src_bitrate" ]]; then
#        echo "Bitrate not available. Trying to get the average bitrate..."
#        src_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" | head -n 1)
#		if [[ "$src_bitrate" == "N/A" || -z "$src_bitrate" ]]; then
#			echo "Bitrate not available. Trying to get the size/time..."
			# Get file size in bytes
			local file_size=$(stat -c%s "$input")
			file_size=$((file_size * 8)) 

			# Get video duration in seconds
			local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
			
			echo "$duration $file_size"

			# Check if duration is valid
			if (( $(echo "$duration != 0" | bc -l) )); then
				# Calculate bitrate in bps
				src_bitrate=$(echo "scale=0; $file_size / $duration" | bc)
				#( (file_size * 8) / duration ))
			else
				src_bitrate="$bitrate"
			fi
			echo "$input is a bitrate2 $src_bitrate"
			
			src_bitrate=$(echo "scale=0; $src_bitrate / 1024" | bc)
#		fi
#    fi
	
	
}

get_filesize()
{
	local file="$1"
	local size=0
	if [ -f "$file" ]; then
        # Get the file size in bytes
        size=$(stat -c%s "$file")
    fi
	echo "$size"
}



format_integer() {
    local number="$1"  # The integer to format
    local width="$2"   # Desired width (total number of digits)

    # Use printf to format the number with leading zeros
    printf "%0${width}d\n" "$number"
}


# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
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
#			echo "bitrate $bitrate"
#			bitrate=$(( bitrate * 1024 ))
#			echo "bitrate $bitrate"			
			
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
		-encoder)
            encoder="$2"
            shift 2
            ;;
		-codec)
            codec="$2"
            shift 2
            ;;
		-arrExt)
            # Check if the next argument exists
            if [[ -n "$2" ]]; then
                # Split the comma-separated string into an array
                IFS=', ' read -r -a extensions_array <<< "$2"
                shift 2  # Move past the option and its argument
            else
                echo "Error: -arrExt requires a non-empty argument."
                exit 1
            fi
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

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
	echo "maxrate not an int: $maxrate"
	echo "bufsize not an int: $bufsize"
	bitrate=1536000
	maxrate=2000
	bufsize = 4000	
fi

max_size=$((max_size * 1024 * 1024)) 


echo "SOURCE = $source_path"
echo "DEST = $dest_path"
echo "MAX SIZE = $max_size"
echo "bitrate = $bitrate"
echo "maxrate = $maxrate"
echo "bufsize = $bufsize"

encode_directory "$source_path"


# Loop through each file in the directory
#for file in "$source_path"/*; do
#    # Check if it's a file (not a directory)
#    if [ -f "$file" ]; then
#        input_file="$(basename "$file")"
#		size=$(stat -c%s "$file")
		
#		filename_without_extension="${input_file%.*}"
#		output_video="$dest_path""$filename_without_extension"".av1.mp4"
		
#		if [ "$size" -gt "$max_size" ]; then
#			encode_video "$file" "$output_video" "$bitrate" "$maxrate" "$bufsize"
#		fi

#   fi
#done

