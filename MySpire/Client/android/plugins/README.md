# GodotGooglePlayBilling 插件目录

本目录用于放置 Google Play Billing Android 插件文件。

## 安装步骤

### 1. 下载插件

从 GitHub 下载 Godot 4 版本的 GodotGooglePlayBilling 插件：

```
https://github.com/godotengine/godot-google-play-billing/releases
```

### 2. 放置文件

将以下文件放入本目录（`android/plugins/`）：

```
android/plugins/
├── GodotGooglePlayBilling.gdap      # 插件描述文件
├── GodotGooglePlayBilling.debug.aar # Debug 构建
└── GodotGooglePlayBilling.release.aar # Release 构建
```

### 3. 验证 project.godot

`project.godot` 已配置 Android 模块加载：

```ini
[android]

modules=PackedStringArray("org/godotengine/godot/GodotGooglePlayBilling")
```

### 4. 导出设置

在 Godot 编辑器中：
1. 项目 → 导出 → 添加 Android 平台
2. 确认勾选 `GodotGooglePlayBilling` 模块
3. 设置 keystore（Release 签名）
4. 导出 APK / AAB

### 5. Google Play Console 配置

1. 在 Google Play Console 创建应用
2. 商品的 → 创建商品，SKU 必须与 `assets/content/iap_products.json` 中的 `sku` 字段一致
3. 设置价格、描述、图标
4. 激活商品

### 6. 测试

- 使用内部测试轨道发布 APK
- 添加 License Tester 账号（可免费测试购买）
- 或使用静态测试 SKU：`android.test.purchased` / `android.test.canceled`

## 桌面端测试（无需插件）

在 PC 编辑器中运行时，PaymentManager 自动切换到**模拟器模式**：
- 模拟连接、查询、购买、消费全流程
- 90% 成功率模拟真实场景
- 有延迟感（0.2-0.5s），接近网络手感

模拟器模式下可以直接测试商店 UI 和购买逻辑，无需 Android 设备。
