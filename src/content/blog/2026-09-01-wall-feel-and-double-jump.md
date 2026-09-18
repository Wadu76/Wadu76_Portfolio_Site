---
title: 让扒墙更顺:默认贴墙 + 多段跳的扩展
date: 2026-09-05
category: unity
reviewed: true
---

续《[墙滑与墙跳](/blog/2026-08-22-wall-slide-wall-jump/)》的一次手感改造。原来墙滑是"主动贴墙"——要按住朝墙方向才扒得上去;我改成"默认贴墙"——扒上墙后**只要不按远离墙的方向,就持续扒着缓慢下落,不用按住朝墙也能跳**。这篇记三处判定改动、一个 `||`/`&&` 的逻辑坑,以及这次改动顺手想清楚的多段跳设计(它和冲刺次数的系统是同一个套路)。

## 为什么改

原手感烦的点:墙在右边,得**一直按住 D** 才扒着;一旦松键就掉下去;想墙跳还得按住朝墙方向再按跳。对"贴着墙观察/等时机"这种动作很不宽容。
再次体验了Celeste和灾厄逆刃，墙爬还是得爽，有些机能不能限制太狠了，只会一味限制只能说明我对自己搭关卡没信心。

因此本篇讲的就是改成如下墙爬:
1. 扒上墙后,**松手也扒着**,缓慢下落。
2. 想走开才需要按**远离墙**的方向。
3. 扒着的时候,不用特意按朝墙方向,按跳就是墙跳。

**贴墙是默认状态,离开是主动动作**

## 三处判定改动

全部在 `PlayerController.cs`,每处一行的规模。

方向约定:墙在左 `wallSlide = -1`,朝墙方向就是 `wallSlide`,远离墙方向是 `-wallSlide`。

### ① 进入墙滑:从"按住朝墙"改成"碰到就贴"

```csharp
// 旧:if (wallSlide != 0 && horizontalMoveLastFrame == wallSlide)
if (wallSlide != 0)   // 下落中碰到墙就贴,不再要求按住朝墙
```

### ② 留在墙滑:从"松键就走"改成"按反方向才走"

```csharp
// 旧:if (wallSlide == 0 || horizontalMoveLastFrame != wallSlide)
if (wallSlide == 0 || horizontalMoveLastFrame == -wallSlide)   // 没墙 或 按了远离墙 → 才脱落
```

### ③ 墙跳:从"按住朝墙"改成"没按远离墙就行"

```csharp
// 旧:if (wallSlide != 0 && (horizontalMoveLastFrame == wallSlide || wallJumpGraceTimer > 0f))
if (wallSlide != 0 && horizontalMoveLastFrame != -wallSlide)   // 挨着墙 且 没按远离墙 → 可墙跳
```

## `||` 写成了该 `&&`

改动时把 ③ 想错了一个符号:

```csharp
if (wallSlide != 0 || horizontalMoveLastFrame != -wallSlide)  
```

**现象**:玩家按住 A/D(任意方向),就能无限起跳。

**为什么 `||` 会这样**:`||` 是"两个条件满足一个就算"。
- **没墙时**:`wallSlide != 0` 为 **false**;
- 但只要按住方向键,`horizontalMoveLastFrame != -wallSlide`(= 方向 ≠ 0)就是 **true**;
- 于是**没墙 + 按住方向也进墙跳分支** → 每次都 `ChangeState(WallJump)` 给一记跳跃 → 一直跳。

**修复**:`||` 改回 `&&`(有墙 **且** 没按反方向):
```csharp
if (wallSlide != 0 && horizontalMoveLastFrame != -wallSlide)
```

这种bug只能靠亲身测试出来，且很容易出这种逻辑错误。每行判定代码的改动都得想清楚再改。


## 多段跳？

这次改动让我重新看了跳跃的部分,多段跳其实不需要一堆参数，只需要和冲刺次数一模一样的"上限 + 剩余"模式:

**1. PlayerStats 加上限:**
```csharp
public int maxJumps = 1;   // 1 = 单段;以后改成 2 就是双段跳
```

**2. PlayerController 记录下:**
```csharp
private int maxJumps;    // 上限,每次 RecalculateStats 重算
private int jumpsLeft;   // 当前还剩几次可跳
```

**3. 充能与消耗三处:**
- 充能:地面/土狼状态时 `jumpsLeft = maxJumps`;
- 放宽起跳条件:能跳 = `isGrounded || coyoteTimer > 0 || jumpsLeft > 0`(第三项就是"空中还能再跳");
- 起跳消耗:`jumpsLeft--`。

**4. 物品加成**:想在 SO 物品系统里加"额外跳跃",和 `dashBonus` 一字不差:
```csharp
// ItemDefinition / IItemEffect 加 int JumpBonus
// RecalculateStats:maxJumps = baseStats.maxJumps; ... maxJumps += e.JumpBonus;
```

这个扩展不是"加 N 个布尔/每个额外跳一个字段",而是把"跳跃"从"一次性的地面事件"升级成"可消耗的次数资源"。这类"次数型能力"(dash、未来的跳跃、甚至受击无敌次数)都该用这一个模式——SO 存上限、账本存剩余、效果用加法叠上限。系统统一。

## 反思与总结

- **默认贴墙 = 三处一行改动**,但它是手感取向选择,改完整墙手感重过。
- 判定条件里的 **`&&`/`||` 最坑**:编译器不报、运行不报,却让你"没墙也能跳"。改条件先过一遍逻辑语义。
- 多段跳,其实就是**把跳跃升级成"上限 + 剩余"**,天然融入已有 SO 加法加成(dashBonus 同款)。
