#!/usr/bin/env bash
# 云盘 ⇄ 本地 同步脚本（小学学习规划汇聚页）
#   ./sync.sh pull    云端 -> 本地（覆盖本地旧版）
#   ./sync.sh push    本地 -> 云端（只传 *.html 和 README.md，增量覆盖）并刷新在线文档
#   ./sync.sh status  只列差异
set -euo pipefail
cd "$(dirname "$0")"

FOLDER_TOKEN="IESMf1R7PlhitZdvmSMcWpFunic"   # 云盘「想法创意/小学学习规划汇聚页」
DOC_TOKEN="N27Ad1yZDoROmLxRActc2qftnog"      # 在线说明文档（README.md 导入版）
DOCS_TOKEN="XskDfpW68lO2K5dmi59cPqOLnJb"     # 云盘「docs」（创作记录等站外文档）

case "${1:-}" in
  pull)
    lark-cli drive +pull --local-dir . --folder-token "$FOLDER_TOKEN" --if-exists smart --format json
    ;;
  push)
    # 先取云端 rel_path -> file_token，用于原地覆盖（避免产生重复文件）
    lark-cli drive +status --local-dir . --folder-token "$FOLDER_TOKEN" --format json \
      | python3 -c '
import json,sys
d=json.load(sys.stdin).get("data",{})
for k in ("unchanged","modified","new_remote"):
    for it in (d.get(k) or []):
        p=it.get("rel_path"); t=it.get("file_token")
        if p and t: print(p+"\t"+t)
' > /tmp/.study_tokens.tsv

    shopt -s nullglob
    for f in *.html *.md docs/*.html docs/*.md; do
      case "$f" in docs/*) target="$DOCS_TOKEN" ;; *) target="$FOLDER_TOKEN" ;; esac
      tok=$(awk -F'\t' -v p="$f" '$1==p{print $2}' /tmp/.study_tokens.tsv)
      if [ -n "${tok:-}" ]; then
        lark-cli drive +upload --file "./$f" --file-token "$tok" --format json >/tmp/.up.json || { echo "失败: $f"; cat /tmp/.up.json; exit 1; }
        echo "覆盖 $f"
      else
        lark-cli drive +upload --file "./$f" --folder-token "$target" --format json >/tmp/.up.json || { echo "失败: $f"; cat /tmp/.up.json; exit 1; }
        echo "新增 $f"
      fi
    done

    echo "--- 刷新在线说明文档 ---"
    lark-cli docs +update --doc "$DOC_TOKEN" --command overwrite \
      --content @README.md --doc-format markdown --format json
    ;;
  status)
    lark-cli drive +status --local-dir . --folder-token "$FOLDER_TOKEN" --format json
    ;;
  *)
    echo "用法: ./sync.sh {pull|push|status}" >&2; exit 2 ;;
esac
