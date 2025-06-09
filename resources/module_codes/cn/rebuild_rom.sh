function rebuild_rom {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
	while true; do
		echo -e "\n   请把要刷入的分区文件放入在所选工作域的 Ready-to-flash/images 目录"
		if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
			echo -e "\n   提示：“轻松移动”可以将 Repacked 目录的文件快速移动到 Ready-to-flash/images 目录"
		fi
		echo -e "\n   [1] 线卡一体包    " "[2] Odin 包    " "[Q] 返回上级菜单\n"

		# 检查是否有 img 文件
		if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
			echo -e "   [M] 轻松移动\n"
		fi

		echo -n "   选择你的操作："
		read main_choice
		main_choice=$(echo "$main_choice" | tr '[:upper:]' '[:lower:]')
		if [[ "$main_choice" == "1" || "$main_choice" == "2" || "$main_choice" == "q" || "$main_choice" == "m" ]]; then
			break
		else
			clear
			echo -e "\n   无效的选项，请重新输入。"
		fi
	done

	if [[ "$main_choice" == "1" ]]; then
		clear
		while true; do
			echo -e "\n   [Q] 返回上级菜单\n"
			echo -n "   请输入你的机型："
			read device_model
			device_model=$(echo "$device_model" | tr '[:upper:]' '[:lower:]')
			if [[ "$device_model" == "q" ]]; then
				echo "   任务取消，返回上级菜单。"
				return
			elif [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
				break
			else
				clear
				echo -e "\n   不可能的型号，请重新输入。"
			fi
		done
		sed -i "s/set \"right_device=.*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat"
		sed -i "s/right_device=\".*\"/right_device=\"$device_model\"/g" "$TOOL_DIR/flash_tool/META-INF/com/google/android/update-binary"
		clear
		while true; do
			echo -e "\n   [1] 分卷压缩    " "[2] 完全压缩    " "[Q] 返回上级菜单\n"
			echo -n "   请输入压缩方式："
			read compression_choice
			if [[ "$compression_choice" == "1" || "$compression_choice" == "2" || "$compression_choice" == "q" ]]; then
				break
			else
				clear
				echo -e "\n   无效的选项，请重新输入。"
			fi
		done
		clear
		if [[ "$compression_choice" == "1" ]]; then
			while true; do
				echo -e "\n   [Q] 返回上级菜单\n"
				echo -n "   请输入分卷大小："
				read volume_size
				if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ || "$volume_size" == "q" ]]; then
					break
				else
					clear
					echo -e "\n   无效的分卷大小，请重新输入。"
				fi
			done
			if [[ "$volume_size" == "q" ]]; then
				echo "   任务取消，返回上级菜单。"
				return
			fi
			clear
			start=$(python3 "$TOOL_DIR/get_right_time.py")
			echo -e "\n开始打包..."
			find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
			"$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" \
				"$TOOL_DIR/flash_tool/bin" \
				"$TOOL_DIR/flash_tool/FlashROM.bat" \
				"$TOOL_DIR/flash_tool/META-INF" \
				"$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
			echo -e "线卡一体包打包完成"
			end=$(python3 "$TOOL_DIR/get_right_time.py")
			runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
			echo "耗时 $runtime 秒"
		elif [[ "$compression_choice" == "2" ]]; then
			start=$(python3 "$TOOL_DIR/get_right_time.py")
			clear
			echo -e "\n开始打包..."
			find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
			"$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" \
				"$TOOL_DIR/flash_tool/bin" \
				"$TOOL_DIR/flash_tool/FlashROM.bat" \
				"$TOOL_DIR/flash_tool/META-INF" \
				"$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
			echo -e "线卡一体包打包完成"
			end=$(python3 "$TOOL_DIR/get_right_time.py")
			runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
			echo "耗时 $runtime 秒"
		else
			echo "   任务取消，返回上级菜单。"
			return
		fi
		echo -n "按任意键返回上级菜单..."
		read -n 1
	elif [[ "$main_choice" == "2" ]]; then
		clear
		start=$(python3 "$TOOL_DIR/get_right_time.py")
		# 定义基础路径
		BASE_PATH="$WORK_DIR/$current_workspace/Ready-to-flash/images"
		# 初始化空数组
		AP_FILES=()
		CP_FILES=()
		BL_FILES=()
		CSC_FILES=()
		# 检测是否存在 modem.bin 文件
		if [[ -f "$BASE_PATH/modem.bin" ]]; then
			while true; do
				echo -e "\n   你的设备是否具有独立基带分区？"
				echo -e "\n   [1] 是    " "[2] 否\n"
				echo -n "   选择你的操作："
				read baseband_choice
				if [[ "$baseband_choice" == "1" || "$baseband_choice" == "2" ]]; then
					break
				else
					clear
					echo -e "\n   无效的选项，请重新输入。"
				fi
			done
		else
			baseband_choice="2"
		fi
		clear
		# 检测是否存在 .pit 文件
		if compgen -G "$BASE_PATH/*.pit" >/dev/null; then
			while true; do
				echo -e "\n   你的设备是否需要保留数据？"
				echo -e "\n   [1] 是    " "[2] 否\n"
				echo -n "   选择你的操作："
				read retain_data_choice
				if [[ "$retain_data_choice" == "1" || "$retain_data_choice" == "2" ]]; then
					break
				else
					clear
					echo -e "\n   无效的选项，请重新输入。"
				fi
			done
		else
			retain_data_choice="2"
		fi
		clear
		echo -e "\n开始打包 Odin 包..."
		# 检查并添加文件到 AP_FILES 数组
		while IFS= read -r -d '' file; do
			AP_FILES+=("$(basename "$file")")
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "boot.img" -o -name "dtbo.img" -o -name "init_boot.img" -o -name "misc.bin" -o -name "persist.img" -o -name "recovery.img" -o -name "super.img" -o -name "vbmeta_system.img" -o -name "vendor_boot.img" -o -name "vm-bootsys.img" \) -print0)
		# 检查并添加 modem.bin 文件到相应的数组
		while IFS= read -r -d '' file; do
			if [[ "$baseband_choice" == "1" ]]; then
				CP_FILES+=("$(basename "$file")")
			else
				AP_FILES+=("$(basename "$file")")
			fi
		done < <(find "$BASE_PATH" -maxdepth 1 -name "modem.bin" -print0)
		# 检查并添加文件到 BL_FILES 数组
		while IFS= read -r -d '' file; do
			BL_FILES+=("$(basename "$file")")
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "vbmeta.img" -o -regex ".*\.\(elf\|mbn\|bin\|fv\|melf\)" \) ! -name "modem.bin" ! -name "misc.bin" -print0)

		# 检查并添加文件到 CSC_FILES 数组
		while IFS= read -r -d '' file; do
			if [[ "$retain_data_choice" == "1" ]]; then
				# 如果选择保留数据，只添加 cache.img、optics.img 和 prism.img
				if [[ "$(basename "$file")" == "cache.img" || "$(basename "$file")" == "optics.img" || "$(basename "$file")" == "prism.img" ]]; then
					CSC_FILES+=("$(basename "$file")")
				fi
			else
				# 否则，添加所有相关文件
				CSC_FILES+=("$(basename "$file")")
			fi
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "cache.img" -o -name "*.pit" -o -name "omr.img" -o -name "optics.img" -o -name "prism.img" \) -print0)
		# 打包 AP 文件
		if [[ ${#AP_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/AP-${current_workspace}.tar" "${AP_FILES[@]/#/$BASE_PATH/}"
		fi
		# 打包 BL 文件
		if [[ ${#BL_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/BL-${current_workspace}.tar" "${BL_FILES[@]/#/$BASE_PATH/}"
		fi
		# 打包 CP 文件
		if [[ ${#CP_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CP-${current_workspace}.tar" "${CP_FILES[@]/#/$BASE_PATH/}"
		fi
		# 打包 CSC 文件
		if [[ ${#CSC_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CSC-${current_workspace}.tar" "${CSC_FILES[@]/#/$BASE_PATH/}"
		fi
		echo -e "Odin 包打包完成"
		end=$(python3 "$TOOL_DIR/get_right_time.py")
		runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
		echo "耗时 $runtime 秒"
		echo -n "按任意键返回上级菜单..."
		read -n 1

	elif [[ "$main_choice" == "m" ]]; then
		clear
		find "$WORK_DIR/$current_workspace/Repacked" -name '*.img' -exec mv {} "$WORK_DIR/$current_workspace/Ready-to-flash/images" \;
		rebuild_rom
		return
	else
		echo "   任务取消，返回上级菜单。"
	fi
}
