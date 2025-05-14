function update_config_files {
	local partition="$1"
	local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
	local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"

	local temp_fs_config_file="$fs_config_file.tmp"
	local temp_file_contexts_file="$file_contexts_file.tmp"

	cat "$fs_config_file" >>"$temp_fs_config_file"
	cat "$file_contexts_file" >>"$temp_file_contexts_file"

	# 确定源分区类型
	case "$partition" in
	"system")
		permission_source="rootfs"
		;;
	"system_dlkm")
		permission_source="system_dlkm_file"
		;;
	"product" | "mi_ext")
		permission_source="system_file"
		;;
	"odm" | "vendor_dlkm")
		permission_source="vendor_file"
		;;
	*)
		permission_source="${partition}_file"
		;;
	esac

	# 遍历解包后的目录中的所有文件、目录和符号链接
	find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | while read -r file; do
		relative_path="${file#$WORK_DIR/$current_workspace/Extracted-files/}"

		escaped_path=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\&/g' -e 's/]/\\]/g')

		escaped_path_for_grep=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\\\\\&/g' -e 's/]/\\]/g')

		if [ "$relative_path" = "$partition" ]; then
			continue
		fi

		# 检查该路径是否已经在临时配置文件中
		if ! grep -Eq "^$escaped_path\s" "$temp_fs_config_file"; then
			# 如果不存在，则按照原来的方式添加
			if [ -d "$file" ]; then
				# 如果是目录，添加目录信息
				echo "$relative_path 0 0 0755" >>"$temp_fs_config_file"
			elif [ -L "$file" ]; then
				# 处理符号链接
				local gid="0"     # 默认组ID
				local mode="0644" # 默认权限模式
				# 根据路径设置特定的组ID和权限
				if [[ "$relative_path" == *"/system/bin"* || "$relative_path" == *"/system/xbin"* || "$relative_path" == *"/vendor/bin"* ]]; then
					gid="2000" # 设置特定的组ID
				fi
				if [[ "$relative_path" == *"/bin"* || "$relative_path" == *"/xbin"* ]]; then
					mode="0755" # 设置可执行权限
				elif [[ "$relative_path" == *".sh"* ]]; then
					mode="0750" # 设置脚本文件权限
				fi
				local link_target=$(readlink -f "$file") # 获取符号链接目标
				if [[ "$link_target" == "$WORK_DIR/$current_workspace/Extracted-files/$partition"* ]]; then
					# 如果链接目标在解包目录内，记录相对路径
					local relative_link_target="${link_target#$WORK_DIR/$current_workspace/Extracted-files/$partition}"
					echo "$relative_path 0 $gid $mode $relative_link_target" >>"$temp_fs_config_file"
				else
					# 否则只记录路径和权限
					echo "$relative_path 0 $gid $mode" >>"$temp_fs_config_file"
				fi
			else
				# 处理普通文件
				local mode="0644" # 默认文件权限
				if [[ "$relative_path" == *".sh"* ]]; then
					mode="0750" # 如果是脚本文件，设置特殊权限
				fi
				echo "$relative_path 0 0 $mode" >>"$temp_fs_config_file"
			fi
		fi

		if ! grep -Eq "^/$escaped_path_for_grep\s.*" "$temp_file_contexts_file"; then
			echo "/$escaped_path u:object_r:${permission_source}:s0" >>"$temp_file_contexts_file"
		fi

	done

	for fs_config_fixed in "/" "${partition}/" "lost+found" "${partition}/lost+found"; do
		if ! grep -Eq "^${fs_config_fixed//+/\\+}\s" "$temp_fs_config_file"; then
			echo "${fs_config_fixed} 0 0 0755" >>"$temp_fs_config_file"
		fi
	done

	for file_contexts_fixed in "/" "/lost\+found" "/${partition}/lost\+found" "/${partition}(/.*)?"; do
		fixed_path=$(echo "$file_contexts_fixed" | sed -e 's/+/\\\\+/g' -e 's/[().*?]/\\&/g')

		if [[ "$file_contexts_fixed" == "/${partition}(/.*)?" ]]; then
			if grep -Eq "^/${partition}/\s.*" "$temp_file_contexts_file"; then
				continue
			fi
		fi

		if ! grep -Eq "^${fixed_path}\s.*" "$temp_file_contexts_file"; then
			echo "${file_contexts_fixed} u:object_r:${permission_source}:s0" >>"$temp_file_contexts_file"
		fi
	done

	mv "$temp_fs_config_file" "$fs_config_file"
	mv "$temp_file_contexts_file" "$file_contexts_file"

	#排序
	sort "$fs_config_file" -o "$fs_config_file"
	sort "$file_contexts_file" -o "$file_contexts_file"
}
