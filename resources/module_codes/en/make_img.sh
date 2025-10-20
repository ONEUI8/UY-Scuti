#!/bin/bash

# Function: Package a single regular partition (erofs, f2fs, ext4)
# Parameters:
#   $1: Partition directory path
#   $2: File system type (1: erofs, 2: f2fs, 3: ext4)
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

    echo "Updating configuration files for ${partition_name} partition..."
    update_config_files "$partition_name"
    echo "Configuration files updated."

    case "$fs_type_choice" in
    1) # EROFS
        echo "Packaging ${partition_name} as EROFS..."
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
        echo "Packaging ${partition_name} as F2FS..."
        local size
        size=$(( $(du -sb "$dir" | cut -f1) * 105 / 100 + (55 * 1024 * 1024) )) # 1.05 times the directory size + 55MB extra space
        
        # Use dd to create an empty file of a specified size
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

        # If the original size exists and is greater than or equal to the current directory size, use the original size
        if [ -f "$original_size_file" ] && [ "$size_to_pack" -le "$(cat "$original_size_file")" ]; then
            size=$(cat "$original_size_file")
            echo "Packaging ${partition_name} using the original partition size..."
        else
            # Otherwise, dynamically calculate the size (directory size * 1.05 + 5MB)
            size=$((size_to_pack * 105 / 100 + (5 * 1024 * 1024)))
            echo "Packaging ${partition_name} by dynamically calculating the partition size..."
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
        echo "Error: Unsupported file system type '$fs_type_choice'."
        return 1
        ;;
    esac

    echo "Task complete."
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "Time elapsed: $runtime seconds."
}

# Function: Package a special partition (boot, dtbo, recovery, etc.)
# Parameters:
#   $1: Partition directory path
function package_special_partition {
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    local dir="$1"
    local partition_name
    partition_name=$(basename "$dir")

    # The optics partition is packaged using the ext4 format
    if [ "$partition_name" == "optics" ]; then
        package_single_partition "$dir" 3
        return
    fi

    echo "Packaging special partition ${partition_name}..."
    (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
    mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"
    cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"
    touch "$TOOL_DIR/boot_editor/${partition_name}.img"
    (cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1
    cp -r "$TOOL_DIR/boot_editor/${partition_name}.img.signed" "$WORK_DIR/$current_workspace/Repacked/${partition_name}.img"
    (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
    
    echo "Task complete."
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "Time elapsed: $runtime seconds."
}

# Function: Package all partitions
function package_all_partitions {
    local fs_type_choice
    # If there are non-special partitions, the user needs to select a file system type
    if [ $special_dir_count -ne ${#dir_array[@]} ]; then
        clear
        while true; do
            echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4\n"
            echo -e "   [Q] Back\n"
            echo -n "   Please select a file system type for regular partitions: "
            read -r fs_type_choice
            fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
            if [[ "$fs_type_choice" =~ ^[1-3]$ ]]; then
                break
            elif [ "$fs_type_choice" = "q" ]; then
                return
            else
                clear
                echo -e "\n   Invalid input, please select again."
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
    echo -n "All partitions have been packaged. Press any key to return..."
    read -n 1
    clear
}

# Function: Main menu interface for packaging images
function package_regular_image {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Repacked"

    while true; do
        echo -e "\n   Partition directories to be packaged:\n"
        local i=1
        local dir_array=()
        local special_dir_count=0
        
        # Scan and display packable partitions
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
            echo -e "\n   No packable partitions detected."
            echo -n "   Press any key to return..."
            read -n 1
            clear
            return
        fi

        echo -e "   [ALL] Package All Partitions    [Q] Back\n"
        echo -n "   Please select an operation (multiple selections can be separated by spaces): "
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

            # Parse user input, distinguishing between special partitions and regular partitions
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
                    echo -e "\n   The input contains an invalid option '$dir_num', please select again."
                    continue 2
                fi
            done

            # If there are regular partitions, let the user choose the file system
            if [ ${#dirs_with_fs_type[@]} -gt 0 ]; then
                clear
                while true; do
                    echo -e "\n   [1] EROFS   [2] F2FS   [3] EXT4\n"
                    echo -e "   [Q] Back\n"
                    echo -n "   Please select a file system type for regular partitions: "
                    read -r fs_type_choice
                    fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')
                    if [[ "$fs_type_choice" =~ ^[1-3]$ ]]; then
                        break
                    elif [ "$fs_type_choice" = "q" ]; then
                        return
                    else
                        clear
                        echo -e "\n   Invalid input, please select again."
                    fi
                done
            fi

            # Merge the two types of partition lists
            dirs_to_package+=("${dirs_with_fs_type[@]}")

            # Package all selected partitions in turn
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

            echo -n "Packaging complete. Press any key to return..."
            read -n 1
            clear
            continue
            ;; 
        esac
    done
}