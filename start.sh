#!/bin/bash

# 引入各个模块
for script in "$(dirname "$0")/resources/module_codes/cn"/*.sh \
	"$(dirname "$0")/resources/module_codes/general"/*.sh; do
	source "$script"
done
source "$(dirname "$0")/resources/my_tools/nice_rom/NiceRom.sh"
super_sub-partitions_list="my_.*\.img|\
mi_ext\.img|\
odm\.img|odm_dlkm\.img|\
product\.img|\
system\.img|system_dlkm\.img|system_ext\.img|\
vendor\.img|vendor_dlkm\.img"
# 定义工具和工作目录的路径
TOOL_DIR="$(dirname "$0")/resources/my_tools"
WORK_DIR="$(dirname "$0")/my_workspaces"

# 定义当前工作域
current_workspace=""

function show_main_menu {
	clear
	echo -e "\033[38;2;135;206;235m"
	echo -e "                               "
	echo -e "   ──────────────────────────"
	echo -e "                             "
	echo -e "           盾牌座 UY  "
	echo -e "                             "
	echo -e "   ──────────────────────────"
	tput sgr0
	echo -e "\n   [01] 选择工作域\n"
	echo -e "   [02] 建立工作域\n"
	echo -e "   [03] 删除工作域\n"
	echo -e "   [04] 更改语言设置\n"
	echo -e "   [05] 退出程序\n"
	echo -n "   请选择一个操作："
}

# 显示工作域菜单的函数
function show_workspace_menu {
	echo -e "\033[38;2;135;206;235m"
	echo -e "                               "
	echo -e "   ────────────────────────"
	echo -e "                             "
	echo -e "           工作域        "
	echo -e "                             "
	echo -e "   ────────────────────────"
	tput sgr0
	echo -e "\n   [01] 分区文件提取\n"
	echo -e "   [02] 分区文件打包\n"
	echo -e "   [03] SUPER 分区打包\n"
	echo -e "   [04] 一键修改\n"
	echo -e "   [05] 构建刷机包\n"
	echo -e "   [06] 返回主菜单\n"
	echo -e "   [07] 退出程序\n"
	echo -n "   请选择一个操作："
}

function create_workspace {
	while true; do
		echo ""
		echo -n "   请输入新建的工作域名称："
		read workspace
		if [ -z "$workspace" ]; then
			clear
			echo -e "\n   你没有进行有效的输入。"
			continue
		fi
		if echo "$workspace" | grep -Pvq "^[a-zA-Z0-9_\-\.\p{Han}—\s]*$"; then
			clear
			echo -e "\n   不允许的工作域名称。"
		else
			if [ -d "$WORK_DIR/$workspace" ]; then
				echo "   工作域 $workspace 已存在，无需创建。"
				echo -n "   按任意键返回主菜单..."
				read -n 1
				return
			else
				mkdir -p "$WORK_DIR/$workspace"
				echo "   工作域 $workspace 已创建。"
				echo -n "   按任意键返回主菜单..."
				read -n 1
				return
			fi
		fi
	done
}

function select_workspace {
	local workspaces=("$WORK_DIR"/*)
	if [ -z "$(ls -A "$WORK_DIR")" ]; then
		echo -e "\n"
		echo -n "   没有可用的工作域，按任意键返回。"
		read -n 1
		return
	fi

	while true; do
		echo -e "\n"
		echo -e "   以下是所有可用的工作域：\n"
		local i=1
		for workspace in "${workspaces[@]}"; do
			if [ -d "$workspace" ]; then
				printf "   [%02d] %s\n\n" "$i" "$(basename "$workspace")"
				i=$((i + 1))
			fi
		done
		echo -e "\n   [Q] 返回主菜单\n"
		echo -n "   请输入要选择的工作域编号："
		read choice
		if [[ "$choice" =~ ^[Qq]$ ]]; then
			return
		elif [[ "$choice" =~ ^[0-9]+$ ]]; then
			workspace=$(ls -d "$WORK_DIR"/* | sed -n "${choice}p")
			if [ -d "$workspace" ]; then
				current_workspace="$(basename "$workspace")"
				echo "   你已选择工作域 '$current_workspace'。"
				workspace_menu
				break
			else
				clear
				echo -e "\n   该工作域编号不存在，请重新输入。"
			fi
		else
			clear
			echo -e "\n   无效的输入，请重新输入。"
		fi
	done
}

function delete_workspace {
	if [ -z "$(ls -A "$WORK_DIR")" ]; then
		echo -e "\n"
		echo -n "   没有工作域可删除，按任意键返回。"
		read -n 1
		return
	fi

	while true; do
		echo -e "\n"
		echo -e "   以下是所有工作域：\n"
		local i=1
		for workspace in "$WORK_DIR"/*; do
			if [ -d "$workspace" ]; then
				printf "   [%02d] %s\n\n" "$i" "$(basename "$workspace")"
				i=$((i + 1))
			fi
		done
		echo -e "\n   [Q] 返回主菜单\n"
		echo -n "   请输入要删除的工作域编号："
		read choice
		if [[ "$choice" =~ ^[Qq]$ ]]; then
			return
		elif [[ "$choice" =~ ^[0-9]+$ ]]; then
			workspace=$(ls -d "$WORK_DIR"/* | sed -n "${choice}p")
			if [ -d "$workspace" ]; then
				rm -rf "$workspace"
				find "$TOOL_DIR/boot_editor" -mindepth 1 ! -regex '^'"$TOOL_DIR/boot_editor"'/\(aosp\|bbootimg\|src\|tools\|gradlew\)\(/.*\)?$' -exec rm -rf {} \; 2>/dev/null
				echo "   工作域 $(basename "$workspace") 已删除。"
				echo -n "   按任意键返回主菜单..."
				read -n 1
				return
			else
				clear
				echo -e "\n   该工作域编号不存在，请重新输入。"
			fi
		else
			clear
			echo -e "\n   无效的输入，请重新输入。"
		fi
	done
}

# 在工作域菜单的函数中添加新功能
function workspace_menu {
	while true; do
		clear
		keep_clean
		show_workspace_menu
		read choice
		case "$choice" in
		1)
			clear
			extract_img
			;;
		2)
			clear
			package_regular_image
			;;
		3)
			clear
			package_super_image
			;;
		4)
			clear
			one_click_modify
			;;
		5)
			clear
			rebuild_rom
			;;
		6)
			clear
			return
			;;
		7)
			clear
			exit 0
			;;
		*)
			clear
			echo "   无效的选择，请重新输入。"
			;;
		esac
	done
}

function one_click_modify {
	pushd . >/dev/null
	local workspace_path=$(realpath "$WORK_DIR/$current_workspace")
	echo -e "\n"
	add_path "$workspace_path"
	popd
}

function keep_clean {
	find "$(dirname "$0")" -type f -name "*Zone.Identifier*" -exec rm -rf {} \;
}

while true; do
	clear
	keep_clean
	show_main_menu
	read choice
	case "$choice" in
	1)
		clear
		select_workspace
		;;
	2)
		clear
		create_workspace
		;;
	3)
		clear
		delete_workspace
		;;
	4)
		clear
		echo -e "\n   [1] English\n"
		echo -e "   [2] 中文\n"
		echo -n "   请选择新的语言设置："
		read new_language
		if [ "$new_language" = "1" ]; then
			replace_script "start_en.sh"
			exec "$(dirname "$0")/start.sh"
		elif [ "$new_language" = "2" ]; then
			replace_script "start_cn.sh"
			exec "$(dirname "$0")/start.sh"
		else
			echo "   无效的选择，请重新输入。"
		fi
		;;
	5)
		clear
		exit 0
		;;
	*)
		echo "   无效的选择，请重新输入。"
		;;
	esac
done
