# UY Scuti
**| [English](README_EN.md) | 简体中文 |**

The purpose of this tool is to solve the troublesome issues of unpacking, packing, and modifying img files.\
This tool has been tested and works well on WSL2 and Ubuntu. The required packages for installation are:

**sudo apt update** \
**sudo apt install lz4 python3 default-jdk device-tree-compiler**

Other Linux kernel systems are yet to be tested but are presumed to work normally. To grant permissions to the tool:

**chmod 777 -R ./***

Then you can start the tool by simply entering:

**./start.sh**

**This tool only supports img format partition files, regular ZIP flashing packages, Samsung TAR flashing packages, lz4 file extraction, and payload.bin extraction. Older versions of other partition file formats are not supported and will not be supported.\
If you are using this tool for the first time, you must carefully read the instructions below. If you do not read carefully and raise issues that are addressed in the instructions, I will ignore them.**

----

## Main Menu

> Select Working Domain: Choose a working domain, and subsequent operations will be based on the path of the selected domain.

> Create Working Domain: Create a working domain with any name, allowing spaces and Chinese characters. The purpose of the working domain is to limit the scope of use.

> Delete Working Domain: Delete a working domain.

> Change Language Settings: Supports switching between Simplified Chinese and English.

> Exit Program

----

## Working Domain Menu

> Partition File Extraction: Supports extraction of files marked as EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE, TAR, ZIP, and LZ4. Press ALL to extract all, or press S to start simple recognition, which automatically identifies super and its sub-partitions. If it is a Samsung ROM, it will also recognize optics.img and vbmeta files, depending on whether optics.img exists in the working domain directory. The extracted partition file list will only display recognizable partitions. If you find that the partition files you placed do not show up, it means the tool does not support recognizing that partition file. It supports recognition for Xiaomi and OnePlus super.

> Partition File Packing: Pack the extracted partition files. If the original identifier is EROFS, EXT, or F2FS, you need to select the packing format, which can be EROFS, EXT, or F2FS. If the original identifier is among the supported formats, no selection is needed; it will be automatically recognized.

> SUPER Partition Packing: Place the packed sub-partition files into the Extracted-files/super folder in the working domain directory (if you packed super sub-partitions, the automatic move function will be displayed before packing). Then use this function, ensuring the dynamic partition type remains consistent with the original. You need to understand the dynamic partition type of your device, and whether to choose sparse format depends on whether the ROM supports it.

> One-Click Modification: Built-in quick modification solutions for HyperOS and OneUI.

> Build Flashing Package: Use the new "Easy Move" function to quickly move the packed partitions to the Ready-to-flash/images directory. Supports volume and complete package compression, with customizable sizes. The device code must strictly adhere to the model you are using to avoid conflicts. The default package name is consistent with the working domain name. This flashing package is a line flashing package, and the script disables AVB2.0 verification by default, so no additional modifications are needed.

> Return to Main Menu

> Exit Program

<br>
<br>
<br>
<br>
<br>
<br>

---

## One-Click Modification Introduction (Key Features Only)

1. **Quick Replace**  
   - Function Description: This feature allows you to quickly replace any file or folder in the system partition. You need to find the `resources/my_tools/nice_rom/quick-replace` directory and follow these steps:
     - Place the files (or folders) to be replaced into the corresponding group folder.
     - Each folder corresponds to a group, and the tool will automatically replace based on the group.
     - Since apktool cannot correctly handle APKs starting from Android 15 (which can cause boot recognition issues), you need to manually modify the APK using MT Manager and place it in the corresponding group.
     - The logic of this feature is designed to facilitate quick replacement of content across multiple ROMs.

2. **Add HyperOS / ONEUI**  
   - Function Description: This feature allows you to add APK files to the specified partition directory. The operation method varies depending on the system used:
   
   **Add HyperOS to Product Partition**  
   - Path: `resources/my_tools/nice_rom/bin/xiaomi/add_for_product`
   - This directory contains subdirectories such as `app`, `data-app`, and `priv-app`.
   - You can add APK files to any of these directories by following the naming rules:
     - For example, if you want to add `1.apk` to the `product/app` directory:
       - Create the directory `resources/my_tools/nice_rom/bin/xiaomi/add_for_product/app/1`.
       - Place `1.apk` into the `1` directory.
     - This feature will add the APK file to the target directory.
     - **Note**: This feature is only applicable to the Product partition, and APK files in the `data-app` directory are uninstallable.

   **Add ONEUI to System Partition**  
   - The operation is similar to HyperOS, but this feature is applicable to the System partition of Samsung devices.
   - For Samsung devices, uninstallable APK files will be placed in the `preload` directory.

3. **Add ONEUI Features**  
   - Function Description: This feature needs to be used after extracting the contents of the `optics.img` partition.
   - Operation Method: Add Samsung ONEUI features by automatically decoding the CSC file.
   - Operation Path: `resources/my_tools/nice_rom/bin/samsung/csc_add/csc_features_need`
   - Place the features you wish to add into this directory.

---

<br>
<br>
<br>
<br>
<br>
<br>

## HyperOS Modification Tutorial (Tested)
1. Create a new working domain and select it immediately.
2. Move the ROM package or partition files into the working domain directory; you need to extract them once.
3. Use simple recognition to automatically filter out SUPER sub-partitions, but before using this function, ensure that all IMG format files have been extracted, and then use all extraction to further extract the contents of the partition files.
4. Use one-click modification. Note: If you want to use a modified APK that retains the original signature, you must use the modification that removes unsigned verification; otherwise, it will not load on Android 13 (due to Google's changes). If you want to boot correctly on Xiaomi 14 and later models, you must remove AVB2.0 verification. Before removal, extract the vbmeta-related IMG, including all related keywords.
5. Pack all extracted partition files; the packing file system depends on your kernel.
6. Move the packed sub-partitions into the selected working domain's Extracted-files/super directory.
7. Use the SUPER packing function, ensuring the packed dynamic partition is consistent with your device; the size will be automatically calculated based on prompts.
8. Move the packed SUPER partition to the selected working domain's Ready-to-flash/images directory. Note that "simple recognition" has automatically moved other partitions to this location!
9. Use the Fastboot(d) packing function to complete the modification of the ROM.

## OneUI Modification Tutorial (Untested)
1. Create a new working domain and select it immediately.
2. Move the ROM package or partition files into the working domain directory; you need to extract them once.
3. Use simple recognition to automatically filter out SUPER sub-partitions, but before using this function, ensure that all IMG format files have been extracted, and then use all extraction to further extract the contents of the partition files.
4. Use one-click modification. Note: If you want to use a modified APK that retains the original signature, you must use the modification that removes unsigned verification; otherwise, it will not load on Android 13 (due to Google's changes). Before removal, extract the vbmeta-related IMG; removing vbmeta verification is necessary.
5. Pack all extracted partition files; the packing file system depends on your kernel.
6. Move the packed sub-partitions into the selected working domain's Extracted-files/super directory.
7. Use the SUPER packing function; for Samsung devices, the packed SUPER partition file must maintain the same size as the official version.
8. Move the packed SUPER partition to the selected working domain's Ready-to-flash/images directory. Note that "simple recognition" has automatically moved other partitions to this location!
9. Use the Odin ROM packing function to complete the modification of the Samsung ROM, but whether it can boot needs to be tested.

<br><br><br>

---

# Thanks

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - Magic number reference.
2. [**ext4**](https://github.com/cubinator/ext4) - ext image configuration files and file extraction.
3. [**android-tools**](https://github.com/nmeum/android-tools) - Provides a rich set of Android tools.
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - Extraction and packing of vbmeta, boot, and vendor_boot.
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - f2fs file extraction.
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - payload.bin file extraction.
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-utils) - erofs file extraction.
8. [**7zip**](https://github.com/ip7z/7zip/releases) - super partition extraction and ROM package packing.
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - Decompilation.
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - Samsung CSC encoding and decoding.

