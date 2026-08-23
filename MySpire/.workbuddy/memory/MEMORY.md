# MySpire 项目记忆

## 项目基本信息
- **项目路径**: D:\GodotProjects\godot_learning\MySpire\
- **项目类型**: 杀戮尖塔类 Roguelike Deckbuilder 游戏
- **技术栈**: Godot 4 (GDScript) 客户端 + C#/.NET 8 服务端
- **文档位置**: KnowledgeBase/ 目录下 5 份分析文档

## 核心架构决策
- 客户端权威 + 服务端验证（ADR-001）：回合制单机 roguelike 不需要服务端权威
- Host 权威联机模式（ADR-006）：复用 GDScript 逻辑层，is_multiplayer_authority() 切换单人/多人
- 数据驱动内容（ADR-002）：JSON 定义卡牌/敌人/遗物，双端共享
- 种子化确定性生成（ADR-003）：服务端可重放验证
- 三轨支付（ADR-011）：Android Billing + iOS StoreKit + 桌面模拟器
- 三轨登录（ADR-012 待写）：Google Sign-In + Sign in with Apple + 桌面模拟器，与支付同构（AuthManager 2026-08-22 Phase 1 落地）

## 文档体系
1. 杀戮尖塔_核心循环分析.md — 骨架层（4 不可拆卸内核 + 经济系统）
2. 杀戮尖塔_卡牌系统分析.md — 战术层（5 类型 + 7 设计模式）
3. 杀戮尖塔_Run探索循环分析.md — 战略层（7 节点 + 4 层张力）
4. 杀戮尖塔_游戏架构设计.md — 技术架构（5 ADR + 客户端/服务端分层）
5. 杀戮尖塔_多人联机架构设计.md — 联机架构（3 新 ADR + Co-op Run）

## 用户状态
- 用户尚未提供自己的游戏概念
- 已要求用户提供：概念一句话、品类平台、目标用户、单局时长
- 用户从 WorkBuddy 临时工作区迁移到正式 Godot 项目目录

## 构建环境（2026-08-21 已验证出包）
- Godot 4.7.1 mono：`D:\Program Files\Godot_v4.7.1-stable_mono_win64\`
- JDK 21（必须 17~21，JBR 25 不兼容 Gradle 8.11）：`C:\Users\amerhau\.jdks\jdk-21.0.12+8`（JAVA_HOME）
- Android SDK：`C:\Users\amerhau\AppData\Local\Android\Sdk`（API 37）
- Gradle 走腾讯镜像，Maven 走阿里云（~/.gradle/init.gradle）
- `.build_version` 必须放 `Client/android/`（build/ 的上级），内容 `4.7.1.stable.mono`
- 出包命令见 2026-08-21.md；首次构建 ~10 分钟

## 迁移记录
- 2026-08-15: 从 C:\Users\amerhau\WorkBuddy\2026-08-05-23-01-56\ 迁移至 D:\GodotProjects\MySpire\
- 2026-08-20: 从 D:\GodotProjects\MySpire\ 迁移至 D:\GodotProjects\godot_learning\MySpire\
