#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Main Setup Orchestrator
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# Version:      2.0.0
# License:      MIT
# Description:  Unified setup script for Raspberry Pi field systems.
#               Integrates Wi-Fi AP, Samba, GPS/Chrony, and
#               KStars/EKOS/INDI configuration.
#               Compatible with Raspberry Pi OS Bookworm.
# =================================================================

set -euo pipefail

# Fix line endings for files edited on Windows (CRLF to LF)
sed -i 's/\r$//' "$0" || true

# ── Resolve script directory ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load common utilities ───────────────────────────────────────
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# ── Load feature modules ────────────────────────────────────────
# shellcheck source=modules/00_init_rpi.sh
source "${SCRIPT_DIR}/modules/00_init_rpi.sh"
# shellcheck source=modules/01_wifi_ap.sh
source "${SCRIPT_DIR}/modules/01_wifi_ap.sh"
# shellcheck source=modules/02_samba.sh
source "${SCRIPT_DIR}/modules/02_samba.sh"
# shellcheck source=modules/03_gps.sh
source "${SCRIPT_DIR}/modules/03_gps.sh"
# shellcheck source=modules/04_kstars.sh
source "${SCRIPT_DIR}/modules/04_kstars.sh"
# shellcheck source=modules/05_phd2.sh
source "${SCRIPT_DIR}/modules/05_phd2.sh"

# ── Pre-flight checks ───────────────────────────────────────────
require_root
resolve_target_user

# ── State variables (set by modules) ────────────────────────────
CURRENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
WIFI_IP="${CURRENT_IP:-192.168.50.1}"   # Updated by wifi module
WIFI_SSID=""                            # Updated by wifi module
WIFI_PASS=""                            # Updated by wifi module
SAMBA_SHARE_NAME=""                     # Updated by samba module
INIT_CONFIGURED=false
AP_CONFIGURED=false
SAMBA_CONFIGURED=false
GPS_CONFIGURED=false
KSTARS_CONFIGURED=false
PHD2_CONFIGURED=false

# ── Banner ───────────────────────────────────────────────────────
echo "================================================================"
echo "  OFSPiBase  –  Raspberry Pi フィールドシステム セットアップ"
echo "================================================================"
echo "  対象ユーザー: $TARGET_USER"
echo "  ホームディレクトリ: $USER_HOME"
echo "================================================================"

# ── Execute modules ──────────────────────────────────────────────

# 0. 初期設定 (X11 / VNC)
setup_init_rpi
if [ $? -eq 2 ]; then
  # Wayland から X11 への切り替えが発生したため、再起動を促してスクリプトを強制終了
  exit 0
fi

# 1. Wi-Fi AP
if setup_wifi_ap; then
  AP_CONFIGURED=true
fi

# 2. Samba
if setup_samba; then
  SAMBA_CONFIGURED=true
fi

# 3. GPS / 時刻同期
if setup_gps; then
  GPS_CONFIGURED=true
fi

# 4. KStars / EKOS / INDI
if setup_kstars; then
  KSTARS_CONFIGURED=true
fi

# 5. PHD2
if setup_phd2; then
  PHD2_CONFIGURED=true
fi

# ── Summary ──────────────────────────────────────────────────────
# 接続先IP: Wi-Fi APが設定されていればそのIP、なければ現在のIPを使用
CLEAN_IP="${WIFI_IP}"

clear
echo "================================================================"
echo "           セットアップ完了！"
echo "================================================================"
echo ""

if [ "$AP_CONFIGURED" = true ]; then
  echo "【ステップ 1: Wi-Fiに接続する】"
  echo "  1. Windowsのタスクバー右下のWi-Fiアイコンをクリック"
  echo "  2. 一覧から以下のネットワークを選んで接続:"
  echo "     ・SSID (ネットワーク名):  $WIFI_SSID"
  echo "     ・セキュリティキー (パスワード): $WIFI_PASS"
  echo ""
fi

if [ "$SAMBA_CONFIGURED" = true ]; then
  echo "【共有フォルダ (Samba) を開く】"
  echo "  1. Windowsキー + R を押して「ファイル名を指定して実行」を開く"
  echo "  2. 以下の文字列をそのまま入力して Enter:"
  echo ""
  echo "     \\\\$CLEAN_IP\\$SAMBA_SHARE_NAME"
  echo ""
  echo "  3. ユーザー名とパスワードを求められたら以下を入力:"
  echo "     ・ユーザー名: $TARGET_USER  (弾かれる場合は .\\$TARGET_USER)"
  echo "     ・パスワード: (設定したパスワード)"
  echo "----------------------------------------------------------------"
fi

if [ "$GPS_CONFIGURED" = true ]; then
  echo "【GPS の動作確認】"
  echo "  ※ まず再起動してください: sudo reboot"
  echo "  再起動後、以下のコマンドで動作を確認できます:"
  echo "  1. GPS Fix ステータス:  cgps -s"
  echo "  2. 時刻同期ステータス:  chronyc sources"
  echo "----------------------------------------------------------------"
fi

if [ "$KSTARS_CONFIGURED" = true ]; then
  echo "【KStars / EKOS の起動確認】"
  echo "  再起動後、以下の手順で動作を確認できます:"
  echo "  1. デスクトップまたは VNC で KStars を起動"
  echo "  2. Ctrl + K で EKOS を開く"
  echo "  3. プロファイルを作成し、機器を接続する"
  echo "----------------------------------------------------------------"
fi

if [ "$PHD2_CONFIGURED" = true ]; then
  echo "【PHD2 の起動確認】"
  echo "  再起動後、デスクトップメニューまたは以下のコマンドで起動できます:"
  echo "  $ phd2"
  echo "----------------------------------------------------------------"
fi

echo ""
echo "【補足: 接続先情報まとめ】"
[ "$SAMBA_CONFIGURED" = true ] && echo "  ・Samba 共有フォルダ: \\\\$CLEAN_IP\\$SAMBA_SHARE_NAME"

# 利用可能なすべてのIPアドレスを取得（APのIPが含まれていなければ追加）
ALL_IPS=$(hostname -I 2>/dev/null)
if [[ ! " $ALL_IPS " =~ " $CLEAN_IP " ]]; then
  ALL_IPS="$ALL_IPS $CLEAN_IP"
fi

echo "  ・VNC Viewer 接続先:"
for ip in $ALL_IPS; do
  [ -n "$ip" ] && echo "      - $ip:5900"
done

echo "  ・SSH 接続先:"
for ip in $ALL_IPS; do
  [ -n "$ip" ] && echo "      - $TARGET_USER@$ip"
done

echo "  ・接続ユーザー名:     $TARGET_USER"
echo "================================================================"

if [ "$GPS_CONFIGURED" = true ] || [ "$KSTARS_CONFIGURED" = true ] || [ "$PHD2_CONFIGURED" = true ]; then
  echo ""
  echo " [要対応] 設定の変更を反映するため、再起動してください:"
  echo "          sudo reboot"
fi
