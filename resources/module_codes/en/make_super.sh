#!/bin/bash

# Function: Create super.img
# Parameters:
#   $1: Partition type (OnlyA, AB, VAB)
#   $2: Whether it is sparse (yes/no)
function create_super_img {
    local partition_type="$1"
    local is_sparse="$2"
    local img_files=()

    # Filter out files with file types ext, f2fs, erofs
    for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
        local file_type
        file_type=$(recognize_file_type "$file")
        if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
            img_files+=("$file")
        fi
    done

    # --- 1. Calculate the total size of all sub-partition images ---
    local total_size=0
    for img_file in "${img_files[@]}"; do
        local file_size_bytes
        file_size_bytes=$(stat -c%s "$img_file")
        total_size=$((total_size + file_size_bytes))
    done
    # Round up to the nearest multiple of 4096
    local remainder=$((total_size % 4096))
    if [ $remainder -ne 0 ]; then
        total_size=$((total_size + 4096 - remainder))
    fi

    # --- 2. Calculate the final size of super.img based on the partition type and extra space ---
    local extra_space=$((1024 * 1024 * 1024 / 8)) # 1/8 GB extra space
    case "$partition_type" in
    "AB")
        total_size=$(((total_size + extra_space) * 2))
        ;; 
    "OnlyA" | "VAB")
        total_size=$((total_size + extra_space))
        ;; 
    esac
    clear

    # --- 3. User interaction: select or customize the size of super.img ---
    local device_size
    while true; do
        local original_super_size
        original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
        echo -e "\n   Packaging size options:\n"
        echo -n "   [1] $total_size (automatically calculated value)"
        if [ -n "$original_super_size" ]; then
                        echo -e "    [2] \e[31m$original_super_size\e[0m (original size)\n"
        else
            echo -e "\n"
        fi
        echo -e "   [C] Custom size    [Q] Back\n"
        echo -n "   Please select: "
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
                    echo -e "\n   Warning: The original size is smaller than the automatically calculated value, which may cause packaging to fail."
                    sleep 2
                fi
                break
            else
                clear
                echo -e "\n   Invalid option, please re-enter."
            fi
            ;; 
        c)
            clear
            while true; do
                echo -e "\n   Tip: The automatically calculated size is $total_size bytes.\n"
                echo -e "   [Q] Back\n"
                echo -n "   Please enter a custom size (bytes): "
                read -r device_size

                if [[ "$device_size" =~ ^[0-9]+$ ]]; then
                    if ((device_size < total_size)); then
                        clear
                        echo -e "\n   Error: The custom size cannot be smaller than the automatically calculated value."
                    else
                        if ((device_size % 4096 != 0)); then
                            device_size=$(((device_size + 4095) / 4096 * 4096))
                            echo -e "\n   The input value is not a multiple of 4096, it has been automatically corrected to $device_size."
                            sleep 2
                        fi
                        break
                    fi
                elif [ "${device_size,,}" = "q" ]; then
                    return
                else
                    clear
                    echo -e "\n   Invalid input, please enter a positive integer."
                fi
            done
            break
            ;; 
        q)
            echo "   Operation cancelled."
            return
            ;; 
        *)
            clear
            echo -e "\n   Invalid option, please re-enter."
            ;; 
        esac
    done
    clear; echo ""

    # --- 4. Build lpmake command parameters ---
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

    # --- 5. Execute the lpmake command ---
    echo "Packaging SUPER partition, please wait..."
    mkdir -p "$WORK_DIR/$current_workspace/Repacked"
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")

    # Start a background spinning cursor animation
    (while true; do for s in ◢ ◣ ◤ ◥; do printf "\r   Task in progress... %s" "$s"; sleep 0.15; done; done) &
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
    echo "Task complete."
    echo "Time elapsed: $runtime seconds."
    echo -n "Press any key to return..."
    read -n 1
}

# Function: Main menu interface for packaging super.img
function package_super_image {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

    # Check if there are eligible sub-partition images in the Repacked directory
    local detected_files=()
    for file in "$WORK_DIR/$current_workspace/Repacked/"*; do
        if [[ -f "$file" && $(basename "$file") =~ ^($super_sub_partitions_list)$ ]]; then
            detected_files+=("$file")
        fi
    done

    # If detected, ask the user whether to move them
    if [ ${#detected_files[@]} -gt 0 ]; then
        while true; do
            echo -e "\n   The following packaged sub-partitions were detected:\n"
            for file in "${detected_files[@]}"; do
                echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
            done
            echo -e "   Do you want to move them to the super packaging directory?"
            echo -e "\n   [1] Yes   [2] No\n"
            echo -n "   Please select: "
            read -r move_files
            clear
            if [[ "$move_files" = "1" ]]; then
                mv "${detected_files[@]}" "$WORK_DIR/$current_workspace/Extracted-files/super/"
                break
            elif [[ "$move_files" = "2" ]]; then
                break
            else
                echo -e "\n   Invalid option, please re-enter."
            fi
        done
    fi

    # Check if there are enough files in the super directory
    shopt -s nullglob
    local img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
    shopt -u nullglob
    if [ ${#img_files[@]} -lt 2 ]; then
        echo -e "\n   Error: The super directory needs to contain at least two .img files to be packaged."
        read -n 1 -s -r -p "   Press any key to return..."
        return
    fi

    # Check for files that are not allowed to be merged
    local forbidden_files=()
    for file in "${img_files[@]}"; do
        local filename
        filename=$(basename "$file")
        if ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
            forbidden_files+=("$file")
        fi
    done
    if [ ${#forbidden_files[@]} -gt 0 ]; then
        echo -e "\n   Error: The following files that are not allowed to be merged into super were detected:\n"
        for file in "${forbidden_files[@]}"; do
            echo -e "   \e[33m☒   $(basename "$file")\e[0m\n"
        done
        read -n 1 -s -r -p "   Press any key to return..."
        return
    fi

    # --- User interaction main loop ---
    while true; do
        echo -e "\n   Super sub-partitions to be packaged:\n"
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
        echo -e "   [Y] Start Packaging   [Q] Back\n"
        echo -n "   Please select: "
        read -r is_pack
        clear

        case "${is_pack,,}" in
        y)
            local partition_type_choice
            while true; do
                echo -e "\n   [1] OnlyA Dynamic Partition   [2] VAB Dynamic Partition   [3] AB Dynamic Partition\n"
                echo -e "   [Q] Back\n"
                echo -n "   Please select a partition type: "
                read -r partition_type_choice
                clear
                if [[ "$partition_type_choice" =~ ^[1-3]$ ]]; then
                    break
                elif [[ "${partition_type_choice,,}" == "q" ]]; then
                    return
                else
                    echo -e "\n   Invalid option, please re-enter."
                fi
            done

            local is_sparse_choice
            while true; do
                echo -e "\n   [1] Sparse   [2] Raw\n"
                echo -e "   [Q] Back\n"
                echo -n "   Please select a packaging method: "
                read -r is_sparse_choice
                clear
                if [[ "$is_sparse_choice" =~ ^[1-2]$ ]]; then
                    break
                elif [[ "${is_sparse_choice,,}" == "q" ]]; then
                    return
                else
                    echo -e "\n   Invalid option, please re-enter."
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
            echo "   Operation cancelled."
            return
            ;; 
        *)
            clear
            echo -e "\n   Invalid option, please re-enter."
            ;; 
        esac
    done
}
