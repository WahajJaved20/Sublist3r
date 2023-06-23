#! /bin/bash

extractExtension(){
	if [[ -d $root ]]; then
		return
	fi
	local filename=$1
	local basename=$(basename "$filename")
	local extension=$(echo "$basename" | rev | cut -d '.' -f 1 | rev)
	echo "$extension"
}

extractBase(){
	if [[ -d $root ]]; then
		return
	fi
	local filename=$1
	local base="${filename%.*}"
	echo "$base"
}

extractFileName(){
	if [[ -d $root ]]; then
		return
	fi
	local filepath=$1
	local filename=$(basename "$filepath")
	echo "$filename"
}

extractParentDirectory(){
	if [[ -d $root ]]; then
		return
	fi
	local completePath=$1
	local fileName=$2
	directory="${completePath/$fileName}"
	echo "$directory"
}

mergePathAndFile(){
	local fileName=$1
	local filePath=$2
	mergedPath="$filePath$fileName"
	echo "$mergedPath"
}

therapist(){
	local parentDirectory=$1
	local base=$2
	cd $parentDirectory
	local mergedPath=$(mergePathAndFile $base $parentDirectory)
	echo "$mergedPath"
}

resolveDirectories(){
	# echo $1
	local root=$1
	local fileName=$(extractFileName $root)
	local extension=$(extractExtension $fileName)
	local base=$(extractBase $fileName)
	local parentDirectory=$(extractParentDirectory $root $fileName)
	if [[ $extension == "zip" ]]; then
		mkdir "$parentDirectory/$base"
		unzip -d "$parentDirectory/$base" $root
		resolveDirectories $(therapist $parentDirectory $base) 
	elif [[ $extension == "tar" || $extension == "gz" ]]; then
		local newBase=$(extractBase $base)
		mkdir "$parentDirectory/$newBase"
		echo $newBase
		tar -xf $root -C "$parentDirectory/$newBase"
		resolveDirectories $(therapist $parentDirectory $newBase) 
	elif [[ -d $root ]]; then
		for file in "$root"/* ; do
			resolveDirectories $file
		done
		# file_list=($(find "$root" -mindepth 1 -maxdepth 1 -exec realpath {} \;))
		# parallel -j $NUM_JOBS resolveDirectories ::: "${file_list[@]}"
	else
		local firstLine=$(head -n 1 $root)
		local notRedisLine=$(echo "$firstLine" | grep -q "msg"; echo $?)
		local notKubeFile=$(echo "$base" | grep -q "kube-system"; echo $?)
		local notMonitoringFile=$(echo "$base" | grep -q "monitoring"; echo $?)
		local contentExists=$(grep -q . $root; echo $?)
		if [[ $extension == "log" || $extension == "txt" || $contentExists == 0 ]]; then
			if [[ $notRedisLine == 0 && $notKubeFile != 0 && $notMonitoringFile != 0 ]]; then
				cat "$root" >> "$genericLogs"
			else
				echo "Skipping File $base"
			fi
		else
			echo "====================================================="
			echo "ERROR"
			echo "Extension $extension"
			echo "Path $root"
			echo "Unexpected or Empty File Encountered, Ignoring it... "
			echo "====================================================="	
		fi
	fi
}

main(){
	# confirm if an argument was given
	if [ -z "$1" ]; then
		echo "=============================================="
		echo "Make Executable => chmod +x sublister.sh"
		echo "Syntax => ./sublister.sh <ABSOULUTE_FILE_PATH>"
		echo "=============================================="
	else
		# confirm if a valid file path was provided
		if [ -f "$1" ]; then
			extension=$(extractExtension $1)
			if [[ $extension == "zip" || $extension == "tar" || $extension == "gz" ]]; then
				start_time=$(date +%s.%N)
				fileName=$(extractFileName $1)
				base=$(extractBase $fileName)
				parentDirectory=$(extractParentDirectory $1 $fileName)
				echo " PARENT DIRECTORY => $parentDirectory"
				cd $parentDirectory
				genericLogs=$(pwd)/genericLogs.log
				if [ -f "$genericLogs" ]; then
					rm "$genericLogs"
				fi
				touch $genericLogs
				resolveDirectories $1
				wait
				echo "The output files have been saved to: $genericLogs"
				end_time=$(date +%s.%N)
				execution_time=$(echo "$end_time - $start_time" | bc)
				echo "Execution time: $execution_time seconds"
			else
				echo "Unsupported File Format, Given : $extension"
				echo "Supported File Formats: ZIP / TAR / GZ"
			fi
		else
			echo "The provided file doesnt exist"
		fi
	fi
}
main $1
