function update_config_files {
	local partition="$1"
	local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
	local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"

	local temp_fs_config_file="$fs_config_file.tmp"
	local temp_file_contexts_file="$file_contexts_file.tmp"

	cat "$fs_config_file" >>"$temp_fs_config_file"  # 复制原配置文件内容
	cat "$file_contexts_file" >>"$temp_file_contexts_file"

	case "$partition" in
	"system")
		permission_source="rootfs"  # 设置权限源
		;;
	"system_dlkm")
		permission_source="system_dlkm_file"
		;;
	"product" | "mi_ext" | "system_ext")
		permission_source="system_file"
		;;
	"odm" | "vendor_dlkm")
		permission_source="vendor_file"
		;;
	*)
		permission_source="${partition}_file"
		;;
	esac

	mapfile -t relative_paths < <(find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | sed "s|^$WORK_DIR/$current_workspace/Extracted-files/||")  # 获取相对路径

	for relative_path in "${relative_paths[@]}"; do
		escaped_path=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\&/g' -e 's/]/\\]/g')
		escaped_path_for_grep=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\\\\\&/g' -e 's/]/\\]/g')

		if [ "$relative_path" = "$partition" ]; then
			continue
		fi

		if ! grep -Eq "^$escaped_path\s" "$temp_fs_config_file"; then
			if [ -d "$WORK_DIR/$current_workspace/Extracted-files/$relative_path" ]; then
				echo "$relative_path 0 0 0755" >>"$temp_fs_config_file"  # 处理目录
			elif [ -L "$WORK_DIR/$current_workspace/Extracted-files/$relative_path" ]; then
				local gid="0"
				local mode="0644"
				if [[ "$relative_path" == *"/system/bin"* || "$relative_path" == *"/system/xbin"* || "$relative_path" == *"/vendor/bin"* ]]; then
					gid="2000"  # 设置特定文件的GID
				fi
				if [[ "$relative_path" == *"/bin"* || "$relative_path" == *"/xbin"* ]]; then
					mode="0755"
				elif [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				local link_target=$(readlink -f "$WORK_DIR/$current_workspace/Extracted-files/$relative_path")
				if [[ "$link_target" == "$WORK_DIR/$current_workspace/Extracted-files/$partition"* ]]; then
					local relative_link_target="${link_target#$WORK_DIR/$current_workspace/Extracted-files/$partition}"
					echo "$relative_path 0 $gid $mode $relative_link_target" >>"$temp_fs_config_file"  # 处理符号链接
				else
					echo "$relative_path 0 $gid $mode" >>"$temp_fs_config_file"
				fi
			else
				local mode="0644"
				if [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				echo "$relative_path 0 0 $mode" >>"$temp_fs_config_file"  # 处理普通文件
			fi
		fi

		if ! grep -Eq "^/$escaped_path_for_grep\s.*" "$temp_file_contexts_file"; then
			echo "/$escaped_path u:object_r:${permission_source}:s0" >>"$temp_file_contexts_file"  # 添加文件上下文
		fi
	done

	for fs_config_fixed in "/" "${partition}/" "lost+found" "${partition}/lost+found"; do
		if ! grep -Eq "^${fs_config_fixed//+/\\+}\s" "$temp_fs_config_file"; then
			echo "${fs_config_fixed} 0 0 0755" >>"$temp_fs_config_file"  # 固定路径的权限
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
			echo "${file_contexts_fixed} u:object_r:${permission_source}:s0" >>"$temp_file_contexts_file"  # 添加固定上下文
		fi
	done

	mv "$temp_fs_config_file" "$fs_config_file"  # 替换原配置文件
	mv "$temp_file_contexts_file" "$file_contexts_file"

	while read -r line; do
		path=$(echo "$line" | awk '{print $1}')
		if [[ "$path" == "/" || "$path" == "lost+found" || "$path" == "$partition/" || "$path" == "$partition/lost+found" ]]; then
			continue
		fi
		if [[ ! " ${relative_paths[*]} " =~ " ${path} " ]]; then
			sed -i "\|^$path\s|d" "$fs_config_file"  # 移除已删除文件的配置
		fi
	done <"$fs_config_file"

	while read -r line; do
		path=$(echo "$line" | awk '{print $1}')
		if [[ "$path" == "/" || "$path" == "/lost\+found" || "$path" == "/$partition/" || "$path" == "/$partition/lost\+found" ]]; then
			continue
		fi
		path=${path#/}
		unescaped_path=$(echo "$path" | sed -e 's/\\\([+.\\[()（）]\)/\1/g' -e 's/\\]/]/g')
		if [[ ! " ${relative_paths[*]} " =~ " ${unescaped_path} " ]]; then
			sed -i "\|^/$path\s|d" "$file_contexts_file"  # 移除已删除文件上下文
		fi
	done <"$file_contexts_file"

	sort "$fs_config_file" -o "$fs_config_file"  # 重新排序配置文件
	sort "$file_contexts_file" -o "$file_contexts_file"  # 重新排序上下文文件
}
