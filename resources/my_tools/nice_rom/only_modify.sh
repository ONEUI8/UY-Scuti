#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/codes/cn/implemented_features.sh"
add_path() {
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "$SCRIPT_DIR"
	onepath="$1"
	rom_brands=("HyperOS" "OneUI" "ColorOS" "返回工作域" "退出程序")
	brand_selected=false
	while true; do
		echo "=============================="
		echo "	可修改的 ROM："
		echo "=============================="
		for i in "${!rom_brands[@]}"; do
			echo "$((i + 1))) ${rom_brands[$i]}"
		done
		read -p "请输入你的选择：" choice
		if [[ ! $choice =~ ^[0-9]+$ ]]; then
			echo "无效的选择：请输入数字！"
			continue
		fi
		if ((choice < 1 || choice > ${#rom_brands[@]})); then
			echo "无效的选择：数字超出范围！"
			continue
		fi
		brand=${rom_brands[$((choice - 1))]}
		case $brand in
		"HyperOS")
			echo "已选择 HyperOS"
			options_order=("移除小爱翻译" "移除小爱语音组件" "移除小爱通话" "移除澎湃 AI 引擎" "移除互联互通服务验证" "移除浏览器" "移除音乐与视频" "移除钱包" "移除广告分析相关组件" "移除自带输入法" "移除传送门" "移除智能助理" "移除搜索功能" "移除悬浮球" "移除应用商店" "移除反馈" "移除系统更新" "移除相册" "移除文件管理器" "移除智能密码管理" "移除家人守护" "移除下载管理器" "移除多余应用" "移除所有" "反向移除" "快速替换" "添加应用到 Product 分区" "禁用未签名验证" "调用原生安装器" "禁止主题还原" "禁用热点名称还原" "小米智能卡支持" "高级材质支持" "关键性 Deodex" "全局 Deodex" "禁用 Avb2.0 校验" "返回工作域" "退出程序")
			declare -A options
			options=(
				["移除小爱翻译"]="com.xiaomi.aiasst.vision"
				["移除小爱语音组件"]="com.miui.voicetrigger com.miui.voiceassist"
				["移除小爱通话"]="com.xiaomi.aiasst.service"
				["移除澎湃 AI 引擎"]="com.xiaomi.aicr"
				["移除互联互通服务验证"]="com.xiaomi.trustservice"
				["移除浏览器"]="com.android.browser"
				["移除音乐与视频"]="com.miui.player com.miui.video"
				["移除钱包"]="com.mipay.wallet"
				["移除广告分析相关组件"]="com.miui.hybrid com.miui.systemAdSolution com.miui.analytics com.xiaomi.ab com.xiaomi.gamecenter.sdk.service com.xiaomi.gamecenter"
				["移除自带输入法"]="com.sohu.inputmethod.sogou.xiaomi com.iflytek.inputmethod.miui com.baidu.input_mi"
				["移除传送门"]="com.miui.contentextension"
				["移除智能助理"]="com.miui.personalassistant"
				["移除搜索功能"]="com.android.quicksearchbox"
				["移除悬浮球"]="com.miui.touchassistant"
				["移除应用商店"]="com.xiaomi.market"
				["移除反馈"]="com.miui.miservice com.miui.bugreport"
				["移除系统更新"]="com.android.updater"
				["移除相册"]="com.miui.gallery"
				["移除文件管理器"]="com.android.fileexplorer"
				["移除智能密码管理"]="com.miui.contentcatcher"
				["移除家人守护"]="com.miui.greenguard"
				["移除下载管理器"]="com.android.providers.downloads.ui"
				["移除多余应用"]="com.miui.cleanmaster MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim *VipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* NewHome* MiRadio"
			)
			brand_selected=true
			;;
		"OneUI")
			echo "已选择 OneUI"
			options_order=("移除三星浏览器" "移除开机验证" "移除官方恢复模式还原" "移除主页负一屏" "移除动态表情相关组件" "移除 Bixby 语音组件" "移除微软输入法" "移除捆绑的谷歌系应用" "移除穿戴设备管理器" "移除系统更新" "移除主题商店" "移除失效的 Knox 系应用" "移除不常用应用" "移除所有" "反向移除" "快速替换" "添加应用到 System 分区" "添加网速显示" "添加通话录音" "添加相机静音" "禁用未签名验证" "关键性 Deodex" "全局 Deodex" "禁用 Avb2.0 校验" "解码 csc" "编码 csc" "返回工作域" "退出程序")
			declare -A options
			options=(
				["移除三星浏览器"]="com.sec.android.app.sbrowser"
				["移除开机验证"]="ActivationDevice_V2"
				["移除官方恢复模式还原"]="recovery-from-boot.p"
				["移除主页负一屏"]="com.samsung.android.app.spage "
				["移除动态表情相关组件"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
				["移除 Bixby 语音组件"]="BixbyWakeup Bixby"
				["移除微软输入法"]="com.touchtype.swiftkey com.swiftkey.swiftkeyconfigurator"
				["移除换机助手"]="SmartSwitchAgent SmartSwitchStub"
				["移除穿戴设备管理器"]="GearManagerStub"
				["移除捆绑的谷歌系应用"]="com.google.android.apps.maps com.google.android.gm com.google.android.youtube com.google.android.apps.tachyon com.google.android.apps.messaging Chrome*"
				["移除系统更新"]="com.wssyncmldm com.sec.android.soagent"
				["移除主题商店"]="com.samsung.android.themestore"
				["移除失效的 Knox 系应用"]="Knox* SamsungBilling SamsungPass"
				["移除不常用应用"]="KidsHome_Installer"
			)
			brand_selected=true
			;;
		"ColorOS")
			echo "已选择 ColorOS"
			options_order=(
				"移除翻译" "移除银联服务" "移除应用商店" "移除家人守护" "移除日历" "移除国际漫游" "移除呼吸灯" "移除便签" "移除备份与恢复"
				"移除音乐" "移除钱包" "移除快捷方式" "移除在线视频" "移除会员中心" "移除文档阅读器" "移除社区" "移除小贴士" "移除主题商店"
				"移除天气" "移除游戏中心" "移除快游戏" "移除文件管理器" "移除游戏大厅" "移除健康"
				"移除阅读器" "移除邮件" "移除红外遥控" "移除铃声"
				"移除浏览器" "移除自带输入法" "移除广告组件" "移除悬浮球" "移除所有" "反向移除" "快速替换" "关键性 Deodex" "全局 Deodex" "禁用 Avb2.0 校验" "返回工作域" "退出程序"
			)
			declare -A options
			options=(
				["移除翻译"]="com.coloros.translate"
				["移除银联服务"]="com.unionpay.tsmservice"
				["移除应用商店"]="com.oppo.store"
				["移除家人守护"]="com.coloros.familyguard"
				["移除日历"]="com.coloros.calendar"
				["移除国际漫游"]="com.redteamobile.roaming"
				["移除呼吸灯"]="com.oneplus.brickmode"
				["移除便签"]="com.coloros.note"
				["移除备份与恢复"]="com.coloros.backuprestore"
				["移除音乐"]="com.heytap.music"
				["移除钱包"]="com.finshell.wallet"
				["移除快捷方式"]="com.coloros.shortcuts"
				["移除在线视频"]="com.heytap.yoli"
				["移除会员中心"]="com.oneplus.member"
				["移除文档阅读器"]="andes.oplus.documentsreader"
				["移除社区"]="com.oneplus.bbs"
				["移除小贴士"]="com.oplus.tips"
				["移除主题商店"]="com.heytap.themestore"
				["移除天气"]="com.coloros.weather2"
				["移除游戏中心"]="com.oplus.games"
				["移除快游戏"]="com.oplus.play"
				["移除文件管理器"]="com.coloros.filemanager"
				["移除游戏大厅"]="com.nearme.gamecenter"
				["移除健康"]="com.heytap.health"
				["移除阅读器"]="com.heytap.reader"
				["移除邮件"]="com.android.email"
				["移除红外遥控"]="com.oplus.consumerIRApp"
				["移除铃声"]="com.oplus.melody"
				["移除浏览器"]="com.heytap.browser"
				["移除自带输入法"]="com.baidu.input_oppo com.sohu.inputmethod.sogouoem"
				["移除广告组件"]="com.opos.ads com.android.adservices.api"
				["移除悬浮球"]="com.coloros.floatassistant"
			)
			brand_selected=true
			;;
		"返回工作域")
			return 0
			;;
		"退出程序")
			clear
			exit 0
			;;
		*)
			echo "无效的选择：$brand"
			;;
		esac
		if [ "$brand_selected" = true ]; then
			clear
			break
		fi
	done
	while true; do
		echo "=============================="
		echo "	可选功能："
		echo "=============================="
		PS3="请输入你的选择序号，以空格分隔："
		select opt in "${options_order[@]}"; do
			read -ra selections <<<"$REPLY"
			echo ""
			for selection in "${selections[@]}"; do
				if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
					echo "无效的选择：$selection"
					continue
				fi
				index=$((selection - 1))
				if [[ $index -lt 0 || $index -ge ${#options_order[@]} ]]; then
					echo "无效的选择：$selection"
					continue
				fi
				opt=${options_order[$index]}
				if [[ ${#selections[@]} -gt 1 && ("$opt" == "退出程序" || "$opt" == "返回工作域") ]]; then
					echo "多选择禁止退出程序或返回工作域。"
					continue
				fi
				deleted=false
				case $opt in
				"禁用 Avb2.0 校验")
					echo "已选择 禁用 Avb2.0 校验"
					remove_vbmeta_verification
					remove_extra_vbmeta_verification
					;;
				"禁用热点名称还原")
					echo "已选择 禁用热点名称还原"
					remove_hyperos_hotspot_name_restore
					;;
				"禁用设置名称校验")
					echo "已选择 禁用设置名称校验"
					remove_hyperos_settings_name_check
					;;
				"快速替换")
					echo "已选择 快速替换"
					replace_files
					;;
				"添加应用到 Product 分区")
					echo "已选择 添加应用到 Product 分区"
					copy_dirs "xiaomi"
					;;
				"添加应用到 System 分区")
					echo "已选择 添加应用到 System 分区"
					copy_dirs "samsung"
					;;
				"解码 csc")
					echo "已选择 解码 csc"
					decode_csc
					;;
				"编码 csc")
					echo "已选择 编码 csc"
					encode_csc
					;;
				"禁用未签名验证")
					echo "已选择 禁用未签名验证"
					remove_unsigned_app_verification
					;;
				"调用原生安装器")
					echo "已选择 调用原生安装器"
					invoke_native_installer
					;;
				"禁止主题还原")
					echo "已选择 禁止主题还原"
					prevent_theme_reversion
					;;
				"全局 Deodex")
					echo "已选择 全局 Deodex"
					deodex
					;;
				"关键性 Deodex")
					echo "已选择 关键性 Deodex"
					deodex_key_files
					;;
				"移除所有")
					echo "已选择 移除所有"
					search_package_name
					remove_all
					;;
				"反向移除")
					echo "已选择 反向移除"
					search_package_name
					echo -n "请输入保留的选项，以空格分隔："
					read -r -a exclude_array
					if [[ ${#exclude_array[@]} -gt 0 ]]; then
						echo -n "保留以下选项：${exclude_array[*]}"
						for opt in "${options_order[@]}"; do
							if [[ "$opt" == 移除* && "$opt" != "移除所有" ]]; then
								exclude_flag=0
								for exclude in "${exclude_array[@]}"; do
									if [[ "$opt" == "${options_order[$((exclude - 1))]}" ]]; then
										exclude_flag=1
										break
									fi
								done
								if [[ $exclude_flag -eq 0 ]]; then
									echo "已选择 $opt"
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
				"GMS 及时推送")
					echo "已选择 GMS 及时推送"
					GMS_instant_push
					;;
				"禁用 Joyose 云控")
					echo "已选择 禁用 Joyose 云控"
					disable_joyose_cloud_control
					;;
				"禁用 Html 查看器云控")
					echo "已选择 禁用 Html 查看器云控"
					disable_html_viewer_cloud_control
					;;
				"允许控制所有通知")
					echo "已选择 允许控制所有通知"
					allow_control_all_notifications
					;;
				"小米智能卡支持")
					echo "已选择 小米智能卡支持"
					xiaomi_smart_card_support
					;;
				"高级材质支持")
					echo "已选择 高级材质支持"
					advanced_material_support
					;;
				"添加网速显示")
					echo "已选择 添加网速显示"
					add_network_speed_feature
					;;
				"添加通话录音")
					echo "已选择 添加通话录音"
					add_call_recording_feature
					;;
				"添加相机静音")
					echo "已选择 添加相机静音"
					add_camera_mute_feature
					;;
				"返回工作域")
					return 0
					;;
				"退出程序")
					clear
					exit 0
					;;
				移除*)
					echo "已选择 $opt"
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