# 盾牌座 UY 
**| [English](README_EN.md) | 简体中文 |**

该工具的目的是为了解决解包，打包，修改 img 麻烦的问题\
使用该工具在 WSL2 和 Ubuntu 测试均可使用，安装所需要的包：

**sudo apt update** \
**sudo apt install lz4 python3 default-jdk device-tree-compiler**


其它 Linux 内核系统待测试，推测都能正常工作，为工具给予权限：

**chmod 777 -R ./***

然后即可启动工具，只需输入：

**./start.sh**

**该工具仅支援 img 格式的分区文件、常规的 ZIP 刷入包、三星的 TAR 刷入包、lz4 文件提取以及 payload.bin 的提取，老版本的其它格式的分区文件不支援，也不会支援\
首次使用该工具，你一定要仔细阅读下面的说明，如果你不仔细阅读而提出在说明中有表述的内容，我会无视**

----

主菜单

> 选择工作域：选中一个工作域，选中后，后续的操作都将基于该工作域的路径

>建立工作域：建立一个工作域，任意命名，允许空格和中文，工作域的作用是限制使用范围

> 删除工作域：删除一个工作域

> 更改语言设置：支持简体中文与英文切换

> 退出程序

----

工作域菜单

> 分区文件提取：支持 EROFS、EXT、F2FS、VBMETA、DTBO、BOOT、PAYLOAD、SUPER、SPARSE、TAR、ZIP、LZ4 标识的文件提取。按 ALL 即可提取所有，按 S 即可启动简易识别，简易识别的作用在通常情况下自动识别 super 和它的子分区。还会识别 optics.img 和 vbmeta 文件，提取分区文件列表只会展示可识别的分区，支持小米与一加的 super 识别。

> 分区文件打包：打包提取后的分区文件，如果原本标识是 EROFS、EXT、F2FS，则打包后需要选择打包的格式，可选 EROFS、EXT、F2FS 打包格式，原本标识为支持格式中的其它，则无需选择，自动识别。

> SUPER 分区打包：将打包的子分区文件放置到工作域目录的 Extracted-files/super 文件夹（如果你打包了 super 子分区，那么打包前会显示自动移动功能），然后使用该功能，动态分区类型要保持与原来的一致，你需要了解你的设备的动态分区类型，而是否选择稀疏格式，这个取决于 ROM 是否支持。

> 一键修改：内置快速修改方案，修改前必须对分区进行提取，本工具逻辑是修改提取后的文件，而不是修补镜像，比如 vbmeta.img 提取后才能修改成功。

> 构建刷机包：使用新的“轻松移动”功能来快速移动已打包的分区到 Ready-to-flash/images 目录，支持分卷与完整包压缩，大小自定义，机型代码需要严格遵守你的使用的机型，避免冲突，而默认打包名与工作域名称一致，脚本默认禁用 AVB2.0 校验，在新机型必须修改。

> 返回主菜单

> 退出程序

<br>
<br>
<br>
<br>
<br>
<br>

---

## 一键修改介绍（仅关键功能）

1. **快速替换**  
   - 功能说明：该功能允许你快速替换系统分区中的任意文件或文件夹。你需要找到 `use-replace` 目录，并按以下步骤操作：
     - 将要替换的文件（或文件夹）放入对应的分组文件夹中。
     - 每个文件夹对应一个分组，工具会根据分组自动进行替换。
     - 由于 apktool 无法正确处理 android 15 开始的 apk（会导致开机不识别），你需要使用 MT 管理器手动修改 APK 后，将其放置到相应的分组中。
     - 该功能的逻辑修改旨在便于快速替换多个 ROM 的内容。

2. **HyperOS / ONEUI 添加**  
   - 功能说明：该功能允许你将 APK 文件添加到指定的分区目录。根据所用的系统不同，操作方式如下：
   
   **HyperOS 添加到 Product 分区**  
   - 路径：`resources/my_tools/nice_rom/bin/xiaomi/add_for_product`
   - 该目录下有 `app`、`data-app` 和 `priv-app` 等子目录。
   - 你可以将 APK 文件添加到这些目录中的任意位置，只需按照命名规则操作：
     - 例如：如果你想将 `1.apk` 添加到 `product/app` 目录：
       - 创建 `resources/my_tools/nice_rom/bin/xiaomi/add_for_product/app/1` 目录。
       - 将 `1.apk` 放入 `1` 目录中。
     - 该功能会将 APK 文件添加到目标目录。
     - **注意**：该功能仅适用于 Product 分区，且 `data-app` 目录中的 APK 文件是可卸载的。

   **ONEUI 添加到 System 分区**  
   - 操作与 HyperOS 类似，但该功能适用于三星设备的 System 分区。
   - 对于三星设备，卸载的 APK 文件会被放置到 `preload` 目录中。

<br>
<br>
<br>
<br>
<br>
<br>

## HyperOS 修改教程
1. 创建一个新的工作域并立即选中它。
2. 将 Rom 包或者分区文件移动到工作域目录当中，你需要提取一次。
3. 使用简易识别自动筛选出 SUPER 子分区，但是使用该功能前，确保所有 IMG 格式的文件已被提取，然后再使用全部提取进一步提取分区文件的内容。
4. 使用一键修改，注意：如果你要使用保留原始签名的修改 APK，那么你必须使用移除未签名验证的修改，否则在 Android 13 不会加载（谷歌的改动）。如果你要在小米 14 及之后的机型正确开机，必须移除 AVB2.0 验证，移除前，提取 vbmeta 相关的 IMG，含相关关键词的都是。
5. 打包所有提取的分区文件，打包的文件系统取决于你的内核。
6. 将打包的子分区移动到选中工作域 Extracted-files/super 里面。
7. 使用 SUPER 打包功能，保证打包的动态分区与你的设备一致，大小会自动计算，根据提示来选择。
8. 将打包好的 SUPER 分区移动到选中工作域的 Ready-to-flash/images 目录，注意“简易识别”已自动将其它分区移动到这！
9. 使用 Fastboot(d) 打包功能，这样一个修改的 ROM 制作完成。

## OneUI 修改教程
1. 创建一个新的工作域并立即选中它。
2. 将 Rom 包或者分区文件移动到工作域目录当中，你需要提取一次。
3. 使用简易识别自动筛选出 SUPER 子分区，但是使用该功能前，确保所有 IMG 格式的文件已被提取，然后再使用全部提取进一步提取分区文件的内容。
4. 使用一键修改，注意：如果你要使用保留原始签名的修改 APK，那么你必须使用移除未签名验证的修改，否则在 Android 13 不会加载（谷歌的改动）。移除前，提取 vbmeta 相关的 IMG，移除 vbmeta 验证是必要的。
5. 打包所有提取的分区文件：打包的文件系统取决于你的内核。
6. 将打包的子分区移动到选中工作域 Extracted-files/super 里面。
7. 使用 SUPER 打包功能：对于三星设备，打包的 SUPER 分区文件必须保持和官方大小一致。
8. 将打包好的 SUPER 分区移动到选中工作域的 Ready-to-flash/images 目录，注意“简易识别”已自动将其它分区移动到这！
9. 使用 Odin Rom 打包功能：这样一个修改的三星 ROM 制作完成，但是能不能开机需要测试。

## ColorOS 修改教程
1. 创建一个新的工作域并立即选中它。
2. 将 Rom 包或者分区文件移动到工作域目录当中，你需要提取一次。
3. 使用简易识别自动筛选出 SUPER 子分区，但是使用该功能前，确保所有 IMG 格式的文件已被提取，然后再使用全部提取进一步提取分区文件的内容。
4. 使用一键修改，注意：如果你要使用保留原始签名的修改 APK，那么你必须使用移除未签名验证的修改，否则在 Android 13 不会加载（谷歌的改动）。移除前，提取 vbmeta 相关的 IMG，移除 vbmeta 验证是必要的。
5. 打包所有提取的分区文件：打包的文件系统取决于你的内核。
6. 将打包的子分区移动到选中工作域 Extracted-files/super 里面。
7. 使用 SUPER 打包功能
8. 将打包好的 SUPER 分区移动到选中工作域的 Ready-to-flash/images 目录，注意“简易识别”已自动将其它分区移动到这！
9. 使用 Odin Rom 打包功能：这样一个修改的 ColorOS ROM 制作完成，但是能不能开机需要测试。

<br><br><br>

---

# 感谢 

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - 魔数参考。
2. [**ext4**](https://github.com/cubinator/ext4) ext 镜像配置文件提取。
3. [**android-tools**](https://github.com/nmeum/android-tools) - 提供了丰富的 Android 工具集。
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - vbmeta、boot、vendor_boot 的提取与打包。
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - f2fs 文件提取。
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - payload.bin 文件提取。
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-utils) - erofs 文件提取。
8. [**7zip**](https://github.com/ip7z/7zip/releases) - super 分区提取及 Rom 包打包。
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - 反编译。
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - 三星 CSC 编码与解码。
