function update_config_files {
	local partition="$1"
	local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
	local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"
	local temp_fs_config_file="$fs_config_file.tmp"
	local temp_file_contexts_file="$file_contexts_file.tmp"
	cat "$fs_config_file" >>"$temp_fs_config_file"
	cat "$file_contexts_file" >>"$temp_file_contexts_file"
	case "$partition" in
	"system")
		source_partition="rootfs"
		;;
	"system_dlkm")
		source_partition="system_dlkm_file"
		;;
	"product")
		source_partition="system_file"
		;;
	"odm" | "vendor_dlkm")
		source_partition="vendor_file"
		;;
	*)
		source_partition="${partition}_file"
		;;
	esac
	find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | while read -r file; do
		relative_path="${file#$WORK_DIR/$current_workspace/Extracted-files/}"
		escaped_path=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\&/g' -e 's/]/\\]/g')
		escaped_path_for_grep=$(echo "$escaped_path" | sed 's/\\/\\\\\\/g')
		if ! grep -Eq "^$escaped_path\s" "$temp_fs_config_file"; then
			if [ -d "$file" ]; then
				echo "$relative_path 0 0 0755" >>"$temp_fs_config_file"
			elif [ -L "$file" ]; then
				local gid="0"
				local mode="0644"
				if [[ "$relative_path" == *"/system/bin"* || "$relative_path" == *"/system/xbin"* || "$relative_path" == *"/vendor/bin"* ]]; then
					gid="2000"
				fi
				if [[ "$relative_path" == *"/bin"* || "$relative_path" == *"/xbin"* ]]; then
					mode="0755"
				elif [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				local link_target=$(readlink -f "$file")
				if [[ "$link_target" == "$WORK_DIR/$current_workspace/Extracted-files/$partition"* ]]; then
					local relative_link_target="${link_target#$WORK_DIR/$current_workspace/Extracted-files/$partition}"
					echo "$relative_path 0 $gid $mode $relative_link_target" >>"$temp_fs_config_file"
				else
					echo "$relative_path 0 $gid $mode" >>"$temp_fs_config_file"
				fi
			else
				local mode="0644"
				if [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				echo "$relative_path 0 0 $mode" >>"$temp_fs_config_file"
			fi
		fi
		if ! grep -Eq "^/$escaped_path_for_grep\s.*" "$temp_file_contexts_file"; then
			echo "/$escaped_path u:object_r:${source_partition}:s0" >>"$temp_file_contexts_file"
		fi
	done
	for fs_config_fixed in "lost+found" "${partition}" "/"; do
		if ! grep -Eq "^${fs_config_fixed//+/\\+}\s" "$temp_fs_config_file"; then
			echo "${fs_config_fixed} 0 0 0755" >>"$temp_fs_config_file"
		fi
	done
	for file_contexts_fixed in  "/${partition}" "/${partition}(/.*)?" "/"; do
		fixed_path=$(echo "$file_contexts_fixed" | sed 's/\\/\\\\/g; s/(/\\(/g; s/)/\\)/g; s/\./\\./g; s/\*/\\*/g; s/?/\\?/g; s/+/\\+/g')
		if ! grep -Eq "^${fixed_path}\s.*" "$temp_file_contexts_file"; then
			if [ "$partition" = "system" ]; then
				echo "${file_contexts_fixed} u:object_r:rootfs:s0" >>"$temp_file_contexts_file"
			else
				echo "${file_contexts_fixed} u:object_r:${source_partition}:s0" >>"$temp_file_contexts_file"
			fi
		fi
	done
	mv "$temp_fs_config_file" "$fs_config_file"
	mv "$temp_file_contexts_file" "$file_contexts_file"
	sort "$fs_config_file" -o "$fs_config_file"
	sort "$file_contexts_file" -o "$file_contexts_file"
}
