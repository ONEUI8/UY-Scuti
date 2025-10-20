#!/bin/bash

# 函数：打包单个普通分区 (erofs, f2fs, ext4)
# 参数:
#   $1: 分区目录路径
#   $2: 文件系统类型 (1: erofs, 2: f2fs, 3: ext4)
function package_single_partition {
    local dir="$1"
    local fs_type_choice="$2"
    local utc
    utc=$(date +%s)
    local partition_name
    partition_name=$(basename "$dir")

    local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition_name}_fs_config"
    local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition_name}_file_contexts"
    local output_image="$WORK_DIR/$current_workspace/Repacked/${partition_name}.img"

    rm -rf "$output_image"

    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")

    echo "正在更新 ${partition_name} 分区的配置文件..."
    update_config_files "$partition_name"
    echo "配置文件更新完成。"

    case "$fs_type_choice" in
    1) # EROFS
        echo "正在打包 ${partition_name} 为 EROFS 格式..."
        "$TOOL_DIR/make.erofs" -d1 -zlz4hc,0 \
            -T "$utc" --all-time \
            --mount-point="/$partition_name" \
            --fs-config-file="$fs_config_file" \
            --file-contexts="$file_contexts_file" \
            --product-out="$(dirname "$output_image")" \
            "$output_image" "$dir" \
            --workers=$(nproc) \
            >/dev/null 2>&1
        ;;
    2) # F2FS
        echo "正在打包 ${partition_name} 为 F2FS 格式..."
        local size
        size=$(( $(du -sb "$dir" | cut -f1) * 105 / 100 + (55 * 1024 * 1024) )) # 目录大小的1.05倍 + 55MB 额外空间
        
        # 使用 dd 创建一个指定大小的空文件
        dd if=/dev/zero of="$output_image" bs=1M count=$((size / 1024 / 1024)) >/dev/null 2>&1
        dd if=/dev/zero of="$output_image" bs=1 count=$((size % (1024 * 1024))) seek=$((size / 1024 / 1024)) conv=notrunc >/dev/null 2>&1

        "$TOOL_DIR/make.f2fs" "$output_image" \
            -O extra_attr,inode_checksum,sb_checksum,compression \
            -f -T "$utc" -q

        "$TOOL_DIR/sload.f2fs" -f "$dir" \
            -C "$fs_config_file" \
            -s "$file_contexts_file" \
            -t "/$partition_name" \
            "$output_image" -c -T "$utc" \
            >/dev/null 2>&1
        ;;
    3) # EXT4
        local original_size_file="$WORK_DIR/$current_workspace/Extracted-files/config/original_${partition_name}_size_ext"
        local size_to_pack
        size_to_pack=$(du -sb "$dir" | cut -f1)
        local size

        # 如果原始大小存在且大于等于当前目录大小，则使用原始大小
        if [ -f "$original_size_file" ] && [ "$size_to_pack" -le "$(cat "$original_size_file")" ]; then
            size=$(cat "$original_size_file")
            echo "正在使用原始分区大小打包 ${partition_name}..."
        else
            # 否则，动态计算大小 (目录大小 * 1.05 + 5MB)
            size=$((size_to_pack * 105 / 100 + (5 * 1024 * 1024)))
            echo "正在动态计算分区大小打包 ${partition_name}..."
        fi

        local size_in_blocks=$((size / 4096))

        "$TOOL_DIR/mke2fs" \
            -O ^has_journal \
            -L "$partition_name" \
            -I 256 \
            -M "/$partition_name" \
            -m 0 \
            -t ext4 \
            -b 4096 \
            "$output_image" \
            "$size_in_blocks" >/dev/null 2>&1

        "$TOOL_DIR/e2fsdroid" \
            -e \
            -T "$utc" \
            -a "/$partition_name" \
            -S "$file_contexts_file" \
            -C "$fs_config_file" \
            "$output_image" \
            -f "$dir" >/dev/null 2>&1
        ;;
    *)
        echo "错误：不支持的文件系统类型 '$fs_type_choice'。"
        return 1
        ;;
    esac

    echo "任务完成。"
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "耗时 $runtime 秒。"
}

# 函数：打包特殊分区 (boot, dtbo, recovery, etc.)
# 参数:
#   $1: 分区目录路径
function package_special_partition {
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    local dir="$1"
    local partition_name
    partition_name=$(basename "$dir")

    # optics 分区使用 ext4 格式打包
    if [ "$partition_name" == "optics" ]; then
        package_single_partition "$dir" 3
        return
    fi

    echo "正在打包特殊分区 ${partition_name}..."
    (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
    mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"
    cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"
    touch "$TOOL_DIR/boot_editor/${partition_name}.img"
    (cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1
    cp -r "$TOOL_DIR/boot_editor/${partition_name}.img.signed" "$WORK_DIR/$current_workspace/Repacked/${partition_name}.img"
    (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
    
    echo "任务完成。"
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "耗时 $runtime 秒。"
}

# 函数：打包所有分区
function package_all_partitions {
    local fs_type_choice
    # 如果存在非特殊分区，则需要用户选择文件系统类型
    if [ $special_dir_count -ne ${#dir_array[@]} ]; then
        clear
        while true; do
            echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4\n"
            echo -e "   [Q] 返回\n"
            echo -n "   请为普通分区选择文件系统类型："
            read -r fs_type_choice
            fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
            if [[ "$fs_type_choice" =~ ^[1-3]$ ]]; then
                break
            elif [ "$fs_type_choice" = "q" ]; then
                return
            else
                clear
                echo -e "\n   无效的输入，请重新选择。"
            fi
        done
    fi
    clear
    for dir in "${dir_array[@]}"; do
        echo ""
        case "$(basename "$dir")" in
        dtbo | boot | init_boot | vendor_boot | recovery | *vbmeta* | optics)
            package_special_partition "$dir"
            ;; 
        *)
            package_single_partition "$dir" "$fs_type_choice"
            ;; 
        esac
    done
    echo -n "所有分区打包完成。按任意键返回..."
    read -n 1
    clear
}

# 函数：打包镜像的主菜单界面
function package_regular_image {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Repacked"

    while true; do
        echo -e "\n   待打包的分区目录：\n"
        local i=1
        local dir_array=()
        local special_dir_count=0
        
        # 扫描并显示可打包的分区
        for dir in "$WORK_DIR/$current_workspace/Extracted-files"/*; do
            if [ -d "$dir" ] && [ "$(basename "$dir")" != "config" ] && [ "$(basename "$dir")" != "super" ]; then
                local file_size
                file_size=$(du -sb "$dir" | awk '{print $1}')
                local size_display
                if [ "$file_size" -lt 1048576 ]; then
                    size_display=$(printf "%.1fKb" "$(echo "scale=1; $file_size / 1024" | bc)")
                elif [ "$file_size" -lt 1073741824 ]; then
                    size_display=$(printf "%.1fMb" "$(echo "scale=1; $file_size / 1048576" | bc)")
                else
                    size_display=$(printf "%.1fGb" "$(echo "scale=1; $file_size / 1073741824" | bc)")
                fi

                printf "   \033[0;31m[%02d] %s —— <%s>\033[0m\n\n" "$i" "$(basename "$dir")" "$size_display"
                dir_array[i]="$dir"
                i=$((i + 1))
                
                case "$(basename "$dir")" in
                dtbo|boot|init_boot|vendor_boot|recovery|*vbmeta*|optics)
                    special_dir_count=$((special_dir_count + 1))
                    ;; 
                esac
            fi
        done

        if [ ${#dir_array[@]} -eq 0 ]; then
            clear
            echo -e "\n   没有检测到任何可打包的分区。"
            echo -n "   按任意键返回..."
            read -n 1
            clear
            return
        fi

        echo -e "   [ALL] 打包所有分区    [Q] 返回\n"
        echo -n "   请选择操作 (可多选，用空格分隔): "
        read -r dir_num_str
        clear

        dir_num_str=$(echo "$dir_num_str" | tr '[:upper:]' '[:lower:]')

        case "$dir_num_str" in
        "all")
            package_all_partitions
            return
            ;; 
        "q")
            break
            ;; 
        *)
            local dirs_to_package=()
            local dirs_with_fs_type=()
            local fs_type_choice

            # 解析用户输入，区分特殊分区和普通分区
            for dir_num in $dir_num_str; do
                if [[ "$dir_num" =~ ^[0-9]+$ ]] && [ -n "${dir_array[$dir_num]}" ]; then
                    local dir="${dir_array[$dir_num]}"
                    case "$(basename "$dir")" in
                    dtbo|boot|init_boot|vendor_boot|recovery|*vbmeta*|optics)
                        dirs_to_package+=("$dir")
                        ;; 
                    *)
                        dirs_with_fs_type+=("$dir")
                        ;; 
                    esac
                else
                    clear
                    echo -e "\n   输入包含无效选项 '$dir_num'，请重新选择。"
                    continue 2
                fi
            done

            # 如果有普通分区，让用户选择文件系统
            if [ ${#dirs_with_fs_type[@]} -gt 0 ]; then
                clear
                while true; do
                    echo -e "\n   [1] EROFS   [2] F2FS   [3] EXT4\n"
                    echo -e "   [Q] 返回\n"
                    echo -n "   请为普通分区选择文件系统类型："
                    read -r fs_type_choice
                    fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
                    if [[ "$fs_type_choice" =~ ^[1-3]$ ]]; then
                        break
                    elif [ "$fs_type_choice" = "q" ]; then
                        return
                    else
                        clear
                        echo -e "\n   无效的输入，请重新选择。"
                    fi
                done
            fi

            # 合并两类分区列表
            dirs_to_package+=("${dirs_with_fs_type[@]}")

            # 依次打包所有选中的分区
            for dir in "${dirs_to_package[@]}"; do
                echo ""
                case "$(basename "$dir")" in
                dtbo|boot|init_boot|vendor_boot|recovery|*vbmeta*|optics)
                    package_special_partition "$dir"
                    ;; 
                *)
                    package_single_partition "$dir" "$fs_type_choice"
                    ;; 
                esac
            done

            echo -n "打包完成。按任意键返回..."
            read -n 1
            clear
            continue
            ;; 
        esac
    done
}