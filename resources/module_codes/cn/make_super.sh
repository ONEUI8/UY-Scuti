function create_super_img {
	local partition_type=$1
	local is_sparse=$2
	local img_files=()
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
		echo -e ""
		echo -n "   [1] $total_size --自动计算"
		if [ -n "$original_super_size" ]; then
			echo -e "    [2] \e[31m$original_super_size\e[0m --原始大小\n"
		else
			echo -e "\n"
		fi
		echo -e "   [C] 自定义输入    [Q] 返回上级菜单\n"
		echo -n "   请选择打包的大小："
		read device_size_option
		case "$device_size_option" in
		1)
			device_size=$total_size
			if ((device_size < total_size)); then
				echo "   小于自动计算大小，请执行其它选项。"
				continue
			fi
			break
			;;
		2)
			if [ -n "$original_super_size" ]; then
				device_size=$original_super_size
				if ((device_size < total_size)); then
					echo "   小于自动计算大小，请执行其它选项。"
					continue
				fi
				break
			else
				clear
				echo -e "\n   无效的选择，请重新输入。"
			fi
			;;
		C | c)
			clear
			while true; do
				echo -e "\n   提示：自动计算大小为 $total_size\n"
				echo -e "   [Q] 返回上级菜单\n"
				echo -n "   请输入自定义大小："
				read device_size
				if [[ "$device_size" =~ ^[0-9]+$ ]]; then
					if ((device_size < total_size)); then
						clear
						echo -e "\n   输入的数值小于自动计算大小，请重新输入。"
					else
						if ((device_size % 4096 != 0)); then
							device_size=$(((device_size + 4095) / 4096 * 4096))
							echo -e "\n   输入的值不是 4096 字节数的倍数，已自动修正为 $device_size。"
						fi
						break
					fi
				elif [ "${device_size,,}" = "q" ]; then
					return
				else
					clear
					echo -e "\n   无效的输入，请重新输入。"
				fi
			done
			break
			;;
		Q | q)
			echo "   任务取消，返回上级菜单。"
			return
			;;
		*)
			clear
			echo -e "\n   无效的选择，请重新输入。"
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
	"AB" | "VAB")
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
	echo -e "正在打包 SUPER 分区，等待中..."
	mkdir -p "$WORK_DIR/$current_workspace/Repacked"
	local start=$(python3 "$TOOL_DIR/get_right_time.py")
	(
		while true; do
			for s in ◢ ◣ ◤ ◥; do
				printf "\r任务执行中 -> %s" "$s"
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
	echo "任务完成"
	echo "耗时 $runtime 秒"
	echo -n "按任意键返回上级菜单..."
	read -n 1
}

function package_super_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	detected_files=()
	for file in "$WORK_DIR/$current_workspace/Repacked/"*; do
		if [[ -f "$file" && $(basename "$file") =~ ^($super_sub-partitions_list)$ ]]; then
			detected_files+=("$file")
		fi
	done
	if [ ${#detected_files[@]} -gt 0 ]; then
		while true; do
			echo -e "\n   侦测到已打包的子分区：\n"
			for file in "${detected_files[@]}"; do
				echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
			done
			echo -e "\n   是否将这些文件移动到待打包目录？"
			echo -e "\n   [1] 移动   [2] 不移动\n"
			echo -n "   选择你的操作："
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
				echo -e "\n   无效的选择，请重新输入。"
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
		echo -e "\n   SUPER 目录需要至少应包含两个镜像文件。"
		read -n 1 -s -r -p "   按任意键返回上级菜单..."
		return
	fi
	forbidden_files=()
	for file in "${real_img_files[@]}"; do
		filename=$(basename "$file")
		if ! [[ "$filename" =~ ^($super_sub-partitions_list)$ ]]; then
			forbidden_files+=("$file")
		fi
	done
	if [ ${#forbidden_files[@]} -gt 0 ]; then
		echo -e "\n   拒绝执行，以下文件禁止合并\n"
		for file in "${forbidden_files[@]}"; do
			echo -e "   \e[33m☒   $(basename "$file")\e[0m\n"
		done
		read -n 1 -s -r -p "   按任意键返回上级菜单..."
		return
	fi
	while true; do
		echo -e "\n   待打包目录的子分区：\n"
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
		echo -e "\n   [Y] 开始打包   [Q] 返回上级菜单\n"
		echo -n "   选择你想要执行的功能："
		read is_pack
		is_pack=$(echo "$is_pack" | tr '[:upper:]' '[:lower:]')
		clear
		case "$is_pack" in
		y)
			while true; do
				echo -e "\n   [1] OnlyA 动态分区   [2] AB 动态分区   [3] VAB 动态分区\n"
				echo -e "   [Q] 返回上级菜单\n"
				echo -n "   请选择你的分区类型："
				read partition_type
				partition_type=$(echo "$partition_type" | tr '[:upper:]' '[:lower:]')
				if [ "$partition_type" = "q" ]; then
					echo "   已取消选择分区类型，返回工作域菜单。"
					return
				fi
				clear
				case "$partition_type" in
				1 | 2 | 3)
					while true; do
						echo -e "\n   [1] 稀疏   [2] 非稀疏\n"
						echo -e "   [Q] 返回上级菜单\n"
						echo -n "   请选择打包方式："
						read is_sparse
						is_sparse=$(echo "$is_sparse" | tr '[:upper:]' '[:lower:]')
						if [ "$is_sparse" = "q" ]; then
							echo "   已取消选择，返回工作域菜单。"
							return
						fi
						case "$is_sparse" in
						1 | 2)
							break
							;;
						*)
							clear
							echo -e "\n   无效的选择，请重新输入。"
							;;
						esac
					done
					break
					;;
				*)
					clear
					echo -e "\n   无效的选择，请重新输入。"
					;;
				esac
			done
			break
			;;
		q)
			echo "已取消打包操作，返回上级菜单。"
			return
			;;
		*)
			clear
			echo -e "\n   无效的选择，请重新输入。"
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
		echo "   无效的选择，请重新输入。"
		;;
	esac
}
