#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Time Synchronization (GPS & Chrony) Setup
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Automated high-precision time sync for Raspberry Pi.
#               Compatible with Raspberry Pi OS Bookworm.
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な関数: ask_yes_no, print_section, info

setup_gps() {
  print_section "3" "GPS / 時刻同期 (GPSD + Chrony) 設定"

  if ! ask_yes_no "GPS (GPSD + Chrony) の設定を行いますか？"; then
    info "GPS の設定をスキップしました。"
    return 1
  fi

  # 0. ハードウェア設定 (UART)
  # UART ハードウェアを有効化し、データ競合を防ぐためシリアルコンソール出力を無効化
  info "[0/8] UART ハードウェアを有効化し config.txt を変更しています..."
  if ! grep -q "enable_uart=1" /boot/firmware/config.txt; then
    echo "enable_uart=1" >> /boot/firmware/config.txt
  fi

  if grep -q "console=serial0" /boot/firmware/cmdline.txt; then
    sed -i 's/console=serial0,[0-9]* //' /boot/firmware/cmdline.txt
  fi

  # 1. パッケージのインストール
  info "[1/8] gpsd, python3-gps, chrony をインストールしています..."
  apt-get update -y
  apt-get install -y gpsd python3-gps chrony

  # 2. シリアルポートの解放
  # OS がログインシェルにシリアルポートを使用しないよう無効化
  info "[2/8] ttyAMA0 の serial getty を無効化しています..."
  systemctl stop serial-getty@ttyAMA0.service || true
  systemctl disable serial-getty@ttyAMA0.service || true
  systemctl mask serial-getty@ttyAMA0.service

  # 3. GPSD ソケット管理
  # gpsd.socket をマスクし、デーモンがシリアルポートを直接管理できるようにする
  info "[3/8] gpsd.socket をマスクして競合を防止しています..."
  systemctl stop gpsd.socket || true
  systemctl disable gpsd.socket || true
  systemctl mask gpsd.socket

  # 4. GPSD 設定
  info "[4/8] /etc/default/gpsd を設定しています..."
  cat <<EOF > /etc/default/gpsd
START_DAEMON="true"
USBAUTO="false"
DEVICES="/dev/ttyAMA0"
GPSD_OPTIONS="-N -n -G -s 9600"
GPSD_SOCKET="/run/gpsd.sock"
EOF

  # 5. GPSD サービスのカスタマイズ
  info "[5/8] gpsd.service を上書きしています..."
  cat <<'EOF' > /lib/systemd/system/gpsd.service
[Unit]
Description=GPS Daemon for OrionFieldStack
After=network.target
Conflicts=gpsd.socket

[Service]
Type=simple
EnvironmentFile=-/etc/default/gpsd
ExecStart=/usr/sbin/gpsd $GPSD_OPTIONS $DEVICES
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  # 6. Chrony 設定 (NTP-GPS パイプライン)
  # GPS 共有メモリ (SHM 2) を Chrony に接続し、マイクロ秒精度の時刻同期を実現
  info "[6/8] chrony を GPS (SHM 2) 用に設定しています..."
  if ! grep -q "SHM 2" /etc/chrony/chrony.conf; then
    cat <<EOF >> /etc/chrony/chrony.conf

# Added by OrionFieldStack (GPS SHM 2)
refclock SHM 2 refid GPS precision 1e-1 offset 0.128 delay 0.2 poll 4 trust
EOF
  fi

  # 初回同期用の高速ステッピングを有効化
  if grep -q "makestep" /etc/chrony/chrony.conf; then
    sed -i 's/^#*makestep.*/makestep 1.0 3/' /etc/chrony/chrony.conf
  else
    echo "makestep 1.0 3" >> /etc/chrony/chrony.conf
  fi

  # 7. 変更の適用
  info "[7/8] サービスを再起動しています..."
  systemctl daemon-reload
  systemctl unmask gpsd.service || true
  systemctl enable gpsd
  systemctl restart gpsd
  systemctl restart chrony

  # 8. INDI-GPSD ドライバのインストール
  # KStars/EKOS から GPS の位置情報・時刻データを利用するためのドライバ
  info "[8/8] INDI-GPSD ドライバをインストールしています..."
  apt-get install -y indi-gpsd

  info "GPS / 時刻同期の設定が完了しました。"
  GPS_CONFIGURED=true
  return 0
}
