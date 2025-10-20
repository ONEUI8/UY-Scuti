#!/bin/bash

# 函数：提取单个镜像文件
# 参数:
#   $1: 镜像文件路径
function extract_single_img {
    local single_file="$1"
    local single_file_name
    single_file_name=$(basename "$single_file")
    local base_name="${single_file_name%.*}"
    local fs_type
    fs_type=$(recognize_file_type "$single_file")
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")

    # 在提取前，根据文件系统类型清理旧的提取目录
    if [[ "$fs_type" == "ext" || "$fs_type" == "erofs" || "$fs_type" == "f2fs" ||
        "$fs_type" == "boot" || "$fs_type" == "dtbo" || "$fs_type" == "recovery" ||
        "$fs_type" == "vbmeta" || "$fs_type" == "vendor_boot" ]]; then
        rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
    fi

    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"

    case "$fs_type" in
    sparse)
        echo "正在转换稀疏格式 ${single_file_name}..."
        "$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
        rm -rf "$single_file"
        mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
        single_file="$WORK_DIR/$current_workspace/${base_name}.img"
        echo "转换完成。"
        extract_single_img "$single_file" # 递归提取转换后的镜像
        return
        ;;
    super)
        echo "正在提取 SUPER 分区 ${single_file_name}..."
        local super_size
        super_size=$(stat -c%s "$single_file")

        # 如果不存在，则记录原始 super 分区大小
        if [ ! -s "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" ]; then
            echo "$super_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size"
        fi

        # 提取 super 分区内的所有文件
        "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
        rm "$single_file"
        mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

        # 清理和重命名提取出的 A/B 分区文件
        for file in "$WORK_DIR/$current_workspace"/*; do
            local base_name
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

        # 如果是批量提取模式，则递归提取 super 的子分区
        if [ "$choice" = "all" ] && $allow_extract_all; then
            local matching_imgs=()
            # 收集所有属于 super 子分区的镜像
            for img in "$WORK_DIR/$current_workspace"/*.img; do
                local img_name
                img_name=$(basename "$img")
                if [[ "$img_name" =~ ^($super_sub_partitions_list)$ ]]; then
                    matching_imgs+=("$img")
                fi
            done

            # 提取这些子分区
            for i in "${!matching_imgs[@]}"; do
                local img="${matching_imgs[$i]}"
                local file_type
                file_type=$(recognize_file_type "$img")
                if [ "$file_type" != "unknown" ]; then
                    extract_single_img "$img"
                    # 在两次提取之间打印空行
                    if [ $i -lt $((${#matching_imgs[@]} - 1)) ]; then
                        echo ""
                    fi
                fi
            done
        else
            echo "任务完成。"
        fi
        return
        ;;
    boot | dtbo | recovery | vendor_boot | vbmeta)
        echo "正在提取分区 ${single_file_name}..."
        (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
        cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
        (cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) >/dev/null 2>&1
        mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
        mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
        (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
        echo "任务完成。"
        ;;
    f2fs)
        echo "正在提取 F2FS 分区 ${single_file_name}..."
        "$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" >/dev/null 2>&1
        echo "任务完成。"
        ;;
    erofs)
        echo "正在提取 EROFS 分区 ${single_file_name}..."
        "$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x >/dev/null 2>&1
        echo "任务完成。"
        ;;
    ext)
        echo "正在提取 EXT4 分区 ${single_file_name}..."
        local partition_size
        partition_size=$(stat -c%s "$single_file")
        echo "$partition_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_${base_name}_size_ext"
        python3 "$TOOL_DIR/extract.ext4.py" -q "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config" "$WORK_DIR/$current_workspace/Extracted-files"
        echo "任务完成。"
        ;;
    payload)
        echo "正在提取 payload.bin ${single_file_name}..."
        "$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file" >/dev/null 2>&1
        rm -rf "$single_file"
        echo "任务完成。"
        ;;
    zip)
        local file_list
        file_list=$("$TOOL_DIR/7z" l "$single_file")
        # 检查是否为包含 payload.bin 的标准刷机包
        if echo "$file_list" | grep -q "payload.bin" && echo "$file_list" | grep -q "META-INF"; then
            echo "检测到标准 Android 刷机包，正在提取 payload.bin..."
            "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "payload.bin" -o"$WORK_DIR/$current_workspace"
            rm -rf "$single_file"
            extract_single_img "$WORK_DIR/$current_workspace/payload.bin"
            return
        # 检查是否为包含 images 目录的工厂镜像
        elif echo "$file_list" | grep -q "images/" && echo "$file_list" | grep -q ".img"; then
            echo "检测到工厂镜像包，正在提取所有 .img 文件..."
            "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "images/*.img" -o"$WORK_DIR/$current_workspace"
            rm -rf "$single_file"
            echo "任务完成。"
        # 检查是否为三星 Odin 包
        elif echo "$file_list" | grep -qE "AP|BL|CP|CSC"; then
            echo "检测到三星 Odin 刷机包，正在提取..."
            "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace" -ir'!AP*' -ir'!BL*' -ir'!CP*' -ir'!CSC*'
            rm -rf "$single_file"
            for extracted_file in "$WORK_DIR/$current_workspace"/{AP*,BL*,CP*,CSC*}; do
                if [ -f "$extracted_file" ] && [[ "$(recognize_file_type "$extracted_file")" == "tar" ]]; then
                    echo ""
                    extract_single_img "$extracted_file"
                fi
            done
            return
        else
            echo "${single_file_name} 似乎不是一个可识别的刷机包。"
        fi
        ;;
    tar)
        echo "正在提取 TAR 归档文件 ${single_file_name}..."
        "$TOOL_DIR/7z" x "$single_file" -o"$WORK_DIR/$current_workspace" -xr'!meta-data'
        rm -rf "$single_file"
        echo "任务完成。"

        # 提取完成后，检查有无 .lz4 文件并递归提取
        local lz4_files=("$WORK_DIR/$current_workspace"/*.lz4)
        if [ ${#lz4_files[@]} -gt 0 ]; then
            echo "检测到 LZ4 文件，将继续提取..."
            for i in "${!lz4_files[@]}"; do
                extract_single_img "${lz4_files[$i]}"
                if [ $i -lt $((${#lz4_files[@]} - 1)) ]; then
                    echo ""
                fi
            done
        fi
        return
        ;;
    lz4)
        echo "正在解压 LZ4 文件 ${single_file_name}..."
        lz4 -dq "$single_file" "$WORK_DIR/$current_workspace/${base_name}"
        rm -rf "$single_file"
        echo "任务完成。"
        ;;
    *)
        echo "未知的文件类型，无法处理。"
        ;;
    esac

    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "耗时 $runtime 秒。"
}

# 函数：文件提取的主菜单界面
function extract_img {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
    while true; do
        # 查找所有支持的文件类型
        shopt -s nullglob
        local regular_files=("$WORK_DIR/$current_workspace"/*.{bin,img,elf,mbn,pit,melf,fv})
        local specific_files=("$WORK_DIR/$current_workspace"/*.{zip,lz4,tar,md5})
        local matched_files=("${regular_files[@]}" "${specific_files[@]}")
        shopt -u nullglob

        if [ ${#matched_files[@]} -eq 0 ]; then
            echo -e "\n   工作区中没有找到可处理的文件。"
            echo -n "   按任意键返回..."
            read -n 1
            return
        fi

        local displayed_files=()
        local allow_extract_all=true
        local has_special_files=false # .tar, .zip, .lz4
        local has_img_files=false     # .img
        local has_ext_files=false     # ext4 格式

        # 过滤并分类文件
        for file in "${matched_files[@]}"; do
            if [ -f "$file" ]; then
                local fs_type
                fs_type=$(recognize_file_type "$file")
                if [ "$fs_type" != "unknown?" ]; then
                    displayed_files+=("$file")
                    case "$fs_type" in
                        ext) has_ext_files=true ;;
                        tar|zip|lz4) has_special_files=true ;;
                    esac
                    [[ "$file" == *.img ]] && has_img_files=true
                fi
            fi
        done

        # 如果同时存在压缩包和镜像文件，则禁止 "全部提取" 功能以避免逻辑混乱
        if $has_special_files && $has_img_files; then
            allow_extract_all=false
        fi

        # 主菜单循环
        while true; do
            echo -e "\n   当前工作区中的文件：\n"
            for i in "${!displayed_files[@]}"; do
                local file="${displayed_files[$i]}"
                local fs_type_upper
                fs_type_upper=$(echo "$(recognize_file_type "$file")" | awk '{print toupper($0)}')
                local file_size
                file_size=$(stat -c%s "$file")
                local size_display
                if [ "$file_size" -lt 1048576 ]; then
                    size_display=$(printf "%.1fKb" "$(echo "scale=1; $file_size / 1024" | bc)")
                elif [ "$file_size" -lt 1073741824 ]; then
                    size_display=$(printf "%.1fMb" "$(echo "scale=1; $file_size / 1048576" | bc)")
                else
                    size_display=$(printf "%.1fGb" "$(echo "scale=1; $file_size / 1073741824" | bc)")
                fi
                printf "   \033[94m[%02d] %s —— %s <%s>\033[0m\n\n" "$((i + 1))" "$(basename "$file")" "$fs_type_upper" "$size_display"
            done

            # 根据情况显示菜单选项
            if $allow_extract_all; then
                echo -e "   [ALL] 提取所有    [S] 简易识别    [F] 刷新    [Q] 返回\n"
            else
                echo -e "   [S] 简易识别    [F] 刷新    [Q] 返回\n"
            fi
            echo -n "   请选择操作 (可多选，用空格分隔): "
            read -r choice_str
            choice_str=$(echo "$choice_str" | tr '[:upper:]' '[:lower:]')

            # 处理数字多选
            if [[ "$choice_str" =~ ^[0-9\ ]+$ ]]; then
                clear
                local selected_files=()
                for num in $choice_str; do
                    if [[ "$num" -ge 1 && "$num" -le ${#displayed_files[@]} ]]; then
                        selected_files+=("${displayed_files[$((num - 1))]}")
                    fi
                done

                if [ ${#selected_files[@]} -gt 0 ]; then
                    echo ""
                    clear; echo ""

                    for i in "${!selected_files[@]}"; do
                        extract_single_img "${selected_files[$i]}"
                        if [ $i -lt $((${#selected_files[@]} - 1)) ]; then
                            echo ""
                        fi
                    done
                    echo -n "提取完成。按任意键返回..."
                    read -n 1
                    clear
                    break # 返回上一级菜单
                fi
                continue # 无效数字，重新显示菜单
            fi

            # 处理命令选项
            local main_choice
            main_choice=$(echo "$choice_str" | awk '{print $1}')
            case "$main_choice" in
            "all")
                if $allow_extract_all; then
                    clear; echo ""
                    for i in "${!displayed_files[@]}"; do
                        extract_single_img "${displayed_files[$i]}"
                        if [ $i -lt $((${#displayed_files[@]} - 1)) ]; then
                            echo ""
                        fi
                    done
                    echo -n "全部提取完成。按任意键返回..."
                    read -n 1
                    clear
                    return # 直接返回顶层菜单
                else
                    echo -e "\n   错误：当前文件组合不支持“全部提取”功能。"
                    sleep 2
                fi
                ;;
            "s") # 简易识别：将非系统分区镜像移动到待刷机目录
                mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
                shopt -s nullglob
                for file in "$WORK_DIR/$current_workspace"/*.{img,elf,melf,mbn,bin,fv,pit}; do
                    local filename
                    filename=$(basename "$file")
                    # 排除 super 自身和其子分区
                    if [ "$filename" != "super.img" ] && ! [[ "$filename" =~ ^vbmeta.*.img$ ]] && [ "$filename" != "optics.img" ] && ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
                        mv -f "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/" 2>/dev/null
                    fi
                done
                shopt -u nullglob
                clear
                break
                ;;
            "f") # 刷新
                clear
                break
                ;;
            "q") # 退出
                return
                ;;
            *)
                clear
                echo -e "\n   无效的输入，请重新选择。"
                ;;
            esac
        done
    done
}