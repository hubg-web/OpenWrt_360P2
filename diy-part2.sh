#!/bin/bash
set -euo pipefail

# 1) 修改默认 LAN IP（仅当存在该文件）
CFG_FILE="package/base-files/files/bin/config_generate"
if [[ -f "$CFG_FILE" ]]; then
  sed -i 's/192\.168\.1\.1/192\.168\.5\.1/g' "$CFG_FILE"
else
  echo "⚠️ 未找到 $CFG_FILE，跳过修改默认 IP（这在少数分支中路径不同属正常）"
fi

# 2) 确保在源码根目录执行（含 .config 或将创建空 .config）
[[ -f ".config" ]] || touch .config

# 3) 先清理可能已有的相关行，避免重复与冲突（幂等）
sed -i -E '/CONFIG_(DEFAULT_)?luci-app-ddns/d' .config
sed -i -E '/CONFIG_(DEFAULT_)?ddns-scripts(_aliyun|_dnspod)?/d' .config
sed -i -E '/CONFIG_(DEFAULT_)?default-settings/d' .config
sed -i -E '/CONFIG_PACKAGE_autosamba(_INCLUDE_KSMBD)?/d' .config
sed -i -E '/CONFIG_PACKAGE_kmod-fs-ksmbd|CONFIG_PACKAGE_ksmbd-(server|tools)|CONFIG_PACKAGE_luci-app-ksmbd/d' .config
sed -i -E '/CONFIG_PACKAGE_dnsmasq(-full.*)?/d' .config
sed -i -E '/^CONFIG_IMAGEOPT=/d' .config

# 4) 追加“强制覆盖片段”（针对 LEDE：使用 ksmbd-server）
cat >> .config <<'EOF'
##### ---- FORCE OVERRIDES (Do not remove) ---- #####
CONFIG_IMAGEOPT=y

# 禁用 DDNS / 默认设置 / autosamba（及其子选项）
# CONFIG_DEFAULT_luci-app-ddns is not set
# CONFIG_DEFAULT_ddns-scripts_aliyun is not set
# CONFIG_DEFAULT_ddns-scripts_dnspod is not set
# CONFIG_DEFAULT_default-settings is not set
# CONFIG_PACKAGE_luci-app-ddns is not set
# CONFIG_PACKAGE_ddns-scripts is not set
# CONFIG_PACKAGE_ddns-scripts-services is not set
# CONFIG_PACKAGE_ddns-scripts_aliyun is not set
# CONFIG_PACKAGE_ddns-scripts_dnspod is not set
# CONFIG_PACKAGE_default-settings is not set
# CONFIG_PACKAGE_autosamba is not set
# CONFIG_PACKAGE_autosamba_INCLUDE_KSMBD is not set

# 仅保留轻量 SMB：ksmbd（LEDE 用 ksmbd-server）
CONFIG_PACKAGE_kmod-fs-ksmbd=y
CONFIG_PACKAGE_ksmbd-server=y
CONFIG_PACKAGE_luci-app-ksmbd=y

# 仅保留 dnsmasq-full，避免与 dnsmasq 冲突
# CONFIG_PACKAGE_dnsmasq is not set
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_dnsmasq_full_dhcp=y
CONFIG_PACKAGE_dnsmasq_full_ipset=y
# CONFIG_PACKAGE_dnsmasq_full_tftp is not set
# CONFIG_PACKAGE_dnsmasq_full_dhcpv6 is not set
# CONFIG_PACKAGE_dnsmasq_full_dnssec is not set
# CONFIG_PACKAGE_dnsmasq_full_auth is not set
# CONFIG_PACKAGE_dnsmasq_full_conntrack is not set
##### ---- END FORCE OVERRIDES ----
EOF

# 5) 规范一次（生成最终 .config）
make defconfig
echo "✅ diy-part2.sh 完成（LEDE 模式）。"
