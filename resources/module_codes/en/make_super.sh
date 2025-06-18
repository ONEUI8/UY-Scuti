function create_super_img {
	local partition_type=$1
	local is_sparse=$2
	local img_files=()
	
	# Collect image files of types ext, f2fs, or erofs
	for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
		file_type=$(recognize_file_type "$file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
			img_files+=("$file")
		fi
	done
	
	local total_size=0
	for img_file in "${img_files[@]}"; do
		file_type=$(recognize_file_type "$img_file")
		file_size_bytes=$(stat -c%s "$img_file")
		total_size=$((total_size + file_size_bytes))
	done
	
	remainder=$((total_size % 4096))
	if [ $remainder -ne 0 ]; then
		total_size=$((total_size + 4096 - remainder))
	fi
	
	local extra_space=$((1024 * 1024 * 1024 / 8))
	local total_size=$((total_size + extra_space))
	
	clear
	while true; do
		local original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
		echo -e ""
		echo -n "   [1] $total_size -- Auto-calculated"
		if [ -n "$original_super_size" ]; then
			echo -e "    [2] \e[31m$original_super_size\e[0m -- Original size\n"
		else
			echo -e "\n"
		fi
		echo -e "   [C] Custom input    [Q] Return to the previous menu\n"
		echo -n "   Please select the size for packaging: "
		read device_size_option
		
		case "$device_size_option" in
		1)
			device_size=$total_size
			if ((device_size < total_size)); then
				echo "   Less than the auto-calculated size, please select another option."
				continue
			fi
			break
			;;
		2)
			if [ -n "$original_super_size" ]; then
				device_size=$original_super_size
				if ((device_size < total_size)); then
					echo "   Less than the auto-calculated size, please select another option."
					continue
				fi
				break
			else
				clear
				echo -e "\n   Invalid selection, please enter again."
			fi
			;;
		C | c)
			clear
			while true; do
				echo -e "\n   Hint: The auto-calculated size is $total_size\n"
				echo -e "   [Q] Return to the previous menu\n"
				echo -n "   Please enter a custom size: "
				read device_size
				if [[ "$device_size" =~ ^[0-9]+$ ]]; then
					if ((device_size < total_size)); then
						clear
						echo -e "\n   The entered value is less than the auto-calculated size, please enter again."
					else
						if ((device_size % 4096 != 0)); then
							device_size=$(((device_size + 4095) / 4096 * 4096))
							echo -e "\n   The entered value is not a multiple of 4096 bytes, automatically adjusted to $device_size."
						fi
						break
					fi
				elif [ "${device_size,,}" = "q" ]; then
					return
				else
					clear
					echo -e "\n   Invalid input, please enter again."
				fi
			done
			break
			;;
		Q | q)
			echo "   Task canceled, returning to the previous menu."
			return
			;;
		*)
			clear
			echo -e "\n   Invalid selection, please enter again."
			;;
		esac
	done
	
	clear
	echo ""
	local metadata_size="65536"
	local block_size="4096"
	local super_name="super"
	local group_name="qti_dynamic_partitions"
	local group_name_a="${group_name}_a"
	local group_name_b="${group_name}_b"
	
	case "$partition_type" in
	"(V)AB")
		metadata_slots="3"
		;;
	*)
		metadata_slots="2"
		;;
	esac
	
	local params=""
	case "$is_sparse" in
	"yes")
		params+="--sparse"
		;;
	esac
	
	case "$partition_type" in
	"(V)AB")
		params+=" --group \"$group_name_a:$device_size\""
		params+=" --group \"$group_name_b:$device_size\""
		params+=" --virtual-ab"
		;;
	*)
		params+=" --group \"$group_name:$device_size\""
		;;
	esac
	
	for img_file in "${img_files[@]}"; do
		local base_name=$(basename "$img_file")
		local partition_name=${base_name%.*}
		local partition_size=$(stat -c%s "$img_file")
		local file_type=$(recognize_file_type "$img_file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]]; then
			local read_write_attr="none"
		else
			local read_write_attr="readonly"
		fi
		
		case "$partition_type" in
		"(V)AB")
			params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
			params+=" --image \"${partition_name}_a=$img_file\""
			params+=" --partition \"${partition_name}_b:$read_write_attr:0:$group_name_b\""
			;;
		*)
			params+=" --partition \"$partition_name:$read_write_attr:$partition_size:$group_name\""
			params+=" --image \"$partition_name=$img_file\""
			;;
		esac
	done
	
	echo -e "Packing SUPER partition, please wait..."
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
	echo "Duration: $runtime seconds"
	echo -n "Press any key to return to the previous menu..."
	read -n 1
}

function package_super_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	detected_files=()
	
	for file in "$WORK_DIR/$current_workspace/Repacked/"*; do
		if [[ -f "$file" && $(basename "$file") =~ ^($super_sub_partitions_list)$ ]]; then
			detected_files+=("$file")
		fi
	done
	
	if [ ${#detected_files[@]} -gt 0 ]; then
		while true; do
			echo -e "\n   Detected packed subpartitions:\n"
			for file in "${detected_files[@]}"; do
				echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
			done
			echo -e "\n   Do you want to move these files to the packing directory?"
			echo -e "\n   [1] Move   [2] Do not move\n"
			echo -n "   Choose your action: "
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
				echo -e "\n   Invalid selection, please enter again."
			fi
		done
	fi
	
	shopt -s nullglob
	img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
	shopt -u nullglob
	real_img_files=()
	for file in "${img_files[@]}"; do
		if [ -e "$file" ]; then
			real_img_files+=("$file")
		fi
	done
	
	if [ ${#real_img_files[@]} -lt 2 ]; then
		echo -e "\n   The SUPER directory must contain at least two image files."
		read -n 1 -s -r -p "   Press any key to return to the previous menu..."
		return
	fi
	
	forbidden_files=()
	for file in "${real_img_files[@]}"; do
		filename=$(basename "$file")
		if ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
			forbidden_files+=("$file")
		fi
	done
	
	if [ ${#forbidden_files[@]} -gt 0 ]; then
		echo -e "\n   Execution denied; the following files are prohibited from merging:\n"
		for file in "${forbidden_files[@]}"; do
			echo -e "   \e[33m☒   $(basename "$file")\e[0m\n"
		done
		read -n 1 -s -r -p "   Press any key to return to the previous menu..."
		return
	fi
	
	while true; do
		echo -e "\n   Subpartitions in the directory to be packed:\n"
		for i in "${!img_files[@]}"; do
			file_name=$(basename "${img_files[$i]}")
			file_size=$(stat -c%s "${img_files[$i]}")
			if [ "$file_size" -lt 1048576 ]; then
				size_display=$(echo "scale=1; $file_size / 1024" | bc)Kb
			elif [ "$file_size" -lt 1073741824 ]; then
				size_display=$(echo "scale=1; $file_size / 1048576" | bc)Mb
			else
				size_display=$(echo "scale=1; $file_size / 1073741824" | bc)Gb
			fi
			printf "   \e[96m[%02d] %s —— <%s>\e[0m\n\n" $((i + 1)) "$file_name" "$size_display"
		done
		echo -e "\n   [Y] Start packing   [Q] Return to the previous menu\n"
		echo -n "   Choose the action you want to perform: "
		read is_pack
		is_pack=$(echo "$is_pack" | tr '[:upper:]' '[:lower:]')
		clear
		case "$is_pack" in
		y)
			while true; do
				echo -e "\n   [1] OnlyA dynamic partition   [2] (V)AB dynamic partition\n"
				echo -e "   [Q] Return to the previous menu\n"
				echo -n "   Please select your partition type: "
				read partition_type
				partition_type=$(echo "$partition_type" | tr '[:upper:]' '[:lower:]')
				if [ "$partition_type" = "q" ]; then
					echo "   Partition type selection canceled, returning to the working menu."
					return
				fi
				clear
				case "$partition_type" in
				1)
					while true; do
						echo -e "\n   [1] Sparse   [2] Non-sparse\n"
						echo -e "   [Q] Return to the previous menu\n"
						echo -n "   Please select the packing method: "
						read is_sparse
						is_sparse=$(echo "$is_sparse" | tr '[:upper:]' '[:lower:]')
						if [ "$is_sparse" = "q" ]; then
							echo "   Selection canceled, returning to the working menu."
							return
						fi
						case "$is_sparse" in
						1 | 2)
							break
							;;
						*)
							clear
							echo -e "\n   Invalid selection, please enter again."
							;;
						esac
					done
					break
					;;
				2)
					while true; do
						echo -e "\n   [1] Sparse   [2] Non-sparse\n"
						echo -e "   [Q] Return to the previous menu\n"
						echo -n "   Please select the packing method: "
						read is_sparse
						is_sparse=$(echo "$is_sparse" | tr '[:upper:]' '[:lower:]')
						if [ "$is_sparse" = "q" ]; then
							echo "   Selection canceled, returning to the working menu."
							return
						fi
						case "$is_sparse" in
						1 | 2)
							break
							;;
						*)
							clear
							echo -e "\n   Invalid selection, please enter again."
							;;
						esac
					done
					break
					;;
				*)
					clear
					echo -e "\n   Invalid selection, please enter again."
					;;
				esac
			done
			break
			;;
		q)
			echo "Packing operation canceled, returning to the previous menu."
			return
			;;
		*)
			clear
			echo -e "\n   Invalid selection, please enter again."
			;;
		esac
	done
	
	case "$partition_type-$is_sparse" in
	1-1)
		create_super_img "OnlyA" "yes"
		;;
	1-2)
		create_super_img "OnlyA" "no"
		;;
	2-1)
		create_super_img "(V)AB" "yes"
		;;
	2-2)
		create_super_img "(V)AB" "no"
		;;
	*)
		echo "   Invalid selection, please enter again."
		;;
	esac
}