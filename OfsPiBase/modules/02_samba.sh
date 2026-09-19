#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Samba (File Sharing) Setup
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Installs and configures Samba for file sharing
#               between Raspberry Pi and Windows PCs.
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な変数: TARGET_USER, USER_HOME
# 必要な関数: ask_yes_no, prompt_with_default, print_section, info

setup_samba() {
  print_section "2" "Samba (ファイル共有) 設定"

  if ! ask_yes_no "Samba の設定を行いますか？"; then
    info "Samba の設定をスキップしました。"
    return 1
  fi

  SAMBA_SHARE_NAME="$TARGET_USER"

  # Sambaのインストール確認
  if ! dpkg -s samba >/dev/null 2>&1; then
    info "Samba をインストールしています..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y samba
  fi

  # バックアップ作成
  if [ ! -f /etc/samba/smb.conf.bak ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
  fi

  # [homes] セクションの安全な無効化処理
  info "[homes] セクションを無効化しています..."
  awk '
    /^[[:space:]]*\[homes\]/ {
      in_homes = 1
      print ";" $0
      next
    }
    in_homes {
      if (/^[[:space:]]*[;#]?[[:space:]]*\[[^]]+\]/) {
        in_homes = 0
      } else {
        if ($0 ~ /^[[:space:]]*[^;#[:space:]]/) {
          print ";" $0
          next
        }
      }
    }
    { print }
  ' /etc/samba/smb.conf > /etc/samba/smb.conf.tmp && mv /etc/samba/smb.conf.tmp /etc/samba/smb.conf

  # 共有フォルダ設定
  local share_path
  share_path=$(prompt_with_default "共有するフォルダパス" "$USER_HOME")
  mkdir -p "$share_path"
  chown -R "$TARGET_USER:$TARGET_USER" "$share_path"

  # 既存設定のクリーニングと追記
  sed -i "/^\[pi_share\]/,/^$/d" /etc/samba/smb.conf
  sed -i "/^\[$SAMBA_SHARE_NAME\]/,/^$/d" /etc/samba/smb.conf

  cat <<EOF >> /etc/samba/smb.conf

[$SAMBA_SHARE_NAME]
   comment = Raspberry Pi Astro Data
   path = $share_path
   browseable = yes
   read only = no
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = $TARGET_USER
EOF

  echo ""
  echo "--------------------------------------------------"
  echo "【推奨】Sambaパスワードは、混乱を防ぐため"
  echo "        Raspberry Pi OSのログインパスワードと"
  echo "        『同じもの』を設定することを強く推奨します。"
  echo "--------------------------------------------------"
  echo ""
  echo "Sambaユーザー ($TARGET_USER) のパスワードを設定してください。"
  echo "(※入力中、画面に文字や伏字は表示されません)"
  smbpasswd -a "$TARGET_USER"

  systemctl restart smbd
  systemctl enable smbd

  info "Samba の設定が完了しました。"
  return 0
}
