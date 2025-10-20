#!/bin/bash

function cleanup {
    echo -e "\nCtrl+C detected. Performing cleanup..."
    # Add any cleanup commands here
    exit 0
}



handbrake_path="/media3/Multimedia/decoder/HandBrake/build/"
ffmpeg_path=""
source_path=""
dest_path="./"
max_size=800
bitrate=0
maxrate=0
bufsize=0
extensions_array=""
encoder="vaapi"
codec="av1"
src_bitrate=0
preset=""
encoder_type="ffmpeg"
multi_pass=0
CRF=0


encode_video()
{
	local input_file="$1"
    local output_video="$2"
#	local src_bitrate="$3"	

	echo "Executing: $input_file $output_video $src_bitrate"
		
	if [ ! -f "$output_video" ]; then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			command=""$ffmpeg_path"ffmpeg $(add_decode_setting) -i "$input_file" $(add_encode_setting) $(add_encoder) $(add_bitrate) $(add_CRF) $(add_maxrate) $(add_bufsize) "$output_video""

#			if [[ "$encoder" == "qsv" ]]; then
#				command=""$ffmpeg_path"ffmpeg -init_hw_device qsv -hwaccel qsv -hwaccel_output_format qsv -i "$input_file" $(add_encoder) $(add_bitrate) $(add_CRF) $(add_maxrate) $(add_bufsize) "$output_video""
#			else
#				command=""$ffmpeg_path"ffmpeg -vaapi_device /dev/dri/renderD128 -i "$input_file" -vf 'format=nv12,hwupload' $(add_encoder) $(add_CRF) $(add_bitrate) $(add_maxrate) $(add_bufsize) "$output_video""
#			fi
			echo "Executing: $command"
			eval "$command"
			
		else
			command=""$handbrake_path"HandBrakeCLI -i "$input_file" -o "$output_video" $(add_audio) $(add_decode_setting) $(add_encode_setting) $(add_preset) $(add_multi_pass) $(add_encoder) $(add_bitrate) $(add_CRF) $(add_maxrate) $(add_bufsize)"
#			if [[ "$encoder" == "qsv" ]]; then
#				command=""$handbrake_path"HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 --enable-qsv-decoding $(add_preset) $(add_multi_pass) $(add_encoder) $(add_bitrate) $(add_maxrate)"
#			else
#				command=""$handbrake_path"HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 $(add_preset) $(add_multi_pass) $(add_encoder) $(add_bitrate) $(add_maxrate)"
#
#			fi
			echo "Executing: $command"
			eval "$command"

		fi
	else
		echo "$output_video ALREADY exist"
	fi
}


process_directory() 
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
			process "$item"
        else
			process_file "$item"		
		fi
	done
}

process_file()
{
	local item="$1"
	echo "item = $item"
	if [ -f "$item" ]; then
		addon="$codec.mp4"
		if [[ "$encoder" == "vaapi" ]]; then
			addon="va.$addon"
		else
			addon="qsv.$addon"
		fi
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			addon="ff.$addon"
		else
			addon="hb.$addon"
		fi
		
		echo "addon $addon"
		
	
		if [[ "$item" != *".$addon" ]]; then
			filename="$(basename "$item")"
			src_size=$(get_filesize "$item")
			echo "$item is a file $src_size"
			
			if [ -n "$bitrate" ]; then
				if [[ "$bitrate" -gt 0 ]]; then
			
					src_bitrate="$bitrate"
					
	#				echo "bitrate0 equals $src_bitrate"
					
					get_bitrate "$item"  "$src_size"						
					
					echo "$item is a bitrate3 $src_bitrate"
				fi
			fi
			
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
				encode_video "$item" "$output_video"
			fi
		else
			echo "The filename $item contains .$addon"
		fi
	else
		echo "$item is neither a file nor a directory"
	fi
}

add_multi_pass()
{
	if (( multi_pass > 0 )); then
		if [[ "$encoder_type" == "handbrake" ]]; then
			echo "--multi-pass" 
		fi
	fi
}


add_preset()
{
#	echo "--preset \""Very Fast 720p30""
	if [[ -n "$preset" ]]; then 
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-p $preset"
		elif [[ "$encoder_type" == "handbrake" ]]; then
	#		printf -- "--preset \"%s\" " "$preset" 
			echo "--preset \"$preset\"" 
		fi
	fi
	
}

add_bitrate()
{
	if (( src_bitrate > 0 )); then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-b:v ${src_bitrate}k" 
		elif [[ "$encoder_type" == "handbrake" ]]; then
			echo "--vb ${src_bitrate}k" 
		fi
	fi
}

add_maxrate()
{
	if (( maxrate > 0 )); then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-maxrate ${maxrate}k" 
		elif [[ "$encoder_type" == "handbrake" ]]; then
			echo "--vbv-maxrate ${maxrate}k" 
		fi
	fi
}

add_bufsize()
{
	if (( bufsize > 0 )); then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-bufsize ${bufsize}k" 
		elif [[ "$encoder_type" == "handbrake" ]]; then
			echo "--vbv-bufsize ${bufsize}k" 
		fi
	fi
}


add_CRF()
{
#	local Value=""
	if (( CRF > 0 )); then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			if [ "$encoder" == "qsv" ] || [ "$encoder" == "vaapi" ]; then
				echo "-global_quality ${CRF}"
			else
				echo "-crf ${CRF}"
			fi
		elif [[ "$encoder_type" == "handbrake" ]]; then
			echo "-q ${CRF}"
		fi
	fi
	
#	if [[ -n "$Encoder" && "$Encoder" != "" ]]; then 
#		echo "$Encoder "		
#	fi
			
		
#			echo "-global_quality ${CRF} "
#			local quality=""
#			case "$codec" in
#				h264)
#					quality="-crf ${CRF} "
#					;;
#				hevc)
#					quality="-crf ${CRF} "
#					;;
#				h265)
#					quality="-crf ${CRF} "
#					;;
	#				vp9)
	#					Encoder="vp9_qsv"
	#					preset="intel_qsv_vp9"
	#					;;
#				av1)
#					quality="-global_quality ${CRF} "
#					;;
#				*)
#					quality="-crf ${CRF} "
#					;;
#			esac
#			if [[ -n "$quality" ]]; then 
#				echo "$quality "		
#			fi
		
#		fi
#	fi
}


add_encoder()
{
	local Encoder=""
	if [[ "$encoder_type" == "ffmpeg" ]]; then
		if [ "$encoder" == "qsv" ] || [ "$encoder" == "vaapi" ]; then
			case "$codec" in
				h264)
					Encoder="-c:v h264_$encoder"
					;;
				hevc)
					Encoder="-c:v hevc_$encoder"
					;;
				h265)
					Encoder="-c:v hevc_$encoder"
					;;
				av1)
					Encoder="-c:v av1_$encoder"
					;;
				*)
					Encoder="-c:v $encoder"
					;;
			esac
		else
			Encoder="-c:v $codec"
		fi
	else
		if [[ "$encoder" == "qsv" ]]; then
			case "$codec" in
				h264)
					Encoder="-e qsv_h264"
					;;
				hevc)
					Encoder="-e qsv_h265"
					;;
				h265)
					Encoder="-e qsv_h265"
					;;
				av1)
					Encoder="-e qsv_av1"
					;;
				*)
					Encoder="-e qsv_h264"
					;;
			esac
		else
			Encoder="-e $codec"
		fi
	fi
	
	
	if [[ -n "$Encoder" && "$Encoder" != "" ]]; then 
		echo "$Encoder"		
	fi
}


add_decode_setting()
{
	local Decoder=""
#	local decode_codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $input_file)"
	if [[ "$encoder_type" == "ffmpeg" ]]; then
		if [[ "$encoder" == "qsv" ]]; then
			if [[ "$codec" == "h264" ]] && [[ $(get_decode_codec) == "av1" ]]; then
				Decoder=""
			else
				Decoder="-init_hw_device qsv -hwaccel qsv -hwaccel_output_format qsv"
			fi
		elif [[ "$encoder" == "vaapi" ]]; then
			eDecoder="-vaapi_device /dev/dri/renderD128"
		fi
	else
		if [[ "$encoder" == "qsv" ]]; then
			Decoder="--enable-hw-decoding qsv" 
		fi
	fi
	if [[ -n "$Decoder" && "$Decoder" != "" ]]; then 
		echo "$Decoder"		
	fi

}

add_encode_setting()
{
#	local Encoder=""
	if [[ "$encoder_type" == "ffmpeg" ]]; then
		if [[ "$encoder" == "vaapi" ]]; then
			echo "-vf 'format=nv12,hwupload'"
		fi
	fi
#	if [[ -n "$Encoder" && "$Encoder" != "" ]]; then 
#		echo "$Encoder "		
#	fi

}

add_audio()
{
	#local Audio=""
	if [[ "$encoder_type" == "handbrake" ]]; then
		echo "-E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3"
	fi
#	if [[ -n "$Audio" && "$Audio" != "" ]]; then 
#		echo "$Audio "		
#	fi

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



get_decode_codec()
{
	echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $input_file)"
}

get_bitrate()
{
	local input="$1" 
	# Get file size in bytes
	local file_size="$2" 
	
	local output=$(ffmpeg -i "$input" 2>&1 | grep "bitrate:")
	
	local bitrate_awk=$(echo "$output" | awk -F 'bitrate: ' '{print $2}' | awk '{print $1}')
	
	if [[ -n "$bitrate_awk" ]] && [[ "$bitrate_awk" -gt 0 ]]; then
		echo "bitrate_awk0 $bitrate_awk"
		src_bitrate="$bitrate_awk"
		src_bitrate=$(( src_bitrate * 1024 ))
		
		echo "bitrate_awk $src_bitrate"
		
	else	
	
	#	local file_size=$(stat -c%s "$input")

		#get the size in bits
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
	fi
	src_bitrate=$(echo "scale=0; $src_bitrate / 1024" | bc)
	
	if [ -n "$src_bitrate" ]; then
		if [[ "$src_bitrate" -gt "$bitrate" ]]; then
			src_bitrate="$bitrate"
		fi
	else
		src_bitrate="$bitrate"
	fi
						
						
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

process(){
	trap cleanup SIGINT

	# Parse command-line arguments
	while [[ "$#" -gt 0 ]]; do
		echo "Processing argument: $1"  # Debugging output
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
			-preset)
				preset="$2"
	#			preset="\"$preset\"" 
				shift 2
	#			echo "preset $preset"	
				;;
			-multi_pass)
				multi_pass="$2"
				shift 2
				;;
			-encoder_type)
				encoder_type="$2"
				shift 2
				;;
			-CRF)
				CRF="$2"
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

	echo "handbrake_path = $handbrake_path"
	echo "ffmpeg_path = $ffmpeg_path"

	echo "source_path = $source_path"
	echo "dest_path = $dest_path"

	echo "max_size = $max_size"
	echo "bitrate = $bitrate"
	echo "maxrate = $maxrate"
	echo "bufsize = $bufsize"

	echo "extensions_array = ${extensions_array[*]}"

	echo "encoder = $encoder"
	echo "codec = $codec"
	echo "src_bitrate = $src_bitrate"

	echo "preset = $preset"
	echo "multi_pass = $multi_pass"
	echo "encoder_type = $encoder_type"
	echo "CRF = $CRF"
	
	if [ -z "$source_path" ]; then
		echo "Usage: $0 -source <source_path>"
		exit 1
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
		bitrate=0
		maxrate=0
		bufsize=0	
	fi

	max_size=$((max_size * 1024 * 1024)) 



	# Check if the directory exists
	if [ -d "$source_path" ]; then
		process_directory "$source_path"
	else
		process_file "$source_path"
	fi
}


process "$@"