---
title: 全 8 向冲刺的实现记录
date: 2026-08-12
category: unity
---
冲刺方向来自输入向量，归一化后叠加到速度上。

```csharp
Vector2 dir = new Vector2(Input.GetAxisRaw("Horizontal"),
                          Input.GetAxisRaw("Vertical"));
if (dir.sqrMagnitude > 0) {
  rb.velocity = dir.normalized * dashSpeed;
}
```
