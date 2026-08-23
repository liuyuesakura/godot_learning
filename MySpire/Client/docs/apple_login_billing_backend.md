# iOS 支付 / 登录 —— 管理后台与配置清单

> 适用项目：MySpire（Bundle ID `com.myspire.game`，Godot 4.5 mono）
> 对应客户端代码：
> - iOS 支付：`scripts/autoload/PaymentManager.gd`（`InAppStore` 单例，StoreKit 1，内置于 iOS 导出模板，无需装机插件）
> - iOS 登录：`scripts/autoload/AuthManager.gd`（`SignInWithApple` 插件单例，Phase 2，非内置、需自定义插件）
> - 服务端验签：`scripts/autoload/NetworkClient.gd`（`verify_purchase_receipt` / `exchange_auth_token`）
> - 商品映射：`assets/content/iap_products.json` 的 `apple_id` 字段
> - 导出配置：`export_presets.cfg` 的 preset.2（`application/info.plist`、`capabilities/in_app_purchases=true`）

---

## 1. 需要打交道的管理后台（共 2 个门户 + 1 组服务端 API）

| # | 门户 / API | 入口 | 用途 |
|---|---|---|---|
| 1 | **Apple Developer** | https://developer.apple.com/ | App ID、**Sign in with Apple** 能力、签名与描述文件、App 对应关系 |
| 2 | **App Store Connect** | https://appstoreconnect.apple.com/ | 创建 App、协议税务与银行、**App 内购买项目**、销售分析、API 密钥 |
| 3 | **Apple Server API** | 服务端调用（App Store Server API / Server Notifications V2） | 校验收据、处理退款与续订通知；签名用 App Store Connect API Key |

> 关系：Apple Developer 管「App 身份与能力」；App Store Connect 管「上架与内购商品」；服务端验签使用 App Store Connect 里签发的 Key（ES256 JWT）。

---

## 2. iOS 支付（App 内购买 / StoreKit 1）需要配置 —— App Store Connect + Apple Developer

客户端使用内置 `InAppStore`（StoreKit 1）：`request_product_info` / `purchase` / `finish_transaction` / `restore_purchases`。`PaymentManager` 通过 `apple_id` 把内部 SKU 翻译为 Apple 产品 ID（见 `get_apple_id`）。

### 2.1 在 Apple Developer 创建 App ID
- 路径：Certificates, Identifiers & Profiles → Identifiers → 创建 App ID。
- 选择 App，Bundle ID 填 `com.myspire.game`。
- 勾选 Capabilities，**必须开启**：`In-App Purchase`、`Sign in with Apple`（后者见第 3 节）。
- 记录 **App ID prefix（Team ID）** 与 App ID。

### 2.2 在 App Store Connect 创建 App
- 路径：App Store Connect → 我的 App → 新建 App（Bundle ID 选上面的 App ID，名称 MySpire）。
- SKU 任意填（如 `MySpire001`）。

### 2.3 协议、税务与银行业务（Agreements, Tax, and Banking）
- 必须先签署 **Paid Applications Agreement**（付费 App 协议），否则内购无法配置/收款。
- 填写 Tax（税务）、Banking（银行账户）信息，并提交合同审核（首次需 1~3 个工作日）。

### 2.4 配置 App 内购买项目（In-App Purchases）
- 路径：App 详情 → 功能（Features）→ App 内购买项目 → 创建。
- **产品 ID 必须与 `iap_products.json` 的 `apple_id` 完全一致**。清单如下：

| 产品 ID（`apple_id`） | 类型 | 价格（USD，参考） | 内部 SKU |
|---|---|---|---|
| `com.myspire.unlock_watcher` | 非消耗 | 2.99 | `unlock_watcher` |
| `com.myspire.remove_ads` | 非消耗 | 1.99 | `remove_ads` |
| `com.myspire.gold_small` | **消耗** | 0.99 | `gold_pack_small` |
| `com.myspire.gold_large` | **消耗** | 3.99 | `gold_pack_large` |
| `com.myspire.revive_token` | **消耗** | 0.99 | `revive_token` |
| `com.myspire.card_skin_gold` | 非消耗 | 1.99 | `card_skin_gold` |

> - 每个商品需填：Localization（App Store 本地化名称/描述）、Review Screenshot、定价（可勾选多地区自动换算）。
> - **付费等级表（Price Tier）确定后改价需重新提交**，请定稿后再设。
> - 消耗品对应客户端 `consume→finish_transaction`；非消耗品对应 `finish_transaction`（确认）＋ 不重复购买，见 `PaymentManager._handle_successful_purchase`。

### 2.5 签名 / 描述文件
- 证书：Apple Developer → Certificates → 生成 **Development** 与 **Distribution** 证书（.p12）。
- 描述文件：为 Debug 生成 Development Provisioning Profile、Release 生成 App Store Provisioning Profile（自动 App Store 分发无需上传，Xcode 自动管理）。

### 2.6 服务端验签（App Store Server API）
客户端生产环境需服务端校验收据（`NetworkClient.verify_purchase_receipt`，L24 注释：`/api/iap/verify/apple`）。

1. **Apple Developer**（可选但推荐）：确保 App 开通 **App Store Server Notifications V2**，便于退款/续订回调。
2. **App Store Connect**：Users & Access → Integrations（旧称 API 访问）→ 创建 **App Store Connect API Key**，角色取「Finance / App 内购买」，签发得到 **Issuer ID、Key ID、.p8 文件**。
3. 服务端用该 `.p8`（ES256）签发 JWT，调用 **App Store Server API**：
   - `GET /inApps/v1/transactions/{transactionId}` 查询交易；
   - `POST /inApps/v1/receipts/verify`（StoreKit 1 收据）校验；
   - 处理 `ServerNotificationsV2` 的退款/更新回调。`transactionId` 对应客户端 `purchase_token`（见 `PaymentManager._on_ios_purchase_success` 的归一化）。

### 2.7 测试与上线
- **Sandbox 测试**：TestFlight 分发给测试账号（未扣款，真实内购流程）。
- TestFlight：需要 `Build` 通过 App Store Connect 归档上传，并配置测试组。
- 上线：提交审核（App Review），需勾选内购/登录能力说明（可加 Review Notes 提升过审率）。

> 若未来迁移到 **StoreKit 2**，需另配 `com.apple.developer.in-app-payments` 等；当前代码走 StoreKit 1。

---

## 3. iOS 登录（Sign in with Apple）需要配置 —— Apple Developer + 服务端

客户端使用 `SignInWithApple` 插件单例（`AuthManager.gd` L56）。**Sign in with Apple 不使用 Google OAuth / GCP**，而是用 Bundle ID 作为 client_id，凭据由 Apple 签发。

### 3.1 在 Apple Developer 开启能力
- 路径：Identifiers → 选中你的 App ID → **Services** 勾选 `Sign in with Apple`（第 2.1 节 App ID 里一并开启）。
- 若在 iOS 9.0+ 上使用 sign-in-with-apple 按钮，需使用 `ASAuthorizationAppleIDProvider`（客户端插件内部处理）。

### 3.2 服务端用 Sign in with Apple 验签（无独立门户，服务端实现）
客户端回调拿到 `identityToken` / `authorizationCode`（对应 `AuthManager.gd` L165 的 `identity_token`）：

1. **ID Token 校验**：用 Apple 公开密钥（`https://appleid.apple.com/auth/keys` 的 JWKS）验 `identityToken` 签名，并核对 claims：
   - `iss` == `https://appleid.apple.com`
   - `aud` == bundle id `com.myspire.game`
   - `exp` / `nonce`（若客户端注入 nonce）
2. **授权码换身份（可选，个人资料服务）**：用 `authorizationCode` 调 `https://appleid.apple.com/auth/token` 换取 `id_token`/`refresh_token`，需客户端密钥。
   - 客户端密钥（client_secret）：Apple Developer → Keys → 生成 **Sign in with Apple key**（导出 `.p8`），用 ES256 按 JWT 格式（`iat`、`exp`、`sub`=Team ID、`iss`=Team ID、`aud`=`https://appleid.apple.com`、`kid`=Key ID）签名。
3. 服务端换得应用 JWT 后走 `AuthManager._complete_login`（L207）持久化。

### 3.3 测试
- 真机 + 测试 Apple ID（需在设备上登录该 Apple ID）。
- Sign in with Apple 支持匿名邮箱转发（`privaterelay@icloud.com`），服务端应兼容 `user_id` 稳定映射（客户端用 `user_id` 主键，见 `_normalize_user`）。

---

## 4. 一站式简化清单（Checklist）

### Apple Developer
- [ ] 创建 App ID：Bundle ID `com.myspire.game`，开启 **In-App Purchase** 与 **Sign in with Apple**
- [ ] 生成 Development / Distribution 证书（.p12）
- [ ] 生成 Development / App Store 描述文件
- [ ] 生成 **Sign in with Apple key（.p8）**（服务端换码用）
- [ ] 生成 **App Store Server Notifications V2** 相关配置（可选）

### App Store Connect
- [ ] 创建 App（名称 MySpire，Bundle ID `com.myspire.game`）
- [ ] 完成 **付费协议、税务、银行**（Paid Applications Agreement）
- [ ] 创建 **6 个 App 内购买项目**（产品 ID 与 `apple_id` 一致）
- [ ] 创建 **App Store Connect API Key**（.p8 + Issuer ID + Key ID，服务端验签用）
- [ ] 配置 TestFlight（Sandbox 测试）与提交审核

### 服务端
- [ ] 用 Apple JWKS 验 `identityToken`（`iss/aud` 校验）
- [ ] 用 `.p8` 客户端密钥完成授权码换 token（Sign in with Apple）
- [ ] 用 App Store Connect `.p8`（ES256 JWT）调 **App Store Server API** 验收据 + 处理退款回调

### 客户端
- [ ] 接入/编译 `SignInWithApple` 自定义 iOS 插件（Phase 2，当前为桩）
- [ ] `PaymentManager` 已用内置 `InAppStore`（StoreKit 1），无需额外插件
- [ ] 配置 iOS 导出模板 + Xcode 环境（`export_presets.cfg` preset.2 已含 `capabilities/in_app_purchases=true`、图标、`info.plist`）

---

## 5. 相关客户端关键位置

- 支付：`scripts/autoload/PaymentManager.gd` (L64 `InAppStore` 探测，L96 `apple_id` 翻译，L112 购买，L300 iOS 购买归一化)
- 登录：`scripts/autoload/AuthManager.gd` (L56 `SignInWithApple` 探测，L77 `login_with_apple`，L164 `_on_apple_sign_in_succeeded`)
- 验签/换token：`scripts/autoload/NetworkClient.gd` (L24 `verify_purchase_receipt`，L67 `exchange_auth_token`)
- 商品定义：`assets/content/iap_products.json`（`apple_id` 字段）
- 导出配置：`export_presets.cfg` preset.2（iOS Xcode Project）
