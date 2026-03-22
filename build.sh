#!/bin/bash
# 本地构建脚本 - 在 Mac 上运行
# Usage: ./build.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo "  AliLedger2 iOS 本地构建脚本"
echo "========================================="

# 1. 构建模拟器版本（无需代码签名）
echo ""
echo "[1/3] 构建模拟器版本..."
xcodebuild build \
    -project AliLedger2.xcodeproj \
    -scheme AliLedger2 \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath build_sim

APP_PATH=$(find build_sim/Build/Products -name "AliLedger2.app" -type d | head -1)
echo "✅ 模拟器版本: $APP_PATH"

# 2. 打包为 ZIP
echo ""
echo "[2/3] 打包 ZIP..."
cd "$(dirname "$APP_PATH")"
zip -r "$PROJECT_DIR/AliLedger2.zip" AliLedger2.app
cd "$PROJECT_DIR"
echo "✅ AliLedger2.zip 已生成"

# 3. 使用个人 Apple ID 签名构建（可安装到真机）
echo ""
echo "[3/3] 真机构建（需要 Apple ID 签名）..."
echo "请在 Xcode 中操作："
echo "  1. 打开 AliLedger2.xcodeproj"
echo "  2. 选择 AliLedger2 target → Signing & Capabilities"
echo "  3. 选择你的 Team（个人 Apple ID）"
echo "  4. 修改 Bundle Identifier 为唯一值（如 com.yourname.aliledger）"
echo "  5. 连接 iPhone，选择设备后 Build & Run"
echo "  6. iPhone 设置 → 通用 → VPN与设备管理 → 信任开发者证书"

echo ""
echo "========================================="
echo "  构建完成！"
echo "========================================="
echo "输出文件:"
echo "  - AliLedger2.zip（模拟器版本）"
echo ""
echo "要在真机安装，推荐使用以下方式之一："
echo "  方法1: Xcode 直接安装（需 Mac + USB 连接）"
echo "  方法2: AltStore 侧载（无线安装，见 INSTALL.md）"
echo "  方法3: GitHub Actions 自动构建（见 .github/workflows/）"
