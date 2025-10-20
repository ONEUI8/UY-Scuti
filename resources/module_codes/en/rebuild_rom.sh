#!/bin/bash

# Function: Rebuild flashing package (ROM)
function rebuild_rom {
    keep_clean
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"

    while true; do
        clear
        echo -e "\n   Please put all partition image files that need to be flashed into the 'Ready-to-flash/images' directory."
        
        # If the Repacked directory has files, display the "Easy Move" prompt
        if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
            echo -e "\n   Tip: Use [M] to easily move files from the Repacked directory."
        fi

                echo -e "   [1] Universal Zip (for both fastboot and recovery)" 
                echo -e "   [2] Samsung Odin Package (.tar)" 
                if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then 
                    echo -e "   [M] Easy Move" 
                fi 
                echo -e "   [Q] Back\n"
        echo -n "   Please select: "
        read -r main_choice

        case "${main_choice,,}" in
        1) # Universal Zip
            package_universal_zip
            break
            ;;
        2) # Odin Package
            package_odin_tar
            break
            ;;
        m) # Move files
            if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
                clear
                mv "$WORK_DIR/$current_workspace/Repacked/"*.img "$WORK_DIR/$current_workspace/Ready-to-flash/images/"
                echo "Files moved successfully."
                sleep 1
            else
                clear
                echo "No .img files found in the Repacked directory."
                sleep 1
            fi
            ;;
        q) # Quit
            return
            ;;
        *)
            clear
            echo "Invalid option, please re-enter."
            sleep 1
            ;;
        esac
    done
}

# Function: Package a universal zip
function package_universal_zip {
    clear
    local device_model
    while true; do
        echo -e "\n   [Q] Back\n"
        echo -n "   Please enter your device model (e.g., aries): "
        read -r device_model
        if [[ "${device_model,,}" == "q" ]]; then return; fi
        if [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
            break
        else
            clear
            echo "Incorrect device model format, please use only letters and numbers."
        fi
    done

    # Write the device model to the flashing script
    sed -i "s/set \"right_device=.*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat"
    sed -i "s/right_device=\".*\"/right_device=\"$device_model\"/g" "$TOOL_DIR/flash_tool/META-INF/com/google/android/update-binary"
    clear

    local compression_choice
    while true; do
        echo -e "\n   [1] Split archive   [2] Single file archive\n"
        echo -e "   [Q] Back\n"
        echo -n "   Please select a compression method: "
        read -r compression_choice
        if [[ "$compression_choice" =~ ^[1-2]$ ]] || [[ "${compression_choice,,}" == "q" ]]; then
            break
        else
            clear
            echo "Invalid option, please re-enter."
        fi
    done
    if [[ "${compression_choice,,}" == "q" ]]; then return; fi
    clear

    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    echo "Starting packaging..."
    
    # Clean up the packaging directory, keeping the images folder
    find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
    
    local archive_path="$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip"
    local common_files=("$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/FlashROM.bat" "$TOOL_DIR/flash_tool/META-INF" "$WORK_DIR/$current_workspace/Ready-to-flash/images")

    if [[ "$compression_choice" == "1" ]]; then
        local volume_size
        while true; do
            echo -e "\n   Example: 4096m (4GB), 1g (1GB)\n   [Q] Back\n"
            echo -n "   Please enter the volume size: "
            read -r volume_size
            if [[ "${volume_size,,}" == "q" ]]; then return; fi
            if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ ]]; then
                break
            else
                clear
                echo "Invalid volume size format, please re-enter."
            fi
        done
        clear
        "$TOOL_DIR/7z" a -tzip -v"$volume_size" "$archive_path" "${common_files[@]}" -y -mx1
    else
        "$TOOL_DIR/7z" a -tzip "$archive_path" "${common_files[@]}" -y -mx1
    fi

    echo "Universal zip packaging complete."
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "Time elapsed: $runtime seconds."
    echo -n "Press any key to return..."
    read -n 1
}

# Function: Package a Samsung Odin package
function package_odin_tar {
    clear
    local start
    start=$(python3 "$TOOL_DIR/get_right_time.py")
    local base_path="$WORK_DIR/$current_workspace/Ready-to-flash/images"
    
    local ap_files=()
    local cp_files=()
    local bl_files=()
    local csc_files=()

    # --- User interaction: confirm device options ---
    local baseband_choice="2"
    if [[ -f "$base_path/modem.bin" ]]; then
        while true;
            do echo -e "\n   Does your device have a separate baseband partition?\n\n   [1] Yes   [2] No\n";
            echo -n "   Please select: "; read -r baseband_choice;
            if [[ "$baseband_choice" =~ ^[1-2]$ ]]; then break; else clear; echo "Invalid option."; fi; done
    fi
    clear

    local retain_data_choice="2"
    if compgen -G "$base_path/*.pit" >/dev/null; then
        while true;
            do echo -e "\n   Do you need to retain user data when flashing?\n\n   [1] Yes   [2] No\n";
            echo -n "   Please select: "; read -r retain_data_choice;
            if [[ "$retain_data_choice" =~ ^[1-2]$ ]]; then break; else clear; echo "Invalid option."; fi; done
    fi
    clear
    echo "Starting to package Odin package..."

    # --- File classification ---
    # AP files
    while IFS= read -r -d '' file; do ap_files+=("$(basename "$file")"); done < <(find "$base_path" -maxdepth 1 \( -name "boot.img" -o -name "dtbo.img" -o -name "init_boot.img" -o -name "misc.bin" -o -name "persist.img" -o -name "recovery.img" -o -name "super.img" -o -name "vbmeta_system.img" -o -name "vendor_boot.img" -o -name "vm-bootsys.img" \) -print0)
    # CP files (baseband)
    while IFS= read -r -d '' file; do if [[ "$baseband_choice" == "1" ]]; then cp_files+=("$(basename "$file")"); else ap_files+=("$(basename "$file")"); fi; done < <(find "$base_path" -maxdepth 1 -name "modem.bin" -print0)
    # BL files (Bootloader)
    while IFS= read -r -d '' file; do bl_files+=("$(basename "$file")"); done < <(find "$base_path" -maxdepth 1 \( -name "vbmeta.img" -o -regex ".*\\.\(elf\\|mbn\\|bin\\|fv\\|melf\)" \) ! -name "modem.bin" ! -name "misc.bin" -print0)
    # CSC files
    while IFS= read -r -d '' file; do
        if [[ "$retain_data_choice" == "1" ]]; then # Retain data
            if [[ "$(basename "$file")" == "cache.img" || "$(basename "$file")" == "optics.img" || "$(basename "$file")" == "prism.img" ]]; then
                csc_files+=("$(basename "$file")")
            fi
        else # Do not retain data
            csc_files+=("$(basename "$file")")
        fi
    done < <(find "$base_path" -maxdepth 1 \( -name "cache.img" -o -name "*.pit" -o -name "omr.img" -o -name "optics.img" -o -name "prism.img" \) -print0)

    # --- Execute packaging ---
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

    echo "Odin package packaging complete."
    local end
    end=$(python3 "$TOOL_DIR/get_right_time.py")
    local runtime
    runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
    echo "Time elapsed: $runtime seconds."
    echo -n "Press any key to return..."
    read -n 1
}
