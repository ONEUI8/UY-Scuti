```bash
#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/codes/en/implemented_features.sh"

add_path() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    onepath="$1"
    rom_brands=("HyperOS" "OneUI" "ColorOS" "Return to Workspace" "Exit")
    brand_selected=false

    while true; do
        echo "=============================="
        echo "    Available ROMs to Modify:"
        echo "=============================="
        for i in "${!rom_brands[@]}"; do
            echo "$((i + 1))) ${rom_brands[$i]}"
        done
        read -p "Please enter your choice: " choice

        if [[ ! $choice =~ ^[0-9]+$ ]]; then
            echo "Invalid choice: please enter a number!"
            continue
        fi
        if (( choice < 1 || choice > ${#rom_brands[@]} )); then
            echo "Invalid choice: number out of range!"
            continue
        fi

        brand=${rom_brands[$((choice - 1))]}
        case $brand in
            "HyperOS")
                echo "HyperOS selected"
                options_order=("Remove XiaoAI Translation" "Remove XiaoAI Voice Component" "Remove XiaoAI Call" "Remove Surge AI Engine" "Remove Connectivity Service Verification" "Remove Browser" "Remove Music & Video" "Remove Wallet" "Remove Ad Analytics Components" "Remove Built-in Input Method" "Remove Portal" "Remove Smart Assistant" "Remove Search" "Remove Assistive Touch" "Remove App Store" "Remove Feedback" "Remove System Update" "Remove Gallery" "Remove File Manager" "Remove Smart Password Manager" "Remove Family Guardian" "Remove Download Manager" "Remove Unnecessary Apps" "Remove All" "Inverse Removal" "Quick Replace" "Add Apps to Product Partition" "Disable Unsigned Verification" "Invoke Native Installer" "Prevent Theme Reversion" "Disable Hotspot Name Restore" "Xiaomi Smart Card Support" "Advanced Material Support" "Critical Deodex" "Global Deodex" "Disable AVB2.0 Verification" "Return to Workspace" "Exit")
                declare -A options=(
                    ["Remove XiaoAI Translation"]="com.xiaomi.aiasst.vision"
                    ["Remove XiaoAI Voice Component"]="com.miui.voicetrigger com.miui.voiceassist"
                    ["Remove XiaoAI Call"]="com.xiaomi.aiasst.service"
                    ["Remove Surge AI Engine"]="com.xiaomi.aicr"
                    ["Remove Connectivity Service Verification"]="com.xiaomi.trustservice"
                    ["Remove Browser"]="com.android.browser"
                    ["Remove Music & Video"]="com.miui.player com.miui.video"
                    ["Remove Wallet"]="com.mipay.wallet"
                    ["Remove Ad Analytics Components"]="com.miui.hybrid com.miui.systemAdSolution com.miui.analytics com.xiaomi.ab com.xiaomi.gamecenter.sdk.service com.xiaomi.gamecenter"
                    ["Remove Built-in Input Method"]="com.sohu.inputmethod.sogou.xiaomi com.iflytek.inputmethod.miui com.baidu.input_mi"
                    ["Remove Portal"]="com.miui.contentextension"
                    ["Remove Smart Assistant"]="com.miui.personalassistant"
                    ["Remove Search"]="com.android.quicksearchbox"
                    ["Remove Assistive Touch"]="com.miui.touchassistant"
                    ["Remove App Store"]="com.xiaomi.market"
                    ["Remove Feedback"]="com.miui.miservice com.miui.bugreport"
                    ["Remove System Update"]="com.android.updater"
                    ["Remove Gallery"]="com.miui.gallery"
                    ["Remove File Manager"]="com.android.fileexplorer"
                    ["Remove Smart Password Manager"]="com.miui.contentcatcher"
                    ["Remove Family Guardian"]="com.miui.greenguard"
                    ["Remove Download Manager"]="com.android.providers.downloads.ui"
                    ["Remove Unnecessary Apps"]="com.miui.cleanmaster MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim *VipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* NewHome* MiRadio"
                )
                brand_selected=true
                ;;
            "OneUI")
                echo "OneUI selected"
                options_order=("Remove Samsung Browser" "Remove Boot Verification" "Remove Official Recovery Restore" "Remove Home Screen Panel" "Remove AR Emojis" "Remove Bixby Voice" "Remove Microsoft IME" "Remove Bundled Google Apps" "Remove Wearable Manager" "Remove System Update" "Remove Theme Store" "Remove Defunct Knox Apps" "Remove Unused Apps" "Remove All" "Inverse Removal" "Quick Replace" "Add Apps to System Partition" "Add Network Speed Display" "Add Call Recording" "Add Camera Mute" "Disable Unsigned Verification" "Critical Deodex" "Global Deodex" "Disable AVB2.0 Verification" "Decode CSC" "Encode CSC" "Return to Workspace" "Exit")
                declare -A options=(
                    ["Remove Samsung Browser"]="com.sec.android.app.sbrowser"
                    ["Remove Boot Verification"]="ActivationDevice_V2"
                    ["Remove Official Recovery Restore"]="recovery-from-boot.p"
                    ["Remove Home Screen Panel"]="com.samsung.android.app.spage"
                    ["Remove AR Emojis"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
                    ["Remove Bixby Voice"]="BixbyWakeup Bixby"
                    ["Remove Microsoft IME"]="com.touchtype.swiftkey com.swiftkey.swiftkeyconfigurator"
                    ["Remove Switch Assistant"]="SmartSwitchAgent SmartSwitchStub"
                    ["Remove Wearable Manager"]="GearManagerStub"
                    ["Remove Bundled Google Apps"]="com.google.android.apps.maps com.google.android.gm com.google.android.youtube com.google.android.apps.tachyon com.google.android.apps.messaging Chrome*"
                    ["Remove System Update"]="com.wssyncmldm com.sec.android.soagent"
                    ["Remove Theme Store"]="com.samsung.android.themestore"
                    ["Remove Defunct Knox Apps"]="Knox* SamsungBilling SamsungPass"
                    ["Remove Unused Apps"]="KidsHome_Installer"
                )
                brand_selected=true
                ;;
            "ColorOS")
                echo "ColorOS selected"
                options_order=(
                    "Remove Translate" "Remove UnionPay Service" "Remove App Store" "Remove Family Guardian" "Remove Calendar" "Remove Roaming Service" "Remove Breathing Light" "Remove Notes" "Remove Backup & Restore"
                    "Remove Music" "Remove Wallet" "Remove Shortcuts" "Remove Online Video" "Remove Member Center" "Remove Document Reader" "Remove Community" "Remove Tips" "Remove Theme Store"
                    "Remove Weather" "Remove Game Center" "Remove Quick Games" "Remove File Manager" "Remove Game Hall" "Remove Health"
                    "Remove Reader" "Remove Email" "Remove IR Remote" "Remove Ringtones"
                    "Remove Browser" "Remove Built-in IME" "Remove Ad Components" "Remove Assistive Touch" "Remove All" "Inverse Removal" "Quick Replace" "Critical Deodex" "Global Deodex" "Disable AVB2.0 Verification" "Return to Workspace" "Exit"
                )
                declare -A options=(
                    ["Remove Translate"]="com.coloros.translate"
                    ["Remove UnionPay Service"]="com.unionpay.tsmservice"
                    ["Remove App Store"]="com.oppo.store"
                    ["Remove Family Guardian"]="com.coloros.familyguard"
                    ["Remove Calendar"]="com.coloros.calendar"
                    ["Remove Roaming Service"]="com.redteamobile.roaming"
                    ["Remove Breathing Light"]="com.oneplus.brickmode"
                    ["Remove Notes"]="com.coloros.note"
                    ["Remove Backup & Restore"]="com.coloros.backuprestore"
                    ["Remove Music"]="com.heytap.music"
                    ["Remove Wallet"]="com.finshell.wallet"
                    ["Remove Shortcuts"]="com.coloros.shortcuts"
                    ["Remove Online Video"]="com.heytap.yoli"
                    ["Remove Member Center"]="com.oneplus.member"
                    ["Remove Document Reader"]="andes.oplus.documentsreader"
                    ["Remove Community"]="com.oneplus.bbs"
                    ["Remove Tips"]="com.oplus.tips"
                    ["Remove Theme Store"]="com.heytap.themestore"
                    ["Remove Weather"]="com.coloros.weather2"
                    ["Remove Game Center"]="com.oplus.games"
                    ["Remove Quick Games"]="com.oplus.play"
                    ["Remove File Manager"]="com.coloros.filemanager"
                    ["Remove Game Hall"]="com.nearme.gamecenter"
                    ["Remove Health"]="com.heytap.health"
                    ["Remove Reader"]="com.heytap.reader"
                    ["Remove Email"]="com.android.email"
                    ["Remove IR Remote"]="com.oplus.consumerIRApp"
                    ["Remove Ringtones"]="com.oplus.melody"
                    ["Remove Browser"]="com.heytap.browser"
                    ["Remove Built-in IME"]="com.baidu.input_oppo com.sohu.inputmethod.sogouoem"
                    ["Remove Ad Components"]="com.opos.ads com.android.adservices.api"
                    ["Remove Assistive Touch"]="com.coloros.floatassistant"
                )
                brand_selected=true
                ;;
            "Return to Workspace")
                return 0
                ;;
            "Exit")
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
        echo "    Available Actions:"
        echo "=============================="
        PS3="Enter your choice numbers separated by spaces: "
        select opt in "${options_order[@]}"; do
            read -ra selections <<< "$REPLY"
            echo ""
            for selection in "${selections[@]}"; do
                if (( selection < 1 || selection > ${#options_order[@]} )); then
                    echo "Invalid choice: $selection"
                    continue
                fi
                index=$((selection - 1))
                opt=${options_order[$index]}

                # Prevent exit/return when multiple selections
                if [[ ${#selections[@]} -gt 1 && ( "$opt" == "Exit" || "$opt" == "Return to Workspace" ) ]]; then
                    echo "Cannot exit or return when multiple selections are made."
                    continue
                fi

                echo "Selected: $opt"
                case $opt in
                    "Disable AVB2.0 Verification")
                        remove_vbmeta_verification
                        remove_extra_vbmeta_verification
                        ;;
                    "Disable Hotspot Name Restore")
                        remove_hyperos_hotspot_name_restore
                        ;;
                    "Disable Settings Name Check")
                        remove_hyperos_settings_name_check
                        ;;
                    "Quick Replace")
                        replace_files
                        ;;
                    "Add Apps to Product Partition")
                        copy_dirs "xiaomi"
                        ;;
                    "Add Apps to System Partition")
                        copy_dirs "samsung"
                        ;;
                    "Decode CSC")
                        decode_csc
                        ;;
                    "Encode CSC")
                        encode_csc
                        ;;
                    "Disable Unsigned Verification")
                        remove_unsigned_app_verification
                        ;;
                    "Invoke Native Installer")
                        invoke_native_installer
                        ;;
                    "Prevent Theme Reversion")
                        prevent_theme_reversion
                        ;;
                    "Global Deodex")
                        deodex
                        ;;
                    "Critical Deodex")
                        deodex_key_files
                        ;;
                    "Remove All")
                        search_package_name
                        remove_all
                        ;;
                    "Inverse Removal")
                        search_package_name
                        echo -n "Enter the choices to keep, separated by spaces: "
                        read -r -a exclude_array
                        if [[ ${#exclude_array[@]} -gt 0 ]]; then
                            echo "Keeping options: ${exclude_array[*]}"
                            for opt_name in "${options_order[@]}"; do
                                if [[ $opt_name == Remove* && $opt_name != "Remove All" ]]; then
                                    skip=false
                                    for ex in "${exclude_array[@]}"; do
                                        if [[ "$opt_name" == "${options_order[$((ex - 1))]}" ]]; then
                                            skip=true
                                            break
                                        fi
                                    done
                                    if ! $skip; then
                                        IFS=' ' read -r -a items <<< "${options[$opt_name]}"
                                        for item in "${items[@]}"; do
                                            if [[ "$item" == com.* ]]; then
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
                        GMS_instant_push
                        ;;
                    "Disable Joyose Cloud Control")
                        disable_joyose_cloud_control
                        ;;
                    "Disable HTML Viewer Cloud Control")
                        disable_html_viewer_cloud_control
                        ;;
                    "Allow Control All Notifications")
                        allow_control_all_notifications
                        ;;
                    "Xiaomi Smart Card Support")
                        xiaomi_smart_card_support
                        ;;
                    "Advanced Material Support")
                        advanced_material_support
                        ;;
                    "Add Network Speed Display")
                        add_network_speed_feature
                        ;;
                    "Add Call Recording")
                        add_call_recording_feature
                        ;;
                    "Add Camera Mute")
                        add_camera_mute_feature
                        ;;
                    "Return to Workspace")
                        return 0
                        ;;
                    "Exit")
                        clear
                        exit 0
                        ;;
                    Remove*)
                        IFS=' ' read -r -a items <<< "${options[$opt]}"
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
```
