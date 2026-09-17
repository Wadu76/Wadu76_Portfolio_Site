---
title: 墙滑 + 蹬墙跳
date: 2026-08-22
category: unity
---

接上一篇状态机重构,这轮在轻量 switch 状态机(`Ground / Jump / Fall / Dash / WallSlide / WallJump`)上加了**墙滑**和**墙跳**。这一篇分三个主要内容:墙系统怎么加进状态机、"单方向贴图怎么对齐墙"的坑怎么用缩碰撞体解决、以及动画机怎么设过渡才不会抽搐。最后分析该不该改变为类状态机

## 墙检测

墙在身子的哪边,用一个函数返回 `-1 / +1  / 0`:分别对应在身体左/右/无

```csharp
private int GetWallSide()
{
    if (Physics2D.Raycast(wallCheckLeft.position,  Vector2.left,  wallCheckDist, wallMask)) return -1;
    if (Physics2D.Raycast(wallCheckRight.position, Vector2.right, wallCheckDist, wallMask)) return  1;
    return 0;
}
```
决策
1. **用射线,不用碰撞回调**。原因和可穿越平台系统正交——穿越平台是"竖直方向 + 切层",墙检测是"水平方向 + 射线",两套互不干扰,玩家平时是实体,贴墙检测可靠。

2. **检测点放身体中部**(两个空子物体),距离 0.25。太短贴不上,太长"空气抓墙"。

## 墙滑

**进入**:只在 Fall 状态里判——`下落中 && 按住朝墙 && 射线命中`。上升中绝不滑,这是蔚蓝的手感。因为 `ChangeState(WallSlide)` 只有这一处调用,所以动画机也只需要一条入口线(后面动画节讲)。

**慢滑**:不是直接设一个下滑速度,而是**重力缩到 0.4 + 把下落速度钳制在 -2**:

```csharp
// UpdateGravity:墙滑分支
else if (currentState == PlayerState.WallSlide) rb.gravityScale = wallSlideGravity; // 0.4

// UpdateWallSlide:
rb.velocity = new Vector2(0f, Mathf.Max(rb.velocity.y, wallSlideMaxFall)); // 钳制 -2
```

重力弱,所以从顶点开始慢慢加速;钳制在 -2,所以不会越滑越快。两个参数各管一件事,手感好调。

**朝向**:贴墙时面向墙外(看得见要跳去的地方),`UpdateCharacterFacing` 里墙滑状态覆盖输入翻转。

## 墙跳:弹离方向 + 强制移动窗口 + 松键宽容

**进入**:`TryStartJump()` 的第二档——相邻有墙 且(正按着朝墙 或 刚松开还在宽容窗口):

```csharp
wallSlide = GetWallSlide();
int side = wallSlide != 0 ? wallSlide : lastWallSide;
if (side != 0 && (horizontalMoveLastFrame == side || wallJumpGraceTimer > 0f))
{
    wallJumpDir = -side;
    wallJumpGraceTimer = 0f;
    ChangeState(PlayerState.WallJump);
}
```

**强制移动窗口**:墙跳设了速度后,还要有 0.16s 的 `wallJumpForceTimer`——窗口内忽略输入、一直弹离墙。否则水平速度会被每帧的移动逻辑立刻盖掉,弹离感就没了。

**松键宽容(手感的关键)**:墙跳要求"按住朝墙"才算数,但松开方向键的时机很容易失误。加了一个 `wallJumpGraceTimer`:扒在墙上时一直充满,松键/离墙后衰减 0.12s。窗口内按跳,哪怕已经不按方向、甚至刚飘离墙一丁点,墙跳照发,方向用记住的 `lastWallSide`。这是典型的输入宽容——**缓冲只加给"有精确时序的瞬时输入",持续条件状态(墙滑)不需要**。

## 美术向的坑:单方向贴图,怎么让手贴上墙

**问题**:墙滑贴图只有朝一个方向的(手贴墙那一侧)。`SpriteRenderer.flipX` 镜像后,另一侧手和墙之间留一道缝——镜像翻转的是贴图,碰撞体没跟着变,视觉和物理对不上。

**解法**:贴图保证一个方向完全对齐,然后把所有"能弹跳的墙"的**右侧碰撞体 x 尺寸缩小一点**,让玩家贴图刚好贴上墙边缘。碰撞体决定"玩家认为墙在哪",sprite 负责视觉贴住,两边各让一点;射线在身体中部,碰撞体缩一点不影响墙检测。

**局限**:单方向方案,另一侧靠缩碰撞体补偿,不是每个墙位都完美。干净的解法是双方向贴图,但这套在 demo 里够用——而且这个"视觉和物理各自妥协"的思路本身值得记一笔。

## 动画机:单状态 + 防抽搐过渡

**墙滑只有一个状态、一张图**。代码里 `WallSlide` 这一个状态就同时是"扒住 + 慢滑",蔚蓝本体也是"扒住即慢滑,一个状态一张图"。不需要"扒住"和"下滑"两个状态——`WallSlide` 是行为名(扒住后慢慢滑),不是姿势名。

**防抽搐的关键在过渡线都带 VelocityY 方向条件**:

```
Fall ──(IsWallSliding==true)──────────────────────→ WallSlide
WallSlide ──(IsWallSliding==false && VelocityY < -0.1)──→ Fall   ← 离墙下落
WallSlide ──(IsWallSliding==false && VelocityY >  0.1)──→ Jump   ← 墙跳跳走
```

两条出口线用 VelocityY 的正负把"墙跳跳走(向上)"和"离墙下落(向下)"**互斥分开**——否则 IsWallSliding 在顶点附近一抖,动画机就会在 WallSlide↔Fall 之间来回闪(抽搐)。入口只需要 Fall→WallSlide 一条,因为代码里墙滑只从 Fall 进。

墙跳动画直接复用 Player_Jump(`VelocityY > 0.1` 会自动切),不为墙跳单开动画状态——少一条触发线、少一个死状态。所有过渡 **Duration=0、Has Exit Time=关**(Unity 默认 0.25 + 开着,2D 动作一律要改)。

## 架构反思:墙跳能不能继承 Jump?

看到本篇的内容不少和Jump类似，那么就有个问题：墙跳和普通跳都清缓冲/土狼、都设上跳速度、都到顶点切 Fall,是不是该写成 `WallJump : Jump` 的类式继承?

**确实有能继承的关系**——但共享的部分只有约 5 行(清两个宽容计时器、设 `velocity.y`、`velocity.y<=0` 切 Fall),墙跳自己的主体是水平弹离 + 强制移动窗口,和 Jump 几乎不共享。为 5 行建一个基类 + 七八个文件,把"一个文件里的 switch 逐行可读"变成"散在多个文件、靠虚拟方法跳来跳去",可读性和面试可讲性都下降。

所以**判断标准还是状态机的篇:状态 ≤8、共享行为没长起来时,switch 更优**;等钩锁做完、共享行为真的多了,再演进化类式——那是正常演进。本人打算后面单独开个分支写一版练手,别替换跑得好好的主版本。（挖坑+1）

## 验收

1. 空中朝墙顶(按住方向)→ 贴墙缓滑,不越滑越快;松开 → 正常下落
2. 墙滑中按跳 → 弹离墙面(有强制移动窗口,不看输入)
3. 松方向键后 0.12s 内按跳 → 仍能墙跳(宽容生效)
4. 墙滑中按 K → 直接冲走
5. 滑到底触地 → 回 Ground;贴墙姿势全程不闪(动画不抽搐)
6. 回归:土狼 / 缓冲 / dash / 可穿越平台不受影响

下一步:钩锁,状态机加 `Grapple`。
