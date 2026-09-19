#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Initial RPi5 Configuration (X11 / VNC)
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Configures X11 instead of Wayland and enables VNC
#               using raspi-config non-interactive mode.
#               Requires reboot after Wayland -> X11 change.
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な関数: print_section, info, warn

setup_init_rpi() {
  print_section "0" "Raspberry Pi 初期設定 (X11 / VNC)"

  # raspi-config が存在するか確認
  if ! command -v raspi-config &> /dev/null; then
    warn "raspi-config が見つかりません。このステップをスキップします。"
    return 0
  fi

  if ! ask_yes_no "X11 への切り替えと VNC の有効化を行いますか？"; then
    info "初期環境設定 (X11 / VNC) をスキップしました。"
    return 0
  fi

  # 1. Wayland から X11 への変更確認と適用
  info "ウィンドウシステム (Wayland / X11) の状態を確認しています..."
  if raspi-config nonint is_wayland; then
    info "Wayland が有効であることを検知しました。X11 に変更します..."
    raspi-config nonint do_wayland W1
    
    echo ""
    echo "================================================================"
    echo " 【重要】ウィンドウシステムを X11 に変更しました。"
    echo " 設定を確実に反映させるため、VNC などの有効化の前に"
    echo " Raspberry Pi の再起動が必要です。"
    echo "================================================================"
    echo " 以下のコマンドで再起動し、再度 SSH 接続してから"
    echo " もう一度 sudo ./setup.sh を実行してください:"
    echo ""
    echo " $ sudo reboot"
    echo "================================================================"
    echo ""
    
    # X11への切り替えが行われた場合、ここで完全に停止して再起動を促す
    return 2
  else
    info "すでに X11 が有効になっています。"
  fi

  # 2. VNC の有効化 (X11 変更後の再実行時にここが実行される)
  info "VNC の状態を確認しています..."
  local vnc_status
  vnc_status=$(raspi-config nonint get_vnc)
  
  # get_vnc の戻り値: 0 = 有効, 1 = 無効
  if [ "$vnc_status" -ne 0 ]; then
    info "VNC が無効になっています。有効化します..."
    raspi-config nonint do_vnc 0
    info "VNC を有効化しました。"
  else
    info "すでに VNC は有効になっています。"
  fi

  INIT_CONFIGURED=true
  return 0
}
