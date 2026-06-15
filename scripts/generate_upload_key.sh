#!/bin/bash
set -e

# パス設定
WORK_DIR="/home/horie/Takamagahara/utsushiyo/book-review-app"
ANDROID_DIR="$WORK_DIR/android"

# パスワードの自動生成（セキュアな32文字のランダム文字列）
STORE_PASSWORD=$(openssl rand -hex 16)
KEY_PASSWORD=$(openssl rand -hex 16)

echo "Generating new upload key for Book-Review-App..."

# 既存の keystore をバックアップ
if [ -f "$ANDROID_DIR/upload-keystore.jks" ]; then
  echo "Backing up existing upload-keystore.jks..."
  mv "$ANDROID_DIR/upload-keystore.jks" "$ANDROID_DIR/upload-keystore.jks.bak"
fi

# 新しい keystore の作成
keytool -genkeypair -v \
  -keystore "$ANDROID_DIR/upload-keystore.jks" \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "CN=Takamagahara-BookReview, OU=Dev, O=Takamagahara, L=Tokyo, S=Tokyo, C=JP"

# 証明書 (PEM) のエクスポート
keytool -export -rfc \
  -alias upload \
  -file "$ANDROID_DIR/upload_certificate.pem" \
  -keystore "$ANDROID_DIR/upload-keystore.jks" \
  -storepass "$STORE_PASSWORD"

# key.properties.new の作成
cat <<EOF > "$ANDROID_DIR/key.properties.new"
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
EOF

# Base64エンコードして一時ファイルに保存（GitHub Actions Secrets登録用）
base64 -w 0 "$ANDROID_DIR/upload-keystore.jks" > "$ANDROID_DIR/upload-keystore.jks.base64"

echo "Generation complete!"
echo "New keystore: $ANDROID_DIR/upload-keystore.jks"
echo "PEM certificate: $ANDROID_DIR/upload_certificate.pem"
echo "Properties file: $ANDROID_DIR/key.properties.new"
echo "Base64 keystore: $ANDROID_DIR/upload-keystore.jks.base64"
