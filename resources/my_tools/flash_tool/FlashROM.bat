@ECHO OFF
chcp 65001
setlocal enabledelayedexpansion

:HOME
set "right_device=Model_code"  REM Set the expected model code for verification
set "PATH=%PATH%;%cd%\bin\windows"  REM Update PATH to include the current directory's "bin\windows"
set sg=1^>nul 2^>nul  REM Suppress output for the next command

REM Check the system's locale (language region)
for /f %%i in ('wmic os get locale ^| findstr /r "[0-9A-F]"') do set "locale=%%i"
cls

REM Set messages based on locale
if "!locale!"=="0804" (
    set "confirm_switch={08}{\n}你确定要执行这个操作吗？{\n}{\n}如果确定，请输入 'sure'，否则，输入任意以退出：{\n}{\n}"  REM Confirmation message in Chinese
    set "device_mismatch_msg=此 ROM 仅适配 !right_device! ，但你的设备是 !DeviceCode!"  REM Mismatch message in Chinese
    set "disabled_avb_verification=已禁用 Avb2.0 校验"  REM Message about AVB verification in Chinese
    set "exit_program={04}{\n}[4] {01}退出程序{#}{#}{\n}"  REM Exit program message in Chinese
    set "execution_completed=执行完成，等待自动重启"  REM Execution completed message in Chinese
    set "failure_status=因为某些原因，未能刷入"  REM Flash failure message in Chinese
    set "fastboot_mode={06}当前所处状态：Fastboot 模式{\n}"  REM Current status for Fastboot mode in Chinese
    set "fastbootd_mode={06}当前所处状态：Fastbootd 模式{\n}"  REM Current status for Fastbootd mode in Chinese
    set "format_data_flash={04}{\n}[2] {01}格式化用户数据并刷入{#}{#}{\n}"  REM Format data flash message in Chinese
    set "formatting_data=正在格式化 DATA"  REM Formatting data message in Chinese
    set "keep_data_flash={04}{\n}[1] {01}保留全部数据并刷入{#}{#}{\n}"  REM Keep data flash message in Chinese
    set "kept_data_reboot=已保留全部数据，准备重启！"  REM All data kept message in Chinese
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"  REM Title in Chinese
    set "retry_message=重试..."  REM Retry message in Chinese
    set "select_project={02}请选择你要操作的项目：{\n}{\n}"  REM Project selection message in Chinese
    set "success_status=刷入成功"  REM Success message in Chinese
    set "switch_to_fastboot={04}{\n}[3] {01}切换到 Fastboot 模式{#}{#}{\n}"  REM Switch to Fastboot message in Chinese
    set "switch_to_fastbootd={04}{\n}[3] {01}切换到 Fastbootd 模式{#}{#}{\n}"  REM Switch to Fastbootd message in Chinese
    set "title=盾牌座 UY 线刷工具"  REM Title in Chinese
    set "waiting_device={0D}————  正在等待设备  ————{#}{\n}{\n}"  REM Waiting for device message in Chinese
) else (
    set "confirm_switch={08}{\n}Are you sure you want to perform this operation?{\n}{\n}If sure, please enter 'sure', otherwise, enter anything to exit：{\n}{\n}"  REM Confirmation message in English
    set "device_mismatch_msg=This ROM is only compatible with !right_device! , but your device is !DeviceCode!"  REM Mismatch message in English
    set "disabled_avb_verification=Avb2.0 verification has been disabled"  REM Message about AVB verification in English
    set "exit_program={04}{\n}[4] {01}Exit program{#}{#}{\n}"  REM Exit program message in English
    set "execution_completed=Execution completed, waiting for automatic reboot"  REM Execution completed message in English
    set "failure_status=Flash failed"  REM Flash failure message in English
    set "fastboot_mode={06}Current status: Fastboot mode{\n}"  REM Current status for Fastboot mode in English
    set "fastbootd_mode={06}Current status: Fastbootd mode{\n}"  REM Current status for Fastbootd mode in English
    set "format_data_flash={04}{\n}[2] {01}Format user data and flash{#}{#}{\n}"  REM Format data flash message in English
    set "formatting_data=Formatting DATA"  REM Formatting data message in English
    set "keep_data_flash={04}{\n}[1] {01}Keep all data and flash{#}{#}{\n}"  REM Keep data flash message in English
    set "kept_data_reboot=All data has been kept, ready to reboot!"  REM All data kept message in English
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"  REM Title in English
    set "retry_message=Retry..."  REM Retry message in English
    set "select_project={02}Please select the project you want to operate：{\n}{\n}"  REM Project selection message in English
    set "success_status=Flash successful"  REM Success message in English
    set "switch_to_fastboot={04}{\n}[3] {01}Switch to Fastboot mode{#}{#}{\n}"  REM Switch to Fastboot message in English
    set "switch_to_fastbootd={04}{\n}[3] {01}Switch to Fastbootd mode{#}{#}{\n}"  REM Switch to Fastbootd message in English
    set "title=UY Scuti Flash Tool"  REM Title in English
    set "waiting_device={0D}————  Waiting for device  ————{#}{\n}{\n}"  REM Waiting for device message in English
)

title !title!  REM Set the window title

echo.  REM Print a blank line
cho !waiting_device!  REM Display the waiting message for device

REM Get the device model code using Fastboot
for /f "tokens=2" %%a in ('fastboot getvar product 2^>^&1^|find "product"') do (
    set DeviceCode=%%a  REM Set DeviceCode variable to the device model retrieved
)

REM Get the slot count for dynamic partitions
for /f "tokens=2" %%a in ('fastboot getvar slot-count 2^>^&1^|find "slot-count" ') do (
    set DynamicPartitionType=%%a  REM Set DynamicPartitionType variable based on the output
)

REM Determine the type of partitioning based on slot count
if "!DynamicPartitionType!" == "2" (
    set DynamicPartitionType=NonOnlyA  REM Set for devices with dual slots
) else (
    set DynamicPartitionType=OnlyA  REM Set for devices with a single slot
)

REM Get the Fastboot state to determine the current mode
for /f "tokens=2" %%a in ('fastboot getvar is-userspace 2^>^&1^|find "is-userspace"') do (
    set FastbootState=%%a  REM Set FastbootState variable based on the output
)

REM Set FastbootState variable to the appropriate mode
if "!FastbootState!" == "yes" (
    set FastbootState=!fastbootd_mode!  REM Set to fastbootd mode if applicable
) else (
    set FastbootState=!fastboot_mode!  REM Set to fastboot mode otherwise
)

cls  REM Clear the console

echo.  REM Print a blank line
if not "!DeviceCode!"=="!right_device!" (
    cho !device_mismatch_msg!  REM Show device mismatch message if the device does not match
    PAUSE  REM Wait for user input before exiting
    GOTO :EOF  REM End of file
)

cls  REM Clear the console again if no mismatch
cho {F9}                                                {\n}
cho !one_title!  REM Display the title
cho {F9}                                                {\n}{\n}
cho !FastbootState!  REM Show the current Fastboot state
cho !keep_data_flash!  REM Show option to keep data
cho !format_data_flash!  REM Show option to format data
if "!FastbootState!" == "!fastbootd_mode!" (
    cho !switch_to_fastboot!  REM Provide option to switch to Fastboot mode
) else (
    cho !switch_to_fastbootd!  REM Provide option to switch to Fastbootd mode
)
cho !exit_program!  REM Show exit program option
echo.

cho !select_project!  REM Prompt user to select a project
set /p UserChoice=  REM Capture user input for choice
if "!UserChoice!" == "1" (
    set SelectedOption=1  REM Set the selected option for keeping data
    goto FLASH  REM Jump to the FLASH section
) else if "!UserChoice!" == "2" (
    set SelectedOption=2  REM Set the selected option for formatting data
    goto FLASH  REM Jump to FLASH section
) else if "!UserChoice!" == "3" (
    cho !confirm_switch!  REM Show confirmation prompt for switching modes
    set /p Confirmation=  REM Capture user input for confirmation
    if /I "!Confirmation!" == "sure" (
        if "!FastbootState!" == "!fastbootd_mode!" (
            cls  REM Clear the console
            echo.
            fastboot reboot bootloader  REM Reboot into bootloader from fastbootd
        ) else (
            cls  REM Clear the console
            echo.
            fastboot reboot fastboot  REM Reboot into fastboot mode
        )
    )
    goto HOME  REM Return to the main menu
) else if "!UserChoice!" == "4" (
    exit  REM Exit the program if option 4 is selected
)
goto HOME&pause  REM Return to the main menu and pause

:FLASH  REM Flash section for executing the flashing process
cls 
echo.

set "count=0"  REM Initialize count for vbmeta flashing
for /R "images\" %%i in (*.img) do (
    echo %%~ni | findstr /B "vbmeta" >nul && (
        if "!DynamicPartitionType!"=="OnlyA" (
            fastboot --disable-verity --disable-verification flash "%%~ni" "%%i"  REM Flash vbmeta for single-slot
        ) else (
            fastboot --disable-verity --disable-verification flash "%%~ni_a" "%%i"  REM Flash vbmeta for slot A
            fastboot --disable-verity --disable-verification flash "%%~ni_b" "%%i"  REM Flash vbmeta for slot B
        )
        set /a "count+=1"  REM Increment count of vbmeta flashes
    )
)

if !count! gtr 0 (
    echo !disabled_avb_verification!  REM Notify AVB verification has been disabled
    echo.
)

REM Loop through all .img files to flash each partition
for /f "delims=" %%b in ('dir /b images\*.img ^| findstr /v /i "super.img" ^| findstr /v /i "cust.img" ^| findstr /v /i /b "vbmeta"') do (
    set "filename=%%~nb"  REM Set the file name without extension
    if "!DynamicPartitionType!"=="OnlyA" (
        fastboot flash "%%~nb" "images\%%~nxb"  REM Flash for single-slot devices
        if "!errorlevel!"=="0" (
            echo !filename!: !success_status!  REM Notify success
            echo.
        ) else (
            echo !filename!: !failure_status!  REM Notify failure
            echo.
        )
    ) else (
        fastboot flash "%%~nb_a" "images\%%~nxb"  REM Flash for slot A
        if "!errorlevel!"=="0" (
            echo !filename!_a: !success_status!  REM Notify success for slot A
        ) else (
            echo !filename!_a: !failure_status!  REM Notify failure for slot A
        )
        fastboot flash "%%~nb_b" "images\%%~nxb"  REM Flash for slot B
        if "!errorlevel!"=="0" (
            echo !filename!_b: !success_status!  REM Notify success for slot B
            echo.
        ) else (
            echo !filename!_b: !failure_status!  REM Notify failure for slot B
            echo.
        )
    )
)

if exist images\cust.img (
    fastboot flash cust "images\cust.img"  REM Flash cust image if exists
    echo.
)

if exist images\super.img (
    fastboot erase super  REM Erase super partition if exists
    fastboot flash super "images\super.img"  REM Flash super partition
    echo.
)

if "!SelectedOption!" == "1" (
    echo !kept_data_reboot!  REM Notify user that data will be kept and ready to reboot
) else if "!SelectedOption!" == "2" (
    echo !formatting_data!  REM Notify user that data is being formatted
    fastboot erase userdata  REM Erase user data partition
    fastboot erase metadata  REM Erase metadata partition
    fastboot erase frp  REM Erase frp partition to avoid installation issues
)

if "!DynamicPartitionType!" == "NonOnlyA" (
    fastboot set_active a %sg%  REM Set active slot for dynamic partition setups
)

fastboot reboot  REM Reboot the device
echo.
echo !execution_completed!  REM Notify user that execution has completed
pause  REM Wait for user input before closing
exit  REM Exit the script
