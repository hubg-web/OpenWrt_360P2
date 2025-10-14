#!/bin/bash
set -e

# 自动定位 LEDE 根目录
guess_lede_root() {
  for d in "." ".." "../lede" "$HOME/lede"; do
    [ -f "$d/include/target.mk" ] && { realpath "$d"; return 0; }
  done
  return 1
}
LEDE_DIR="${LEDE_DIR:-$(guess_lede_root || true)}"
[ -z "$LEDE_DIR" ] && { echo "❌ 未找到 lede 源码（需包含 include/target.mk）。先 git clone lede"; exit 1; }
echo "✅ LEDE 根目录：$LEDE_DIR"

# 可选：镜像加速
# sed -i 's#downloads.openwrt.org#mirror2.openwrt.org#g' "$LEDE_DIR/scripts/download.pl"

# 需要彻底移除的默认包（避免 defconfig 写回）
# * ddns-scripts_aliyun / ddns-scripts_dnspod / default-settings / autosamba / samba36-server / luci-app-ddns
sed -i \
  -e 's/\<ddns-scripts_aliyun\>//g' \
  -e 's/\<ddns-scripts_dnspod\>//g' \
  -e 's/\<default-settings\>//g' \
  -e 's/\<autosamba\>//g' \
  -e 's/\<samba36-server\>//g' \
  -e 's/\<luci-app-ddns\>//g' \
  "$LEDE_DIR/include/target.mk"

# 某些机型 profile 会追加默认包，再扫一遍 image 目录
find "$LEDE_DIR/target/linux" -type f -name '*.mk' -path '*/image/*' -exec \
  sed -i \
    -e 's/\<luci-app-ddns\>//g' \
    -e 's/\<autosamba\>//g' {} +

# 可选：物理移除 autosamba 包（极端保险，不影响 ksmbd）
rm -rf "$LEDE_DIR/package/lean/autosamba" 2>/dev/null || true
rm -rf "$LEDE_DIR/feeds/"*/autosamba       2>/dev/null || true

echo "✅ 默认包与 autosamba 源头已清理"
