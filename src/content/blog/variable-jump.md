---
title: 可变跳跃高度实现
date: 2026-08-08
category: 手感
---
松开跳跃键时把上升速度减半，手感会更跟手。

- 按下跳跃：`velocity.y = jumpForce`
- 松开且仍在上升：`velocity.y *= 0.5`
- 空中再按无效（只允许一次跳）
