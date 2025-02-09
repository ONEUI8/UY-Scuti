#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/codes/cn/implemented_features.sh"

add_path() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    onepath="$1"
    rom_brands=("HyperOS" "OneUI" "ColorOS" "Return to Work Domain" "Exit Program")
    brand_selected=false

    while true; do
        echo "=============================="
        echo "    Modifiable ROMs:"
        echo "=============================="
        for i in "${!rom_brands[@]}"; do
            echo "$((i + 1))) ${rom_brands[$i]}"
        done

        read -p "Please enter your choice: " choice
        if [[ ! $choice =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#rom_brands[@]})); then
            echo "Invalid selection: Please enter a valid number!"
            continue
        fi

        brand=${rom_brands[$((choice - 1))]}
        case $brand in
            "HyperOS")
                echo "Selected HyperOS"
                options_order=("Remove Xiao Ai Translation" "Remove Xiao Ai Voice Component" "Remove Xiao Ai Call" "Remove Interconnect Service Verification" "Remove Browser" "Remove Music and Video" "Remove Wallet" "Remove Advertising Analysis Components" "Remove Built-in Input Method" "Remove Portal" "Remove Smart Assistant" "Remove Search Function" "Remove Floating Ball" "Remove App Store" "Remove Feedback" "Remove System Update" "Remove Gallery" "Remove File Manager" "Remove Smart Password Management" "Remove Family Guardian" "Remove Download Manager" "Remove Redundant Apps" "Remove All" "Reverse Removal" "HyperOS Replacement" "Add Apps to Product Partition" "Disable Unsigned Verification" "Disable Device and Hotspot Name Detection" "Invoke Native Installer" "Prevent Theme Reversion" "GMS Instant Push" "Disable Joyose Cloud Control" "Disable HTML Viewer Cloud Control" "Xiaomi Smart Card Support" "Advanced Material Support" "Critical Deodex" "Disable Avb2.0 Verification" "Return to Work Domain" "Exit Program")
                declare -A options=(
                    ["Remove Xiao Ai Translation"]="com.xiaomi.aiasst.vision"
                    ["Remove Xiao Ai Voice Component"]="com.miui.voicetrigger com.miui.voiceassist"
                    ["Remove Xiao Ai Call"]="com.xiaomi.aiasst.service"
                    ["Remove Interconnect Service Verification"]="com.xiaomi.trustservice"
                    ["Remove Browser"]="com.android.browser"
                    ["Remove Music and Video"]="com.miui.player com.miui.video"
                    ["Remove Wallet"]="com.mipay.wallet"
                    ["Remove Advertising Analysis Components"]="com.miui.hybrid com.miui.systemAdSolution com.miui.analytics com.xiaomi.ab com.xiaomi.gamecenter.sdk.service com.xiaomi.gamecenter"
                    ["Remove Built-in Input Method"]="com.sohu.inputmethod.sogou.xiaomi com.iflytek.inputmethod.miui com.baidu.input_mi"
                    ["Remove Portal"]="com.miui.contentextension"
                    ["Remove Smart Assistant"]="com.miui.personalassistant"
                    ["Remove Search Function"]="com.android.quicksearchbox"
                    ["Remove Floating Ball"]="com.miui.touchassistant"
                    ["Remove App Store"]="com.xiaomi.market"
                    ["Remove Feedback"]="com.miui.miservice com.miui.bugreport"
                    ["Remove System Update"]="com.android.updater"
                    ["Remove Gallery"]="com.miui.gallery"
                    ["Remove File Manager"]="com.android.fileexplorer"
                    ["Remove Smart Password Management"]="com.miui.contentcatcher"
                    ["Remove Family Guardian"]="com.miui.greenguard"
                    ["Remove Download Manager"]="com.android.providers.downloads.ui"
                    ["Remove Redundant Apps"]="com.miui.cleanmaster MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim *VipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* NewHome* MiRadio"
                )
                brand_selected=true
                ;;
            "OneUI")
                echo "Selected OneUI"
                options_order=("Remove Samsung Browser Component" "Remove Boot Verification" "Restore Rec to Official" "Remove Home Page Negative One Screen" "Remove Dynamic Emoji Related Components" "Remove Bixby Voice Component" "Remove Microsoft Input Method" "Remove Google Bundled Apps" "Remove Wearable Device Manager" "Remove System Update" "Remove Theme Store" "Remove Knox Related Applications" "Remove Infrequently Used Apps" "Remove All" "Reverse Removal" "ONEUI Replacement" "Add Apps to System Partition" "Add Network Speed Display" "Add Call Recording" "Add Camera Mute" "Disable Unsigned Verification" "Critical Deodex" "Disable Avb2.0 Verification" "Decode CSC" "Encode CSC" "Return to Work Domain" "Exit Program")
                declare -A options=(
                    ["Remove Samsung Browser Component"]="SBrowser SBrowserIntelligenceService"
                    ["Remove Boot Verification"]="ActivationDevice_V2"
                    ["Restore Rec to Official"]="recovery-from-boot.p"
                    ["Remove Home Page Negative One Screen"]="BixbyHomeCN_Disable"
                    ["Remove Dynamic Emoji Related Components"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
                    ["Remove Bixby Voice Component"]="BixbyWakeup Bixby"
                    ["Remove Microsoft Input Method"]="SwiftkeyIme SwiftkeySetting"
                    ["Remove Device Switch Assistant"]="SmartSwitchAgent SmartSwitchStub"
                    ["Remove Wearable Device Manager"]="GearManagerStub"
                    ["Remove Google Bundled Apps"]="Maps Gmail2 YouTube DuoStub Messages Chrome64*"
                    ["Remove System Update"]="FotaAgent SOAgent7"
                    ["Remove Theme Store"]="ThemeStore"
                    ["Remove Knox Related Applications"]="Knox* SamsungBilling SamsungPass"
                    ["Remove Infrequently Used Apps"]="KidsHome_Installer"
                )
                brand_selected=true
                ;;
            "ColorOS")
                echo "Selected ColorOS"
                options_order=("Remove Browser" "Remove Built-in Input Method" "Remove Advertising Components" "Remove Floating Ball" "Remove All" "Reverse Removal" "ColorOS Replacement" "Critical Deodex" "Disable Avb2.0 Verification" "Return to Work Domain" "Exit Program")
                declare -A options=(
                    ["Remove Browser"]="com.heytap.browser"
                    ["Remove Built-in Input Method"]="com.baidu.input_oppo"
                    ["Remove Advertising Components"]="com.opos.ads com.android.adservices.api"
                    ["Remove Floating Ball"]="com.coloros.floatassistant"
                )
                brand_selected=true
                ;;
            "Return to Work Domain")
                return 0
                ;;
            "Exit Program")
                clear
                exit 0
                ;;
            *)
                echo "Invalid selection: $brand"
                ;;
        esac

        if [ "$brand_selected" = true ]; then
            clear
            break
        fi
    done

    while true; do
        echo "=============================="
        echo "    Available Functions:"
        echo "=============================="
        PS3="Please enter your selection numbers, separated by spaces: "
        select opt in "${options_order[@]}"; do
            read -ra selections <<<"$REPLY"
            echo ""

            for selection in "${selections[@]}"; do
                if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
                    echo "Invalid selection: $selection"
                    continue
                fi
                index=$((selection - 1))
                opt=${options_order[$index]}

                if [[ ${#selections[@]} -gt 1 && ("$opt" == "Exit Program" || "$opt" == "Return to Work Domain") ]]; then
                    echo "Multiple selections are not allowed for exiting the program or returning to the work domain."
                    continue
                fi

                case $opt in
                    "Disable Avb2.0 Verification")
                        echo "Selected Disable Avb2.0 Verification"
                        remove_vbmeta_verification
                        remove_extra_vbmeta_verification
                        ;;
                    "Disable Device and Hotspot Name Detection")
                        echo "Selected Disable Device and Hotspot Name Detection"
                        remove_device_and_network_verification
                        ;;
                    "HyperOS Replacement")
                        echo "Selected HyperOS Replacement"
                        replace_files "xiaomi"
                        ;;
                    "Add Apps to Product Partition")
                        echo "Selected Add Apps to Product Partition"
                        copy_dirs "xiaomi"
                        ;;
                    "ONEUI Replacement")
                        echo "Selected ONEUI Replacement"
                        replace_files "samsung"
                        ;;
                    "Add Apps to System Partition")
                        echo "Selected Add Apps to System Partition"
                        copy_dirs "samsung"
                        ;;
                    "Decode CSC")
                        echo "Selected Decode CSC"
                        decode_csc
                        ;;
                    "Encode CSC")
                        echo "Selected Encode CSC"
                        encode_csc
                        ;;
                    "Disable Unsigned Verification")
                        echo "Selected Disable Unsigned Verification"
                        remove_unsigned_app_verification
                        ;;
                    "Invoke Native Installer")
                        echo "Selected Invoke Native Installer"
                        invoke_native_installer
                        ;;
                    "Prevent Theme Reversion")
                        echo "Selected Prevent Theme Reversion"
                        prevent_theme_reversion
                        ;;
                    "Deodex")
                        echo "Selected Deodex"
                        deodex
                        ;;
                    "Critical Deodex")
                        echo "Selected Critical Deodex"
                        deodex_key_files
                        ;;
                    "Remove All")
                        echo "Selected Remove All"
                        search_package_name
                        remove_all
                        ;;
                    "Reverse Removal")
                        echo "Selected Reverse Removal"
                        echo "Please enter the option numbers you do not want to remove, separated by spaces:"
                        read -r -a exclude_array
                        if [[ ${#exclude_array[@]} -gt 0 ]]; then
                            echo "Excluding the following options: ${exclude_array[*]}"
                            for opt in "${options_order[@]}"; do
                                if [[ "$opt" == Remove* && "$opt" != "Remove All" ]]; then
                                    exclude_flag=0
                                    for exclude in "${exclude_array[@]}"; do
                                        if [[ "$opt" == "${options_order[$((exclude - 1))]}" ]]; then
                                            exclude_flag=1
                                            break
                                        fi
                                    done
                                    if [[ $exclude_flag -eq 0 ]]; then
                                        echo "Selected $opt"
                                        IFS=' ' read -r -a items <<<"${options[$opt]}"
                                        for item in "${items[@]}"; do
                                            if [[ "$item" == com.* ]]; then
                                                search_package_name
                                                remove_packages "$item"
                                            else
                                                remove_files "$item"
                                            fi
                                        done
                                    fi
                                fi
                            done
                        else
                            search_package_name
                            remove_all
                        fi
                        ;;
                    "GMS Instant Push")
                        echo "Selected GMS Instant Push"
                        GMS_instant_push
                        ;;
                    "Disable Joyose Cloud Control")
                        echo "Selected Disable Joyose Cloud Control"
                        disable_joyose_cloud_control
                        ;;
                    "Disable HTML Viewer Cloud Control")
                        echo "Selected Disable HTML Viewer Cloud Control"
                        disable_html_viewer_cloud_control
                        ;;
                    "Allow Control of All Notifications")
                        echo "Selected Allow Control of All Notifications"
                        allow_control_all_notifications
                        ;;
                    "Xiaomi Smart Card Support")
                        echo "Selected Xiaomi Smart Card Support"
                        xiaomi_smart_card_support
                        ;;
                    "Advanced Material Support")
                        echo "Selected Advanced Material Support"
                        advanced_material_support
                        ;;
                    "Add Network Speed Display")
                        echo "Selected Add Network Speed Display"
                        add_network_speed_feature
                        ;;
                    "Add Call Recording")
                        echo "Selected Add Call Recording"
                        add_call_recording_feature
                        ;;
                    "Add Camera Mute")
                        echo "Selected Add Camera Mute"
                        add_camera_mute_feature
                        ;;
                    "ColorOS Replacement")
                        echo "Selected ColorOS Replacement"
                        replace_files "oneplus"
                        ;;
                    "Return to Work Domain")
                        return 0
                        ;;
                    "Exit Program")
                        clear
                        exit 0
                        ;;
                    Remove*)
                        echo "Selected $opt"
                        IFS=' ' read -r -a items <<<"${options[$opt]}"
                        for item in "${items[@]}"; do
                            if [[ "$item" == com.* ]]; then
                                search_package_name
                                remove_packages "$item"
                            else
                                remove_files "$item"
                            fi
                        done
                        ;;
                esac
                echo ""
            done
            break
        done
    done
}
