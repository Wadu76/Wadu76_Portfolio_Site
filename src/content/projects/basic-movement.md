---
title: Risk Of Portal
subtitle: 2D 平台动作小游戏 — 移动手感 · 收集装备 · 关卡流程
date: 2026-09-01
tech: [Unity, C#, 2D, ScriptableObject, Editor Tooling]
cover: /media/images/basic-movement.svg
video: /media/videos/demo.mp4
gallery:
  - /media/architecture/basic-movement-preview.png
featured: true
---

从"移动手感 demo"一路做成的完整 2D 平台动作小游戏:以移动手感为壳,叠加收集/装备、死亡重生、关卡流程与存档。全部系统在 Unity 2022 中从零实现,每一步的设计取舍与踩坑都记录在下面的技术博客里。
游戏demo中的demo下载地址：https://github.com/Wadu76/Wadu76_2D_Platform_Unity_Demo/releases/tag/game

## 内容

- **移动手感**:轻量 switch 状态机(Ground / Jump / Fall / Dash / WallSlide / WallJump)。土狼时间、跳跃输入缓冲、可变重力、墙滑墙跳、可穿越平台;数值全部走 ScriptableObject + 全量重算,调手感不碰代码。
- **收集与装备**:物品用 SO 定义,`IItemEffect` 接口统一装卸。装备效果乘法叠加,装卸顺序无关、卸下必定还原。
- **游戏循环**:伤害 / 死亡 / Checkpoint 重生,`IResettable` 统一复位场景物体;单场景三关 + 终点门黑屏转场;PlayerPrefs + JSON 存档(关卡 / 出生点 / 背包 / 装备)。
- **关卡工具(自研 EditorWindow)**:网格吸附、轴向阵列复制、对齐与等间距、批量设置 Layer,全部接入 Undo。一段 30+ 平台的搭建从十几分钟压到几秒。


## 深入阅读

**移动与手感**
- [输入优化:最后按下的键优先](/blog/2026-08-08-input-optimization/)
- [可变跳跃高度](/blog/2026-08-08-variable-jump-height/)
- [冲刺(Dash)实现](/blog/2026-08-12-dash-implementation/)
- [土狼时间与输入缓冲](/blog/2026-08-17-coyote-time-jump-buffer/)
- [墙滑与墙跳](/blog/2026-08-22-wall-slide-wall-jump/)
- [让扒墙更顺:默认贴墙 + 多段跳的扩展](/blog/2026-09-01-wall-feel-and-double-jump/)
- [角色卡在墙角](/blog/2026-09-16-wall-corner-stuck/)

**架构与系统**
- [状态机重构:从 flag 式到 switch 状态机](/blog/2026-08-21-state-machine/)
- [背包系统开发](/blog/2026-09-01-inventory-system/)
- [加成物品如何施加到角色](/blog/2026-09-01-item-effects-on-player/)
- [死亡与重生(存档点)](/blog/2026-08-27-checkpoint-death-respawn/)
- [跨关与存档](/blog/2026-09-01-level-transition-and-save/)
- [拾取物重生导致背包重复](/blog/2026-09-16-pickup-respawn-duplicate/)

**关卡与环境**
- [坠落平台](/blog/2026-08-27-falling-platform-breakdown/)
- [可穿越平台](/blog/2026-08-19-one-way-platform/)
- [视差与无限背景](/blog/2026-08-17-infinite-background-parallax/)

**工具**
- [自研关卡编辑器工具](/blog/2026-09-16-editor-tools/)

## 技术栈

Unity 2022 · C# · ScriptableObject · uGUI · TextMeshPro · Physics2D · PlayerPrefs / JSON · Editor Tooling
