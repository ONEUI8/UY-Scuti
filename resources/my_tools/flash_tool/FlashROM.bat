@ECHO OFF
setlocal enabledelayedexpansion
:HOME

REM 设置机型
set "right_device=Model_code"

set "PATH=%PATH%;%cd%\bin\windows"
set sg=1^>nul 2^>nul

for /f "tokens=2 delims=:" %%a in ('chcp') do set "locale=%%a"

cls

if "!locale!"==" 936" (
    set "confirm_switch={08}{\n}你确定要执行这个操作吗？{\n}{\n}如果确定，请输入 'sure'，否则，输入任意以退出：{\n}{\n}"
    set "device_mismatch_msg=此 ROM 仅适配 !right_device! ，但你的设备是 !DeviceCode!"
    set "disabled_avb_verification=已禁用 Avb2.0 校验"
    set "exit_program={04}{\n}[4] {01}退出程序{#}{#}{\n}"
    set "execution_completed=执行完成，等待自动重启"
    set "failure_status=因为某些原因，未能刷入"
    set "fastboot_mode={06}当前所处状态：Fastboot 模式{\n}"
    set "fastbootd_mode={06}当前所处状态：Fastbootd 模式{\n}"
    set "format_data_flash={04}{\n}[2] {01}格式化用户数据并刷入{#}{#}{\n}"
    set "formatting_data=正在格式化 DATA"
    set "keep_data_flash={04}{\n}[1] {01}保留全部数据并刷入{#}{#}{\n}"
    set "kept_data_reboot=已保留全部数据，准备重启！"
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"
    set "retry_message=重试..."
    set "select_project={02}请选择你要操作的项目：{\n}{\n}"
    set "success_status=刷入成功"
    set "switch_to_fastboot={04}{\n}[3] {01}切换到 Fastboot 模式{#}{#}{\n}"
    set "switch_to_fastbootd={04}{\n}[3] {01}切换到 Fastbootd 模式{#}{#}{\n}"
    set "title=盾牌座 UY 线刷工具"
    set "waiting_device={0D}————  正在等待设备  ————{#}{\n}{\n}"
) else (
    set "confirm_switch={08}{\n}Are you sure you want to perform this operation?{\n}{\n}If sure, please enter 'sure', otherwise, enter anything to exit：{\n}{\n}"
    set "device_mismatch_msg=This ROM is only compatible with !right_device! , but your device is !DeviceCode!"
    set "disabled_avb_verification=Avb2.0 verification has been disabled"
    set "exit_program={04}{\n}[4] {01}Exit program{#}{#}{\n}"
    set "execution_completed=Execution completed, waiting for automatic reboot"
    set "failure_status=Flash failed"
    set "fastboot_mode={06}Current status: Fastboot mode{\n}"
    set "fastbootd_mode={06}Current status: Fastbootd mode{\n}"
    set "format_data_flash={04}{\n}[2] {01}Format user data and flash{#}{#}{\n}"
    set "formatting_data=Formatting DATA"
    set "keep_data_flash={04}{\n}[1] {01}Keep all data and flash{#}{#}{\n}"
    set "kept_data_reboot=All data has been kept, ready to reboot!"
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"
    set "retry_message=Retry..."
    set "select_project={02}Please select the project you want to operate：{\n}{\n}"
    set "success_status=Flash successful"
    set "switch_to_fastboot={04}{\n}[3] {01}Switch to Fastboot mode{#}{#}{\n}"
    set "switch_to_fastbootd={04}{\n}[3] {01}Switch to Fastbootd mode{#}{#}{\n}"
    set "title=UY Scuti Flash Tool"
    set "waiting_device={0D}————  Waiting for device  ————{#}{\n}{\n}"
)

title !title!

REM 显示等待设备的消息
echo.
cho !waiting_device!

REM 获取设备型号
for /f "tokens=2" %%a in ('fastboot getvar product 2^>^&1^|find "product"') do (
    set DeviceCode=%%a
)
REM 获取设备的分区类型
for /f "tokens=2" %%a in ('fastboot getvar slot-count 2^>^&1^|find "slot-count" ') do (
    set DynamicPartitionType=%%a
)
REM 根据设备的分区类型设置变量 DynamicPartitionType 的值
if "!DynamicPartitionType!" == "2" (
    set DynamicPartitionType=NonOnlyA
) else (
    set DynamicPartitionType=OnlyA
)
REM 获取设备的 Fastboot 状态
for /f "tokens=2" %%a in ('fastboot getvar is-userspace 2^>^&1^|find "is-userspace"') do (
    set FastbootState=%%a
)
REM 根据设备的 Fastboot 状态设置变量 FastbootState 的值
if "!FastbootState!" == "yes" (
    set FastbootState=!fastbootd_mode!
) else (
    set FastbootState=!fastboot_mode!
)

cls

echo.
if not "!DeviceCode!"=="!right_device!" (
    cho !device_mismatch_msg!
    PAUSE
    GOTO :EOF
)

cls

cho {F9}                                                {\n}
cho !one_title!
cho {F9}                                                {\n}{\n}
cho !FastbootState!
cho !keep_data_flash!
cho !format_data_flash!
if "!FastbootState!" == "!fastbootd_mode!" (
    cho !switch_to_fastboot!
) else (
    cho !switch_to_fastbootd!
)
cho !exit_program!
echo.

cho !select_project!
set /p UserChoice=
if "!UserChoice!" == "1" (
    set SelectedOption=1
    goto FLASH
) else if "!UserChoice!" == "2" (
    set SelectedOption=2
    goto FLASH
) else if "!UserChoice!" == "3" (
    cho !confirm_switch!
    set /p Confirmation=
    if /I "!Confirmation!" == "sure" (
        if "!FastbootState!" == "!fastbootd_mode!" (
            cls
            echo.
            fastboot reboot bootloader
        ) else (
            cls
            echo.
            fastboot reboot fastboot
        )
    )
    goto HOME
) else if "!UserChoice!" == "4" (
    exit
)
goto HOME&pause

:FLASH
cls 
echo.

REM 看起来像新机型要求？
if "!DynamicPartitionType!" == "NonOnlyA" (
    fastboot set_active a %sg%
)

REM 对 vbmeta 分区文件专门刷入
set "count=0"
for /R "images\" %%i in (*.img) do (
	echo %%~ni | findstr /B "vbmeta" >nul && (
		if "!DynamicPartitionType!"=="OnlyA" (
			fastboot --disable-verity --disable-verification flash "%%~ni" "%%i"
		) else (
			fastboot --disable-verity --disable-verification flash "%%~ni_a" "%%i"
			fastboot --disable-verity --disable-verification flash "%%~ni_b" "%%i"
		)
		set /a "count+=1"
	)
)
if !count! gtr 0 (
	echo !disabled_avb_verification!
	echo.
)

REM 遍历分区文件并刷入
for /f "delims=" %%b in ('dir /b images\*.img ^| findstr /v /i "super.img" ^| findstr /v /i "preloader_raw.img" ^| findstr /v /i "cust.img" ^| findstr /v /i "recovery.img" ^| findstr /v /i /b "vbmeta"') do (
    set "filename=%%~nb"
    if "!DynamicPartitionType!"=="OnlyA" (
        fastboot flash "%%~nb" "images\%%~nxb"
        if "!errorlevel!"=="0" (
            echo !filename!: !success_status!
            echo.
        ) else (
            echo !filename!: !failure_status!
            echo.
        )
    ) else (
        fastboot flash "%%~nb_a" "images\%%~nxb"
        if "!errorlevel!"=="0" (
            echo !filename!_a: !success_status!
        ) else (
            echo !filename!_a: !failure_status!
        )
        fastboot flash "%%~nb_b" "images\%%~nxb"
        if "!errorlevel!"=="0" (
            echo !filename!_b: !success_status!
            echo.
        ) else (
            echo !filename!_b: !failure_status!
            echo.
        )
    )
)

REM MTK 机型专属
if exist "images\preloader_raw.img" (
    fastboot flash preloader_a "images\preloader_raw.img"
    fastboot flash preloader_b "images\preloader_raw.img"
    fastboot flash preloader1 "images\preloader_raw.img"
    fastboot flash preloader2 "images\preloader_raw.img"
    echo.
)

if exist images\cust.img (
    fastboot flash cust "images\cust.img"
    echo.
)

if exist images\super.img (
    fastboot erase super
    fastboot flash super "images\super.img"
    echo.
)

if "!SelectedOption!" == "1" (
    echo !kept_data_reboot!
) else if "!SelectedOption!" == "2" (
    echo !formatting_data!
    fastboot erase userdata
    fastboot erase metadata
)

if "!DynamicPartitionType!" == "NonOnlyA" (
    fastboot set_active a %sg%
)

fastboot reboot
echo.
echo !execution_completed!
pause
exit
