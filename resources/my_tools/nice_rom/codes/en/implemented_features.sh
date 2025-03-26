#!/bin/bash
apktool_path="$(dirname "$0")/bin/all/apktool/apktool.jar"
zipalign_path="$(dirname "$0")/bin/all/zipalign/zipalign"

remove_extra_vbmeta_verification() {
	declare -A printed_files
	find "$onepath" -type f -name 'fstab.qcom' -print0 | while IFS= read -r -d '' file; do
		sed -i 's/avb[^,]*,//g' "$file"
		sed -i 's/,avb[^,]*,//g' "$file"
		sed -i 's/,avb[^,]*$//g' "$file"
		if [[ -z "${printed_files[$file]}" ]]; then
			echo "$file"
			printed_files["$file"]=1
		fi
	done
}

remove_vbmeta_verification() {
	find "$onepath" -type f \( -name 'vbmeta*.avb.json' -o -name 'vendor_boot.avb.json' \) -print0 | while IFS= read -r -d '' file; do
		sed -i '/^[[:space:]]*"authBlob" : {/,/}/c\
  "authBlob" : null,' "$file"
		sed -i '/^[[:space:]]*"pubkey" : {/,/}/c\
    "pubkey" : null,' "$file"
		sed -i '/"header" : {/,/}/{
            s/"authentication_data_block_size" : [0-9]\+/"authentication_data_block_size" : 0/
            s/"algorithm_type" : [0-9]\+/"algorithm_type" : 0/
            s/"hash_size" : [0-9]\+/"hash_size" : 0/
            s/"signature_offset" : [0-9]\+/"signature_offset" : 0/
            s/"signature_size" : [0-9]\+/"signature_size" : 0/
            s/"public_key_size" : [0-9]\+/"public_key_size" : 0/
            s/"flags" : [0-9]\+/"flags" : 3/
		}' "$file"
		echo "$file"
	done
	find "$onepath" -type f -name 'vbmeta.avb.json' -print0 | while IFS= read -r -d '' file; do
		declare -A keys=(
			["com.android.build.boot.os_version"]="com.android.build.init_boot.os_version"
			["com.android.build.boot.fingerprint"]="com.android.build.init_boot.fingerprint"
			["com.android.build.boot.security_patch"]="com.android.build.init_boot.security_patch"
		)
		for key in "${!keys[@]}"; do
			if ! grep -q "\"key\" : \"$key\"" "$file"; then
				next_line=$(sed -n "/\"key\" : \"${keys[$key]}\"/{n; p}" "$file")
				if [ -n "$next_line" ]; then
					sed -i "/\"propertyDescriptors\" : \[ {/a\\
      \"tag\" : 0,\\
      \"num_bytes_following\" : 128,\\
      \"sequence\" : 1,\\
      \"key\" : \"$key\",\\
$next_line\\
    }, {" "$file"
				fi
			fi
		done
	done
}

replace_files() {
	local quick_replace_dir="$(dirname "$0")/quick-replace"
	echo "Available replacement directories:"
	local -a available_dirs
	i=1
	for dir in "$quick_replace_dir"/*; do
		if [[ -d "$dir" ]]; then
			local name=$(basename "$dir")
			echo -n "[$i] $name   "
			available_dirs+=("$dir")
			((i++))
		fi
	done
	echo
	read -p "Please select the baseline target to use (multiple options separated by space): " choices
	local -a selected_indices=()
	for choice in $choices; do
		if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1)) || ((choice > ${#available_dirs[@]})); then
			echo "Invalid choice: $choice. Please rerun the script and select a valid number."
			return 1
		fi
		selected_indices+=("$choice")
	done
	echo "You have replaced the following:"
	for index in "${selected_indices[@]}"; do
		local selected_dir="${available_dirs[$((index - 1))]}"
		local file_conditions=""
		while IFS= read -r -d '' file; do
			file_conditions+=" -o -name '$(basename "$file")'"
		done < <(find "$selected_dir" -type f -print0)
		file_conditions="${file_conditions:4}"
		while IFS= read -r -d '' file; do
			local name=$(basename "$file")
			for src_file in "$selected_dir"/*; do
				if [[ "$(basename "$src_file")" == "$name" ]]; then
					cp -T -f "$src_file" "$file" >/dev/null
					echo "$file"
				fi
			done
		done < <(eval "find \"$onepath\" -type f \( $file_conditions \) -not -path \"$quick_replace_dir/*\" -print0")
		while IFS= read -r -d '' dir; do
			local name=$(basename "$dir")
			if [[ -d "$selected_dir/$name" ]]; then
				cp -rT -f "$selected_dir/$name" "$dir" >/dev/null
				echo "$dir"
			fi
		done < <(find "$onepath" -type d -not -path "$quick_replace_dir/*" -print0)
	done
}

remove_hyperos_settings_name_check() {
	declare -a settings_apk_paths
	while IFS= read -r -d '' settings_apk_path; do
		settings_apk_paths+=("$settings_apk_path")
		java -jar "$apktool_path" d -f -r "$settings_apk_path" -o "${settings_apk_path%.apk}"
		while IFS= read -r -d '' smali_file; do
			if [[ "$smali_file" == *"com/android/settings/MiuiDeviceNameEditFragment.smali" ]]; then
				sed -i 's/sget-boolean \([vp][0-9]\+\), Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/const\/4 \1, 0x1/' "$smali_file"
				echo -e "$smali_file"
			fi
			if [[ "$smali_file" == *"com/android/settings/wifi/EditTetherFragment.smali" ]]; then
				sed -i 's/sget-boolean \([vp][0-9]\+\), Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/const\/4 \1, 0x1/' "$smali_file"
				echo -e "$smali_file"
			fi
			if [[ "$smali_file" == *"com/android/settings/DeviceNameCheckManager.smali" ]]; then
				sed -i 's/sget-boolean \([vp][0-9]\+\), Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/const\/4 \1, 0x1/' "$smali_file"
				echo -e "$smali_file"
			fi
			if [[ "$smali_file" == *"com/android/settings/bluetooth/MiuiBTUtils.smali" ]]; then
				sed -i '/.method public static isInternationalBuild()Z/,/.end method/c\
.method public static isInternationalBuild()Z\n\
	.registers 1\n\
	const/4 v0, 0x1\n\
	return v0\n\
.end method' "$smali_file"
				sed -i '/.method public static isSupportNameComplianceCheck(Landroid\/content\/Context;)Z/,/.end method/c\
.method public static isSupportNameComplianceCheck(Landroid\/content\/Context;)Z\n\
	.registers 1\n\
	const/4 p0, 0x0\n\
	return p0\n\
.end method' "$smali_file"
				echo -e "$smali_file"
			fi
		done < <(find "${settings_apk_path%.apk}" -name '*.smali' -print0)
	done < <(find "$onepath" -name "Settings.apk" -print0)
	temporary_fix_invoke_custom
	for settings_apk_path in "${settings_apk_paths[@]}"; do
		java -jar "$apktool_path" b -c -f "${settings_apk_path%.apk}" -o "$settings_apk_path"
		"$zipalign_path" -f 4 "$settings_apk_path" "${settings_apk_path%.apk}_latest.apk"
		mv -f "${settings_apk_path%.apk}_latest.apk" "$settings_apk_path"
		rm -rf "${settings_apk_path%.apk}"
	done
}

remove_hyperos_hotspot_name_restore() {
	declare -a wifi_service_jar_paths
	while IFS= read -r -d '' wifi_service_jar_path; do
		wifi_service_jar_paths+=("$wifi_service_jar_path")
		java -jar "$apktool_path" d -f -r "$wifi_service_jar_path" -o "${wifi_service_jar_path%.jar}"
		while IFS= read -r -d '' smali_file; do
			if [[ "$smali_file" == *"com/android/server/wifi/Utils.smali" ]]; then
				sed -i '/.method public static checkDeviceNameIsIllegalSync(Landroid\/content\/Context;ILjava\/lang\/String;)Z/,/.end method/c\
.method public static checkDeviceNameIsIllegalSync(Landroid\/content\/Context;ILjava\/lang\/String;)Z\n\
	.registers 3\n\
	const/4 p0, 0x0\n\
	return p0\n\
.end method' "$smali_file"
				echo -e "$smali_file"
			fi
		done < <(find "${wifi_service_jar_path%.jar}" -name '*.smali' -print0)
	done < <(find "$onepath" -name "miui-wifi-service.jar" -print0)
	temporary_fix_invoke_custom
	for wifi_service_jar_path in "${wifi_service_jar_paths[@]}"; do
		java -jar "$apktool_path" b -c -f "${wifi_service_jar_path%.jar}" -o "$wifi_service_jar_path"
		rm -rf "${wifi_service_jar_path%.jar}"
	done
}

add_camera_mute_feature() {
	decode_csc >/dev/null 2>&1
	find "$onepath" -name "cscfeature_decoded.xml" -print0 | while IFS= read -r -d $'\0' file; do
		local content=$(cat "$file")
		local modified=false
		if [[ "$content" == *Camera_ConfigEnableCameraMute* ]]; then
			content=$(echo "$content" | sed '/Camera_ConfigEnableCameraMute/d')
			modified=true
		fi
		if ! [[ "$content" == *CscFeature_Camera_ConfigEnableCameraMute* ]]; then
			content=$(echo "$content" | sed '/<FeatureSet>/a \
    <CscFeature_Camera_ConfigEnableCameraMute>TRUE</CscFeature_Camera_ConfigEnableCameraMute>')
			modified=true
		fi
		if $modified; then
			echo "$content" >"$file"
			echo "$file"
		fi
	done
	encode_csc >/dev/null 2>&1
}

add_call_recording_feature() {
	decode_csc >/dev/null 2>&1
	find "$onepath" -name "cscfeature_decoded.xml" -print0 | while IFS= read -r -d $'\0' file; do
		local content=$(cat "$file")
		local modified=false
		if [[ "$content" == *Camera_EnableCameraDuringCall* || "$content" == *VoiceCall_ConfigRecording* ]]; then
			content=$(echo "$content" | sed '/Camera_EnableCameraDuringCall/d; /VoiceCall_ConfigRecording/d')
			modified=true
		fi
		if ! [[ "$content" == *CscFeature_VoiceCall_ConfigRecording* ]]; then
			content=$(echo "$content" | sed '/<FeatureSet>/a \
    <CscFeature_VoiceCall_ConfigRecording>RecordingAllowed</CscFeature_VoiceCall_ConfigRecording>')
			modified=true
		fi
		if ! [[ "$content" == *CscFeature_Camera_EnableCameraDuringCall* ]]; then
			content=$(echo "$content" | sed '/<FeatureSet>/a \
    <CscFeature_Camera_EnableCameraDuringCall>TRUE</CscFeature_Camera_EnableCameraDuringCall>')
			modified=true
		fi
		if $modified; then
			echo "$content" >"$file"
			echo "$file"
		fi
	done
	encode_csc >/dev/null 2>&1
}

add_network_speed_feature() {
	decode_csc >/dev/null 2>&1
	find "$onepath" -name "cscfeature_decoded.xml" -print0 | while IFS= read -r -d $'\0' file; do
		local content=$(cat "$file")
		if [[ "$content" == *SupportRealTimeNetworkSpeed* ]]; then
			content=$(echo "$content" | sed '/SupportRealTimeNetworkSpeed/d')
		fi
		content=$(echo "$content" | sed '/<FeatureSet>/a \
    <CscFeature_Setting_SupportRealTimeNetworkSpeed>TRUE</CscFeature_Setting_SupportRealTimeNetworkSpeed>')
		echo "$content" >"$file"
		echo "$file"
	done
	encode_csc >/dev/null 2>&1
}

allow_control_all_notifications() {
	while IFS= read -r -d '' jarfile; do
		if [[ -f "$jarfile" ]]; then
			java -jar "$apktool_path" d -f -r "$jarfile" -o "${jarfile%.jar}"
			find "${jarfile%.jar}" -type f -name "*.smali" -print0 | xargs -0 -n 1 -P "$(nproc)" bash -c '
				sed -i -E "/.*->isBlockable\(\)Z/,/move-result [vp][0-9]*/{
					s/.*->isBlockable\(\)Z//
					s/move-result ([vp][0-9]*)/const\/4 \1, 0x1/
				}" "$1"
				sed -i -E "/invoke-virtual \{([vp][0-9]+), ([vp][0-9]+)\}, Landroid\/app\/NotificationChannelGroup;->setBlocked\(Z\)V/{s//\n    const \2, 0x1\n    &/}" "$1"
			' _
			temporary_fix_invoke_custom
			java -jar "$apktool_path" b -f -c "${jarfile%.jar}" -o "$jarfile"
			rm -rf "${jarfile%.jar}"
		fi
	done < <(find "$onepath" -name "services.jar" -print0)
}

advanced_material_support() {
	while IFS= read -r -d '' file; do
		parent_dir=$(basename "$(dirname "$file")")
		if [[ "$parent_dir" == "system" ]]; then
			grep -q "^persist.sys.background_blur_supported=true$" "$file" || echo "persist.sys.background_blur_supported=true" >>"$file"
			grep -q "^persist.sys.background_blur_status_default=true$" "$file" || echo "persist.sys.background_blur_status_default=true" >>"$file"
			grep -q "^persist.sys.background_blur_mode=0$" "$file" || echo "persist.sys.background_blur_mode=0" >>"$file"
			grep -q "^persist.sys.background_blur_version=2$" "$file" || echo "persist.sys.background_blur_version=2" >>"$file"
		fi
	done < <(find "$onepath" -type f -name "build.prop" -print0)
}

xiaomi_smart_card_support() {
	while IFS= read -r -d '' file; do
		parent_dir=$(basename "$(dirname "$file")")
		if [[ "$parent_dir" == "vendor" ]]; then
			if ! grep -q "^ro.vendor.se.type=HCE,UICC,eSE$" "$file"; then
				echo "ro.vendor.se.type=HCE,UICC,eSE" >>"$file"
			fi
		fi
	done < <(find "$onepath" -type f -name "build.prop" -print0)
}

update_build_props() {
	declare -A lines_to_add=(
		[vendor]="ro.vendor.audio.sfx.scenario=true"
		[product]="persist.sys.miui_animator_sched.sched_threads=2 persist.vendor.display.miui.composer_boost=4-7"
	)
}

disable_html_viewer_cloud_control() {
	while IFS= read -r -d '' apk_path; do
		apk_dir="${apk_path%.apk}"
		java -jar "$apktool_path" d -f -r "$apk_path" -o "$apk_dir"
		find "$apk_dir" -name "JobTask.smali" -print0 | while IFS= read -r -d '' smali_file; do
			if [[ "$smali_file" == *"com/android/settings/cloud/JobTask.smali" ]]; then
				sed -i '/^[[:space:]]*\.method.*updateCloudAllData()V/,/^[[:space:]]*\.end method/c\
.method private updateCloudAllData()V\n\
	.registers 1\n\
	return-void\n\
.end method' "$smali_file"
			fi
		done
		java -jar "$apktool_path" b -f -c "$apk_dir" -o "$apk_path"
		"$zipalign_path" -f 4 "$apk_path" "${apk_path%.apk}_latest.apk"
		mv -f "${apk_path%.apk}_latest.apk" "$apk_path"
		rm -rf "$apk_dir"
	done < <(find "$onepath" -name "HTMLViewer.apk" -print0)
}

disable_joyose_cloud_control() {
	while IFS= read -r -d '' apk_path; do
		apk_dir="${apk_path%.apk}"
		java -jar "$apktool_path" d -f -r "$apk_path" -o "$apk_dir"
		find "$apk_dir" -name "*.smali" -print0 | xargs -0 -n 1 -P "$(nproc)" bash -c '
			file="$1"
			gawk -i inplace '"'"'
			{
				if ($0 ~ /^[[:space:]]*\.method/) {
					in_method = 1;
					method_header = $0;
					method_body = "";
					has_keywords = 0;
				} else if (in_method) {
					if ($0 ~ /job exist, sync local.../) {
						has_keywords = 1;
					}
					method_body = method_body $0 "\n";
					if ($0 ~ /^[[:space:]]*\.end method/) {
						in_method = 0;
						if (has_keywords) {
							print method_header;
							print "    .registers 1";
							print "    return-void";
							print $0;
						} else {
							print method_header;
							print method_body;
						}
						method_header = "";
						method_body = "";
					}
				} else {
					print;
				}
			}
			END {
				if (in_method && has_keywords) {
					print method_header;
					print "    .registers 1";
					print "    return-void";
					print ".end method";
				} else if (in_method) {
					print method_header;
					print method_body;
				}
			}
			'"'"' "$file"
		' _
		temporary_fix_invoke_custom
		java -jar "$apktool_path" b -f -c "$apk_dir" -o "$apk_path"
		"$zipalign_path" -f 4 "$apk_path" "${apk_path%.apk}_latest.apk"
		mv -f "${apk_path%.apk}_latest.apk" "$apk_path"
		rm -rf "$apk_dir"
	done < <(find "$onepath" -name "Joyose.apk" -print0)
}

GMS_instant_push() {
	while IFS= read -r -d '' apk_path; do
		apk_dir="${apk_path%.apk}"
		java -jar "$apktool_path" d -f -r "$apk_path" -o "$apk_dir"
		find "$apk_dir" -name "MilletPolicy.smali" -print0 | while IFS= read -r -d '' smali_file; do
			if [[ "$smali_file" == *"MilletPolicy.smali" ]]; then
				sed -i 's/com\.google\.android\.gms/com.google.android.gms.keeplive/g' "$smali_file"
			fi
		done
		temporary_fix_invoke_custom
		java -jar "$apktool_path" b -c -f "$apk_dir" -o "$apk_path"
		"$zipalign_path" -f 4 "$apk_path" "${apk_path%.apk}_latest.apk"
		mv -f "${apk_path%.apk}_latest.apk" "$apk_path"
		rm -rf "$apk_dir"
	done < <(find "$onepath" -name "PowerKeeper.apk" -print0)
}

temporary_fix_invoke_custom() {
	find "$onepath" -name "*.smali" -print0 | xargs -0 -n 1 -P "$(nproc)" bash -c '
        file="$1"
        gawk -i inplace '"'"'
        {
            if ($0 ~ /^[[:space:]]*\.method/) {
                in_method = 1;
                method_block = $0 "\n";
                has_invoke_custom = 0;
            } else if (in_method) {
                method_block = method_block $0 "\n";
                if ($0 ~ /invoke-custom/) {
                    has_invoke_custom = 1;
                    next;
                }
                if ($0 ~ /^[[:space:]]*\.end method/) {
                    in_method = 0;
                    if (!has_invoke_custom) {
                        print method_block;
                    }
                    method_block = "";
                }
            } else {
                print;
            }
        }
        END {
            if (in_method && !has_invoke_custom) {
                print method_block;
            }
        }
        '"'"' "$file"
    ' _
}

search_package_name() {
	search_package_name_tool="$(dirname "$0")/bin/all/search_package_name/pnget"
	mkdir -p "$onepath/Extracted-files/config"
	"$search_package_name_tool" -dir "$onepath" -data "$onepath/Extracted-files/config/nice.list" >/dev/null 2>&1
}

remove_packages() {
	local package_list="$onepath/Extracted-files/config/nice.list"
	local packages_to_remove=("$@")
	while IFS=: read -r package paths; do
		for pkg in "${packages_to_remove[@]}"; do
			if [[ "$package" == "$pkg" ]]; then
				IFS=';' read -ra path_array <<<"$paths"
				for path in "${path_array[@]}"; do
					(
						if [[ "$path" == *.capex || "$path" == *.apex ]]; then
							rm -f "$path"
						else
							parent_dir=$(dirname "$path")
							rm -rf "$parent_dir"
						fi
					) &
				done
				wait
			fi
		done
	done <"$package_list"
}

remove_all() {
	for opt in "${options_order[@]}"; do
		IFS=' ' read -r -a items <<<"${options[$opt]}"
		for item in "${items[@]}"; do
			if [[ "$item" == com.* ]]; then
				remove_packages "$item"
			else
				remove_files "$item"
			fi
		done
	done
}

remove_files() {
	local exclude_files=("1" "2")
	local exclude_string=""
	for exclude in "${exclude_files[@]}"; do
		exclude_string+=" -not -name $exclude"
	done
	for file in "$@"; do
		while IFS= read -r -d '' path; do
			if [[ -d "$path" ]]; then
				base_name=$(basename "$path")
				if find "$path" -name "$base_name.apk" | grep -q .; then
					rm -rf "$path"
				fi
			elif [[ -f "$path" ]]; then
				rm -f "$path"
			fi
		done < <(find "$onepath" \( -type d -name "$file" $exclude_string -o -type f -name "$file" \) -print0)
	done
}

prevent_theme_reversion() {
	while IFS= read -r -d '' jarfile; do
		if [[ -f "$jarfile" ]]; then
			java -jar "$apktool_path" d -f "$jarfile" -o "${jarfile%.jar}"
			temporary_fix_invoke_custom
			while IFS= read -r -d '' smali_file; do
				sed -i '/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;/,/move-result-object [a-z0-9]*/{
          s/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;//
          s/move-result-object \([a-z0-9]*\)/sget-object \1, Lmiui\/drm\/DrmManager\$DrmResult;->DRM_SUCCESS:Lmiui\/drm\/DrmManager\$DrmResult;/
        }' "$smali_file"
			done < <(find "${jarfile%.jar}" -name "ThemeReceiver.smali" -print0)
			java -jar "$apktool_path" b -api 29 -c -f "${jarfile%.jar}" -o "$jarfile"
			rm -rf "${jarfile%.jar}"
		fi
	done < <(find "$onepath" -name "miui-framework.jar" -print0)
}

invoke_native_installer() {
	while IFS= read -r -d '' jarfile; do
		if [[ -f "$jarfile" ]]; then
			java -jar "$apktool_path" d -f "$jarfile" -o "${jarfile%.jar}"
			temporary_fix_invoke_custom
			while IFS= read -r -d '' smali_file; do
				if [[ "$smali_file" == *"PackageManagerServiceImpl.smali" ]]; then
					sed -i '/.method public checkGTSSpecAppOptMode()V/,/.end method/c\
.method public checkGTSSpecAppOptMode()V\n\
    .registers 1\n\
    return-void\n\
.end method' "$smali_file"
					sed -i '/.method public static isCTS()Z/,/.end method/c\
.method public static isCTS()Z\n\
    .registers 1\n\
    const/4 v0, 0x1\n\
    return v0\n\
.end method' "$smali_file"
				fi
			done < <(find "${jarfile%.jar}" -name "PackageManagerServiceImpl.smali" -print0)
			java -jar "$apktool_path" b -c -f "${jarfile%.jar}" -o "$jarfile"
			rm -rf "${jarfile%.jar}"
		fi
	done < <(find "$onepath" -name "miui-services.jar" -print0)
	echo "Removed:"
	remove_files "MIUIPackageInstaller"
}

remove_unsigned_app_verification() {
	while IFS= read -r -d '' jarfile; do
		java -jar "$apktool_path" d -f -r "$jarfile" -o "${jarfile%.jar}"
		temporary_fix_invoke_custom
		while IFS= read -r -d '' smali_file; do
			if sed -n '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result [a-z0-9]*/p' "$smali_file" | grep -q 'invoke-static'; then
				sed -i '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result [a-z0-9]*/{
          s/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I//
          s/move-result \([a-z0-9]*\)/const\/4 \1, 0x1/
        }' "$smali_file"
			fi
		done < <(find "${jarfile%.jar}" -name '*.smali' -print0)
		java -jar "$apktool_path" b -c -f "${jarfile%.jar}" -o "$jarfile"
		rm -rf "${jarfile%.jar}"
	done < <(find "$onepath" -name "services.jar" -print0)
}

copy_dirs() {
	local brand=$1
	local script_dir=$(dirname "$(readlink -f "$0")")
	if [[ "$brand" == "samsung" ]]; then
		find "$onepath" -type d -name "system" | while read -r system_dir; do
			declare -A dirs=(["app"]="app" ["preload"]="preload" ["priv-app"]="priv-app")
			local source_dir="$script_dir/bin/samsung/add_for_system"
			local all_dirs_exist=true
			for dir in "${!dirs[@]}"; do
				if [[ ! -d "$system_dir/${dirs[$dir]}" ]]; then
					all_dirs_exist=false
					break
				fi
			done
			if $all_dirs_exist; then
				for dir in "${!dirs[@]}"; do
					cp -r "$source_dir"/* "$system_dir/"
				done
				for file in "$source_dir"/*/*/*; do
					current_dir=$(basename "$(dirname "$file")")
					parent_dir=$(basename "$(dirname "$(dirname "$file")")")
				done
			fi
		done
	elif [[ "$brand" == "xiaomi" ]]; then
		find "$onepath" -type d -name "product" | while read -r product_dir; do
			declare -A dirs=(["app"]="app" ["data-app"]="data-app" ["priv-app"]="priv-app")
			local source_dir="$script_dir/bin/xiaomi/add_for_product"
			local all_dirs_exist=true
			for dir in "${!dirs[@]}"; do
				if [[ ! -d "$product_dir/${dirs[$dir]}" ]]; then
					all_dirs_exist=false
					break
				fi
			done
			if $all_dirs_exist && [[ -d "$product_dir/prebuilts" ]]; then
				for dir in "${!dirs[@]}"; do
					cp -r "$source_dir"/* "$product_dir/"
				done
				for file in "$source_dir"/*/*/*; do
					current_dir=$(basename "$(dirname "$file")")
					parent_dir=$(basename "$(dirname "$(dirname "$file")")")
				done
			fi
		done
	else
		echo "Unsupported brand: $brand"
		return 1
	fi
}

decode_csc() {
	local script_dir=$(dirname "$0")
	local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
	local files=("cscfeature.xml" "customer_carrier_feature.json")
	for file in "${files[@]}"; do
		while IFS= read -r -d '' filepath; do
			output_file="${filepath%.*}_decoded.${filepath##*.}"
			java -jar "$omc_decoder_path" -i "$filepath" -o "$output_file"
			if [ $? -eq 0 ]; then
				rm "$filepath"
			fi
		done < <(find "$onepath" -name "$file" -print0)
	done
}

encode_csc() {
	local script_dir=$(dirname "$0")
	local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
	local files=("cscfeature_decoded.xml" "customer_carrier_feature_decoded.json")
	for file in "${files[@]}"; do
		while IFS= read -r -d '' filepath; do
			output_file="${filepath/_decoded/}"
			java -jar "$omc_decoder_path" -e -i "$filepath" -o "$output_file"
			if [ $? -eq 0 ]; then
				rm "$filepath"
			fi
		done < <(find "$onepath" -name "$file" -print0)
	done
}

deodex() {
	local found=false
	local exclude_files=("example")
	local exclude_string=""
	for exclude in "${exclude_files[@]}"; do
		exclude_string+=" -not -iname $exclude"
	done
	for file in "oat" "*.art" "*.oat" "*.vdex" "*.odex" "*.fsv_meta" "*.bprof" "*.prof"; do
		if find "$onepath" -name "$file" $exclude_string -print0 | xargs -0 | grep -q .; then
			if [ "$found" = false ]; then
				found=true
			fi
			find "$onepath" -name "$file" $exclude_string -print0 | xargs -0 -I {} sh -c 'rm -rf "{}"'
		fi
	done
	if [ "$found" = false ]; then
		echo "No files related to odex to remove"
	fi
}

deodex_key_files() {
	local found=false
	local files=("services.*" "miui-services.*" "miui-framework.*" "miui-wifi-service.*")
	for file in "${files[@]}"; do
		if find "$onepath" -name "$file" -not -name "*.jar" -print0 | xargs -0 | grep -q .; then
			if [ "$found" = false ]; then
				found=true
			fi
			find "$onepath" -name "$file" -not -name "*.jar" -print0 | xargs -0 -I {} sh -c 'rm -rf "{}"'
		fi
	done
	if [ "$found" = false ]; then
		echo "No related files to remove"
	fi
}
