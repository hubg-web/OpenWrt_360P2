#!/usr/bin/env bash
# tools/run_make_with_logs.sh
# 用法：
#   bash tools/run_make_with_logs.sh [-j N] [额外 make 参数...]
# 例子：
#   bash tools/run_make_with_logs.sh -j$(nproc) V=s world

set -Eeuo pipefail

# 日志根目录（可自定义）
LOG_ROOT="${LOG_ROOT:-$HOME/owrt-logs}"
TS="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$LOG_ROOT/$TS"
mkdir -p "$RUN_DIR"

FULL_LOG="$RUN_DIR/full.log"           # 全量日志
FAIL_ONLY="$RUN_DIR/fail.log"          # 仅错误行
FAIL_CTX="$RUN_DIR/fail.ctx.log"       # 错误上下文（默认前后各 30 行）
CTX=30

# 记录当前源码/分支/commit（可选，便于回溯）
{
  echo "=== META ==="
  echo "TIME: $(date -Is)"
  echo "PWD: $(pwd)"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && {
    echo "GIT_REPO: $(git remote get-url origin 2>/dev/null || true)"
    echo "GIT_BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    echo "GIT_COMMIT: $(git rev-parse --short HEAD 2>/dev/null || true)"
  } || true
  echo "MAKE_CMD: make $*"
  echo "==========="
} > "$RUN_DIR/meta.txt"

# 建立/更新一个 latest 软链接，快速定位最近一次日志
ln -sfn "$RUN_DIR" "$LOG_ROOT/latest"

echo "📄 全量日志：$FULL_LOG"
echo "📄 错误行：  $FAIL_ONLY"
echo "📄 上下文：  $FAIL_CTX"

# 以“行缓冲”把 stdout/stderr 同时写到 full.log，并保留 make 的真实返回码
set +e
stdbuf -oL -eL make "$@" 2>&1 | tee "$FULL_LOG"
MAKE_RC=${PIPESTATUS[0]}
set -e

# 从 full.log 提取典型错误关键词（可按需扩充）
grep -E \
  '(^|\s)(error:|fatal error:|ERROR:|CMake Error|configure: error|collect2: error|failed to build|No rule to make target)' \
  "$FULL_LOG" >"$FAIL_ONLY" || true

# 生成带上下文的错误日志：匹配到错误的行，前后各 CTX 行
awk -v ctx="$CTX" '
  {
    line[NR]=$0
    for(i=NR-ctx;i<=NR+ctx;i++) if(i>0) window[i]=window[i]
    if($0 ~ /(error:|fatal error:|ERROR:|CMake Error|configure: error|collect2: error|failed to build|No rule to make target)/){
      for(i=NR-ctx;i<=NR+ctx;i++) if(i>0) keep[i]=1
      sep_needed=1
    }
  }
  END{
    if(sep_needed){
      for(i=1;i<=NR;i++){
        if(keep[i]){
          printf "%6d | %s\n", i, line[i]
        }
      }
    }
  }
' "$FULL_LOG" >"$FAIL_CTX" || true

# 额外生成结尾 1000 行，方便快速查看
tail -n 1000 "$FULL_LOG" > "$RUN_DIR/last1000.log" || true

echo
if [[ $MAKE_RC -eq 0 ]]; then
  echo "✅ make 成功（日志已保存到：$RUN_DIR）"
else
  echo "❌ make 失败（返回码：$MAKE_RC）"
  echo "   快速排错建议：先看 $FAIL_ONLY ，不够再看 $FAIL_CTX 或 $RUN_DIR/last1000.log"
fi

exit "$MAKE_RC"
