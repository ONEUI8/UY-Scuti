#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/codes/en/implemented_features.sh"

add_path() {
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "$SCRIPT_DIR"

	onepath="$1"

	rom_brands=("HyperOS" "OneUI" "ColorOS" "Return to Work Domain" "Exit Program")

	brand_selected=false
	while true; do
		echo "=============================="
		echo "	Editable ROMs:"
		echo "=============================="
		for i in "${!rom_brands[@]}"; do
			echo "$((i + 1))) ${rom_brands[$i]}"
		done

		read -p "Please enter your choice: " choice

		if [[ ! $choice =~ ^[0-9]+$ ]]; then
			echo "Invalid choice: Please enter a number!"
			continue
		fi

		if ((choice < 1 || choice > ${#rom_brands[@]})); then
			echo "Invalid choice: Number out of range!"
			continue
		fi

		brand=${rom_brands[$((choice - 1))]}

		case $brand in
		"HyperOS")
			echo "Selected HyperOS"
			options_order=("Remove Xiao Ai Translation" "Remove Xiao Ai Voice Component" "Remove Xiao Ai Call" "Remove Interconnect Service Verification" "Remove Browser" "Remove Music and Video" "Remove Wallet" "Remove Ad Analysis Related Components" "Remove Built-in Input Method" "Remove Portal" "Remove Smart Assistant" "Remove Search Function" "Remove Floating Ball" "Remove App Store" "Remove Feedback" "Remove System Update" "Remove Gallery" "Remove File Manager" "Remove Smart Password Management" "Remove Family Guardian" "Remove Download Manager" "Remove Excess Applications" "Remove All" "Reverse Remove" "Quick Replace" "Add Application to Product Partition" "Disable Unsigned Verification" "Invoke Native Installer" "Prevent Theme Reversion" "Disable Hotspot Name Restore" "Xiaomi Smart Card Support" "Advanced Material Support" "Critical Deodex" "Disable Avb2.0 Verification" "Return to Work Domain" "Exit Program")
			declare -A options
			options=(
				["Remove Xiao Ai Translation"]="com.xiaomi.aiasst.vision"
				["Remove Xiao Ai Voice Component"]="com.miui.voicetrigger com.miui.voiceassist"
				["Remove Xiao Ai Call"]="com.xiaomi.aiasst.service"
				["Remove Interconnect Service Verification"]="com.xiaomi.trustservice"
				["Remove Browser"]="com.android.browser"
				["Remove Music and Video"]="com.miui.player com.miui.video"
				["Remove Wallet"]="com.mipay.wallet"
				["Remove Ad Analysis Related Components"]="com.miui.hybrid com.miui.systemAdSolution com.miui.analytics com.xiaomi.ab com.xiaomi.gamecenter.sdk.service com.xiaomi.gamecenter"
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
				["Remove Excess Applications"]="com.miui.cleanmaster MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim *VipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* NewHome* MiRadio"
			)
			brand_selected=true
			;;
		"OneUI")
			echo "Selected OneUI"
			options_order=("Remove Samsung Browser" "Remove Boot Verification" "Remove Official Recovery Mode Restore" "Remove Home Page Negative One Screen" "Remove Dynamic Emoji Related Components" "Remove Bixby Voice Component" "Remove Microsoft Input Method" "Remove Bundled Google Apps" "Remove Wearable Device Manager" "Remove System Update" "Remove Theme Store" "Remove Invalid Knox System Apps" "Remove Unused Apps" "Remove All" "Reverse Remove" "Quick Replace" "Add Application to System Partition" "Add Network Speed Display" "Add Call Recording" "Add Camera Mute" "Disable Unsigned Verification" "Critical Deodex" "Disable Avb2.0 Verification" "Decode csc" "Encode csc" "Return to Work Domain" "Exit Program")
			declare -A options
			options=(
				["Remove Samsung Browser"]="com.sec.android.app.sbrowser"
				["Remove Boot Verification"]="ActivationDevice_V2"
				["Remove Official Recovery Mode Restore"]="recovery-from-boot.p"
				["Remove Home Page Negative One Screen"]="com.samsung.android.app.spage "
				["Remove Dynamic Emoji Related Components"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
				["Remove Bixby Voice Component"]="BixbyWakeup Bixby"
				["Remove Microsoft Input Method"]="com.touchtype.swiftkey com.swiftkey.swiftkeyconfigurator"
				["Remove Smart Switch"]="SmartSwitchAgent SmartSwitchStub"
				["Remove Wearable Device Manager"]="GearManagerStub"
				["Remove Bundled Google Apps"]="com.google.android.apps.maps com.google.android.gm com.google.android.youtube com.google.android.apps.tachyon com.google.android.apps.messaging Chrome*"
				["Remove System Update"]="com.wssyncmldm com.sec.android.soagent"
				["Remove Theme Store"]="com.samsung.android.themestore"
				["Remove Invalid Knox System Apps"]="Knox* SamsungBilling SamsungPass"
				["Remove Unused Apps"]="KidsHome_Installer"
			)
			brand_selected=true
			;;
		"ColorOS")
			echo "Selected ColorOS"
			options_order=(
				"Remove Browser" "Remove Built-in Input Method" "Remove Ad Components" "Remove Floating Ball" "Remove All" "Reverse Remove" "Quick Replace" "Critical Deodex" "Disable Avb2.0 Verification" "Return to Work Domain" "Exit Program"
			)
			declare -A options
			options=(
				["Remove Browser"]="com.heytap.browser"
				["Remove Built-in Input Method"]="com.baidu.input_oppo"
				["Remove Ad Components"]="com.opos.ads com.android.adservices.api"
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
			echo "Invalid choice: $brand"
			;;
		esac

		if [ "$brand_selected" = true ]; then
			clear
			break
		fi
	done

	while true; do
		echo "=============================="
		echo "	Optional Features:"
		echo "=============================="
		PS3="Please enter your choice numbers, separated by spaces: "
		select opt in "${options_order[@]}"; do
			read -ra selections <<<"$REPLY"
			echo ""

			for selection in "${selections[@]}"; do
				if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
					echo "Invalid choice: $selection"
					continue
				fi
				index=$((selection - 1))
				if [[ $index -lt 0 || $index -ge ${#options_order[@]} ]]; then
					echo "Invalid choice: $selection"
					continue
				fi
				opt=${options_order[$index]}

				if [[ ${#selections[@]} -gt 1 && ("$opt" == "Exit Program" || "$opt" == "Return to Work Domain") ]]; then
					echo "Multiple selections cannot include exit program or return to work domain."
					continue
				fi

				deleted=false
				case $opt in
				"Disable Avb2.0 Verification")
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
				"Add Application to Product Partition")
					copy_dirs "xiaomi"
					;;
				"Add Application to System Partition")
					copy_dirs "samsung"
					;;
				"Decode csc")
					decode_csc
					;;
				"Encode csc")
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
				"Deodex")
					deodex
					;;
				"Critical Deodex")
					deodex_key_files
					;;
				"Remove All")
					search_package_name
					remove_all
					;;
				"Reverse Remove")
					search_package_name
					echo -n "Please enter the options to keep, separated by spaces: "
					read -r -a exclude_array
					if [[ ${#exclude_array[@]} -gt 0 ]]; then
						echo -n "Keep the following options: ${exclude_array[*]}"
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
									IFS=' ' read -r -a items <<<"${options[$opt]}"
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
				"Disable Html Viewer Cloud Control")
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
				"Return to Work Domain")
					return 0
					;;
				"Exit Program")
					clear
					exit 0
					;;
				Remove*)
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
