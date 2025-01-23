function create_super_img {
	local partition_type=$1
	local is_sparse=$2
	local img_files=()
	# Filter out files with types ext, f2fs, erofs
	for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
		file_type=$(recognize_file_type "$file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
			img_files+=("$file")
		fi
	done
	# Calculate the total bytes of all files in the super folder
	local total_size=0
	for img_file in "${img_files[@]}"; do
		file_type=$(recognize_file_type "$img_file")
		# Calculate the size of the file
		file_size_bytes=$(stat -c%s "$img_file")
		total_size=$((total_size + file_size_bytes))
	done
	remainder=$((total_size % 4096))
	if [ $remainder -ne 0 ]; then
		total_size=$((total_size + 4096 - remainder))
	fi
	# Define the size of the extra space
	local extra_space=$((1024 * 1024 * 1024 / 8))
	# Adjust the total_size based on the partition type
	case "$partition_type" in
	"VAB")
		total_size=$((total_size + extra_space))
		;;
	"AB")
		total_size=$(((total_size + extra_space) * 2))
		;;
	"OnlyA")
		total_size=$((total_size + extra_space))
		;;
	esac
	clear
	while true; do
		local original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
		# Display different options based on whether the original_super_size file can be read
		echo -e ""
		echo -n "   [1] 9126805504    [2] $total_size -- Auto Calculated"
		if [ -n "$original_super_size" ]; then
			echo -e "    [3] \e[31m$original_super_size\e[0m -- Original Size\n"
		else
			echo -e "\n"
		fi
		echo -e "   [C] Custom Input    [Q] Return to Previous Menu\n"
		echo -n "   Please select the size for packaging: "
		read device_size_option
		# Set the value of device_size based on user selection
		case "$device_size_option" in
		1)
			device_size=9126805504
			if ((device_size < total_size)); then
				echo "   Less than auto calculated size, please choose another option."
				continue
			fi
			break
			;;
		2)
			device_size=$total_size
			if ((device_size < total_size)); then
				echo "   Less than auto calculated size, please choose another option."
				continue
			fi
			break
			;;
		3)
			if [ -n "$original_super_size" ]; then
				device_size=$original_super_size
				if ((device_size < total_size)); then
					echo "   Less than auto calculated size, please choose another option."
					continue
				fi
				break
			else
				clear
				echo -e "\n   Invalid selection, please re-enter."
			fi
			;;
		C | c)
			clear
			while true; do
				echo -e "\n   Note: Auto calculated size is $total_size\n"
				echo -e "   [Q] Return to Previous Menu\n"
				echo -n "   Please enter custom size: "
				read device_size
				if [[ "$device_size" =~ ^[0-9]+$ ]]; then
					# If the input value is less than total_size, ask to re-enter
					if ((device_size < total_size)); then
						clear
						echo -e "\n   The entered value is less than the auto calculated size, please re-enter."
					else
						if ((device_size % 4096 == 0)); then
							break
						else
							clear
							echo -e "\n   The entered value is not a multiple of 4096 bytes, please re-enter."
						fi
					fi
				elif [ "${device_size,,}" = "q" ]; then
					return
				else
					clear
					echo -e "\n   Invalid input, please re-enter."
				fi
			done
			break
			;;
		Q | q)
			echo "   Task canceled, returning to previous menu."
			return
			;;
		*)
			clear
			echo -e "\n   Invalid selection, please re-enter."
			;;
		esac
	done
	clear # Clear the screen
	echo -e "\n"
	# Other parameters
	local metadata_size="65536"
	local block_size="4096"
	local super_name="super"
	local group_name="qti_dynamic_partitions"
	local group_name_a="${group_name}_a"
	local group_name_b="${group_name}_b"
	# Set metadata_slots based on partition type
	case "$partition_type" in
	"AB" | "VAB")
		metadata_slots="3"
		;;
	*)
		metadata_slots="2"
		;;
	esac
	# Initialize parameter string
	local params=""
	case "$is_sparse" in
	"yes")
		params+="--sparse"
		;;
	esac
	case "$partition_type" in
	"VAB")
		overhead_adjusted_size=$((device_size - 10 * 1024 * 1024))
		params+=" --group \"$group_name_a:$overhead_adjusted_size\""
		params+=" --group \"$group_name_b:$overhead_adjusted_size\""
		params+=" --virtual-ab"
		;;
	"AB")
		overhead_adjusted_size=$(((device_size / 2) - 10 * 1024 * 1024))
		params+=" --group \"$group_name_a:$overhead_adjusted_size\""
		params+=" --group \"$group_name_b:$overhead_adjusted_size\""
		;;
	*)
		overhead_adjusted_size=$((device_size - 10 * 1024 * 1024))
		params+=" --group \"$group_name:$overhead_adjusted_size\""
		;;
	esac
	# Calculate the size each partition has
	for img_file in "${img_files[@]}"; do
		# Extract the filename from the file path
		local base_name=$(basename "$img_file")
		local partition_name=${base_name%.*}
		# Calculate the size of the file
		local partition_size=$(stat -c%s "$img_file")
		# Set read-write attribute based on file system type
		local file_type=$(recognize_file_type "$img_file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]]; then
			local read_write_attr="none"
		else
			local read_write_attr="readonly"
		fi
		# Set partition group name parameter based on partition type
		case "$partition_type" in
		"VAB")
			params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
			params+=" --image \"${partition_name}_a=$img_file\""
			params+=" --partition \"${partition_name}_b:$read_write_attr:0:$group_name_b\""
			;;
		"AB")
			params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
			params+=" --image \"${partition_name}_a=$img_file\""
			params+=" --partition \"${partition_name}_b:$read_write_attr:$partition_size:$group_name_b\""
			params+=" --image \"${partition_name}_b=$img_file\""
			;;
		*)
			params+=" --partition \"$partition_name:$read_write_attr:$partition_size:$group_name\""
			params+=" --image \"$partition_name=$img_file\""
			;;
		esac
	done
	echo -e "Packaging SUPER partition, please wait..."
	mkdir -p "$WORK_DIR/$current_workspace/Repacked"
	local start=$(python3 "$TOOL_DIR/get_right_time.py")
	(
		while true; do
			for s in ◢ ◣ ◤ ◥; do
				printf "\rTask in progress -> %s" "$s"
				sleep 0.15
			done
		done
	) &
	SPIN_PID=$!
	eval "$TOOL_DIR/lpmake  \
		--device-size \"$device_size\" \
		--metadata-size \"$metadata_size\" \
		--metadata-slots \"$metadata_slots\" \
		--block-size \"$block_size\" \
		--super-name \"$super_name\" \
		--force-full-image \
		$params \
		--output \"$WORK_DIR/$current_workspace/Repacked/super.img\"" >/dev/null 2>&1
	kill $SPIN_PID
	wait $SPIN_PID 2>/dev/null
	printf "\r%40s\r"
	local end=$(python3 "$TOOL_DIR/get_right_time.py")
	local runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "Task completed"
	echo "Time taken: $runtime seconds"
	echo -n "Press any key to return to the previous menu..."
	read -n 1
}
function package_super_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	# Detect img files in $WORK_DIR/$current_workspace/Repacked
	detected_files=()
	while IFS= read -r line; do
		line=$(echo "$line" | xargs) # Remove leading and trailing spaces
		if [ -e "$WORK_DIR/$current_workspace/Repacked/$line" ]; then
			detected_files+=("$WORK_DIR/$current_workspace/Repacked/$line")
		fi
	done < <(grep -oP '^[^#]+' "$TOOL_DIR/super_search")
	# Ask whether to move to super folder
	if [ ${#detected_files[@]} -gt 0 ]; then
		while true; do
			echo -e "\n   Detected packed subpartitions:\n"
			for file in "${detected_files[@]}"; do
				echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
			done
			echo -e "\n   Do you want to move these files to the packaging directory?"
			echo -e "\n   [1] Move   [2] Don't Move\n"
			echo -n "   Choose your operation: "
			read move_files
			clear
			if [[ "$move_files" = "1" ]]; then
				for file in "${detected_files[@]}"; do
					mv "$file" "$WORK_DIR/$current_workspace/Extracted-files/super/"
				done
				break
			elif [[ "$move_files" = "2" ]]; then
				break
			else
				echo -e "\n   Invalid selection, please re-enter."
			fi
		done
	fi
	# Get all image files
	shopt -s nullglob
	img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
	shopt -u nullglob
	real_img_files=()
	for file in "${img_files[@]}"; do
		if [ -e "$file" ]; then
			real_img_files+=("$file")
		fi
	done
	# Check if there are enough image files
	if [ ${#real_img_files[@]} -lt 2 ]; then
		echo -e "\n   SUPER directory must contain at least two image files."
		read -n 1 -s -r -p "   Press any key to return to the previous menu..."
		return
	fi
	# Check for forbidden files
	forbidden_files=()
	for file in "${real_img_files[@]}"; do
		filename=$(basename "$file")
		if ! grep -q -x "$filename" "$TOOL_DIR/super_search"; then
			forbidden_files+=("$file")
		fi
	done
	# If there are forbidden files, display error and return
	if [ ${#forbidden_files[@]} -gt 0 ]; then
		echo -e "\n   Execution denied, the following files are forbidden to merge\n"
		for file in "${forbidden_files[@]}"; do
			echo -e "   \e[33m☒   $(basename "$file")\e[0m\n"
		done
		read -n 1 -s -r -p "   Press any key to return to the previous menu..."
		return
	fi
	# Ask user whether to package
	while true; do
		# List all subfiles in the target directory, each preceded by a number
		echo -e "\n   Subpartitions in the packaging directory:\n"
		for i in "${!img_files[@]}"; do
			file_name=$(basename "${img_files[$i]}")
			printf "   \e[96m[%02d] %s\e[0m\n\n" $((i + 1)) "$file_name"
		done
		echo -e "\n   [Y] Start Packaging   [Q] Return to Previous Menu\n"
		echo -n "   Choose the function you want to execute: "
		read is_pack
		is_pack=$(echo "$is_pack" | tr '[:upper:]' '[:lower:]')
		clear
		# Handle user selection
		case "$is_pack" in
		y)
			# User chose to package, ask partition type and packaging method
			while true; do
				echo -e "\n   [1] OnlyA Dynamic Partition   [2] AB Dynamic Partition   [3] VAB Dynamic Partition\n"
				echo -e "   [Q] Return to Previous Menu\n"
				echo -n "   Please select your partition type: "
				read partition_type
				partition_type=$(echo "$partition_type" | tr '[:upper:]' '[:lower:]')
				if [ "$partition_type" = "q" ]; then
					echo "   Partition type selection canceled, returning to workspace menu."
					return
				fi
				clear
				# Handle user selected partition type
				case "$partition_type" in
				1 | 2 | 3)
					# User selected a valid partition type, ask packaging method
					while true; do
						echo -e "\n   [1] Sparse   [2] Non-Sparse\n"
						echo -e "   [Q] Return to Previous Menu\n"
						echo -n "   Please select packaging method: "
						read is_sparse
						is_sparse=$(echo "$is_sparse" | tr '[:upper:]' '[:lower:]')
						if [ "$is_sparse" = "q" ]; then
							echo "   Selection canceled, returning to workspace menu."
							return
						fi
						# Handle user selected packaging method
						case "$is_sparse" in
						1 | 2)
							break
							;;
						*)
							clear
							echo -e "\n   Invalid selection, please re-enter."
							;;
						esac
					done
					break
					;;
				*)
					clear
					echo -e "\n   Invalid selection, please re-enter."
					;;
				esac
			done
			break
			;;
		q)
			echo "Packaging operation canceled, returning to previous menu."
			return
			;;
		*)
			clear
			echo -e "\n   Invalid selection, please re-enter."
			;;
		esac
	done
	# Add your code here to handle the parts after user input
	case "$partition_type-$is_sparse" in
	1-1)
		create_super_img "OnlyA" "yes"
		;;
	1-2)
		create_super_img "OnlyA" "no"
		;;
	2-1)
		create_super_img "AB" "yes"
		;;
	2-2)
		create_super_img "AB" "no"
		;;
	3-1)
		create_super_img "VAB" "yes"
		;;
	3-2)
		create_super_img "VAB" "no"
		;;
	*)
		echo "   Invalid selection, please re-enter."
		;;
	esac
}
