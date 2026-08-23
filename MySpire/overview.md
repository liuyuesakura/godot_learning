# MySpire 项目概述

> 基于 Godot 4 + C#/.NET 8 的杀戮尖塔类 Roguelike Deckbuilder 游戏项目

## 项目状态

### 已完成
- **设计分析体系**（5 份文档，位于 `KnowledgeBase/`）：
  - 杀戮尖塔核心循环、卡牌系统、Run 探索循环的完整拆解
  - 单机技术架构设计（Godot 客户端 + C# 服务端）
  - 多人联机架构设计（Co-op Run）
- **UI/UX 设计**（2 份产物，位于 `UIUXDesign/`）：
  - 竖屏交互式 HTML 原型（8 个核心画面，碧蓝幻想视觉风格）
  - UI 设计系统规范（色彩/字体/组件/布局/动效 + Godot 实现映射）
- **客户端工程**（Godot 4 GDScript，位于 `Client/`）：
  - 离线垂直切片：完整 run 循环（菜单→选角→地图→战斗→奖励→Boss→结算）
  - 7 Autoload + game 纯逻辑层 + ui 表现层 + JSON 数据驱动内容
  - Google Play Billing（Android）+ StoreKit（iOS）+ 桌面模拟器三轨支付系统
  - Google Sign-In + Sign in with Apple 三轨登录系统（Phase 1 抽象层 + 模拟器就绪，原生插件 Phase 2/3 接入）
  - **打包构建系统**：导出预设 + 自动化脚本（APK/AAB/IPA）+ 平台图标 + keystore 签名
  - 详见 `Client/README.md`

### 待开始
- 用户游戏概念验证（需用户提供：概念一句话、品类平台、目标用户、单局时长）
- 核心系统扩展：遗物效果、篝火锻造、药水、观心者
- C#/.NET 8 服务端工程（含 IAP 服务端验签）
- 联机原型（Co-op Run）
- Android 端 GodotGooglePlayBilling 插件安装与真机测试
- iOS 端 InAppStore 沙盒测试与 App Store Connect 商品创建

## 技术栈

| 层 | 技术选型 | 说明 |
|----|---------|------|
| 客户端引擎 | Godot 4.x (GDScript) | 场景树驱动，Autoload 单例架构 |
| 服务端 | C# / .NET 8 | Clean Architecture，REST + SignalR |
| 网络传输 | ENet (P2P) / 可选中继 | Host 权威模型，MultiplayerAPI |
| 数据格式 | JSON | 数据驱动内容系统，双端共享 Schema |
| 持久化 | SQLite (服务端) / JSON (客户端存档) | 元进度 + 单局存档 |

## 核心架构决策

| ADR | 决策 | 理由 |
|-----|------|------|
| 001 | 客户端权威 + 服务端验证 | 回合制单机 roguelike 不需要 PvP 实时同步 |
| 002 | 数据驱动内容架构 | JSON 定义卡牌/敌人/遗物，双端共享 |
| 003 | 种子化确定性生成 | 所有 RNG 受管，服务端可复现验证 |
| 004 | 命令模式状态变更 | 每次出牌 = 一个 Command，可回放验证 |
| 005 | Godot 场景树即状态机 | 原生场景切换替代外部状态机框架 |
| 006 | Host 权威（联机） | 复用 GDScript 逻辑层，零移植成本 |
| 007 | 快照 + RPC 混合同步 | 标量用 Synchronizer，复杂状态用 RPC |
| 008 | C# 服务端可选中继 | 解决 NAT 穿透，只转发不解析 |
| 009 | 桌面模拟器 + 平台插件多轨 | Android/iOS/桌面三轨，UI 开发不需要真机 |
| 010 | IAP 存档独立于 Run 存档 | 购买跨 run 持久，退款不影响 run 进度 |
| 011 | 三轨支付抽象 + SKU 双向映射 | 内部 SKU 统一标识，平台 ID 自动翻译 |

## 目录结构

```
D:\GodotProjects\godot_learning\MySpire\
├── KnowledgeBase/          # 设计分析与架构文档
│   ├── README.md           # 文档索引
│   ├── 杀戮尖塔_核心循环分析.md
│   ├── 杀戮尖塔_卡牌系统分析.md
│   ├── 杀戮尖塔_Run探索循环分析.md
│   ├── 杀戮尖塔_游戏架构设计.md
│   ├── 杀戮尖塔_多人联机架构设计.md
│   └── 杀戮尖塔_支付系统设计.md
├── UIUXDesign/             # UI/UX 设计产物
│   ├── UI原型_竖屏.html    # 交互式原型（8 画面）
│   └── UI设计系统.md       # 设计规范 + Godot 映射
├── Client/                 # Godot 4 客户端工程（离线垂直切片 + IAP + 打包构建）
│   ├── README.md           # 运行方式 + 架构映射
│   ├── project.godot       # 720×1280 竖屏 + 7 Autoload + Android/iOS 配置
│   ├── export_presets.cfg  # 导出预设（Android APK/AAB + iOS Xcode）
│   ├── .gitignore          # 忽略构建产物和签名文件
│   ├── build/              # 打包构建系统
│   │   ├── generate_icons.py      # 平台图标批量生成器
│   │   ├── generate_keystore.bat  # Android keystore 签名生成
│   │   ├── build_android.bat      # Android 构建 (APK/AAB)
│   │   ├── build_ios.sh           # iOS 构建 (Xcode/IPA/Archive)
│   │   ├── build_all.bat          # 全平台一键构建
│   │   ├── dist/                  # 构建产物输出
│   │   ├── keystore/              # 签名文件 (gitignored)
│   │   └── ios/                   # Xcode 工程输出
│   ├── assets/icons/      # 平台图标 (Android 3 + iOS 11 = 14 PNG)
│   │   ├── android/       # 192 主图标 + 432 自适应前景/背景
│   │   └── ios/           # 40-1024 全尺寸
│   ├── android/plugins/   # GodotGooglePlayBilling 插件目录
│   ├── scenes/ · scripts/ · assets/content/
├── .workbuddy/             # WorkBuddy 项目配置
│   └── memory/             # 项目工作记忆
└── overview.md             # 本文件
```

## 下一步

1. **用户提供游戏概念** → 用现有分析框架做适配验证
2. **初始化 Godot 项目** → 按架构文档搭建目录结构
3. **实现核心原型** → 战斗系统 + 卡牌系统 + 地图系统
4. **联机原型** → Co-op Run 最小可行实现
