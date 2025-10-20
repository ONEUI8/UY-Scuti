#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
# 禁用 __pycache__ 目录的生成
sys.dont_write_bytecode = True

import os
import ext4
import re
import struct
import argparse
import shutil

# 如果在 Windows 系统上运行，导入必要的 ctypes 库以处理文件属性
if os.name == 'nt':
    from ctypes.wintypes import DWORD
    from stat import FILE_ATTRIBUTE_SYSTEM
    from ctypes import windll

# 存储中文文本
MESSAGES = {
    'argparse_desc': '提取 ext4 镜像，生成配置文件并提取所有内容。',
    'argparse_img_path': 'ext4 镜像文件路径',
    'argparse_cfg_dir': 'fs_config 与 file_contexts 输出目录',
    'argparse_file_dir': '文件内容提取输出目录',
    'argparse_quiet': '静默模式，无输出',
    'extracting': "\r提取中... {percent:.2f}% ({extracted_files}/{total_files})",
    'extract_complete': "\n提取完成。",
    'err_read_symlink': "读取符号链接目标 {path} 时出错: {e}",
    'err_read_dir': "读取目录 {path} 时出错: {e}",
    'err_set_attr': "为 {file_output_path} 设��属性时出错: {e}",
    'skip_special_file': "跳过特殊文件类型: {path}",
    'err_extract': "提取 {path} 时出错: {e}",
    'err_not_found': "错误: 镜像文件未找到于 {image_path}",
    'err_unexpected': "发生意外错误: {e}",
}

def get_msg(key, **kwargs):
    """获取格式化后的消息文本"""
    return MESSAGES[key].format(**kwargs)

def parse_args():
    """
    解析命令行参数。
    """
    parser = argparse.ArgumentParser(description=get_msg('argparse_desc'))
    parser.add_argument('image_path', type=str, help=get_msg('argparse_img_path'))
    parser.add_argument('config_output_dir', type=str, help=get_msg('argparse_cfg_dir'))
    parser.add_argument('file_extract_dir', type=str, help=get_msg('argparse_file_dir'))
    parser.add_argument('-q', '--quiet', action='store_true', help=get_msg('argparse_quiet'))
    return parser.parse_args()


def count_files(volume):
    """
    计算 ext4 卷中的文件总数（不包括目录）。
    :param volume: ext4.Volume 对象
    :return: 文件总数
    """
    count = 0
    stack = [(volume.root, "")]  # 使用栈进行深度优先遍历 (inode, path)
    visited = set()  # 记录已访问的路径，防止循环
    while stack:
        inode, path = stack.pop()
        if path in visited:
            continue
        visited.add(path)
        if inode.is_dir:
            for entry in inode.open_dir():
                # 忽略当前目录 '.' 和上级目录 '..'
                if entry[0] in [".", ".."]:
                    continue
                sub_inode = volume.get_inode(entry[1], entry[2])
                file_type = sub_inode.inode.i_mode & 0o170000
                # 跳过未知文件类型
                if file_type == 0:
                    continue
                # 如果是目录，则入栈继续遍历
                if file_type == 0o040000:  # S_IFDIR
                    stack.append((sub_inode, join_path(path, entry[0])))
                else:
                    count += 1
    return count


def join_path(base, entry):
    """
    安全地拼接路径。
    :param base: 基础路径
    :param entry: 要添加的路径条目
    :return: 拼接后的完整路径
    """
    return base + "/" + entry if base else "/" + entry


def extract_xattrs(inode, path, file_contexts):
    """
    从 inode 中提取扩展属性 (xattrs)，如 SELinux context 和 capabilities。
    :param inode: ext4.Inode 对象
    :param path: 文件路径
    :param file_contexts: 用于存储 SELinux contexts 的字典
    :return: capabilities 字符串
    """
    capabilities = ""
    for xattr in inode.xattrs():
        if xattr[0] == "security.selinux":
            file_contexts[path] = xattr[1]
        elif xattr[0] == "security.capability":
            # 解析 security.capability 的二进制数据
            r = struct.unpack('<5I', xattr[1])
            if r[1] > 65535:
                cap = hex(int(f'{r[3]:04x}{r[1]:04x}', 16)).upper()
            else:
                cap = hex(int(f'{r[3]:04x}{r[2]:04x}{r[1]:04x}', 16)).upper()
            capabilities = f"capabilities={cap}"
    return capabilities


def extract_volume(volume, prefix, extract_dir, quiet):
    """
    遍历 ext4 卷，提取所有文件和目录，并生成 fs_config 和 file_contexts。
    :param volume: ext4.Volume 对象
    :param prefix: 提取路径的前缀 (通常是镜像文件名)
    :param extract_dir: 文件内容提取的目标目录
    :param quiet: 是否启用静默模式
    :return: (fs_config 列表, file_contexts 字典)
    """
    fs_config = []
    file_contexts = {}
    stack = [(volume.root, "")]  # 使用栈进行深度优先遍历 (inode, path)
    visited = set()
    extracted_files = 0
    total_files = count_files(volume)

    while stack:
        inode, path = stack.pop()
        if path in visited:
            continue
        visited.add(path)

        # 提取扩展属性
        capabilities = extract_xattrs(inode, path, file_contexts)

        # 获取文件元数据
        owner = inode.inode.i_uid
        group = inode.inode.i_gid
        mode = inode.inode.i_mode & 0o777
        link_target = ""
        file_type = inode.inode.i_mode & 0o170000  # 获取文件类型

        # 跳过未知文件类型
        if file_type == 0:
            continue

        # 如果是符号链接，读取链接目标
        if file_type == 0o120000:  # S_IFLNK
            try:
                link_target = inode.open_read().read().decode('utf8')
            except Exception as e:
                if not quiet:
                    print(get_msg('err_read_symlink', path=path, e=e))

        # 记录 fs_config 条目
        fs_config.append((path, owner, group, mode, capabilities, link_target))

        if inode.is_dir:
            try:
                dir_output_path = os.path.join(extract_dir, prefix + path)
                os.makedirs(dir_output_path, exist_ok=True)
                for entry in inode.open_dir():
                    if entry[0] in [".", ".."]:
                        continue
                    full_path = join_path(path, entry[0])
                    sub_inode = volume.get_inode(entry[1], entry[2])
                    stack.append((sub_inode, full_path))
            except Exception as e:
                if not quiet:
                    print(get_msg('err_read_dir', path=path, e=e))
        else:
            file_output_path = os.path.join(extract_dir, prefix + path)
            os.makedirs(os.path.dirname(file_output_path), exist_ok=True)
            try:
                if file_type == 0o120000:  # S_IFLNK (符号链接)
                    if os.path.lexists(file_output_path):
                        os.remove(file_output_path)

                    if os.name == 'nt':
                        # 在 Windows 上创建符号链接的替代方法
                        with open(file_output_path, 'wb') as out:
                            out.write(b'!<symlink>' + link_target.encode('utf-16') + b'\x00\x00')
                        try:
                            windll.kernel32.SetFileAttributesW(file_output_path, FILE_ATTRIBUTE_SYSTEM)
                        except Exception as e:
                            if not quiet:
                                print(get_msg('err_set_attr', file_output_path=file_output_path, e=e))
                    else:
                        # 在非 Windows 系统上创建标准符号链接
                        os.symlink(link_target, file_output_path)
                    extracted_files += 1
                elif file_type == 0o100000:  # S_IFREG (普通文件)
                    data = inode.open_read().read()
                    with open(file_output_path, "wb") as out_f:
                        out_f.write(data)
                    extracted_files += 1
                else:
                    if not quiet:
                        print(get_msg('skip_special_file', path=path))
            except Exception as e:
                if not quiet:
                    print(get_msg('err_extract', path=path, e=e))

        # 打印提取进度
        if not quiet and total_files > 0:
            percent = extracted_files / total_files * 100
            print(get_msg('extracting', percent=percent, extracted_files=extracted_files, total_files=total_files), end="", flush=True)

    if not quiet:
        print(get_msg('extract_complete'))
    return fs_config, file_contexts


def write_file_contexts(path, prefix, file_contexts):
    """
    将 file_contexts 字典写入到文件。
    :param path: 输出文件路径
    :param prefix: 路径前缀
    :param file_contexts: 包含 SELinux contexts 的字典
    """
    with open(path, "w", encoding='utf-8') as f:
        sorted_contexts = sorted(file_contexts.items())

        # 找到根目录的 context
        root_context_str = None
        for p, context in sorted_contexts:
            if p == "":
                root_context_str = context.decode('utf8', errors='replace').strip().replace('\x00', '')
                break

        # 如果找到了根目录的 context，则写入
        if root_context_str:
            f.write(f"/ {root_context_str}\n")
            f.write(f"/{prefix} {root_context_str}\n")
            f.write(f"/{prefix}/ {root_context_str}\n")

        # 写入其他所有文件的 context
        for p, context in sorted_contexts:
            if p == "":
                continue
            context_str = context.decode('utf8', errors='replace').strip().replace('\x00', '')
            f.write(f"/{prefix}{re.escape(p)} {context_str}\n")


def write_fs_config(path, prefix, fs_config):
    """
    将 fs_config 列表写入到文件。
    :param path: 输出文件路径
    :param prefix: 路径前缀
    :param fs_config: 包含文件元数据的列表
    """
    root_perm = None
    # 找到根目录的权限
    for p, owner, group, mode, cap, link in fs_config:
        if p == "":
            root_perm = (owner, group, mode)
            break

    # 如果没找到，使用默认值
    if root_perm is None:
        root_perm = (0, 0, 0o755)

    owner, group, mode = root_perm

    with open(path, "w", encoding='utf-8', newline='\n') as f:
        # 写入根目录和前缀目录的配置
        f.write(f"/ {owner} {group} {mode:04o}\n")
        f.write(f"{prefix} {owner} {group} {mode:04o}\n")

        # 写入其他所有文件和目录的配置
        for p, owner, group, mode, cap, link in fs_config:
            if p == "":
                continue
            out_path = f"{prefix}{p}"
            cap_link = f"{cap} {link}".strip()
            out = f"{out_path} {owner} {group} {mode:04o} {cap_link}"
            f.write(out.strip() + "\n")


def main():
    """
    主函数，程序的入口点。
    """
    args = parse_args()
    
    try:
        with open(args.image_path, "rb") as f:
            # 加载 ext4 卷
            volume = ext4.Volume(f)
            # 使用镜像文件名作为前缀
            prefix = os.path.basename(args.image_path).split('.')[0]

            # 创建输出目录
            os.makedirs(args.config_output_dir, exist_ok=True)
            if args.file_extract_dir:
                os.makedirs(args.file_extract_dir, exist_ok=True)

            # 提取数据
            fs_config, file_contexts = extract_volume(volume, prefix, args.file_extract_dir, args.quiet)

            # 构造输出文件路径
            ctx_path = os.path.join(args.config_output_dir, f"{prefix}_file_contexts")
            cfg_path = os.path.join(args.config_output_dir, f"{prefix}_fs_config")

            # 写入配置文件
            write_file_contexts(ctx_path, prefix, file_contexts)
            write_fs_config(cfg_path, prefix, fs_config)

    except FileNotFoundError:
        print(get_msg('err_not_found', image_path=args.image_path), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(get_msg('err_unexpected', e=e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()