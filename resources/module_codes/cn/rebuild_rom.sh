#!/bin/bash

# 函数：重建刷机包 (ROM)
function rebuild_rom {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"

    while true; do
        clear
        echo -e "\n   请将所有需要刷入的分区镜像文件放入 'Ready-to-flash/images' 目录。"
        
        # 如果 Repacked 目录有文件，则显示“轻松移动”提示
        if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
            echo -e "\n   提示：使用 [M] 轻松移动，可以将 Repacked 目录的文件快速移入。"
        fi

                echo -e "   [1] 线刷/卡刷一体包 (通用 Zip)" 
                echo -e "   [2] 三星 Odin 包 (.tar)" 
                if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then 
                    echo -e "   [M] 轻松移动" 
                fi 
                echo -e "   [Q] 返回\n"         echo -n "   请选择："
        read -r main_choice

        case "${main_choice,,}" in
        1) # 线刷/卡刷一体包
            package_universal_zip
            break
            ;;
        2) # Odin 包
            package_odin_tar
            break
            ;;
        m) # 移动文件
            if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
                clear
                mv "$WORK_DIR/$current_workspace/Repacked/"*.img "$WORK_DIR/$current_workspace/Ready-to-flash/images/"
                echo "文件移动完成。"
                sleep 1
            else
                clear
                echo "Repacked 目录中没有找到 .img 文件。"
                sleep 1
            fi
            ;;
        q) # 退出
            return
            ;;
        *)
            clear
            echo "无效选项，请重新输入。"
            sleep 1
            ;;
        esac
    done
}

# 函数：打包通用一体包
function package_universal_zip {
    clear
    local device_model
    while true; do
        echo -e "\n   [Q] 返回\n"
        echo -n "   请输入您的机型代号 (例如: aries): "
        read -r device_model
        if [[ "${device_model,,}" == "q" ]]; then return; fi
        if [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
            break
        else
            clear
            echo "机型代号格式不正确，请仅使用字母和数字。"
        fi
    done

    # 将机型代号写入刷机脚本
    sed -i "s/set \"right_device=.*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat"
    sed -i "s/right_device=\".*\"/right_device=\"$device_model\"/g" "$TOOL_DIR/flash_tool/META-INF/com/google/android/update-binary"
    clear

    local compression_choice
    while true; do
        echo -e "\n   [1] 分卷压缩   [2] 单文件压缩\n"
        echo -e "   [Q] 返回\n"
        echo -n "   请选择压缩方式："
        read -r compression_choice
        if [[ "$compression_choice" =~ ^[1-2]$ ]] || [[ "${compression_choice,,}" == "q" ]]; then
            break
        else
            clear
            echo "无效选项，请重新输入。"
        fi
    done
    if [[ "${compression_choice,,}" == "q" ]]; then return; fi
    clear

    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    echo "开始打包..."
    
    # 清理打包目录，保留 images 文件夹
    find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
    
    local archive_path="$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip"
    local common_files=("$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/FlashROM.bat" "$TOOL_DIR/flash_tool/META-INF" "$WORK_DIR/$current_workspace/Ready-to-flash/images")

    if [[ "$compression_choice" == "1" ]]; then
        local volume_size
        while true; do
            echo -e "\n   示例: 4096m (4GB), 1g (1GB)\n   [Q] 返回\n"
            echo -n "   请输入分卷大小："
            read -r volume_size
            if [[ "${volume_size,,}" == "q" ]]; then return; fi
            if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ ]]; then
                break
            else
                clear
                echo "无效的分卷大小格式，请重新输入。"
            fi
        done
        clear
        "$TOOL_DIR/7z" a -tzip -v"$volume_size" "$archive_path" "${common_files[@]}" -y -mx1
    else
        "$TOOL_DIR/7z" a -tzip "$archive_path" "${common_files[@]}" -y -mx1
    fi

    echo "线刷/卡刷一体包打包完成。"
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "耗时 $runtime 秒。"
    echo -n "按任意键返回..."
    read -n 1
}

# 函数：打包三星 Odin 包
function package_odin_tar {
    clear
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    local base_path="$WORK_DIR/$current_workspace/Ready-to-flash/images"
    
    local ap_files=()
    local cp_files=()
    local bl_files=()
    local csc_files=()

    # --- 用户交互：确认设备选项 ---
    local baseband_choice="2"
    if [[ -f "$base_path/modem.bin" ]]; then
        while true;
            do echo -e "\n   您的设备是否具有独立基带分区？\n\n   [1] 是   [2] 否\n";
            echo -n "   请选择："; read -r baseband_choice;
            if [[ "$baseband_choice" =~ ^[1-2]$ ]]; then break; else clear; echo "无效选项。"; fi; done
    fi
    clear

    local retain_data_choice="2"
    if compgen -G "$base_path/*.pit" >/dev/null; then
        while true;
            do echo -e "\n   刷入时是否需要保留用户数据？\n\n   [1] 是   [2] 否\n";
            echo -n "   请选择："; read -r retain_data_choice;
            if [[ "$retain_data_choice" =~ ^[1-2]$ ]]; then break; else clear; echo "无效选项。"; fi; done
    fi
    clear
    echo "开始打包 Odin 包..."

    # --- 文件分类 ---
    # AP 文件
    while IFS= read -r -d '' file; do ap_files+=("$(basename "$file")"); done < <(find "$base_path" -maxdepth 1 \( -name "boot.img" -o -name "dtbo.img" -o -name "init_boot.img" -o -name "misc.bin" -o -name "persist.img" -o -name "recovery.img" -o -name "super.img" -o -name "vbmeta_system.img" -o -name "vendor_boot.img" -o -name "vm-bootsys.img" \) -print0)
    # CP 文件 (基带)
    while IFS= read -r -d '' file; do if [[ "$baseband_choice" == "1" ]]; then cp_files+=("$(basename "$file")"); else ap_files+=("$(basename "$file")"); fi; done < <(find "$base_path" -maxdepth 1 -name "modem.bin" -print0)
    # BL 文件 (Bootloader)
    while IFS= read -r -d '' file; do bl_files+=("$(basename "$file")"); done < <(find "$base_path" -maxdepth 1 \( -name "vbmeta.img" -o -regex ".*\\.\(elf\\|mbn\\|bin\\|fv\\|melf\)" \) ! -name "modem.bin" ! -name "misc.bin" -print0)
    # CSC 文件
    while IFS= read -r -d '' file; do
        if [[ "$retain_data_choice" == "1" ]]; then # 保留数据
            if [[ "$(basename "$file")" == "cache.img" || "$(basename "$file")" == "optics.img" || "$(basename "$file")" == "prism.img" ]]; then
                csc_files+=("$(basename "$file")")
            fi
        else # 不保留数据
            csc_files+=("$(basename "$file")")
        fi
    done < <(find "$base_path" -maxdepth 1 \( -name "cache.img" -o -name "*.pit" -o -name "omr.img" -o -name "optics.img" -o -name "prism.img" \) -print0)

    # --- 执行打包 ---
    local output_path="$WORK_DIR/$current_workspace/Ready-to-flash"
    if [[ ${#ap_files[@]} -gt 0 ]]; then
        "$TOOL_DIR/7z" a -ttar -mx1 "$output_path/AP-${current_workspace}.tar" "${ap_files[@]/#/$base_path/}"
    fi
    if [[ ${#bl_files[@]} -gt 0 ]]; then
        "$TOOL_DIR/7z" a -ttar -mx1 "$output_path/BL-${current_workspace}.tar" "${bl_files[@]/#/$base_path/}"
    fi
    if [[ ${#cp_files[@]} -gt 0 ]]; then
        "$TOOL_DIR/7z" a -ttar -mx1 "$output_path/CP-${current_workspace}.tar" "${cp_files[@]/#/$base_path/}"
    fi
    if [[ ${#csc_files[@]} -gt 0 ]]; then
        "$TOOL_DIR/7z" a -ttar -mx1 "$output_path/CSC-${current_workspace}.tar" "${csc_files[@]/#/$base_path/}"
    fi

    echo "Odin 包打包完成。"
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "耗时 $runtime 秒。"
    echo -n "按任意键返回..."
    read -n 1
}