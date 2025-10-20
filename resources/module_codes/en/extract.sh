#!/bin/bash

# Function: Extract a single image file
# Parameters:
#   $1: Image file path
function extract_single_img {
    local single_file="$1"
    local single_file_name
    single_file_name=$(basename "$single_file")
    local base_name="${single_file_name%.*}"
    local fs_type
    fs_type=$(recognize_file_type "$single_file")
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")

    # Before extracting, clean up old extraction directories based on the file system type
    if [[ "$fs_type" == "ext" || "$fs_type" == "erofs" || "$fs_type" == "f2fs" ||
        "$fs_type" == "boot" || "$fs_type" == "dtbo" || "$fs_type" == "recovery" ||
        "$fs_type" == "vbmeta" || "$fs_type" == "vendor_boot" ]]; then
        rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
    fi

    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/config"

    case "$fs_type" in
    sparse)
        echo "Converting sparse image ${single_file_name}..."
        "$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
        rm -rf "$single_file"
        mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
        single_file="$WORK_DIR/$current_workspace/${base_name}.img"
        echo "Conversion complete."
        extract_single_img "$single_file" # Recursively extract the converted image
        return
        ;;
    super)
        echo "Extracting SUPER partition ${single_file_name}..."
        local super_size
        super_size=$(stat -c%s "$single_file")

        # If it doesn't exist, record the original super partition size
        if [ ! -s "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" ]; then
            echo "$super_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size"
        fi

        # Extract all files within the super partition
        "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
        rm "$single_file"
        mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

        # Clean up and rename the extracted A/B partition files
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

        # If in batch extraction mode, recursively extract sub-partitions of super
        if [ "$choice" = "all" ] && $allow_extract_all; then
            local matching_imgs=()
            # Collect all images that are sub-partitions of super
            for img in "$WORK_DIR/$current_workspace"/*.img; do
                local img_name
                img_name=$(basename "$img")
                if [[ "$img_name" =~ ^($super_sub_partitions_list)$ ]]; then
                    matching_imgs+=("$img")
                fi
            done

            # Extract these sub-partitions
            for i in "${!matching_imgs[@]}"; do
                local img="${matching_imgs[$i]}"
                local file_type
                file_type=$(recognize_file_type "$img")
                if [ "$file_type" != "unknown" ]; then
                    extract_single_img "$img"
                    # Print a blank line between two extractions
                    if [ $i -lt $((${#matching_imgs[@]} - 1)) ]; then
                        echo ""
                    fi
                fi
            done
        else
            echo "Task complete."
        fi
        return
        ;;
    boot | dtbo | recovery | vendor_boot | vbmeta)
        echo "Extracting partition ${single_file_name}..."
        (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
        cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
        (cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) >/dev/null 2>&1
        mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
        mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
        (cd "$TOOL_DIR/boot_editor" && ./gradlew clear) >/dev/null 2>&1
        echo "Task complete."
        ;;
    f2fs)
        echo "Extracting F2FS partition ${single_file_name}..."
        "$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" >/dev/null 2>&1
        echo "Task complete."
        ;;
    erofs)
        echo "Extracting EROFS partition ${single_file_name}..."
        "$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x >/dev/null 2>&1
        echo "Task complete."
        ;;
    ext)
        echo "Extracting EXT4 partition ${single_file_name}..."
        local partition_size
        partition_size=$(stat -c%s "$single_file")
        echo "$partition_size" >"$WORK_DIR/$current_workspace/Extracted-files/config/original_${base_name}_size_ext"
        python3 "$TOOL_DIR/extract.ext4.py" -q "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config" "$WORK_DIR/$current_workspace/Extracted-files"
        echo "Task complete."
        ;;
    payload)
        echo "Extracting payload.bin ${single_file_name}..."
        "$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file" >/dev/null 2>&1
        rm -rf "$single_file"
        echo "Task complete."
        ;;
    zip)
        local file_list
        file_list=$("$TOOL_DIR/7z" l "$single_file")
        # Check if it is a standard flashing package containing payload.bin
        if echo "$file_list" | grep -q "payload.bin" && echo "$file_list" | grep -q "META-INF"; then
            echo "Standard Android flashing package detected, extracting payload.bin..."
            "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "payload.bin" -o"$WORK_DIR/$current_workspace"
            rm -rf "$single_file"
            extract_single_img "$WORK_DIR/$current_workspace/payload.bin"
            return
        # Check if it is a factory image containing an images directory
        elif echo "$file_list" | grep -q "images/" && echo "$file_list" | grep -q ".img"; then
            echo "Factory image package detected, extracting all .img files..."
            "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" "images/*.img" -o"$WORK_DIR/$current_workspace"
            rm -rf "$single_file"
            echo "Task complete."
        # Check if it is a Samsung Odin package
        elif echo "$file_list" | grep -qE "AP|BL|CP|CSC"; then
            echo "Samsung Odin flashing package detected, extracting..."
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
            echo "${single_file_name} does not seem to be a recognizable flashing package."
        fi
        ;;
    tar)
        echo "Extracting TAR archive file ${single_file_name}..."
        "$TOOL_DIR/7z" x "$single_file" -o"$WORK_DIR/$current_workspace" -xr'!meta-data'
        rm -rf "$single_file"
        echo "Task complete."

        # After extraction, check for .lz4 files and extract them recursively
        local lz4_files=("$WORK_DIR/$current_workspace"/*.lz4)
        if [ ${#lz4_files[@]} -gt 0 ]; then
            echo "LZ4 file detected, will continue to extract..."
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
        echo "Decompressing LZ4 file ${single_file_name}..."
        lz4 -dq "$single_file" "$WORK_DIR/$current_workspace/${base_name}"
        rm -rf "$single_file"
        echo "Task complete."
        ;;
    *)
        echo "Unknown file type, cannot process."
        ;;
    esac

    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "Time elapsed: $runtime seconds."
}

# Function: Main menu interface for file extraction
function extract_img {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
    while true; do
        # Find all supported file types
        shopt -s nullglob
        local regular_files=("$WORK_DIR/$current_workspace"/*.{bin,img,elf,mbn,pit,melf,fv})
        local specific_files=("$WORK_DIR/$current_workspace"/*.{zip,lz4,tar,md5})
        local matched_files=("${regular_files[@]}" "${specific_files[@]}")
        shopt -u nullglob

        if [ ${#matched_files[@]} -eq 0 ]; then
            echo -e "\n   No processable files found in the workspace."
            echo -n "   Press any key to return..."
            read -n 1
            return
        fi

        local displayed_files=()
        local allow_extract_all=true
        local has_special_files=false # .tar, .zip, .lz4
        local has_img_files=false     # .img
        local has_ext_files=false     # ext4 format

        # Filter and classify files
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

        # If both compressed packages and image files exist, disable the "Extract All" function to avoid logical confusion
        if $has_special_files && $has_img_files; then
            allow_extract_all=false
        fi

        # Main menu loop
        while true; do
            echo -e "\n   Files in the current workspace:\n"
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

            # Display menu options according to the situation
            if $allow_extract_all; then
                echo -e "   [ALL] Extract All    [S] Simple Recognition    [F] Refresh    [Q] Back\n"
            else
                echo -e "   [S] Simple Recognition    [F] Refresh    [Q] Back\n"
            fi
            echo -n "   Please select an operation (multiple selections can be separated by spaces): "
            read -r choice_str
            choice_str=$(echo "$choice_str" | tr '[:upper:]' '[:lower:]')

            # Handle multiple numeric selections
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
                    echo -n "Extraction complete. Press any key to return..."
                    read -n 1
                    clear
                    break # Return to the previous menu
                fi
                continue # Invalid number, re-display the menu
            fi

            # Handle command options
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
                    echo -n "All extractions complete. Press any key to return..."
                    read -n 1
                    clear
                    return # Return directly to the top-level menu
                else
                    echo -e "\n   Error: The current file combination does not support the 'Extract All' function."
                    sleep 2
                fi
                ;;
            "s") # Simple recognition: move non-system partition images to the directory to be flashed
                mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
                shopt -s nullglob
                for file in "$WORK_DIR/$current_workspace"/*.{img,elf,melf,mbn,bin,fv,pit}; do
                    local filename
                    filename=$(basename "$file")
                    # Exclude super itself and its sub-partitions
                    if [ "$filename" != "super.img" ] && ! [[ "$filename" =~ ^vbmeta.*.img$ ]] && [ "$filename" != "optics.img" ] && ! [[ "$filename" =~ ^($super_sub_partitions_list)$ ]]; then
                        mv -f "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/" 2>/dev/null
                    fi
                done
                shopt -u nullglob
                clear
                break
                ;;
            "f") # Refresh
                clear
                break
                ;;
            "q") # Quit
                return
                ;;
            *)
                clear
                echo -e "\n   Invalid input, please select again."
                ;;
            esac
        done
    done
}