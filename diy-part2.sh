#!/bin/bash
set -euo pipefail

# -----------------------------
# 1) 修改默认 LAN IP
# -----------------------------
CFG_FILE="package/base-files/files/bin/config_generate"
if [[ -f "$CFG_FILE" ]]; then
  sed -i 's/192\.168\.1\.1/192\.168\.5\.1/g' "$CFG_FILE"
  echo "[OK] 默认 IP 修改为 192.168.5.1"
else
  echo "⚠️ 未找到 $CFG_FILE，跳过修改默认 IP"
fi


# -----------------------------
# 2) 启用 USB 节点（针对 360P2 DTS）
# -----------------------------
DTS="target/linux/ramips/dts/mt7628an_hiwifi_hc5861b.dts"

if [[ -f "$DTS" ]]; then
  echo "[INFO] Patching USB nodes in $DTS"

  # 方式1：修改 disabled → okay
  sed -i 's/\(usbphy.*\)status = "disabled"/\1status = "okay"/' "$DTS" || true
  sed -i 's/\(ehci.*\)status = "disabled"/\1status = "okay"/' "$DTS" || true
  sed -i 's/\(ohci.*\)status = "disabled"/\1status = "okay"/' "$DTS" || true

  # 方式2：若没字段，则在文件末追加
  if ! grep -q '&usbphy' "$DTS"; then
    cat >> "$DTS" <<'EOF'

/* --- added by diy-part2.sh to enable USB --- */
&usbphy {
	status = "okay";
};

&ehci {
	status = "okay";
};

&ohci {
	status = "okay";
};
EOF
    echo "[OK] 已追加 USB 节点片段"
  fi
else
  echo "[WARN] DTS not found: $DTS — 请检查路径"
fi


# -----------------------------
# 3) 确保存在 .config
# -----------------------------
[[ -f ".config" ]] || touch .config


# -----------------------------
# 4) 清理旧配置避免冲突（幂等）
# -----------------------------
sed -i -E '/CONFIG_(DEFAULT_)?luci-app-ddns/d' .config
sed -i -E '/CONFIG_(DEFAULT_)?ddns-scripts(_aliyun|_dnspod)?/d' .config
sed -i -E '/CONFIG_(DEFAULT_)?default-settings/d' .config
sed -i -E '/CONFIG_PACKAGE_autosamba(_INCLUDE_KSMBD)?/d' .config
sed -i -E '/CONFIG_PACKAGE_kmod-fs-ksmbd|CONFIG_PACKAGE_ksmbd-(server|tools)|CONFIG_PACKAGE_luci-app-ksmbd/d' .config
sed -i -E '/CONFIG_PACKAGE_dnsmasq(-full.*)?/d' .config
sed -i -E '/^CONFIG_IMAGEOPT=/d' .config
sed -i -E '/CONFIG_PACKAGE_kmod-usb|CONFIG_PACKAGE_kmod-fs-vfat|CONFIG_PACKAGE_kmod-nls/d' .config


# -----------------------------
# 5) 追加强制配置段（LEDE 用 ksmbd-server）
# -----------------------------
cat >> .config <<'EOF'
##### ---- FORCE OVERRIDES (Do not remove) ---- #####
CONFIG_IMAGEOPT=y

# 禁用 DDNS / 默认设置 / autosamba
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

# 启用 USB 支持模块
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
##### ---- END FORCE OVERRIDES ----
EOF


# -----------------------------
# 6) 规范配置
# -----------------------------
make defconfig

echo "✅ diy-part2.sh 执行完成（LEDE + USB 版本）"
