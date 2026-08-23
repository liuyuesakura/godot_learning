# 谷歌登录 / 谷歌支付 —— 管理后台与配置清单

> 适用项目：MySpire（包名 `com.myspire.game`，Godot 4.5 mono）
> 对应客户端代码：
> - 谷歌登录：`scripts/autoload/AuthManager.gd`（Phase 3，依赖 `GodotGoogleSignIn` 插件单例）
> - 谷歌支付：`scripts/autoload/PaymentManager.gd`（依赖 `GodotGooglePlayBilling` 插件单例）
> - 服务端验签：`scripts/autoload/NetworkClient.gd`（生产环境需在线验证，见 `verify_purchase_receipt` / `exchange_auth_token`）
> - 商品清单：`assets/content/iap_products.json`

---

## 1. 需要打交道的管理后台（共 2 个门户 + 1 个 API）

| # | 门户 / API | 入口 | 用途 |
|---|---|---|---|
| 1 | **Google Play Console** | https://play.google.com/console/ | 应用信息、内购商品、结算授权、Play Billing、发布与闭/内测、接受产品策略 |
| 2 | **Google Cloud Console (GCP)** | https://console.cloud.google.com/ | OAuth 2.0 客户端（谷歌登录）、Play Developer API 启用、Service Account |
| 3 | **Google Play Developer API** | （隶属于 GCP，密钥在 GCP 生成） | 服务端校验购买收据、做退款做账 |

> 关系：Google Play Console 负责「面向玩家」的应用与商品；Google Cloud Console 负责「身份与接口」的凭据与服务账号；服务端验签最终在 Google Cloud Console 落地。

---

## 2. 谷歌登录（Google Sign-In）需要配置 —— 全在 GCP

客户端逻辑：`_google.startSignIn()` 需传入 `server_client_id`（见 `AuthManager.gd` L74，当前为 Phase 3 桩）。服务端需用 `id_token` 换取应用 JWT。

### 2.1 创建/选择 GCP 项目
- 进入 Google Cloud Console → 项目 → 新建项目（或复用已有）。
- 记录 **项目 ID / 项目编号**，后续填到 Play Console 的「创建应用」/「API 访问」处。

### 2.2 配置 OAuth 同意屏幕（OAuth Consent Screen）
- 路径：APIs & Services → OAuth consent screen。
- 选择 **External**（外部用户）。
- 填写应用名称、支持邮箱、品牌 Logo 等。
- 添加测试用户（`Scopes` 仅需 `openid email profile`）。
- 发布状态：正式上线前可先设为 **Testing**；对生产改为 **In production**。
- 生成 **支持/隐私政策 URL** 备填。

### 2.3 创建 OAuth 2.0 客户端 ID（关键：两种类型）
- 路径：APIs & Services → Credentials → Create Credentials → OAuth client ID。

| 客户端类型 | 用途 | 关键填项 |
|---|---|---|
| **Web application**（或 Desktop） | 作为 `server_client_id`（服务端校验用） | 授权回调可按需填写 |
| **Android** | 供 `GodotGoogleSignIn` 在真机使用 | **SHA-1 证书指纹**（必填） |

**Android 端 SHA-1 获取**（两个都要加：debug + release）：
```bash
# Debug keystore
keytool -list -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey \
  -storepass android -keypass android | grep SHA1

# Release keystore（对应 build/keystore/myspire_release.keystore，密码用生成时的密码）
keytool -list -v -keystore "build/keystore/myspire_release.keystore" -alias myspire \
  -storepass <你的密码> | grep SHA1
```
- Debug 用 debug keystore 的 SHA-1，Release 用 release keystore 的 SHA-1，**两个客户端 ID 都建好并加到同一条 Android client 的 SHA-1 列表**（或各建一条，别搞混）。

### 2.4 回填到客户端 / 服务器
- 把 **Web/Desktop 对应的 client_id** 作为 `server_client_id` 传给 `startSignIn(server_client_id)`（需接入 GodotGoogleSignIn 插件，Phase 3）。
- 服务端拿到 `id_token` 后，用该 client_id 的 **客户端私钥**验签（Google 校验库），换取应用 JWT。

### 2.5 注意
- 谷歌登录**不需要**在 Google Play Console 做配置；只与 GCP 相关。
- 若国内/审核要求，可在 GCP 里补 **品牌验证（Brand Verification）**（只读范围可豁免）。

---

## 3. 谷歌支付（Google Play Billing）需要配置 —— Play Console + GCP

客户端使用 `GodotGooglePlayBilling` 连接、查询、购买、消费；`PaymentManager` 已将内部 SKU 与 `iap_products.json` 绑定。

### 3.1 在 Play Console 创建/完善应用
- 路径：主页 → 创建应用（包名 `com.myspire.game`，名称 MySpire）。
- 完成 **应用内容** 声明：数据安全、是否含广告（`remove_ads` 商品说明应用含广告，需如实填写）、目标受众、内容分级（IARC）。
- 填写 **隐私政策** URL、素材（截图、图标 512×512、Feature Graphic）。
- 进入内测前需填写「联系方式」。

### 3.2 创建应用内商品（In-App Products）
- 路径：应用 → 营收（Monetize）→ 应用内商品 → 创建产品。
- 商品 ID 必须与 `iap_products.json` 的 `sku` **完全一致**。清单如下：

| SKU（商品 ID） | 类型 | 价格（USD） | 内部定义 |
|---|---|---|---|
| `unlock_watcher` | 非消耗 | 2.99 | 解锁角色 |
| `remove_ads` | 非消耗 | 1.99 | 去广告 |
| `gold_pack_small` | 消耗 | 0.99 | +500 金币 |
| `gold_pack_large` | 消耗 | 3.99 | +2500 金币 |
| `revive_token` | 消耗 | 0.99 | 续命币（最大堆叠 3） |
| `card_skin_gold` | 非消耗 | 1.99 | 金色卡背 |

> - 消耗品（consumable）在客户端会被 `consumePurchase`；非消耗（non_consumable）走 `acknowledgePurchase`（对应 `PaymentManager._handle_successful_purchase`）。
> - **价格只能设一次**，改价需额外流程，定稿后再填。
> - 上线前可先在「内测/闭测」里跑真机购买验证。

### 3.3 启用 Play Billing 依赖（客户端已就绪）
- 客户端插件 `plugin.cfg` 声明 `GodotGooglePlayBilling`，`export_plugin.gd` 拉取依赖 `com.android.billingclient:billing-ktx:9.1.0`。
- 包内声明了权限 `com.android.vending.BILLING`（见 `export_presets.cfg` 的 `permissions/custom_permissions`），无需在 Console 重复配。

### 3.4 建立 GCP 关联 + Play Developer API + 服务账号（服务端验签必需）
客户端生产环境需服务端调用 **Google Play Developer API** 验签（`NetworkClient.verify_purchase_receipt`，L22 注释）。

1. 在 **GCP** 启用 API：APIs & Services → Enable APIs → **Google Play Developer API**。
2. 在 **Play Console**：设置 → API 访问 → 关联该 GCP 项目 → **创建服务账号**（创建后会得到 Service Account 邮箱）。
3. 在 **GCP**：IAM & Admin → Service Accounts → 为上述账号生成 **JSON 密钥**，下载交给服务端。
4. 在 **Play Console**：Users & permissions → 添加该服务账号，授予「查看财务数据 / 管理订单」等最小权限。
5. 服务端用 Google 客户端库 `androidpublisher` API：
   - 校验收据：`purchases.products.get(packageName, productId, purchaseToken)` → `purchaseState == PURCHASED`；
   - 确认消费：`purchases.products.acknowledge`（避免自动退款窗口）；
   - 记账：consume/退款处理。

### 3.5 测试与上线
- 使用 **License Testers**（Play Console → 设置 → 许可测试）即可不扣款测试内购。
- 发布通道：优先 **内部测试（Internal）/ 闭环测试（Closed）** 验证；再开放测试到 Production。
- 「计价地区」按需勾选；人民币/美元由 Play 自动换算。

---

## 4. 一站式简化清单（Checklist）

### GCP（Google Cloud Console）
- [ ] 创建/选择项目，记录项目 ID
- [ ] 配置 OAuth 同意屏幕（External）
- [ ] 创建 OAuth 2.0 客户端 ID：**Web**（作 server_client_id）
- [ ] 创建 OAuth 2.0 客户端 ID：**Android**（填 debug + release 两个 SHA-1）
- [ ] 启用 **Google Play Developer API**
- [ ] 为 Play Developer API 创建 **Service Account** 并导出 JSON 密钥
- [ ] （可选）品牌验证 / 隐私政策 URL

### Play Console
- [ ] 创建应用（包名 `com.myspire.game`）
- [ ] 完成应用内容声明（广告、数据安全、内容分级、隐私政策）
- [ ] 创建 6 个内购商品（与 `iap_products.json` 的 sku 一致）
- [ ] 设置 → API 访问：关联 GCP 项目，添加服务账号并授权
- [ ] 添加许可测试用户、上架/内测真机验证

### 客户端
- [ ] 接入 `GodotGoogleSignIn` 插件，填入 `server_client_id`（Phase 3）
- [ ] 补齐 `android/plugins/GodotGooglePlayBilling/bin/` 下的 `.aar`（当前缺失）
- [ ] 配置 release keystore + 密码（`build/keystore/`，见 `generate_keystore.bat`）
- [ ] 安装 Godot 4.x Android 导出模板、安装 Android SDK（当前缺失）

---

## 5. 相关客户端关键位置

- 登录：`scripts/autoload/AuthManager.gd`（L50 探测 `GodotGoogleSignIn`，L74 `startSignIn`，L207 `_complete_login`）
- 支付：`scripts/autoload/PaymentManager.gd`（L56 连接 Billing，L79 `purchase`，L351 `_handle_successful_purchase`）
- 验签/换token：`scripts/autoload/NetworkClient.gd`（L24 `verify_purchase_receipt`，L67 `exchange_auth_token`）
- 商品定义：`assets/content/iap_products.json`
- 导出配置：`export_presets.cfg`（权限、包名、Billing 插件）
