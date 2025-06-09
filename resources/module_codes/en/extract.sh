function extract_single_img {
	local single_file="$1"
	local single_file_name=$(basename "$single_file")
	local base_name="${single_file_name%.*}"
	fs_type=$(recognize_file_type "$single_file")
	start=$(python3 "$TOOL_DIR/get_right_time.py")

	if [[ "$fs_type" == "ext" || "$fs_type" == "erofs" || "$fs_type" == "f2fs" ||
		"$fs_type" == "boot" || "$fs_type" == "dtbo" || "$fs_type" == "recovery" ||
		"$fs_type" == "vbmeta" || "$fs_type" == "vendor_boot" ]]; then
		rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
	fi

	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"

	case "$fs_type" in
	sparse)
		echo "Converting sparse format ${single_file_name}, please wait..."
		"$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
		rm -rf "$single_file"
		mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
		single_file="$WORK_DIR/$current_workspace/${base_name}.img"
		echo "Conversion completed"
		extract_single_img "$single_file"
		return
		;;
	super)
		echo "Extracting SUPER partition file ${single_file_name}, please wait..."
		super_size=$(stat -c%s "$single_file")
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"
		if [ ! -s "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" ]; then
			echo "$super_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size"
		fi
		"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
		rm "$single_file"
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

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

		if [ "$choice" = "all" ] && $allow_extract_all; then
			matching_imgs=()
			for img in "$WORK_DIR/$current_workspace"/*.img; do
				img_name=$(basename "$img")
				if [[ "$img_name" =~ ^($super_sub_partitions_list)$ ]]; then
					matching_imgs+=("$img")
				fi
			done

			for img in "${matching_imgs[@]}"; do
				img_name=$(basename "$img")
				file_type=$(recognize_file_type "$img")

				if [ "$file_type" != "unknown" ]; then
					extract_single_img "$img" "$file_type"

					if [ "$img" != "${matching_imgs[-1]}" ]; then
						echo ""
					fi
				fi
			done
		else
			echo "Task completed"
		fi

		return
		;;
	boot | dtbo | recovery | vendor_boot | vbmeta)
		echo "Extracting partition ${single_file_name}, please wait..."
		(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
		cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
		(cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) >/dev/null 2>&1
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
		mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
		(cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
		echo "Task completed"
		;;
	f2fs)
		echo "Extracting partition ${single_file_name}, please wait..."
		"$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" >/dev/null 2>&1
		echo "Task completed"
		;;
	erofs)
		echo "Extracting partition ${single_file_name}, please wait..."
		"$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x >/dev/null 2>&1
		echo "Task completed"
		;;
	ext)
		echo "Extracting partition ${single_file_name}, please wait..."
		partition_size=$(stat -c%s "$single_file")
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"
		echo "$partition_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_${base_name}_size_ext"
		PYTHONDONTWRITEBYTECODE=1 python3 "$TOOL_DIR/ext4_info_get.py" "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config"
		mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/${base_name}"
		echo "rdump / \"$WORK_DIR/${current_workspace}/Extracted-files/${base_name}\"" | sudo debugfs "$single_file" >/dev/null 2>&1
		sudo chmod -R a+rwx "$WORK_DIR/$current_workspace/Extracted-files/${base_name}"
		echo "Task completed"
		;;
	payload)
		echo "Extracting ${single_file_name}, please wait..."
		"$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file" >/dev/null 2>&1
		rm -rf "$single_file"
		echo "Task completed"
		;;
	zip)
		file_list=$("$TOOL_DIR/7z" l "$single_file")

		if echo "$file_list" | grep -q "payload.bin" && echo "$file_list" | grep -q "META-INF"; then
			echo "Detected ROM flash package ${single_file_name}, please wait..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "payload.bin" -o"$WORK_DIR/$current_workspace"
			extract_single_img "$WORK_DIR/$current_workspace/payload.bin"
			rm -rf "$single_file"
			return
		elif echo "$file_list" | grep -q "images/" && echo "$file_list" | grep -q ".img"; then
			echo "Detected ROM flash package ${single_file_name}, please wait..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "images/*.img" -o"$WORK_DIR/$current_workspace"
			rm -rf "$single_file"
			echo "Task completed"
		elif echo "$file_list" | grep -qE "AP|BL|CP|CSC"; then
			echo "Detected Odin format ROM package ${single_file_name}, please wait..."
			"$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace" -ir'!AP*' -ir'!BL*' -ir'!CP*' -ir'!CSC*'
			for extracted_file in "$WORK_DIR/$current_workspace"/{AP*,BL*,CP*,CSC*}; do
				if [ -f "$extracted_file" ]; then
					fs_type=$(recognize_file_type "$extracted_file")
					if [ "$fs_type" == "tar" ]; then
						echo ""
						extract_single_img "$extracted_file"
					fi
				fi
			done
			rm -rf "$single_file"
			return
		else
			echo "${single_file_name} may not be a flashable ROM package"
		fi
		;;
	tar)
		echo "Extracting TAR file ${single_file_name}, please wait..."
		"$TOOL_DIR/7z" x "$single_file" -o"$WORK_DIR/$current_workspace" -xr'!meta-data'
		rm -rf "$single_file"
		echo "Task completed"

		found_lz4=false
		lz4_count=0
		lz4_total=$(ls "$WORK_DIR/$current_workspace"/*.lz4 2>/dev/null | wc -l)

		for lz4_file in "$WORK_DIR/$current_workspace"/*.lz4; do
			if [ -f "$lz4_file" ]; then
				extract_single_img "$lz4_file"
				found_lz4=true
				lz4_count=$((lz4_count + 1))

				if [ "$lz4_count" -lt "$lz4_total" ]; then
					echo ""
				fi
			fi
		done

		if [ "$found_lz4" = true ]; then
			return
		fi
		;;
	lz4)
		echo "Extracting LZ4 file ${single_file_name}, please wait..."
		lz4 -dq "$single_file" "$WORK_DIR/$current_workspace/${base_name}"
		rm -rf "$single_file"
		echo "Task completed"
		;;
	*)
		echo "Unknown file system type"
		;;
	esac

	end=$(python3 "$TOOL_DIR/get_right_time.py")
	runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "Time taken $runtime seconds"
}

function extract_img {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	while true; do
		shopt -s nullglob
		regular_files=("$WORK_DIR/$current_workspace"/*.{bin,img,elf,mbn,pit,melf,fv})
		specific_files=("$WORK_DIR/$current_workspace"/*.{zip,lz4,tar,md5})
		matched_files=("${regular_files[@]}" "${specific_files[@]}")
		shopt -u nullglob
		if [ -e "${matched_files[0]}" ]; then
			displayed_files=()
			counter=0
			allow_extract_all=true
			img_files_exist=false
			special_files_exist=false
			ext_files_exist=false
			for i in "${!matched_files[@]}"; do
				if [ -f "${matched_files[$i]}" ]; then
					fs_type=$(recognize_file_type "${matched_files[$i]}")
					if [ "$fs_type" != "unknown?" ]; then
						displayed_files+=("${matched_files[$i]}")
						counter=$((counter + 1))
						if [[ "$fs_type" == "ext" ]]; then
							ext_files_exist=true
							if [[ "$fs_type" == "tar" || "$fs_type" == "zip" || "$fs_type" == "lz4" ]]; then
								special_files_exist=true
							elif [[ "${matched_files[$i]}" == *.img ]]; then
								img_files_exist=true
							fi
						fi
					fi
				fi
			done

			if $special_files_exist && $img_files_exist; then
				allow_extract_all=false
			fi

			while true; do
				echo -e "\n   Files in the current working directory:\n"
				for i in "${!displayed_files[@]}"; do
					fs_type_upper=$(echo "$(recognize_file_type "${displayed_files[$i]}")" | awk '{print toupper($0)}')
					file_size=$(stat -c%s "${displayed_files[$i]}")
					if [ "$file_size" -lt 1048576 ]; then
						size_display=$(echo "scale=1; $file_size / 1024" | bc)Kb
					elif [ "$file_size" -lt 1073741824 ]; then
						size_display=$(echo "scale=1; $file_size / 1048576" | bc)Mb
					else
						size_display=$(echo "scale=1; $file_size / 1073741824" | bc)Gb
					fi
					printf "   \033[94m[%02d] %s —— %s <%s>\033[0m\n\n" "$((i + 1))" "$(basename "${displayed_files[$i]}")" "$fs_type_upper" "$size_display"
				done
				if $allow_extract_all; then
					echo -e "   [ALL] Extract all    [S] Simple recognition    [F] Refresh    [Q] Return to previous menu\n"
				else
					echo -e "   [S] Simple recognition    [F] Refresh    [Q] Return to previous menu\n"
				fi
				echo -n "   Please select an extraction option, supports multiple selections, separated by spaces: "
				read -r choice
				choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

				if [[ "$choice" =~ ^[0-9\ ]+$ ]]; then
					clear
					selected_files=()
					for num in $choice; do
						if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#displayed_files[@]} ]; then
							selected_files+=("${displayed_files[$((num - 1))]}")
						fi
					done

					if [ ${#selected_files[@]} -gt 0 ]; then
						echo ""
						for ((i = 0; i < ${#selected_files[@]}; i++)); do
							file="${selected_files[$i]}"
							extract_single_img "$file"
							if [ $i -lt $((${#selected_files[@]} - 1)) ]; then
								echo ""
							fi
						done
						echo -n "Press any key to return to the file list..."
						read -n 1
						clear
						break
					fi
					continue
				fi

				case "$choice" in
				"all")
					if $allow_extract_all; then
						clear
						echo ""
						if $ext_files_exist; then
							sudo echo "" >/dev/null
						fi
						clear
						echo ""
						for ((i = 0; i < ${#displayed_files[@]}; i++)); do
							file="${displayed_files[$i]}"
							extract_single_img "$file"
							if [ $i -lt $((${#displayed_files[@]} - 1)) ]; then
								echo ""
							fi
						done
						echo -n "Press any key to return to the previous menu..."
						read -n 1
						clear
						return
					else
						echo -e "\n   Currently, extracting all files is not supported."
					fi
					;;
				"s")
					mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
					shopt -s nullglob
					for file in "$WORK_DIR/$current_workspace"/*.{img,elf,melf,mbn,bin,fv,pit}; do
						filename=$(basename "$file")
						if [ "$filename" != "super.img" ] && ! [[ "$filename" =~ ^vbmeta.*.img$ ]] && [ "$filename" != "optics.img" ] && ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
							mv -f "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/" 2>/dev/null
						fi
					done
					shopt -u nullglob
					clear
					break
					;;
				"f")
					clear
					break
					;;
				"q")
					return
					;;
				*)
					clear
					echo -e "\n   Invalid selection, please try again."
					;;
				esac
			done
		else
			echo -e "\n   No files in the working directory."
			echo -n "   Press any key to return to the previous menu..."
			read -n 1
			return
		fi
	done
}
