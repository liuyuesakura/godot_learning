#!/usr/bin/env bash
# ============================================================
#  MySpire — iOS 构建脚本
#  运行环境: macOS (需安装 Xcode + Godot CLI + 导出模板)
#
#  用法:
#    ./build_ios.sh export    # 仅导出 Xcode 工程 (可在任何平台运行 Godot)
#    ./build_ios.sh ipa       # 导出 + 编译 IPA (需 macOS + Xcode)
#    ./build_ios.sh archive   # 导出 + Archive (用于 App Store 上传)
#    ./build_ios.sh all       # export + archive
#  默认: export
# ============================================================
set -euo pipefail

# === 路径 ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/build/dist"
IOS_EXPORT_DIR="$PROJECT_DIR/build/ios"
XCODE_PROJECT="$IOS_EXPORT_DIR/MySpire.xcodeproj"
SCHEME="MySpire"
BUNDLE_ID="com.myspire.game"
ARCHIVE_PATH="$DIST_DIR/MySpire.xcarchive"
IPA_PATH="$DIST_DIR/MySpire.ipa"

# === 参数 ===
MODE="${1:-export}"

# === Godot CLI 检测 ===
GODOT=""
if [[ -n "${GODOT_PATH:-}" ]]; then
    GODOT="$GODOT_PATH"
elif command -v godot &>/dev/null; then
    GODOT="godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
fi

if [[ -z "$GODOT" ]]; then
    echo "[ERROR] 未找到 Godot CLI。"
    echo "  方案 1: export GODOT_PATH=/path/to/godot"
    echo "  方案 2: brew install godot (Homebrew)"
    exit 1
fi
echo "[INFO] Godot CLI: $GODOT"

mkdir -p "$DIST_DIR"
mkdir -p "$IOS_EXPORT_DIR"

# ============================================================
export_xcode() {
    echo ""
    echo "========================================"
    echo "  导出 Xcode 工程"
    echo "========================================"
    "$GODOT" --headless --export-debug "iOS (Xcode Project)" --path "$PROJECT_DIR"
    if [[ ! -d "$XCODE_PROJECT" ]]; then
        echo "[ERROR] Xcode 工程导出失败 — 未找到 $XCODE_PROJECT"
        exit 1
    fi
    echo "[OK] Xcode 工程: $XCODE_PROJECT"
}

# ============================================================
build_ipa() {
    if [[ ! -d "$XCODE_PROJECT" ]]; then
        echo "[ERROR] Xcode 工程不存在，请先运行: ./build_ios.sh export"
        exit 1
    fi

    echo ""
    echo "========================================"
    echo "  编译 IPA (Development)"
    echo "========================================"

    # 清理 + 构建
    xcodebuild clean \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "generic/platform=iOS" \
        -quiet

    xcodebuild build \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$IOS_EXPORT_DIR/DerivedData" \
        archive

    # 导出 IPA
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist <(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
) \
        -exportPath "$DIST_DIR"

    if [[ -f "$IPA_PATH" ]]; then
        echo "[OK] IPA: $IPA_PATH"
    else
        echo "[ERROR] IPA 生成失败"
        exit 1
    fi
}

# ============================================================
archive_for_store() {
    if [[ ! -d "$XCODE_PROJECT" ]]; then
        echo "[ERROR] Xcode 工程不存在，请先运行: ./build_ios.sh export"
        exit 1
    fi

    echo ""
    echo "========================================"
    echo "  Archive (App Store Distribution)"
    echo "========================================"

    echo "[提示] 请确保已在 Xcode 中配置 Team ID 和签名证书"
    echo "       编辑此脚本的 TEAM_ID 后重新运行"
    echo ""

    xcodebuild clean \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -quiet

    xcodebuild build \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$IOS_EXPORT_DIR/DerivedData" \
        archive

    echo "[OK] Archive 完成: $ARCHIVE_PATH"
    echo "     使用 Xcode > Organizer 上传到 App Store Connect"
    echo "     或使用: xcrun altool --upload-app -f <ipa> ..."
}

# ============================================================
case "$MODE" in
    export)
        export_xcode
        ;;
    ipa)
        export_xcode
        build_ipa
        ;;
    archive)
        export_xcode
        archive_for_store
        ;;
    all)
        export_xcode
        archive_for_store
        ;;
    *)
        echo "用法: $0 [export|ipa|archive|all]"
        echo "  export  — 仅导出 Xcode 工程"
        echo "  ipa     — 导出 + 编译 Development IPA"
        echo "  archive — 导出 + Release Archive (App Store)"
        echo "  all     — export + archive"
        exit 1
        ;;
esac

echo ""
echo "[完成] iOS 构建流程结束"
echo "产物目录: $DIST_DIR"
