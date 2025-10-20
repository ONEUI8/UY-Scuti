#!/bin/bash

# 函数：创建 super.img
# 参数:
#   $1: 分区类型 (OnlyA, AB, VAB)
#   $2: 是否稀疏 (yes/no)
function create_super_img {
    local partition_type="$1"
    local is_sparse="$2"
    local img_files=()

    # 筛选出文件类型为 ext, f2fs, erofs 的文件
    for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
        local file_type
        file_type=$(recognize_file_type "$file")
        if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
            img_files+=("$file")
        fi
    done

    # --- 1. 计算所有子分区镜像的总大小 ---
    local total_size=0
    for img_file in "${img_files[@]}"; do
        local file_size_bytes
        file_size_bytes=$(stat -c%s "$img_file")
        total_size=$((total_size + file_size_bytes))
    done
    # 向上取整到 4096 的倍数
    local remainder=$((total_size % 4096))
    if [ $remainder -ne 0 ]; then
        total_size=$((total_size + 4096 - remainder))
    fi

    # --- 2. 根据分区类型和额外空间，计算最终 super.img 的大小 ---
    local extra_space=$((1024 * 1024 * 1024 / 8)) # 1/8 GB 额外空间
    case "$partition_type" in
    "AB")
        total_size=$(((total_size + extra_space) * 2))
        ;; 
    "OnlyA" | "VAB")
        total_size=$((total_size + extra_space))
        ;; 
    esac
    clear

    # --- 3. 用户交互：选择或自定义 super.img 大小 ---
    local device_size
    while true; do
        local original_super_size
        original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
        echo -e "\n   打包大小选项：\n"
        echo -n "   [1] $total_size (自动计算值)"
        if [ -n "$original_super_size" ]; then
                        echo -e "    [2] \e[31m$original_super_size\e[0m (原始大小)\n"         else
            echo -e "\n"
        fi
        echo -e "   [C] 自定义大小    [Q] 返回\n"
        echo -n "   请选择："
        read -r device_size_option

        case "${device_size_option,,}" in
        1)
            device_size=$total_size
            break
            ;; 
        2)
            if [ -n "$original_super_size" ]; then
                device_size=$original_super_size
                if ((device_size < total_size)); then
                    echo -e "\n   警告：原始大小小于自动计算值，可能导致打包失败。"
                    sleep 2
                fi
                break
            else
                clear
                echo -e "\n   无效选项，请重新输入。"
            fi
            ;; 
        c)
            clear
            while true; do
                echo -e "\n   提示：自动计算的大小为 $total_size 字节。\n"
                echo -e "   [Q] 返回\n"
                echo -n "   请输入自定义大小 (字节): "
                read -r device_size

                if [[ "$device_size" =~ ^[0-9]+$ ]]; then
                    if ((device_size < total_size)); then
                        clear
                        echo -e "\n   错误：自定义大小不能小于自动计算值。"
                    else
                        if ((device_size % 4096 != 0)); then
                            device_size=$(((device_size + 4095) / 4096 * 4096))
                            echo -e "\n   输入值不是 4096 的倍数，已自动修正为 $device_size。"
                            sleep 2
                        fi
                        break
                    fi
                elif [ "${device_size,,}" = "q" ]; then
                    return
                else
                    clear
                    echo -e "\n   无效输入，请输入一个正整数。"
                fi
            done
            break
            ;; 
        q)
            echo "   操作已取消。"
            return
            ;; 
        *)
            clear
            echo -e "\n   无效选项，请重新输入。"
            ;; 
        esac
    done
    clear; echo ""

    # --- 4. 构建 lpmake 命令参数 ---
    local metadata_size="65536"
    local block_size="4096"
    local super_name="super"
    local group_name="qti_dynamic_partitions"
    local group_name_a="${group_name}_a"
    local group_name_b="${group_name}_b"
    local metadata_slots=2
    [[ "$partition_type" == "AB" || "$partition_type" == "VAB" ]] && metadata_slots=3

    local params=""
    [[ "$is_sparse" == "yes" ]] && params+="--sparse "

    case "$partition_type" in
    "OnlyA")
        params+=" --group \"$group_name:$device_size\""
        ;; 
    "VAB")
        params+=" --group \"$group_name_a:$device_size\""
        params+=" --group \"$group_name_b:$device_size\""
        params+=" --virtual-ab"
        ;; 
    "AB")
        params+=" --group \"$group_name_a:$((device_size / 2))\""
        params+=" --group \"$group_name_b:$((device_size / 2))\""
        ;; 
    esac

    for img_file in "${img_files[@]}"; do
        local base_name
        base_name=$(basename "$img_file")
        local partition_name="${base_name%.*}"
        local partition_size
        partition_size=$(stat -c%s "$img_file")
        local file_type
        file_type=$(recognize_file_type "$img_file")
        local read_write_attr="readonly"
        [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]] && read_write_attr="none"

        case "$partition_type" in
        "OnlyA")
            params+=" --partition \"$partition_name:$read_write_attr:$partition_size:$group_name\""
            params+=" --image \"$partition_name=$img_file\""
            ;; 
        "VAB")
            params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
            params+=" --image \"${partition_name}_a=$img_file\""
            params+=" --partition \"${partition_name}_b:$read_write_attr:0:$group_name_b\""
            ;; 
        "AB")
            params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
            params+=" --image \"${partition_name}_a=$img_file\""
            params+=" --partition \"${partition_name}_b:$read_write_attr:$partition_size:$group_name_b\""
            params+=" --image \"${partition_name}_b=$img_file\""
            ;; 
        esac
    done

    # --- 5. 执行 lpmake 命令 ---
    echo "正在打包 SUPER 分区，请稍候..."
    mkdir -p "$WORK_DIR/$current_workspace/Repacked"
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")

    # 启动一个后台旋转光标动画
    (while true; do for s in ◢ ◣ ◤ ◥; do printf "\r   任务执行中... %s" "$s"; sleep 0.15; done; done) &
    local SPIN_PID=$!

    eval "$TOOL_DIR/lpmake \
        --device-size \"$device_size\" \
        --metadata-size \"$metadata_size\" \
        --metadata-slots \"$metadata_slots\" \
        --block-size \"$block_size\" \
        --super-name \"$super_name\" \
        --force-full-image \
        $params \
        --output \"$WORK_DIR/$current_workspace/Repacked/super.img\"" >/dev/null 2>&1

    kill $SPIN_PID
    wait $SPIN_PID 2>/dev/null
    printf "\r%40s\r" ""

    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "任务完成。"
    echo "耗时 $runtime 秒。"
    echo -n "按任意键返回..."
    read -n 1
}

# 函数：打包 super.img 的主菜单界面
function package_super_image {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

    # 检查 Repacked 目录中是否有符合条件的子分区镜像
    local detected_files=()
    for file in "$WORK_DIR/$current_workspace/Repacked/"*; do
        if [[ -f "$file" && $(basename "$file") =~ ^($super_sub_partitions_list)$ ]]; then
            detected_files+=("$file")
        fi
    done

    # 如果检测到，询问用户是否移动它们
    if [ ${#detected_files[@]} -gt 0 ]; then
        while true; do
            echo -e "\n   检测到以下已打包的子分区：\n"
            for file in "${detected_files[@]}"; do
                echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
            done
            echo -e "   是否将它们移动到 super 打包目录？"
            echo -e "\n   [1] 是   [2] 否\n"
            echo -n "   请选择："
            read -r move_files
            clear
            if [[ "$move_files" = "1" ]]; then
                mv "${detected_files[@]}" "$WORK_DIR/$current_workspace/Extracted-files/super/"
                break
            elif [[ "$move_files" = "2" ]]; then
                break
            else
                echo -e "\n   无效选项，请重新输入。"
            fi
        done
    fi

    # 检查 super 目录中是否有足够的文件
    shopt -s nullglob
    local img_files=($"$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
    shopt -u nullglob
    if [ ${#img_files[@]} -lt 2 ]; then
        echo -e "\n   错误：super 目录需要至少包含两个 .img 文件才能打包。"
        read -n 1 -s -r -p "   按任意键返回..."
        return
    fi

    # 检查是否有不允许合并的文件
    local forbidden_files=()
    for file in "${img_files[@]}"; do
        local filename
        filename=$(basename "$file")
        if ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
            forbidden_files+=("$file")
        fi
    done
    if [ ${#forbidden_files[@]} -gt 0 ]; then
        echo -e "\n   错误：检测到以下不允许合并到 super 的文件：\n"
        for file in "${forbidden_files[@]}"; do
            echo -e "   \e[33m☒   $(basename "$file")\e[0m\n"
        done
        read -n 1 -s -r -p "   按任意键返回..."
        return
    fi

    # --- 用户交互主循环 ---
    while true; do
        echo -e "\n   待打包的 super 子分区：\n"
        for i in "${!img_files[@]}"; do
            local file_name
            file_name=$(basename "${img_files[$i]}")
            local file_size
            file_size=$(stat -c%s "${img_files[$i]}")
            local size_display
            if [ "$file_size" -lt 1048576 ]; then
                size_display=$(printf "%.1fKb" "$(echo "scale=1; $file_size / 1024" | bc)")
            elif [ "$file_size" -lt 1073741824 ]; then
                size_display=$(printf "%.1fMb" "$(echo "scale=1; $file_size / 1048576" | bc)")
            else
                size_display=$(printf "%.1fGb" "$(echo "scale=1; $file_size / 1073741824" | bc)")
            fi
            printf "   \e[96m[%02d] %s —— <%s>\e[0m\n\n" $((i + 1)) "$file_name" "$size_display"
        done
        echo -e "   [Y] 开始打包   [Q] 返回\n"
        echo -n "   请选择："
        read -r is_pack
        clear

        case "${is_pack,,}" in
        y)
            local partition_type_choice
            while true; do
                echo -e "\n   [1] OnlyA 动态分区   [2] VAB 动态分区   [3] AB 动态分区\n"
                echo -e "   [Q] 返回\n"
                echo -n "   请选择分区类型："
                read -r partition_type_choice
                clear
                if [[ "$partition_type_choice" =~ ^[1-3]$ ]]; then
                    break
                elif [[ "${partition_type_choice,,}" == "q" ]]; then
                    return
                else
                    echo -e "\n   无效选项，请重新输入。"
                fi
            done

            local is_sparse_choice
            while true; do
                echo -e "\n   [1] 稀疏 (Sparse)   [2] 非稀疏 (Raw)\n"
                echo -e "   [Q] 返回\n"
                echo -n "   请选择打包方式："
                read -r is_sparse_choice
                clear
                if [[ "$is_sparse_choice" =~ ^[1-2]$ ]]; then
                    break
                elif [[ "${is_sparse_choice,,}" == "q" ]]; then
                    return
                else
                    echo -e "\n   无效选项，请重新输入。"
                fi
            done

            local p_type=""
            case "$partition_type_choice" in
                1) p_type="OnlyA" ;; 
                2) p_type="VAB" ;; 
                3) p_type="AB" ;; 
            esac
            local sparse=""
            case "$is_sparse_choice" in
                1) sparse="yes" ;; 
                2) sparse="no" ;; 
            esac
            
            create_super_img "$p_type" "$sparse"
            return
            ;; 
        q)
            echo "   操作已取消。"
            return
            ;; 
        *)
            clear
            echo -e "\n   无效选项，请重新输入。"
            ;; 
        esac
    done
}