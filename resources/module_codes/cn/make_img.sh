function package_single_partition {
	dir=$1
	fs_type_choice=$2
	utc=$(date +%s)

	fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_fs_config"
	file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_file_contexts"
	output_image="$WORK_DIR/$current_workspace/Repacked/$(basename "$dir").img"

	rm -rf "$output_image"

	start=$(python3 "$TOOL_DIR/get_right_time.py")

	update_config_files "$(basename "$dir")"
	echo "更新完成"

	case "$fs_type_choice" in
	1)
		fs_type="erofs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
		echo "正在打包分区 $(basename "$dir") ..."
		"$mkfs_tool_path" -d1 -zlz4hc,1 \
			-T "$utc" \
			--mount-point="/$(basename "$dir")" \
			--fs-config-file="$fs_config_file" \
			--product-out="$(dirname "$output_image")" \
			--file-contexts="$file_contexts_file" \
			"$output_image" "$dir" \
			>/dev/null 2>&1
		;;

	2)
		fs_type="f2fs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		size=$(($(du -sm "$dir" | cut -f1) * 1025 / 1000 + 55))
		echo "正在打包分区 $(basename "$dir") ..."
		dd if=/dev/zero of="$output_image" bs=1M count=$size >/dev/null 2>&1
		"$mkfs_tool_path" "$output_image" \
			-O extra_attr,inode_checksum,sb_checksum,compression \
			-f \
			-T "$utc" \
			-q
		"$sload_tool_path" -f "$dir" \
			-C "$fs_config_file" \
			-s "$file_contexts_file" \
			-t "/$(basename "$dir")" \
			"$output_image" \
			-c \
			-T "$utc" \
			>/dev/null 2>&1
		;;

	3)
		fs_type="ext4"
		mke2fs_tool_path="$(dirname "$0")/resources/my_tools/mke2fs"
		e2fsdroid_tool_path="$(dirname "$0")/resources/my_tools/e2fsdroid"
		size=$(du -sb "$dir" | cut -f1)

		if [ "$size" -lt $((1 * 1024 * 1024)) ]; then
			size=$((2 * 1024 * 1024))
		else
			size=$((size * 11 / 10))
		fi

		echo "正在打包分区 $(basename "$dir") ..."
		size_in_blocks=$((size / 4096))
		"$mke2fs_tool_path" \
			-O ^has_journal \
			-L "$(basename "$dir")" \
			-I 256 \
			-M "/$(basename "$dir")" \
			-m 0 \
			-t ext4 \
			-b 4096 \
			"$output_image" \
			"$size_in_blocks" \
			>/dev/null 2>&1
		"$e2fsdroid_tool_path" \
			-e \
			-T "$utc" \
			-a "/$(basename "$dir")" \
			-S "$file_contexts_file" \
			-C "$fs_config_file" \
			"$output_image" \
			-f "$dir" \
			>/dev/null 2>&1
		;;

	*)
		echo "不支持的文件系统类型：$fs_type_choice"
		return 1
		;;
	esac

	echo "任务完成"
	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "耗时 $runtime 秒"
}

function package_special_partition {
	start=$(python3 "$TOOL_DIR/get_right_time.py")
	local dir="$1"

	if [ "$(basename "$dir")" == "optics" ]; then
		package_single_partition "$dir" 3
		return
	fi

	echo -e "正在打包分区 $(basename "$dir")..."
	(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
	mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"
	cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"
	touch "$TOOL_DIR/boot_editor/$(basename "$dir").img"
	(cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1
	cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Repacked/$(basename "$dir").img"
	(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
	echo "任务完成"
	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "耗时 $runtime 秒"
}

function package_all_partitions {
	if [ $special_dir_count -ne ${#dir_array[@]} ]; then
		clear
		while true; do
			echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4\n"
			echo -e "   [Q] 返回上级菜单\n"
			echo -n "   请选择要打包的文件系统类型："
			read fs_type_choice
			fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
			if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" ]]; then
				break
			elif [ "$fs_type_choice" = "q" ]; then
				return
			else
				clear
				echo -e "\n   无效的输入，请重新输入。"
			fi
		done
	fi
	clear
	for dir in "${dir_array[@]}"; do
		if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* || "$(basename "$dir")" == "optics" ]]; then
			echo -e "\n"
			package_special_partition "$dir"
		else
			echo -e "\n"
			package_single_partition "$dir" "$fs_type_choice"
		fi
	done
	echo -n "按任意键返回上级菜单..."
	read -n 1
	clear
	return
}

function package_regular_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Repacked"
	while true; do
		echo -e "\n   当前分区目录：\n"
		local i=1
		local dir_array=()
		local special_dir_count=0
		for dir in "$WORK_DIR/$current_workspace/Extracted-files"/*; do
			if [ -d "$dir" ] && [ "$(basename "$dir")" != "config" ] && [ "$(basename "$dir")" != "super" ]; then
				printf "   \033[0;31m[%02d] %s\033[0m\n\n" "$i" "$(basename "$dir")"
				dir_array[i]="$dir"
				i=$((i + 1))
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* || "$(basename "$dir")" == "optics" ]]; then
					special_dir_count=$((special_dir_count + 1))
				fi
			fi
		done
		if [ ${#dir_array[@]} -eq 0 ]; then
			clear
			echo -e "\n   没有检测到任何分区文件。"
			echo -n "   按任意键返回..."
			read -n 1
			clear
			return
		fi
		echo -e "   [ALL] 打包所有分区文件    [Q] 返回上级菜单\n"
		echo -n "   请选择打包的分区目录："
		read dir_num
		dir_num=$(echo "$dir_num" | tr '[:upper:]' '[:lower:]')
		if [ "$dir_num" = "all" ]; then
			package_all_partitions
		elif [ "$dir_num" = "q" ]; then
			break
		else
			dir="${dir_array[$dir_num]}"
			if [ -d "$dir" ]; then
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* || "$(basename "$dir")" == "optics" ]]; then
					clear
					echo -e "\n"
					package_special_partition "$dir"
				else
					clear
					while true; do
						echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4\n"
						echo -e "   [Q] 返回上级菜单\n"
						echo -n "   请选择要打包的文件系统类型："
						read fs_type_choice
						fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
						if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" ]]; then
							break
						elif [ "$fs_type_choice" = "q" ]; then
							return
						else
							clear
							echo -e "\n   无效的输入，请重新输入。"
						fi
					done
					clear
					echo -e "\n"
					package_single_partition "$dir" "$fs_type_choice"
				fi
				echo -n "按任意键返回文件列表..."
				read -n 1
				clear
				continue
			else
				clear
				echo -e "\n   选择的目录不存在，请重新选择。"
			fi
		fi
	done
}
