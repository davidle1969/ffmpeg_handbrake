#!/bin/bash


shopt -s nocasematch  # Enable case-insensitive matching


source "log.sh"

function cleanup {
    echo -e "\nCtrl+C detected. Performing cleanup..."
    # Add any cleanup commands here
    exit 0
}




encode_video()
{
	local input_file="$1"
    local output_video="$2"
	local multi_file="${3:-0}"

#	log "$INFO" "encode_video: Executing - $input_file $output_video $src_bitrate"
		
	if [[ "$encoder_type" == "ffmpeg" ]]; then
	
		if (( multi_pass > 0 )); then
			command=""$ffmpeg_path"ffmpeg $(add_error_logging) $(add_decode_setting) -i \"$input_file\" $(add_encode_setting) $(add_encoder) $(add_bitrate) $(add_CRF) $(add_maxrate) $(add_bufsize) -pass 1 -vsync cfr -f null /dev/null"
			log "$INFO" "encode_video: Executing $command"
			eval "$command"
			command=""$ffmpeg_path"ffmpeg $(add_error_logging) $(add_decode_setting) -i \"$input_file\" $(add_encode_setting) $(add_encoder) $(add_bitrate) $(add_CRF) $(add_maxrate) $(add_bufsize) -pass 2 $(add_audio_encode) \"$output_video\""
			log "$INFO" "encode_video: Executing $command"
			eval "$command"
		else
			command=""$ffmpeg_path"ffmpeg $(add_error_logging) $decode_string $(add_concat "$multi_file") -i \"$input_file\" $endcode_string $(add_bitrate) $(add_audio_bitrate) \"$output_video\""
			
			log "$INFO" "encode_video: Executing $command"
			eval "$command"
		fi
	else
		command=""$handbrake_path"HandBrakeCLI -i \"$input_file\" -o \"$output_video\" $decode_string $(add_encode_setting) $endcode_string $(add_multi_pass) $(add_bitrate)"
		log "$INFO" "encode_video: Executing $command"
		eval "$command"

	fi
	
	local output=$?
	
	if [ "$output" -ne 0 ]; then
		log "$ERROR" "encode_video:  $output_file encountered an ERROR with exit code $output"
		# You can handle the error here, such as logging or exiting the script
#	else
#		log "$INFO" "encode_video:  ffmpeg completed successfully with exit code $output"
	fi
	
	
}

move_file() {
	local src_file="$1"
	local dest_path="$2"
	
	command="mv -f \"$src_file\" \"$dest_path\""
	log "$WARNING" "move_file: Executing $command"
	eval "$command"

}

delete_file() {
	local _src_file="$1"
	
	command="rm \"$_src_file\""
	log "$INFO" "delete_file: Executing $command"
	eval "$command"

}

process_into_single_file(){

	local _sourcepath="$1"		
 #   log "$INFO" "process_into_single_file $_sourcepath"
	
	if [ ! -d "$_sourcepath" ]; then
        log "$WARNING" "process_into_single_file Error: '$_sourcepath' is not a valid directory."
        return 1
    fi
	
	local current_dir_name="$(basename "$_sourcepath")"
	local current_dir_name_wo_dates=$(echo "$current_dir_name" | sed 's/ (.*)//')
	
	log "$INFO" "process_into_single_file: $current_dir_name_wo_dates"
	
	output_file="$dest_path""$current_dir_name.txt"
	input_file="$current_dir_name*"	
	output_video="$dest_path""$current_dir_name.$addon"
	
	if [ -s "$output_video" ]; then
		#check to see if it's not empty
		log "$INFO" "process_into_single_file:  $output_video Already exist in DEST"
		return 1
	fi
	
	
	# Create or clear the output file
    > "$output_file"  # This creates a new empty file or clears an existing one
	
	local check="$codec"
	if [[ "$encoder" == "vaapi" ]]; then
		check="va.$check"
	elif [[ "$encoder" == "qsv" ]]; then
		check="qsv.$check"
	fi
	
	local file_count=$(find "$_sourcepath" -maxdepth 1 -type f | wc -l)
	local src_size=0
	
	# Loop through each file in the directory
	for item in "$_sourcepath"/*; do
		
		# Check if it's a file or directory
        if [ -f "$item" ]; then
			
			#check to see if it's a single file
			if [ "$file_count" -eq 1 ]; then
				process_file "$item" "$_sourcepath"
				delete_file "$output_file"
				return 1
			fi
			
			src_size=$((src_size + $(get_filesize "$item")))
		
			local filename="$(basename "$item")"
			local filename_without_extension="${filename%.*}"
			#check to see if new file has NOT already been created and it matches the input wildcard 
			if [[ "$filename_without_extension" != *".$check" ]]; then
				if [[ "$filename_without_extension" == "$current_dir_name_wo_dates"* ]] ; then
					printf "file '%s'\n" "$item" >> "$output_file"
				else
					log "$WARNING" "process_into_single_file: error - WILDCARD $filename_without_extension DOES NOT matches $input_file"
				fi
			else
				log "$WARNING" "process_into_single_file: info - CHECK $filename_without_extension does matches $check"
			fi
		fi
	done
	
	if [ -s "$output_file" ]; then
		#check to see if it's not empty
		encode_video "$output_file" "$output_video" "1"	
		local out_size=$(get_filesize "$output_video")	
		
#		log "$INFO" "out_size: $out_size src_size: $src_size"

		if [[ "$out_size" -lt "$src_size"  ]]; then
			move_file "$output_video" "$_sourcepath"
			log "$WARNING" "$_sourcepath/""$current_dir_name.$addon"
			echo "$(get_current_timestamp): $_sourcepath/""$current_dir_name.$addon" >> ./log/output.log
		else
			move_file "$output_video" "$trash_path"
		fi

	else 
		delete_file "$output_file"
	fi

}


process_consolidated(){

	local _sourcepath="$1"		
    log "$INFO" "process_consolidated $_sourcepath"
	
	#check to see if current directory has files in it
	if [ "$(find "$_sourcepath" -maxdepth 1 -type f | wc -l)" -gt 0 ]; then
		#log "$INFO" "There are files in the directory."
		process_into_single_file "$_sourcepath"
		return 1
	fi
				
		
	if [ -d "$_sourcepath" ]; then
	
		for item in "$_sourcepath"/*; do
			# Check if it's a file or directory
			if [ -d "$item" ]; then
#				echo "$(find "$item" -maxdepth 1 -type f | wc -l)"
				if [ "$(find "$item" -maxdepth 1 -type f | wc -l)" -gt 0 ]; then
					#log "$INFO" "There are files in the directory."
					process_into_single_file "$item"
				else
					#log "$INFO" "There are NO files in the directory."
					process_consolidated "$item"
				
				fi
			fi
		done
	else
		#there are files in the current directory, lets process it
	    log "$INFO" "process_consolidated Error: '$source_path' is not a valid directory."
		process_into_single_file "$_sourcepath"
		
    fi

}

process_directory() 
{
	local _sourcepath="$1"

    log "$INFO" "process_directory $_sourcepath"
	
	 # Check if the directory exists
    if [ ! -d "$_sourcepath" ]; then
        log "$INFO" "Error: '$_sourcepath' is not a valid directory."
        return 1
    fi

	# Loop through each file in the directory
	for item in "$_sourcepath"/*; do
		# Check if it's a file or directory
        if [ -d "$item" ]; then
			process_directory "$item"
        else
			process_file "$item" "$_sourcepath"		
		fi
	done
}

process_file()
{
	local item="$1"
	local _sourcepath="$2"
	
	if [ -f "$item" ]; then
	
		local check="$codec"
		if [[ "$encoder" == "vaapi" ]]; then
			check="va.$check"
		else
			check="qsv.$check"
		fi
		
		local filename="$(basename "$item")"
		local filename_without_extension="${filename%.*}"
	
		if [[ "$filename_without_extension" != *".$check" ]]; then
			output_video="$dest_path""$filename_without_extension.$addon"			
			if [ ! -f "$output_video" ]; then
				file_extension="${filename##*.}"
				
				src_size=$(get_filesize "$item")
				src_bitrate="$bitrate"
				
					
				found=0
				for element in "${extensions_array[@]}"; do
					if [[ "$element" == "$file_extension" ]]; then
						found=1
						break
					fi
				done

				if [[ "$src_size" -gt "$max_size" || "$found" -eq 1 ]]; then
					get_bitrate "$item"  "$src_size"

					audio_bitrate=0
					get_audio_bitrate "$item"	
					
					encode_video "$item" "$output_video"
					
					out_size=$(get_filesize "$output_video")
					#move it to trash bin if the new file is greater than the trash bin max file size.  Usually 90% of the max size
					
					
					if [[ "$trash_file_size" -eq 0 ]]; then
						if [[ "$out_size" -lt "$src_size"  ]]; then
							move_file "$output_video" "$_sourcepath"
							log "$WARNING" "$_sourcepath/""$current_dir_name.$addon"
							echo "$(get_current_timestamp): $_sourcepath/""$current_dir_name.$addon" >> ./log/output.log
						else
							move_file "$output_video" "$trash_path"
						fi
					elif [[ "$out_size" -gt "$trash_file_size"  ]]; then
						move_file "$output_video" "$trash_path"
					else
						move_file "$output_video" "$_sourcepath"
						log "$WARNING" "$_sourcepath/""$filename_without_extension.$addon"
						echo "$(get_current_timestamp): $_sourcepath/""$filename_without_extension.$addon" >> ./log/output.log
					fi				
				fi
			else
				log "$INFO" "process_file:  $output_video ALREADY exist"
			fi
		else
			log "$INFO" "process_file: The filename $filename_without_extension contains .$check"
		fi
	else
		log "$INFO" "process_file: $item is neither a file nor a directory"
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
	if [[ -n "$preset" ]]; then 
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-preset $preset"
		elif [[ "$encoder_type" == "handbrake" ]]; then
	#		printf -- "--preset \"%s\" " "$preset" 
			echo "--preset \"$preset\"" 
		fi
	fi
	
}


add_audio_bitrate()
{
	if (( audio_bitrate > 0 )); then
		if [[ "$encoder_type" == "ffmpeg" ]]; then
			echo "-b:a ${audio_bitrate}k" 
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
				#echo "-global_quality ${CRF}"
				echo "-global_quality:v ${CRF} -extbrc 1 -look_ahead_depth 50"
			else
				echo "-crf:v ${CRF}"
			fi
		elif [[ "$encoder_type" == "handbrake" ]]; then
			echo "-q:v ${CRF}"
		fi
	fi
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

add_error_logging()
{
	local error=""
	
	if [[ "$error_logging" -gt 0 ]]; then
		error="-xerror -loglevel info"
	fi
	
	if [[ -n "$error" && "$error" != "" ]]; then 
		echo "$error"		
	fi
}


add_decode_setting(){
	local Decoder=""
#	local decode_codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $input_file)"
	if [[ "$encoder_type" == "ffmpeg" ]]; then
		Decoder="-init_hw_device qsv -hwaccel qsv -hwaccel_output_format qsv"
		if [[ "$encoder" == "qsv" ]]; then
			if [[ "$codec" == "h264" ]] ; then
				if [[ $(get_decode_codec) == "av1" ]]; then
					Decoder=""
				fi
			fi
		elif [[ "$encoder" == "vaapi" ]]; then
			Decoder="-vaapi_device /dev/dri/renderD128"
		else
			Decoder=""			
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
			if [[ -n "$scale" ]]; then 
				echo "-vf 'format=nv12,hwupload,scale_vaapi=$scale'"
			else
				echo "-vf 'format=nv12,hwupload'"
			fi
		fi
	fi
#	if [[ -n "$Encoder" && "$Encoder" != "" ]]; then 
#		echo "$Encoder "		
#	fi

}

add_audio_encode()
{
	local strAudio=""

	if [[ -n "$audio_encode" ]]; then 
		strAudio="$audio_encode"
	else
		if [[ "$encoder_type" == "handbrake" ]]; then
			strAudio="-E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3"
		else
			strAudio="-c:a copy"
		fi
	fi
	
	echo "$strAudio"
}

add_scale(){

	if [[ -n "$scale" ]]; then 
		echo "-vf \"scale=$scale\""
	fi
	
}

check_file_size() {
    local file="$1"

    if [ -f "$file" ]; then
        # Get the file size in bytes
        local size=$(stat -c%s "$file")
        log "$INFO" "check_file_size: File size of '$file': $size bytes"
    else
        log "$ERROR" "check_file_size: '$file' does not exist or is not a file."
    fi
}

check_addon()
{
	local check="$codec.mp4"
	if [[ "$encoder" == "vaapi" ]]; then
		check="va.$addon"
	else
		check="qsv.$addon"
	fi
	
	
	if [[ "$input_string" == *".$check" ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}


add_concat() {
	local multi_file="$1"

	if [[ "$consolidate" -gt 0 && "$multi_file" -gt 0 ]]; then
		echo "-f concat -safe 0"
	fi

}

init_addon()
{
	addon="$codec.mp4"
	if [[ "$encoder" == "vaapi" ]]; then
		addon="va.$addon"
	elif [[ "$encoder" == "qsv" ]]; then
		addon="qsv.$addon"
	fi
	
#	if (( CRF > 0 )); then
#		addon="crf${CRF}.$addon"
#	fi

	if [[ -n "$CRF" && "$CRF" =~ ^[0-9]+$ && "$CRF" -gt 0 ]]; then
        addon="crf${CRF}.$addon"
    fi
	
	if [[ "$encoder_type" == "ffmpeg" ]]; then
		addon="ff.$addon"
	else
		addon="hb.$addon"
	fi
	
	log "$INFO" "init_addon: $addon"
}


init_decode()
{
	decode_string="$(add_decode_setting)"
	log "$INFO" "init_decode: $decode_string"
}

init_encode()
{
	endcode_string="$(add_encode_setting) $(add_encoder) $(add_CRF) $(add_maxrate) $(add_bufsize) $(add_preset) $(add_audio_encode)"
	log "$INFO" "init_encode: $endcode_string"
}


get_decode_codec()
{
	echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $input_file)"
}


get_audio_bitrate(){

#error, not passing the audio_bitrate
	local input="$1" 
	
#	local output=$(ffmpeg -i "$input" 2>&1 )
	local output=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input")
	log "$INFO" "get_audio_bitrate:  output $output"
	
	local bitrate_awk=$(echo "$output" | awk -F', ' '/Audio:/ {print $NF}' | awk '{print $(NF-1)}')
#	local bitrate_awk=$(ffmpeg -i "$input" 2>&1 | grep -oP '(?<=Audio:\s).*?(?=\s\w+,\s*\d+ kb/s)' | head -n 1)
	log "$INFO" "get_audio_bitrate:  bitrate_awk $bitrate_awk"
	
	if [[ -n "$bitrate_awk" ]] && [[ "$bitrate_awk" -gt 0 ]]; then
		log "$INFO" "get_audio_bitrate:  bitrate_awk0 $bitrate_awk"
		audio_bitrate="$bitrate_awk"
		audio_bitrate=$(( audio_bitrate * 1024 ))
		
		log "$INFO" "get_audio_bitrate:  audio_bitrate $audio_bitrate"
		
	fi
}

get_bitrate()
{
	if [ -n "$bitrate" ]; then
		if [[ "$bitrate" -gt 0 ]]; then
	
			local input="$1" 
			# Get file size in bytes
			local file_size="$2" 
			local output=$(ffmpeg -i "$input" 2>&1 | grep "bitrate:")
			
			local bitrate_awk=$(echo "$output" | awk -F 'bitrate: ' '{print $2}' | awk '{print $1}')
			
			if [[ -n "$bitrate_awk" ]] && [[ "$bitrate_awk" -gt 0 ]]; then
				log "$INFO" "get_bitrate:  bitrate_awk0 $bitrate_awk"
				src_bitrate="$bitrate_awk"
				src_bitrate=$(( src_bitrate * 1024 ))
				
				log "$INFO" "get_bitrate:  bitrate_awk $src_bitrate"
				
			else	

				#get the size in bits
				file_size=$((file_size * 8)) 

				# Get video duration in seconds
				local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
				
				log "$INFO" "$duration $file_size"

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
		fi
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


get_current_timestamp() {
    # Get the current date and time in a formatted string
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp"
}


format_integer() {
    local number="$1"  # The integer to format
    local width="$2"   # Desired width (total number of digits)
	
#	echo "format_integer:  $number $width"

    # Use printf to format the number with leading zeros
	if [[ width -eq 0 ]]; then
		printf "%d\n" "$number"
	else
		printf "%0${width}d\n" "$number"
	fi
}

process(){

	# Check if the directory exists
	if [ -d "$source_path" ]; then
		process_directory "$source_path"
	else
		local file_path
		file_path=$(realpath "$source_path" 2>/dev/null)	
		process_file "$source_path" "$file_path"
	fi

}


process_config(){
	trap cleanup SIGINT
	
	
	# Check if a configuration file was provided
	if [ "$#" -ne 1 ]; then
		log "$ERROR" "Usage: NO Config File given"
		exit 1
	fi

	# Load the configuration file from the first argument
	config_file="$1"
	log "$INFO" "config = $config_file"
	log "$INFO" "handbrake_path = $handbrake_path"
	log "$INFO" "ffmpeg_path = $ffmpeg_path"
	log "$INFO" "trash_path = $trash_path"

	log "$INFO" "source_path = $source_path"
	log "$INFO" "dest_path = $dest_path"

	log "$INFO" "max_size = $max_size"
	log "$INFO" "bitrate = $bitrate"
	log "$INFO" "maxrate = $maxrate"
	log "$INFO" "bufsize = $bufsize"
	log "$INFO" "audio_encode = $audio_encode"

	
	
#	echo "config = $config_file"
	source "$config_file"

	
	if [[ ${#extensions_array[@]} -gt 0 ]]; then
		log "$INFO" "Array loaded successfully:"
		for value in "${extensions_array[@]}"; do
			log "$INFO" "$value"
		done
	else
		log "$WARNING" "Array not loaded."
	fi


	log "$INFO" "extensions_array = ${extensions_array[*]}"

	log "$INFO" "encoder = $encoder"
	log "$INFO" "codec = $codec"
	log "$INFO" "src_bitrate = $src_bitrate"

	log "$INFO" "preset = $preset"
	log "$INFO" "multi_pass = $multi_pass"
	log "$INFO" "encoder_type = $encoder_type"
	log "$INFO" "CRF = $CRF"
	
	log "$INFO" "consolidate = $consolidate"
	log "$INFO" "error_logging = $error_logging"
	log "$INFO" "scale = $scale"
	
	
	
	
	if [ -z "$source_path" ]; then
		log "$ERROR" "Usage: $0 -source <source_path>"
		exit 1
	fi

	# Check if size is an integers
	if ! [[ "$max_size" =~ ^-?[0-9]+$  ]]; then
		log "$WARNING" "max_size not an int: $max_size"
		max_size=0
	fi

	if ! [[ "$bitrate" =~ ^-?[0-9]+$ || "$maxrate" =~ ^-?[0-9]+$ || "$bufsize" =~ ^-?[0-9]+$ ]]; then
		log "$WARNING" "bitrate not an int: $bitrate"
		log "$WARNING" "maxrate not an int: $maxrate"
		log "$WARNING" "bufsize not an int: $bufsize"
		bitrate=0
		maxrate=0
		bufsize=0	
	fi

	max_size=$((max_size * 1024 * 1024))
	trash_file_size=$(( max_size * 9 / 10 ))	
	log "$INFO" "trash_file_size = $trash_file_size"

	init_addon
	init_decode
	init_encode

	

}



endcode_string=""
decode_string=""
trash_path="./trash/"
trash_file_size=0

audio_encode=""
config_file="./config/config.sh"
source_path="./"
dest_path="./"
max_size=0
handbrake_path=""
ffmpeg_path=""
audio_bitrate=0
bitrate=0
maxrate=0
bufsize=0
extensions_array=""
encoder=""
codec=""
src_bitrate=0
preset=""
encoder_type=""
multi_pass=0
CRF=0
addon=""
consolidate=0
error_logging=0
scale=""


process_config "$@"

if [[ "$consolidate" -eq 0 ]]; then
	process
else
	process_consolidated "$source_path"
fi

#	max_size=$(format_integer "$_max_size" 0)

#	bitrate=$(format_integer "$_bitrate" 0)
#	maxrate=$(format_integer "$_maxrate" 0)
#	bufsize=$(format_integer "$_bufsize" 0)
#	src_bitrate=0
#	multi_pass=$(format_integer "$_multi_pass" 0)
#	CRF=$(format_integer "$_CRF" 0)

	
#	while IFS='=' read -r key value; do
#		key=$(echo "$key" | xargs)
#		value=$(echo "$value" | xargs)
#		
#		echo "Processing argument: $key - $value"  # Debugging output
#
#		case "$key" in
#			source_path) source_path="$value" ;;
#			dest_path) dest_path="$value" ;;
#			max_size) 
#				# Validate that max_size is an integer
#				if [[ "$value" =~ ^[0-9]+$ ]]; then
#					max_size="$value"
#				else
#					echo "Error: max_size must be an integer."
#					max_size=800				
#				fi
 #           ;;
	#		bitrate) bitrate="$value" ;;
	#		maxrate) maxrate="$value" ;;
	#		bufsize) bufsize="$value" ;;	
	#		encoder) encoder="$value" ;;
	#		codec) codec="$value" ;;
	#		preset) preset="$value" ;;
	#		multi_pass) multi_pass="$value" ;;
	##		CRF) 
		##		if [[ "$value" =~ ^[0-9]+$ ]]; then
#					CRF="$value"
#				else
#					echo "Error: CRF must be an integer."
#					CRF=0
#				fi
#			;;
#			arrExt) arrExt="$value" ;;
#		esac
#	done < "$config_file"


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

#			if [[ "$encoder" == "qsv" ]]; then
#				command=""$handbrake_path"HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 --enable-qsv-decoding $(add_preset) $(add_multi_pass) $(add_encoder) $(add_bitrate) $(add_maxrate)"
#			else
#				command=""$handbrake_path"HandBrakeCLI -i "$input_file" -o "$output_video" -E copy –audio-copy-mask ac3,dts,dtshd –audio-fallback ffac3 $(add_preset) $(add_multi_pass) $(add_encoder) $(add_bitrate) $(add_maxrate)"
#
#			fi


# Parse command-line arguments
#while [[ "$#" -gt 0 ]]; do
#	echo "Processing argument: $1"  # Debugging output
#	case "$1" in
#		-config)
#			config="$2"
#			shift 2
#			;;
#		*)
#			echo "Invalid option: $1" >&2
#			exit 1
#			;;
#	esac
#done
# Load the configuration file
#source "$config"

		
: '		command=""$ffmpeg_path"ffmpeg $(add_error_logging) $decode_string -f concat -safe 0 -i \"$output_file\" $endcode_string $(add_bitrate) $(add_audio_bitrate) \"$output_video\""
		log "$INFO" "process_into_single_file: info - Executing $command"
#		ffmpeg $(add_error_logging) $(add_decode_setting) -f concat -safe 0 -i "$output_file" -vf format=nv12,hwupload $(add_encoder) $(add_CRF) $(add_maxrate) $(add_bufsize) $(add_preset) $(add_audio_encode) $(add_bitrate) $(add_audio_bitrate) "$output_video"
	
		eval "$command"
		output=$?
		
		log "$INFO" "process_into_single_file: The output is: $output" 
		
		if [ "$output" -ne 0 ]; then
			log "$ERROR" "$output_file encountered an ERROR with exit code $output"
			# You can handle the error here, such as logging or exiting the script
		else
			log "$INFO" "process_into_single_file:  ffmpeg completed successfully with exit code $output"
		fi
'