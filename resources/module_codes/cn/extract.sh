function extract_single_img {
	local single_file="$1"
	local single_file_name=$(basename "$single_file")
	local base_name="${single_file_name%.*}"
	fs_type=$(recognize_file_type "$single_file")
	start=$(python3 "$TOOL_DIR/get_right_time.py")

	# 在提取前清理一次目标文件夹
	if [[ "$fs_type" == "ext" || "$fs_type" == "erofs" || "$fs_type" == "f2fs" ||
		"$fs_type" == "boot" || "$fs_type" == "dtbo" || "$fs_type" == "recovery" ||
		"$fs_type" == "vbmeta" || "$fs_type" == "vendor_boot" ]]; then
		rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
	fi

	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"

	case "$fs_type" in
	sparse)
		echo "正在转换稀疏格式 ${single_file_name}，请稍等..."
		"$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
		rm -rf "$single_file"
		mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
		single_file="$WORK_DIR/$current_workspace/${base_name}.img"
		echo "转换完成"
		extract_single_img "$single_file"
		return
		;;
	super)
		echo "正在提取 SUPER 分区文件 ${single_file_name}，请稍等..."

		# 读取 super 文件的字节数大小
		super_size=$(stat -c%s "$single_file")

		# 创建 config 文件夹并写入 original_super_size 文件
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"

		# 检查 original_super_size 文件是否存在且有内容
		if [ ! -s "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" ]; then
			echo "$super_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size"
		fi

		"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
		rm "$single_file"
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
		echo "任务完成"
		;;
	boot | dtbo | recovery | vbmeta | vendor_boot)
		echo "正在提取分区 ${single_file_name}，请稍等..."
		(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
		cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
		(cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) >/dev/null 2>&1
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
		mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
		(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
		echo "任务完成"
		;;
	f2fs)
		echo "正在提取分区 ${single_file_name}，请稍等..."
		"$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" >/dev/null 2>&1
		echo "任务完成"
		;;
	erofs)
		echo "正在提取分区 ${single_file_name}，请稍等..."
		"$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x >/dev/null 2>&1
		echo "任务完成"
		;;
	ext)
		echo "正在提取分区 ${single_file_name}，请稍等..."
		PYTHONDONTWRITEBYTECODE=1 python3 "$TOOL_DIR/ext4_info_get.py" "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config"
		partition_size=$(stat -c%s "$single_file")
		
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"
		echo "$partition_size" > "$WORK_DIR/$current_workspace/Extracted-files/config/original_${base_name}_size_for_ext4"

		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/${base_name}"

		echo "rdump / \"$WORK_DIR/${current_workspace}/Extracted-files/${base_name}\"" | sudo debugfs "$single_file" >/dev/null 2>&1

		sudo chmod -R a+rwx "$WORK_DIR/$current_workspace/Extracted-files/${base_name}"
		echo "任务完成"
		;;
	payload)
		echo "正在提取 ${single_file_name}，请稍等..."
		"$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file" >/dev/null 2>&1
		rm -rf "$single_file"
		echo "任务完成"
		;;
	zip)
		# 列出 zip 文件内容
		file_list=$("$TOOL_DIR/7z" l "$single_file")

		# 检查是否存在 payload.bin 文件和 META-INF 文件夹
		if echo "$file_list" | grep -q "payload.bin" && echo "$file_list" | grep -q "META-INF"; then
			echo "检测到 Rom 刷入包 ${single_file_name}，请稍等..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "payload.bin" -o"$WORK_DIR/$current_workspace"
			extract_single_img "$WORK_DIR/$current_workspace/payload.bin"
			rm -rf "$single_file"
			return
		# 检查是否存在 images 文件夹和 .img 文件
		elif echo "$file_list" | grep -q "images/" && echo "$file_list" | grep -q ".img"; then
			echo "检测到 Rom 刷入包 ${single_file_name}，请稍等..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "images/*.img" -o"$WORK_DIR/$current_workspace"
			rm -rf "$single_file"
			echo "任务完成"
		# 检查是否存在 AP, BL, CP, CSC 开头的文件
		elif echo "$file_list" | grep -qE "AP|BL|CP|CSC"; then
			echo "检测到 Odin 格式 Rom 包 ${single_file_name}，请稍等..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace" -ir'!AP*' -ir'!BL*' -ir'!CP*' -ir'!CSC*'
			for extracted_file in "$WORK_DIR/$current_workspace"/{AP*,BL*,CP*,CSC*}; do
				if [ -f "$extracted_file" ]; then
					fs_type=$(recognize_file_type "$extracted_file")
					if [ "$fs_type" == "tar" ]; then
						extract_single_img "$extracted_file"
					fi
				fi
			done
			rm -rf "$single_file"
			return
		else
			echo "${single_file_name} 可能并不是一个可刷入的 Rom 包"
		fi
		;;
	tar)
		echo "正在提取 TAR 文件 ${single_file_name}，请稍等..."
		"$TOOL_DIR/7z" x "$single_file" -o"$WORK_DIR/$current_workspace" -xr'!meta-data'
		rm -rf "$single_file"
		echo "任务完成"

		found_lz4=false
		for lz4_file in "$WORK_DIR/$current_workspace"/*.lz4; do
			if [ -f "$lz4_file" ]; then
				extract_single_img "$lz4_file"
				found_lz4=true
			fi
		done

		if [ "$found_lz4" = true ]; then
			return
		fi
		;;
	lz4)
		echo "正在提取 LZ4 文件 ${single_file_name}，请稍等..."
		lz4 -dq "$single_file" "$WORK_DIR/$current_workspace/${base_name}"
		rm -rf "$single_file"
		echo "任务完成"
		;;
	*)
		echo "未知的文件系统类型"
		;;
	esac

	for file in "$WORK_DIR/$current_workspace"/*; do
		base_name=$(basename "$file")
		if [[ ! -s $file ]] || [[ $base_name == *_b.img ]] || [[ $base_name == *_b ]] || [[ $base_name == *_b.ext ]]; then
			rm -rf "$file"
		elif [[ $base_name == *_a.img ]]; then
			mv -f "$file" "${file%_a.img}.img"
		elif [[ $base_name == *_a.ext ]]; then
			mv -f "$file" "${file%_a.ext}.img"
		elif [[ $base_name == *.ext ]]; then
			mv -f "$file" "${file%.ext}.img"
		fi
	done

	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "耗时 $runtime 秒"
}

function extract_img {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	while true; do
		shopt -s nullglob
		regular_files=("$WORK_DIR/$current_workspace"/*.{bin,img})
		specific_files=("$WORK_DIR/$current_workspace"/*.{zip,lz4,tar,md5})
		matched_files=("${regular_files[@]}" "${specific_files[@]}")
		shopt -u nullglob
		if [ -e "${matched_files[0]}" ]; then
			displayed_files=()
			counter=0
			allow_extract_all=true
			img_files_exist=false
			special_files_exist=false
			for i in "${!matched_files[@]}"; do
				if [ -f "${matched_files[$i]}" ]; then
					fs_type=$(recognize_file_type "${matched_files[$i]}")
					if [ "$fs_type" != "unknown" ]; then
						displayed_files+=("${matched_files[$i]}")
						counter=$((counter + 1))
						if [[ "$fs_type" == "tar" || "$fs_type" == "zip" || "$fs_type" == "lz4" ]]; then
							special_files_exist=true
						elif [[ "${matched_files[$i]}" == *.img ]]; then
							img_files_exist=true
						fi
					fi
				fi
			done
			if $special_files_exist && $img_files_exist; then
				allow_extract_all=false
			fi
			while true; do
				echo -e "\n   当前工作域的文件：\n"
				for i in "${!displayed_files[@]}"; do
					fs_type_upper=$(echo "$(recognize_file_type "${displayed_files[$i]}")" | awk '{print toupper($0)}')
					printf "   \033[94m[%02d] %s —— %s\033[0m\n\n" "$((i + 1))" "$(basename "${displayed_files[$i]}")" "$fs_type_upper"
				done
				if $allow_extract_all; then
					echo -e "   [ALL] 提取所有    [S] 简易识别    [F] 刷新    [Q] 返回上级菜单\n"
				else
					echo -e "   [S] 简易识别    [F] 刷新    [Q] 返回上级菜单\n"
				fi
				echo -n "   请选择要提取的分区文件："
				read choice
				choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
				if [ "$choice" = "all" ] && $allow_extract_all; then
					clear
					for file in "${displayed_files[@]}"; do
						echo -e "\n"
						extract_single_img "$file"
					done
					echo -n "按任意键返回上级菜单..."
					read -n 1
					clear
					return
				elif [ "$choice" = "s" ]; then
					mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
					for file in "$WORK_DIR/$current_workspace"/*.{img,elf,melf,mbn,bin,fv,pit}; do
						filename=$(basename "$file")
						if [ -f "$WORK_DIR/$current_workspace/optics.img" ]; then
							if [ "$filename" != "super.img" ] && [[ "$filename" != vbmeta*.img ]] && [[ "$filename" != "optics.img" ]] && [[ "$filename" != "vendor_boot.img" ]] && ! grep -q "$filename" "$TOOL_DIR/super_search"; then
								mv "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/" 2>/dev/null
							fi
						else
							if [ "$filename" != "super.img" ] && ! grep -q "$filename" "$TOOL_DIR/super_search"; then
								mv "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/" 2>/dev/null
							fi
						fi
					done
					clear
					break
				elif [ "$choice" = "f" ]; then
					clear
					break
				elif [ "$choice" = "q" ]; then
					return
				elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#displayed_files[@]} ]; then
					file="${displayed_files[$((choice - 1))]}"
					if [ -f "$file" ]; then
						clear
						echo -e "\n"
						extract_single_img "$file"
						echo -n "按任意键返回文件列表..."
						read -n 1
						clear
						break
					else
						echo "   文件不存在。"
					fi
				else
					clear
					echo -e "\n   无效的选择，请重新输入。"
				fi
			done
		else
			echo -e "\n   工作域中没有文件。"
			echo -n "   按任意键返回上级菜单..."
			read -n 1
			return
		fi
	done
}
