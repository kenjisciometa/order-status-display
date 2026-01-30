# Raspberry Pi OSD Setup Guide

Order Status Display (OSD) をRaspberry Piにセットアップするためのガイドです。

## 前提条件

- Raspberry Pi 4/5 (4GB以上推奨)
- Raspberry Pi OS Desktop (GUI環境)
- インターネット接続
- SSH接続可能

## 1. Raspberry Piの初期設定

### SSH接続

```bash
ssh pi@<raspberry-pi-ip>
# 例: ssh pi@100.114.253.102
```

### 自動ログインの有効化

```bash
sudo raspi-config
```

→ `1 System Options` → `S5 Boot / Auto Login` → `B4 Desktop Autologin` を選択

## 2. Flutter SDKのインストール

### 依存関係のインストール

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

### Flutter SDKのダウンロード

```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Flutterの確認

```bash
flutter doctor
```

以下が✓であれば問題なし：
- Flutter
- Linux toolchain
- Connected device

※ Android toolchainとChromeは不要

### Linux Desktopの有効化

```bash
flutter config --enable-linux-desktop
```

## 3. アプリのビルド

### プロジェクトをRaspberry Piにコピー

Mac/PCから実行：

```bash
scp -r /path/to/order-status-display/flutter_app pi@<raspberry-pi-ip>:~/osd_app
```

### 追加の依存関係をインストール

```bash
# GStreamer (audioplayers用)
sudo apt install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good

# libsecret (flutter_secure_storage用)
sudo apt install -y libsecret-1-dev

# gnome-keyring (セキュアストレージ用)
sudo apt install -y gnome-keyring libpam-gnome-keyring
```

### ビルド

```bash
cd ~/osd_app
flutter pub get
flutter build linux --release
```

### 動作確認

```bash
cd ~/osd_app/build/linux/arm64/release/bundle
./osd_app
```

## 4. ストレージについて

**注意**: OSDアプリは`shared_preferences`を使用してデータを保存します。
以前のバージョンでは`flutter_secure_storage`を使用していましたが、Linux/Raspberry Pi環境でのキーリング問題（「Authentication required」や「Choose password for new keyring」ダイアログ）を回避するため、`shared_preferences`に変更されました。

データは `~/.local/share/com.sciometa.osd_app/` に保存されます。

### 旧バージョンからの移行

旧バージョン（flutter_secure_storage使用）からアップデートする場合、キーリングに保存された認証情報はクリアされます。再度ログインが必要です。

キーリング関連のダイアログが表示される場合は、以下を実行してキーリングをクリアしてください：

```bash
rm -rf ~/.local/share/keyrings/*
```

## 5. フルスクリーン表示

アプリは起動時に自動的にフルスクリーンモードで表示されます。

### 実装詳細

`lib/main.dart` に以下の設定が含まれています：

```dart
// Initialize window manager for desktop platforms (Linux, Windows, macOS)
if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: 'Order Status Display',
    fullScreen: true,      // フルスクリーン
    alwaysOnTop: true,     // 常に最前面
    skipTaskbar: true,     // タスクバーに表示しない
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
  });
}
```

### 使用パッケージ

`pubspec.yaml` に `window_manager` パッケージが必要です：

```yaml
dependencies:
  window_manager: ^0.4.3
```

### フルスクリーン解除

開発・デバッグ時にフルスクリーンを解除したい場合は、`main.dart` の `fullScreen: true` を `false` に変更して再ビルドしてください。

## 6. 自動起動の設定

### autostartを使用

```bash
mkdir -p ~/.config/autostart
nano ~/.config/autostart/osd.desktop
```

以下を貼り付け：

```ini
[Desktop Entry]
Type=Application
Name=Order Status Display
Exec=/home/pi/osd_app/build/linux/arm64/release/bundle/osd_app
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
```

## 6. 環境変数の設定

### .envファイルの編集

```bash
nano ~/osd_app/.env
```

### 自動ログインの設定（オプション）

キオスクモードで自動ログインを有効にする場合：

```env
# Auto Login Credentials (for kiosk/display mode)
AUTO_LOGIN_EMAIL=your-email@example.com
AUTO_LOGIN_PASSWORD=your-password
```

### 本番環境の設定

```env
FLUTTER_ENV=production
API_BASE_URL=https://pos.sciometa.com
WEBSOCKET_PRODUCTION_URL=wss://websocket.sciometa.com
ENABLE_VERBOSE_LOGGING=false
```

## 7. 再起動

```bash
sudo reboot
```

再起動後、自動的にデスクトップにログインし、OSDアプリが起動します。

## トラブルシューティング

### アプリが起動しない

1. 手動で実行してエラーを確認：
   ```bash
   cd ~/osd_app/build/linux/arm64/release/bundle
   ./osd_app
   ```

2. ログを確認：
   ```bash
   journalctl --user -f
   ```

### 「Authentication required」が表示される

キーリングの設定が正しくありません。「4. キーリングの設定」を再度実行してください。

### CORSエラー（Web版の場合）

Flutter LinuxアプリはネイティブアプリなのでCORSの問題は発生しません。
Web版を使用する場合は、サーバー側でCORSを設定するか、Nginxリバースプロキシを使用してください。

### ビルドエラー

依存関係が不足している可能性があります：

```bash
sudo apt install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libsecret-1-dev gnome-keyring libpam-gnome-keyring
```

## アプリの更新

新しいバージョンをデプロイする場合：

### Mac/PCから

```bash
# 変更したファイルをコピー
scp -r /path/to/flutter_app/lib pi@<raspberry-pi-ip>:~/osd_app/
scp /path/to/flutter_app/.env pi@<raspberry-pi-ip>:~/osd_app/
scp /path/to/flutter_app/pubspec.yaml pi@<raspberry-pi-ip>:~/osd_app/
```

### Raspberry Piで再ビルド

```bash
cd ~/osd_app
flutter clean
flutter pub get
flutter build linux --release
sudo reboot
```

## アプリ側の自動ログイン実装

キオスクモードでアプリを自動ログインさせるための実装方法です。

### 1. .envファイルに環境変数を追加

`flutter_app/.env` に以下の環境変数を追加：

```env
# Auto Login Credentials (for kiosk/display mode)
# Leave empty to disable auto-login
AUTO_LOGIN_EMAIL=
AUTO_LOGIN_PASSWORD=
```

### 2. login_screen.dartの変更

`lib/screens/login_screen.dart` に以下の変更を加えます：

#### flutter_dotenvのインポートを追加

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  // 追加
import '../services/auth_service.dart';
import 'display_selection_screen.dart';
import 'order_status_screen.dart';
```

#### initStateと_checkAutoLoginメソッドを追加

`_LoginScreenState`クラス内に以下を追加：

```dart
@override
void initState() {
  super.initState();
  _checkAutoLogin();
}

Future<void> _checkAutoLogin() async {
  final autoEmail = dotenv.env['AUTO_LOGIN_EMAIL'] ?? '';
  final autoPassword = dotenv.env['AUTO_LOGIN_PASSWORD'] ?? '';

  if (autoEmail.isNotEmpty && autoPassword.isNotEmpty) {
    // Set credentials and trigger auto-login
    _emailController.text = autoEmail;
    _passwordController.text = autoPassword;

    // Small delay to ensure widget is fully built
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _handleLogin();
    }
  }
}
```

### 3. 使用方法

#### 開発/テスト環境

`.env`ファイルに認証情報を設定：

```env
AUTO_LOGIN_EMAIL=test@example.com
AUTO_LOGIN_PASSWORD=testpassword123
```

#### 本番環境（Raspberry Pi）

ラズパイの`~/osd_app/.env`を直接編集：

```bash
nano ~/osd_app/.env
```

```env
AUTO_LOGIN_EMAIL=store-display@example.com
AUTO_LOGIN_PASSWORD=securepassword
```

### 4. セキュリティに関する注意

- `.env`ファイルは**絶対にGitにコミットしない**でください
- `.gitignore`に`.env`が含まれていることを確認してください
- 本番環境では、アクセスが制限されたディスプレイ専用アカウントを使用してください
- 自動ログインを無効にするには、環境変数を空のままにしてください：
  ```env
  AUTO_LOGIN_EMAIL=
  AUTO_LOGIN_PASSWORD=
  ```

### 5. 動作フロー

1. アプリ起動
2. `LoginScreen`の`initState`が呼ばれる
3. `_checkAutoLogin()`が環境変数をチェック
4. 認証情報が設定されている場合：
   - テキストフィールドに値をセット
   - 500ms待機（UIの構築完了を待つ）
   - `_handleLogin()`を自動実行
5. ログイン成功後、ディスプレイ選択画面またはオーダーステータス画面に遷移

### 6. 再ビルドが必要

`.env`や`login_screen.dart`を変更した場合、ラズパイで再ビルドが必要です：

```bash
cd ~/osd_app
flutter clean
flutter pub get
flutter build linux --release
sudo reboot
```

## 参考情報

- Flutter Linux Desktop: https://docs.flutter.dev/platform-integration/linux/building
- Raspberry Pi OS: https://www.raspberrypi.com/software/
- GNOME Keyring: https://wiki.gnome.org/Projects/GnomeKeyring
- flutter_dotenv: https://pub.dev/packages/flutter_dotenv
