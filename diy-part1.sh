#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# ================================================
# 1. 修改 feeds 源（可选）
# ================================================
# 解除注释 helloworld 源
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# 添加 lienol 源（例）
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default


# ================================================
# 2. 移除默认包，防止重复或冲突（关键部分）
# ================================================
# 这段命令会在每次 Actions 构建时自动执行，
# 从 include/target.mk 删除不需要的默认包，
# 防止它们在 defconfig 阶段被重新写入 .config。
# ================================================
sed -i \
  -e 's/\<ddns-scripts_aliyun\>//g' \
  -e 's/\<ddns-scripts_dnspod\>//g' \
  -e 's/\<default-settings\>//g' \
  -e 's/\<autosamba\>//g' \
  -e 's/\<samba36-server\>//g' \
  include/target.mk

# ================================================
# 3. （可选）替换 OpenWrt 下载源为国内镜像，加速下载
# ================================================
# sed -i 's#downloads.openwrt.org#mirror2.openwrt.org#g' scripts/download.pl
# echo "src/gz openwrt_core https://mirrors.aliyun.com/openwrt/releases/23.05.3/targets/x86/64/packages" >> feeds.conf.default
