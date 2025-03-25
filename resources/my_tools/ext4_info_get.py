#!/usr/bin/env python3
import os
import sys
import ext4
import re
import struct
import argparse
from collections import Counter

def main():
    parser = argparse.ArgumentParser(description='Process ext4 image files and generate configuration files.')
    parser.add_argument('image_path', type=str, help='Path to the ext4 image file')
    parser.add_argument('output_dir', type=str, help='Directory for output files')
    if len(sys.argv) < 3:
        parser.print_help(sys.stderr)
        sys.exit(1)
    args = parser.parse_args()
    image_path = args.image_path
    output_dir = args.output_dir
    prefix = os.path.basename(image_path).split('.')[0]
    config_output_path = os.path.join(output_dir, f"{prefix}_fs_config")
    context_output_path = os.path.join(output_dir, f"{prefix}_file_contexts")
    f = open(image_path, "rb")
    volume = ext4.Volume(f)
    file_contexts = {}
    fs_config = []
    stack = [(volume.root, "")]
    visited = set()
    while stack:
        inode, path = stack.pop()
        for xattr in inode.xattrs():
            if xattr[0] == "security.selinux":
                file_contexts[path] = xattr[1]
                if path == "":
                    file_contexts["/"] = xattr[1]
        if path in visited:
            continue
        visited.add(path)
        if inode.is_dir:
            for entry in inode.open_dir():
                if entry[0] in [".", ".."]:
                    continue
                if path == "/":
                    full_path = path + entry[0]
                else:
                    full_path = path + "/" + entry[0]
                sub_inode = volume.get_inode(entry[1], entry[2])
                link_target = ""
                if sub_inode.is_symlink:
                    try:
                        link_target = sub_inode.open_read().read().decode
                    except Exception as e:
                        print(f'Error reading symlink target: {e}')
                owner = sub_inode.inode.i_uid
                group = sub_inode.inode.i_gid
                mode = sub_inode.inode.i_mode & 0o777
                capabilities = ""
                for xattr in sub_inode.xattrs():
                    if xattr[0] == "security.selinux":
                        file_contexts[full_path] = xattr[1]
                    elif xattr[0] == "security.capability":
                        r = struct.unpack('<5I', xattr[1])
                        if r[1] > 65535:
                            cap = hex(int(f'{r[3]:04x}{r[1]:04x}', 16)).upper()
                        else:
                            cap = hex(int(f'{r[3]:04x}{r[2]:04x}{r[1]:04x}', 16)).upper()
                        capabilities = f"capabilities={cap}"
                fs_config.append((full_path, owner, group, mode, capabilities, link_target))
                if sub_inode.is_dir:
                    stack.append((sub_inode, full_path))
                    for sub_entry in sub_inode.open_dir():
                        if sub_entry[0] not in ['.', '..']:
                            sub_sub_inode = volume.get_inode(sub_entry[1], sub_entry[2])
                            stack.append((sub_sub_inode, full_path + '/' + sub_entry[0]))
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    with open(context_output_path, "w") as f:
        for path, context in file_contexts.items():
            escaped_path = re.escape(path) 
            context_str = context.decode('utf8', errors='replace').strip().replace('\x00', '')
            f.write(f"/{prefix}{escaped_path} {context_str}\n")
    with open(config_output_path, "w") as f:
        for path, owner, group, mode, capabilities, link_target in fs_config:
            output = f"{prefix}{path} {owner} {group} 0{mode:o} {capabilities} {link_target}"
            f.write(output.rstrip() + "\n")
    with open(context_output_path, "r") as f:
        lines = f.readlines()
    prefix_permission = None
    prefix_line = "/" + prefix
    for line in lines:
        if line.startswith(prefix_line):
            prefix_permission = line[len(prefix_line):].strip()
            break
    if prefix_permission is not None:
        lines.insert(0, f"/ {prefix_permission}\n")
    with open(context_output_path, "w") as f:
        f.writelines(lines)
    with open(config_output_path, 'r') as f:
        lines = f.readlines()
    if prefix == "vendor":
        lines.insert(0, f"/ 0 2000 0755\n")
        lines.insert(1, f"{prefix} 0 2000 0755\n")
        lines.insert(2, f"{prefix}/ 0 2000 0755\n")
    else:
        lines.insert(0, f"/ 0 0 0755\n")
        lines.insert(1, f"{prefix} 0 0 0755\n")
        lines.insert(2, f"{prefix}/ 0 0 0755\n")
    with open(config_output_path, 'w') as f:
        f.writelines(lines)
    f.close()

if __name__ == "__main__":
    main()
