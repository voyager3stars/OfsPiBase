#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Wi-Fi Access Point Setup
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Configures the Raspberry Pi as a Wi-Fi access point
#               using NetworkManager (nmcli).
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な変数: TARGET_USER, USER_HOME
# 必要な関数: ask_yes_no, prompt_with_default, print_section, info

setup_wifi_ap() {
  print_section "1" "Wi-Fi アクセスポイント 設定"

  if ! ask_yes_no "Wi-Fi アクセスポイントの設定を行いますか？"; then
    info "Wi-Fi アクセスポイントの設定をスキップしました。"
    return 1
  fi

  # 既存の AP 接続プロファイルを検索
  local existing_aps=()
  while IFS= read -r line; do
    [ -n "$line" ] && existing_aps+=("$line")
  done < <(nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)

  local default_ssid="FieldAP"
  if [ ${#existing_aps[@]} -gt 0 ]; then
    echo "登録済みの Wi-Fi 設定:"
    for i in "${!existing_aps[@]}"; do
      echo "  [$((i + 1))] ${existing_aps[$i]}"
    done
    echo "  [0] 新しい SSID を手動入力する"

    local sel_num
    read -r -p "上書き・再利用する設定番号 (0-${#existing_aps[@]}) [0]: " sel_num
    sel_num="${sel_num:-0}"

    if [[ "$sel_num" =~ ^[1-9][0-9]*$ ]] && [ "$sel_num" -le "${#existing_aps[@]}" ]; then
      default_ssid="${existing_aps[$((sel_num - 1))]}"
      echo "-> '${default_ssid}' を選択しました。"
    fi
  fi

  # SSID / パスワード / IP入力
  WIFI_SSID=$(prompt_with_default "SSID" "$default_ssid")

  local pass
  while true; do
    pass=$(prompt_with_default "Wi-Fi パスワード" "xyzxyzxyz")
    if [ ${#pass} -ge 8 ]; then
      break
    fi
    echo "エラー: パスワードは8文字以上で指定してください。"
  done
  WIFI_PASS="$pass"

  local raw_ip
  raw_ip=$(prompt_with_default "IPアドレス" "192.168.50.1")
  WIFI_IP="${raw_ip%%/*}"
  local ip_addr="${WIFI_IP}/24"

  echo ""
  echo "--- AP設定の適用 ---"
  nmcli connection delete "$WIFI_SSID" 2>/dev/null || true
  nmcli connection add type wifi ifname wlan0 con-name "$WIFI_SSID" ssid "$WIFI_SSID" mode ap
  nmcli connection modify "$WIFI_SSID" ipv4.method shared ipv4.addresses "$ip_addr"
  nmcli connection modify "$WIFI_SSID" \
    802-11-wireless-security.proto rsn \
    802-11-wireless-security.key-mgmt wpa-psk \
    802-11-wireless-security.psk "$WIFI_PASS"
  nmcli connection modify "$WIFI_SSID" 802-11-wireless-security.pmf disable
  nmcli radio wifi on
  ip link set wlan0 up
  nmcli connection up "$WIFI_SSID"

  info "Wi-Fi AP の設定が完了しました。"
  return 0
}
