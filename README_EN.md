# Shield Base UY 
**| [English](README_EN.md) | 简体中文 |**

The purpose of this tool is to address the cumbersome issues of unpacking, packing, and modifying IMG files.\
This tool can be used in WSL2 and Ubuntu, and the required packages for installation are:

**sudo apt update** \
**sudo apt install lz4 python3 default-jdk device-tree-compiler**

Other Linux kernel systems are yet to be tested, but it is presumed that they will work normally. To grant permissions to the tool:

**chmod 777 -R ./***

You can then start the tool by simply entering:

**./start.sh**

**This tool only supports IMG format partition files, regular ZIP flashing packages, Samsung TAR flashing packages, LZ4 file extraction, and payload.bin extraction. Older versions of other format partition files are not supported and will not be supported.\
When using this tool for the first time, you must carefully read the instructions below. If you ask about content that is stated in the instructions without reading them carefully, I will ignore it.**

----

## Main Menu

> **Select Working Domain:** Choose a working domain; subsequent operations will be based on the path of the selected working domain.

> **Create Working Domain:** Create a working domain with any name, allowing spaces and Chinese characters. The purpose of the working domain is to limit the scope of use.

> **Delete Working Domain:** Delete a working domain.

> **Change Language Settings:** Support switching between Simplified Chinese and English.

> **Exit Program**

----

## Working Domain Menu

> **Partition File Extraction:** Supports the extraction of files marked with EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE, TAR, ZIP, LZ4. Press ALL to extract all, or press S to start a simplified identification, which automatically recognizes SUPER and its sub-partitions under normal circumstances. If it is a Samsung ROM, it will also recognize optics.img and vbmeta files, depending on whether optics.img exists in the working domain directory. The extracted partition file list will only display recognizable partitions. If you find that the partition files you placed do not display, it indicates that the tool does not support the recognition of that partition file. This implementation is necessary because displaying unsupported files in the list is meaningless. It supports recognition of SUPER for Xiaomi and OnePlus.

> **Partition File Packing:** Pack the extracted partition files. If the original designation is EROFS, EXT, or F2FS, you will need to choose the packing format after packing. Options include EROFS, EXT, F2FS packing formats. If the original designation is among the supported formats, no selection is required, and it will be automatically recognized.

> **SUPER Partition Packing:** Place the packed sub-partition files into the Extracted-files/super folder in the working domain directory (if you packed SUPER sub-partitions, an automatic move function will be displayed before packing). Then use this function; the dynamic partition type must remain consistent with the original. You need to understand the dynamic partition type of your device, and whether to choose sparse format depends on whether the ROM supports it.

> **One-Click Modification:** Built-in quick modification solutions for HyperOS and OneUI.

> **Build Flashing Package:** Use the new "Easy Move" feature to quickly move the packed partitions to the Ready-to-flash/images directory. Supports multi-volume and complete package compression, with customizable sizes. The device code must strictly comply with the model you are using to avoid conflicts, and the default packing name will be consistent with the working domain name. This flashing package is a line flashing package, and the script defaults to disabling AVB2.0 verification, so no additional modifications are required.

> **Return to Main Menu**

> **Exit Program**

<br>
<br>
<br>
<br>
<br>
<br>

---

## One-Click Modification Introduction (Key Functions Only)

1. **XXXX Replacement**  
   - **Function Description:** This function allows you to replace any file or folder in the system partition. You need to find the `resources/my_tools/nice_rom/bin/(samsung|xiaomi|oneplus)/replace` directory and follow these steps:
     - Suppose you extracted a file from the system partition (for example, named `1`).
     - Place this file (or folder) into the `replace` directory.
     - After using this function, the `1` file (or folder) in the `replace` directory will replace the same-named file (or folder) in the system partition.
     - **Note:** The `1` file here is just an example; you can replace any file or folder.

2. **HyperOS / ONEUI Addition**  
   - **Function Description:** This function allows you to add APK files to specified partition directories. The operation varies depending on the system used:

   **HyperOS Adding to Product Partition**  
   - **Path:** `resources/my_tools/nice_rom/bin/xiaomi/add_for_product`
   - This directory contains subdirectories such as `app`, `data-app`, and `priv-app`.
   - You can add APK files to any of these directories by following the naming rules:
     - For example: If you want to add `1.apk` to the `product/app` directory:
       - Create the directory `resources/my_tools/nice_rom/bin/xiaomi/add_for_product/app/1`.
       - Place `1.apk` into the `1` directory.
     - This function will add the APK file to the target directory.
     - **Note:** This function is only applicable to the Product partition, and APK files in the `data-app` directory are uninstallable.

   **ONEUI Adding to System Partition**  
   - The operation is similar to HyperOS, but this function is applicable to the System partition of Samsung devices.
   - For Samsung devices, uninstallable APK files will be placed in the `preload` directory.

3. **ONEUI Feature Addition**  
   - **Function Description:** This function needs to be used after extracting the contents of the `optics.img` partition.
   - **Operation Method:** Add Samsung ONEUI features by automatically decoding the CSC file.
   - **Operation Path:** `resources/my_tools/nice_rom/bin/samsung/csc_add/csc_features_need`
   - Place the features you wish to add in this directory.

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
3. Use the simplified identification to automatically filter out SUPER sub-partitions, but before using this function, ensure that all IMG format files have been extracted, then use "Extract All" to further extract the contents of the partition files.
4. Use One-Click Modification; check the prompts for what needs to be modified.
5. Pack all extracted partition files; the file system for packing depends on your kernel.
6. Move the packed sub-partitions into the selected working domain's Extracted-files/super.
7. Use the SUPER packing function, ensuring that the packed dynamic partition matches your device; the size will be automatically calculated based on the prompts.
8. Move the packed SUPER partition to the selected working domain's Ready-to-flash/images directory; note that "Simplified Identification" has automatically moved other partitions here!
9. Use the Fastboot(d) packing function, and thus a modified ROM is completed.

## OneUI Modification Tutorial (Untested)
1. Create a new working domain and select it immediately.
2. Move the ROM package or partition files into the working domain directory; you need to extract them once.
3. Use the simplified identification to automatically filter out SUPER sub-partitions, but before using this function, ensure that all IMG format files have been extracted, then use "Extract All" to further extract the contents of the partition files.
4. Use One-Click Modification: check the prompts for what needs to be modified; for Samsung, removing vbmeta verification is necessary.
5. Pack all extracted partition files; the file system for packing depends on your kernel.
6. Move the packed sub-partitions into the selected working domain's Extracted-files/super.
7. Use the SUPER packing function: for Samsung devices, the packed SUPER partition file must maintain the same size as the official version.
8. Move the packed SUPER partition to the selected working domain's Ready-to-flash/images directory; note that "Simplified Identification" has automatically moved other partitions here!
9. Use the Odin ROM packing function: thus a modified Samsung ROM is completed, but whether it can boot requires testing.

<br><br><br>

---

# Acknowledgments 

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - Reference for magic numbers.
2. [**ext4**](https://github.com/cubinator/ext4) - ext image configuration files and file extraction.
3. [**android-tools**](https://github.com/nmeum/android-tools) - Provides a rich set of Android tools.
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - Extraction and packing of vbmeta, boot, and vendor_boot.
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - f2fs file extraction.
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - payload.bin file extraction.
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-utils) - erofs file extraction.
8. [**7zip**](https://github.com/ip7z/7zip/releases) - super partition extraction and ROM package packing.
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - Decompilation.
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - Samsung CSC encoding and decoding.
