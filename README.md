# UY Scuti
**| [English](README_EN.md) | Simplified Chinese |**

The purpose of this tool is to solve the hassle of unpacking, packing, and modifying img files.\
This tool can be used on WSL2 and Ubuntu. The required packages for installation are:

**sudo apt update** \
**sudo apt install lz4 python3 default-jdk device-tree-compiler**

Other Linux kernel systems are yet to be tested, but it is presumed to work normally. To grant permissions to the tool:

**chmod 777 -R ./***

Then you can start the tool by simply entering:

**./start.sh**

**This tool only supports img format partition files, regular ZIP flashing packages, Samsung TAR flashing packages, lz4 file extraction, and payload.bin extraction. It does not support older versions of other format partition files and will not in the future.\
If you are using this tool for the first time, you must read the instructions below carefully. If you do not read carefully and raise issues that are addressed in the instructions, I will ignore them.**

----

## Main Menu

> **Select Workspace:** Choose a workspace; subsequent operations will be based on the path of the selected workspace.

> **Create Workspace:** Create a workspace with any name, allowing spaces and Chinese characters. The purpose of the workspace is to limit the scope of use.

> **Delete Workspace:** Delete a workspace.

> **Change Language Settings:** Supports switching between Simplified Chinese and English.

> **Exit Program**

----

## Workspace Menu

> **Partition File Extraction:** Supports extraction of files marked with EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE, TAR, ZIP, LZ4. Press ALL to extract all, or S to start simple recognition, which automatically identifies super and its sub-partitions under normal circumstances. It will also recognize optics.img and vbmeta files. The extracted partition file list will only display recognizable partitions, supporting Xiaomi and OnePlus super recognition.

> **Partition File Packing:** Pack the extracted partition files. If the original format is EROFS, EXT, or F2FS, you will need to choose the packing format; options are EROFS, EXT, or F2FS. If the original format is one of the supported formats, it will be automatically recognized.

> **SUPER Partition Packing:** Place the packed sub-partition files into the Extracted-files/super folder of the workspace directory (if you packed the super sub-partition, an automatic move function will be displayed before packing). The dynamic partition type must remain consistent with the original; you need to understand the dynamic partition type of your device. Whether to choose sparse format depends on whether the ROM supports it.

> **One-click Modification:** Built-in quick modification scheme. The partition must be extracted before modification. This tool's logic modifies the extracted files, not patches the image. For example, vbmeta.img must be extracted before modification can succeed.

> **Build Flash Package:** Use the new "Easy Move" function to quickly move packed partitions to the Ready-to-flash/images directory. Supports volume and full package compression, size customization. The device model code must strictly adhere to the model you are using to avoid conflicts. The default packing name is consistent with the workspace name, and the script disables AVB2.0 verification by default, which must be modified for new models.

> **Return to Main Menu**

> **Exit Program**

<br>
<br>
<br>
<br>
<br>
<br>

---

## One-click Modification Introduction (Key Functions Only)

1. **Quick Replace**  
   - **Function Description:** This feature allows you to quickly replace any file or folder in the system partition. You need to find the `use-replace` directory and follow these steps:
     - Place the file (or folder) you want to replace into the corresponding group folder.
     - Each folder corresponds to a group, and the tool will automatically replace based on the group.
     - Since apktool cannot correctly handle APKs starting from Android 15 (which can cause boot issues), you need to manually modify the APK using MT Manager and place it in the corresponding group.
     - The logic of this feature is designed to facilitate quick replacements of content across multiple ROMs.

2. **HyperOS / ONEUI Addition**  
   - **Function Description:** This feature allows you to add APK files to specified partition directories. The operation varies based on the system used:
   
   **HyperOS Adding to Product Partition**  
   - **Path:** `resources/my_tools/nice_rom/bin/xiaomi/add_for_product`
   - This directory contains subdirectories such as `app`, `data-app`, and `priv-app`.
   - You can add APK files to any location in these directories by following the naming rules:
     - For example, if you want to add `1.apk` to the `product/app` directory:
       - Create the directory `resources/my_tools/nice_rom/bin/xiaomi/add_for_product/app/1`.
       - Place `1.apk` in the `1` directory.
     - This feature will add the APK file to the target directory.
     - **Note:** This feature is only applicable to the Product partition, and APK files in the `data-app` directory are uninstallable.

   **ONEUI Adding to System Partition**  
   - The operation is similar to HyperOS but applies to the System partition of Samsung devices.
   - For Samsung devices, uninstalled APK files will be placed in the `preload` directory.

<br>
<br>
<br>
<br>
<br>
<br>

## HyperOS Modification Tutorial
1. Create a new workspace and immediately select it.
2. Move the ROM package or partition file into the workspace directory; you need to extract it once.
3. Use simple recognition to automatically filter out SUPER sub-partitions. However, before using this feature, ensure that all IMG format files have been extracted, and then use full extraction to further extract the contents of the partition files.
4. Use one-click modification. Note: If you want to use modified APKs while retaining the original signature, you must remove the unsigned verification modification; otherwise, it will not load on Android 13 (due to Google's changes). If you want to boot correctly on Xiaomi 14 and later models, you must remove AVB2.0 verification. Extract vbmeta-related IMGs, including those with relevant keywords, before removing.
5. Pack all extracted partition files. The packing file system depends on your kernel.
6. Move the packed sub-partitions to the selected workspace's Extracted-files/super directory.
7. Use the SUPER packing feature, ensuring that the packed dynamic partition matches your device. The size will be automatically calculated; follow the prompts to choose.
8. Move the packed SUPER partition to the Ready-to-flash/images directory of the selected workspace. Note that "Easy Recognition" has automatically moved other partitions here!
9. Use the Fastboot(d) packing feature to complete the creation of a modified ROM.

## OneUI Modification Tutorial
1. Create a new workspace and immediately select it.
2. Move the ROM package or partition file into the workspace directory; you need to extract it once.
3. Use simple recognition to automatically filter out SUPER sub-partitions. However, before using this feature, ensure that all IMG format files have been extracted, and then use full extraction to further extract the contents of the partition files.
4. Use one-click modification. Note: If you want to use modified APKs while retaining the original signature, you must remove the unsigned verification modification; otherwise, it will not load on Android 13 (due to Google's changes). Extract vbmeta-related IMGs, as removing vbmeta verification is necessary.
5. Pack all extracted partition files: the packing file system depends on your kernel.
6. Move the packed sub-partitions to the selected workspace's Extracted-files/super directory.
7. Use the SUPER packing feature: for Samsung devices, the packed SUPER partition file must maintain the same size as the official one.
8. Move the packed SUPER partition to the Ready-to-flash/images directory of the selected workspace. Note that "Easy Recognition" has automatically moved other partitions here!
9. Use the Odin ROM packing feature: this completes the creation of a modified Samsung ROM, but whether it can boot needs to be tested.

## ColorOS Modification Tutorial
1. Create a new workspace and immediately select it.
2. Move the ROM package or partition file into the workspace directory; you need to extract it once.
3. Use simple recognition to automatically filter out SUPER sub-partitions. However, before using this feature, ensure that all IMG format files have been extracted, and then use full extraction to further extract the contents of the partition files.
4. Use one-click modification. Note: If you want to use modified APKs while retaining the original signature, you must remove the unsigned verification modification; otherwise, it will not load on Android 13 (due to Google's changes). Extract vbmeta-related IMGs, as removing vbmeta verification is necessary.
5. Pack all extracted partition files: the packing file system depends on your kernel.
6. Move the packed sub-partitions to the selected workspace's Extracted-files/super directory.
7. Use the SUPER packing feature.
8. Move the packed SUPER partition to the Ready-to-flash/images directory of the selected workspace. Note that "Easy Recognition" has automatically moved other partitions here!
9. Use the Odin ROM packing feature: this completes the creation of a modified ColorOS ROM, but whether it can boot needs to be tested.

<br><br><br>

---

# Thanks 

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - Magic number reference.
2. [**ext4**](https://github.com/cubinator/ext4) - Extracting ext image configuration files.
3. [**android-tools**](https://github.com/nmeum/android-tools) - Provides a rich set of Android tools.
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - Extraction and packing of vbmeta, boot, vendor_boot.
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - f2fs file extraction.
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - payload.bin file extraction.
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-utils) - erofs file extraction.
8. [**7zip**](https://github.com/ip7z/7zip/releases) - Extraction of super partitions and packaging of ROM packages.
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - Decompilation.
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - Samsung CSC encoding and decoding.

