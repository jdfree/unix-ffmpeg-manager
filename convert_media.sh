#!/bin/bash

usage="./$(basename "$0") [-h] [-d] [-f] [-o] [-e] -- convert files using ffmpeg
options:
	-h show this help message
	-d look for files in this directory
	-f convert these files
	-o write output to this location (default: './converted/')
	-p preserve directory structure in output
	-s move source files to output location and write new files to source location
	-y overwrite files in output location
	-t remove leading track numbers"


if [ $# -lt 2 ]; then
	echo "$usage"
	exit
fi

output_directory="converted"
overwrite="n"

while getopts :hd:f:o:e:n:psty option; do
	case "$option" in
		h)	echo "$usage"
			exit
			;;
		d)	input_directories+=("$OPTARG")
			;;
		f)	files+=("$OPTARG")
			;;
		o)	output_directory="$OPTARG"
			;;
		p)	preserve_structure=true
			;;
		s)	preserve_structure=true
			swap=true
			;;
		t)	tracknumbers=true
			;;
		y)	overwrite="y"
			;;
	esac
done


if [ ${#input_directories[@]} > 0 ]; then
	echo "Converting files from $input_directories and writing into $output_directory"
elif [[ ! -z $files ]]; then
	echo "Converting $files and writing into $output_directory"
fi
if [ $preserve_structure ]; then
	echo "Preserving directory structure"
fi
if [ $swap ]; then
	echo "Swapping input and output file locations before generation; original files will be in output directory and new files will be in originals' location"
fi
if [ $tracknumbers ]; then
	echo "Removing track number prefixes from output files"
fi
if [ $overwrite == "y" ]; then
	echo "Overwriting output files if already present"
else
	echo "Will not overwrite preexisting output files"
fi

# set internal field separator to newline to handle filenames with whitespace correctly
IFS=$'\n'

mkdir -p $output_directory

convert_file()
{
	start_directory=$1
	end_directory=$2
	file=$3
	path=$(dirname "${file}")
	filename=$(echo "${file##*/}")
	extension=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
	basename=$(echo "${filename%.*}")
	if [ $tracknumbers ]; then
		basename=`echo $basename | sed "s/^[0-9]*[[:space:]]*//"`
	fi
	
	if [[ "wma" == $extension || "wav" == $extension ]]; then
		new_file_extension=".mp3"
	elif [[ "wmv" == $extension || "mov" == $extension ]]; then
		new_file_extension=".mp4"
	fi
	newfile=$end_directory/$basename$new_file_extension
	if [ $preserve_structure ]; then
		newfile=$end_directory${path#$start_directory}/$basename$new_file_extension
        	mkdir -p $end_directory${path#$start_directory}
	fi
	
	echo "Converting $file to $newfile"
        if [[ ".mp3" == $new_file_extension ]]; then
		ffmpeg -$overwrite -i $file -codec:a libmp3lame -qscale:a 2 -loglevel warning $newfile
	elif [[ "wmv" == $extension ]]; then
		ffmpeg -$overwrite -i $file -f mp4 -strict -2 -qscale 1 -loglevel warning $newfile
	else
		ffmpeg -$overwrite -i $file -strict -2 -qscale 1 -loglevel warning $newfile
	fi
}

move_file()
{
	current_directory=$1
        new_directory=$2
        file=$3
	path=$(dirname "${file}")
	newfile=$new_directory${path#$current_directory}/${file##*/}
	mkdir -p $new_directory${path#$current_directory}
	mv -f $file $newfile
	echo $newfile
}

for directory in ${input_directories[@]}; do
	for file in $(find "$directory" \( -iname *.wma -o -iname *.wmv -o -iname *.wav -o -iname *.mov \)); do
		if [ $swap ]; then
			convert_file $output_directory $directory $(move_file $directory $output_directory $file)
		else
			convert_file $directory $output_directory $file
		fi
	done
done

if [[ ! -z $files ]]; then
	for file in ${files[@]}; do
		convert_file $(dirname "${file}") $output_directory $file
		if [ $swap ]; then
			convert_file $output_directory $(dirname "${file}") $(move_file $(dirname "${file}") $output_directory $file)
                else
                        convert_file $(dirname "${file}") $output_directory $file
                fi
	done
fi

echo "All done!"

