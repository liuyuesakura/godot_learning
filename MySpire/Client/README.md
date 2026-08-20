# MySpire Client — Godot 4 竖屏客户端原型

> 对应设计文档：`../KnowledgeBase/杀戮尖塔_游戏架构设计.md`（ADR 001–005）
> 支付系统文档：`../KnowledgeBase/杀戮尖塔_支付系统设计.md`（ADR 009–011）
> 打包构建指南：`../KnowledgeBase/杀戮尖塔_打包构建指南.md`
> 对应 UI 规范：`../UIUXDesign/UI设计系统.md`（720×1280 竖屏，碧蓝幻想风）

## 如何运行

1. 用 **Godot 4.3+**（标准版即可，无需 .NET 版——客户端逻辑全部为 GDScript 2.0）打开本目录的 `project.godot`。
2. 按 F5 运行。鼠标点击 = 触屏（已开启 emulate_touch_from_mouse）。
3. 商店画面在桌面端自动走**支付模拟器**（90% 成功率 + 延迟），无需 Android 设备即可测试 UI 和购买流程。

## 打包构建

```batch
REM 生成 Android keystore（首次）
build\generate_keystore.bat

REM 构建 Android APK (Debug)
build\build_android.bat debug

REM 构建 Android AAB (Release, 需先配 keystore)
build\build_android.bat release

REM 导出 iOS Xcode 工程
build\build_all.bat ios

REM 全平台构建
build\build_all.bat all
```

详见 `../KnowledgeBase/杀戮尖塔_打包构建指南.md`。

## 已实现范围（离线垂直切片 + IAP）

| 层 | 内容 |
|----|------|
| **完整 run 循环** | 主菜单 → 角色选择（菱形链 + 立绘背景 + 随机骰子）→ 地图（16 层分支路径）→ 战斗/篝火/宝箱/事件 → 卡牌奖励（可跳过）→ Boss → 远征结算 |
| **战斗系统** | 敌人意图明牌、3 能量、格挡/力量/虚弱/易伤、抽牌堆洗回、消耗、卡牌奖励三选一 |
| **3 个可玩角色** | 铁卫（红）/ 静默猎手（绿）/ 闪电法师（蓝）；观心者锁定占位 |
| **地图生成** | 每层 2–4 节点、分支连线、类型加权（战/精/火/事/宝/店/王） |
| **存档** | 继续/新远征；地图由种子确定性重建（不落盘） |
| **支付系统** | Google Play Billing（Android）+ StoreKit（iOS）+ 桌面模拟器三轨；商店画面 + 6 个商品 + 恢复购买；iOS 无需额外插件（InAppStore 内置于 Godot iOS 导出模板）|

## 未实装（占位或跳过）

- 观心者（姿态系统）、遗物效果（仅收藏）、药水、升级（篝火休息已实现，锻造未实装）
- NetworkClient 为桩——完全离线运行；服务端接入后再实现命令日志上报（ADR-004 的日志记录点在 `CombatState.play_card` / `end turn` 调用处）
- 支付服务端验证为桩（离线信任）；Android 真机需安装 GodotGooglePlayBilling 插件（见 `android/plugins/README.md`）；iOS 真机需在 App Store Connect 创建商品 + 沙盒测试（见支付系统文档第 8 章）

## 架构映射

```
Client/
├── project.godot            # 竖屏 720×1280 + 6 Autoload + Android 配置
├── scenes/main.tscn         # 唯一入口场景（屏幕容器）
├── android/plugins/         # GodotGooglePlayBilling 插件目录（见 README.md）
└── scripts/
    ├── main.gd              # 注册容器 → 进主菜单
    ├── autoload/            # GameManager / ContentRegistry / SaveManager / NetworkClient(桩) / RNGManager / PaymentManager(支付)
    ├── game/                # 纯逻辑层（零 UI 依赖，可脱离场景测试）
    │   ├── state/           # RunState（run 状态+序列化）、CombatState（战斗状态机）
    │   ├── combat/          # EffectResolver（效果解析）、EnemyAI（意图）、EnemyState
    │   ├── cards/           # CardInstance（运行时实例）、DeckManager（四区管理）
    │   └── map/             # MapGenerator（种子化分支地图）
    ├── ui/                  # 表现层（只依赖 game/ 层）
    │   ├── UITheme.gd       # 设计系统（色彩/组件/文案生成）
    │   ├── components/      # CardView、EnemyView（信号上抛，不直接改状态）
    │   └── screens/         # MainMenu / CharacterSelect / MapScreen / CombatScene / ShopScreen
    └── assets/content/      # 数据驱动内容 JSON（ADR-002）
```

### 关键设计落点

| 架构要求 | 实现位置 |
|---------|---------|
| 逻辑层不依赖 UI | `game/` 只引用 autoload 数据服务；UI 反向调用 `CombatState` |
| RNG 全受管（无裸 randi） | 所有随机走 `RNGManager.get_rng(channel)`；同 seed 同通道可复现 |
| 地图确定性 | `MapGenerator` 只吃种子化 RNG；存档只存玩家状态 |
| 场景切换统一管理 | 只有 `GameManager.change_screen()` 一个入口 |
| 敌人回合演出 | 逻辑同步（`begin_enemy_phase` / `execute_enemy_action` / `begin_player_turn`），表现层用 `await` 插帧 |
| 支付唯一入口 | UI 只调 `PaymentManager.purchase()`；插件实例不暴露给 UI |

### 数据驱动扩展

- 新卡牌：`assets/content/cards.json` 加一条 + 效果若已支持（damage/block/weak/vulnerable/strength/draw/energy/damage_all）即开即用
- 新效果：`EffectResolver.resolve` 的 match 加一个分支
- 新敌人/遭遇池：`enemies.json` 的 `enemies` / `encounters`
- 新角色：`characters.json`（`locked: true` 即为锁定槽）
- 新内购商品：`assets/content/iap_products.json` 加一条 + Google Play Console 创建相同 SKU

## 已知限制（按设计是刻意的）

- 手牌区横向滚动而非扇形展开（原型优先功能正确性）
- 地图全图可见（部分可见迷雾留待后续）
- 意图伤害显示含力量/虚弱修正，不含玩家易伤修正
- 支付桌面模拟器无法测试真实付款/退款流程（需 Android 真机 + 插件）
