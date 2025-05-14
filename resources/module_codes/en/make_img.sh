function package_single_partition {
	dir=$1
	fs_type_choice=$2
	utc=$(date +%s)
	fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_fs_config"
	file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_file_contexts"
	output_image="$WORK_DIR/$current_workspace/Repacked/$(basename "$dir").img"
	rm -rf "$output_image"
	start=$(python3 "$TOOL_DIR/get_right_time.py")
	echo -e "Updating configuration files for partition $(basename "$dir")..."
	update_config_files "$(basename "$dir")"
	echo "Update complete"
	case "$fs_type_choice" in
	1)
		fs_type="erofs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
		echo "Packing partition $(basename "$dir") ..."
		"$mkfs_tool_path" -d1 -zlz4hc,0 \
			-T "$utc" --all-time \
			--mount-point="/$(basename "$dir")" \
			--fs-config-file="$fs_config_file" \
			--file-contexts="$file_contexts_file" \
			--product-out="$(dirname "$output_image")" \
			"$output_image" "$dir" \
			--workers=$(nproc) \
			>/dev/null 2>&1
		;;
	2)
		fs_type="f2fs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		size=$(($(du -sb "$dir" | cut -f1) + (55 * 1024 * 1024)))
		echo "Packing partition $(basename "$dir")..."
		full_blocks=$((size / 1024 / 1024))
		remaining_bytes=$((size % (1024 * 1024)))
		if [ "$full_blocks" -gt 0 ]; then
			dd if=/dev/zero of="$output_image" bs=1M count=$full_blocks >/dev/null 2>&1
		fi
		if [ "$remaining_bytes" -gt 0 ]; then
			dd if=/dev/zero of="$output_image" bs=1 count=$remaining_bytes seek=$((full_blocks * 1024 * 1024)) conv=notrunc >/dev/null 2>&1
		fi
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
		original_size_file="$WORK_DIR/$current_workspace/Extracted-files/config/original_$(basename "$dir")_size_ext"
		size_to_pack=$(du -sb "$dir" | cut -f1)
		if [ -f "$original_size_file" ] && [ "$size_to_pack" -le "$(cat "$original_size_file")" ]; then
			size=$(cat "$original_size_file")
			echo "Using original size to pack partition $(basename "$dir")..."
		else
			size=$((size_to_pack * 101 / 100 + (5 * 1024 * 1024)))
			echo "Using dynamically calculated size to pack partition $(basename "$dir")..."
		fi
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
			"$size_in_blocks" >/dev/null 2>&1
		"$e2fsdroid_tool_path" \
			-e \
			-T "$utc" \
			-a "/$(basename "$dir")" \
			-S "$file_contexts_file" \
			-C "$fs_config_file" \
			"$output_image" \
			-f "$dir" >/dev/null 2>&1
		;;
	*)
		echo "Unsupported filesystem type: $fs_type_choice"
		return 1
		;;
	esac
	echo "Task completed"
	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "Elapsed time: $runtime seconds"
}
function package_special_partition {
	start=$(python3 "$TOOL_DIR/get_right_time.py")
	local dir="$1"
	if [ "$(basename "$dir")" == "optics" ]; then
		package_single_partition "$dir" 3
		return
	fi
	echo -e "Packing partition $(basename "$dir")..."
	(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
	mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"
	cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"
	touch "$TOOL_DIR/boot_editor/$(basename "$dir").img"
	(cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1
	cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Repacked/$(basename "$dir").img"
	(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
	echo "Task completed"
	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "Elapsed time: $runtime seconds"
}
function package_all_partitions {
	if [ $special_dir_count -ne ${#dir_array[@]} ]; then
		clear
		while true; do
			echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4\n"
			echo -e "   [Q] Return to previous menu\n"
			echo -n "   Please select the filesystem type to pack: "
			read fs_type_choice
			fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
			if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" ]]; then
				break
			elif [ "$fs_type_choice" = "q" ]; then
				return
			else
				clear
				echo -e "\n   Invalid input, please try again."
			fi
		done
	fi
	clear
	for dir in "${dir_array[@]}"; do
		case "$(basename "$dir")" in
		dtbo | boot | init_boot | vendor_boot | recovery | *vbmeta* | optics)
			echo ""
			package_special_partition "$dir"
			;;
		*)
			echo ""
			package_single_partition "$dir" "$fs_type_choice"
			;;
		esac
	done
	echo -n "Press any key to return to previous menu..."
	read -n 1
	clear
	return
}
function package_regular_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Repacked"
	while true; do
		echo -e "\n   Partitions to be packed:\n"
		local i=1
		local dir_array=()
		local special_dir_count=0
		for dir in "$WORK_DIR/$current_workspace/Extracted-files"/*; do
			if [ -d "$dir" ] && [ "$(basename "$dir")" != "config" ] && [ "$(basename "$dir")" != "super" ]; then
				file_size=$(du -sb "$dir" | awk '{print $1}')
				if [ "$file_size" -lt 1048576 ]; then
					size_display=$(echo "scale=1; $file_size / 1024" | bc)Kb
				elif [ "$file_size" -lt 1073741824 ]; then
					size_display=$(echo "scale=1; $file_size / 1048576" | bc)Mb
				else
					size_display=$(echo "scale=1; $file_size / 1073741824" | bc)Gb
				fi
				printf "   \033[0;31m[%02d] %s —— <%s>\033[0m\n\n" "$i" "$(basename "$dir")" "$size_display"
				dir_array[i]="$dir"
				i=$((i + 1))
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* || "$(basename "$dir")" == "optics" ]]; then
					special_dir_count=$((special_dir_count + 1))
				fi
			fi
		done
		if [ ${#dir_array[@]} -eq 0 ]; then
			clear
			echo -e "\n   No partition files detected."
			echo -n "   Press any key to return..."
			read -n 1
			clear
			return
		fi
		echo -e "   [ALL] Pack all partition files    [Q] Return to previous menu\n"
		echo -n "   Please select packing options, multiple selections supported, separated by spaces: "
		read dir_num_str
		clear
		dir_num_str=$(echo "$dir_num_str" | tr '[:upper:]' '[:lower:]')
		if [ "$dir_num_str" = "all" ]; then
			package_all_partitions
			return
		elif [ "$dir_num_str" = "q" ]; then
			break
		else
			IFS=' ' read -r -a dir_nums <<<"$dir_num_str"
			local dirs_to_package=()
			local dirs_with_fs_type=()
			for dir_num in "${dir_nums[@]}"; do
				dir_num=$(echo "$dir_num" | tr -d '[:space:]')
				dir="${dir_array[$dir_num]}"
				if [ -d "$dir" ]; then
					case "$(basename "$dir")" in
					dtbo | boot | init_boot | vendor_boot | recovery | *vbmeta* | optics)
						dirs_to_package+=("$dir")
						;;
					*)
						dirs_with_fs_type+=("$dir")
						;;
					esac
				else
					clear
					echo -e "\n   The selected directory does not exist, please select again."
					continue 2
				fi
			done
			if [ ${#dirs_with_fs_type[@]} -gt 0 ]; then
				clear
				while true; do
					echo -e "\n   [1] EROFS   [2] F2FS   [3] EXT4\n"
					echo -e "   [Q] Return to previous menu\n"
					echo -n "   Please select the filesystem type to pack: "
					read fs_type_choice
					fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
					if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" ]]; then
						break
					elif [ "$fs_type_choice" = "q" ]; then
						return
					else
						clear
						echo -e "\n   Invalid input, please try again."
					fi
				done
				clear
				for dir in "${dirs_with_fs_type[@]}"; do
					dirs_to_package+=("$dir")
				done
			fi
			for dir in "${dirs_to_package[@]}"; do
				case "$(basename "$dir")" in
				dtbo | boot | init_boot | vendor_boot | recovery | *vbmeta* | optics)
					echo ""
					package_special_partition "$dir"
					;;
				*)
					echo ""
					package_single_partition "$dir" "$fs_type_choice"
					;;
				esac
			done
			echo -n "Press any key to return to the file list..."
			read -n 1
			clear
			continue
		fi
	done
}
