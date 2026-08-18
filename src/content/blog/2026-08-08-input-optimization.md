---
title: 移动输入优化
date: 2026-07-08
category: unity
---

这篇记录 2D 移动输入的一次重构:把左右移动的输入从轴输入(GetAxisRaw)改成"最后按下的键优先"(last-pressed-wins),解决转向时闪一帧 Idle 的问题。

## 问题:一直往右跑,突然按左,角色闪一帧 Idle

现象很具体:角色匀速向右跑,这时按下左方向,画面里角色会先闪一下站立的 Idle 动画,再转身往左跑。这一闪极短,但肉眼能察觉,手感上就是"一顿"。

## 原理:轴输入在转向时必然经过 0

先看移动和动画是怎么连起来的:

- 移动输入由水平轴提供,值域是 -1 / 0 / 1。
- 动画机里 Idle 和 Run 由参数 `Speed` 驱动:`Speed > 0.1` 进 Run,`Speed < 0.1` 回 Idle。`Speed` 取的是 `|水平输入|`。

问题就在这:角色往右跑时轴值是 1,突然按左,轴值要从 1 变成 -1,**中间必然经过 0**。经过 0 的那一帧,`Speed = 0`,动画机判定"停下来了",切入 Idle;下一帧值变成 -1,又切回 Run。于是闪一帧 Idle。

这个 0 是"两个键在极短时间内被先后按下"这种操作在数学上不可避免的中间态,和玩家无关——他按左就是想转向,游戏却先播放了一帧"停住"。

顺带说 GetAxis(带平滑的版本):它内部有加速度和摩擦力,手感偏"黏",转向更迟钝,同样躲不过 0 值瞬间,只是把问题藏在了平滑曲线里。

## 解决思路:不从动画侧补丁,从输入源头消掉 0

一开始想过在动画侧解决,比如给 Idle 到 Run 加一个短过渡或者放宽条件。但这等于"用动画掩盖输入缺陷":输入本身仍然在转向时经过了 0,只是让动画别那么明显。更干净的做法是**让水平输入在转向时根本不经过 0**——值从 1 直接跳到 -1。

## 实现:`OptimizedInput()`

核心是一个持续存在的状态 `horizontalMoveLastFrame`,它不再是"读取轴值",而是**由按键事件自己维护**,规则只有两条:

1. **按下**:谁后按,谁生效(最后按下的键优先)。
2. **松开**:先问另一边是否还按着——还按着就切到那边,否则归 0。

```csharp
public float horizontalMoveLastFrame;

void OptimizedInput()
{
    // 按下：谁后按谁生效（"最后按下的键优先"）
    if (Input.GetKeyDown(KeyCode.A))
        horizontalMoveLastFrame = -1;
    if (Input.GetKeyDown(KeyCode.D))
        horizontalMoveLastFrame = 1;

    // 松开：问"另一边是否还按着"——还按着就切到那边，否则停下
    // 注意用 GetKey（查"按住"），不能用 GetKeyDown（只在一帧内为 true）
    if (Input.GetKeyUp(KeyCode.A))
        horizontalMoveLastFrame = Input.GetKey(KeyCode.D) ? 1 : 0;
    if (Input.GetKeyUp(KeyCode.D))
        horizontalMoveLastFrame = Input.GetKey(KeyCode.A) ? -1 : 0;
}
```

它只在 `Update` 里跑,结果被两处消费:

```csharp
void Update()
{
    OptimizedInput();
    // ... 跳跃缓冲、冲刺冷却 ...
    UpdateCharacterFacing(horizontalMoveLastFrame);   // 朝向 + Speed 动画参数
}

void UpdateCharacterFacing(float moveX)
{
    if (moveX != 0) sr.flipX = moveX < 0;
    anim.SetFloat("Speed", Mathf.Abs(moveX));
}

void FixedUpdate()
{
    float moveX = horizontalMoveLastFrame;
    // ... 重力、土狼/缓冲、冲刺 ...
    rb.velocity = new Vector2(moveX * moveSpeed, rb.velocity.y);   // 只改 X,保留 Y
}
```

这样当角色按住 D(值 1)时按 A,值直接从 1 变成 -1,`|值|` 全程是 1,`Speed` 永远是 1,动画不会经过 Idle。

## 两个容易踩的点

**松开键时要用 `GetKey`,不能再用 `GetKeyDown`。** `GetKeyDown` 只在"按下那一帧"返回 true,之后立刻变回 false;而松开检测发生在 `GetKeyUp` 那一帧,此时再用 `GetKeyDown` 查另一边的按键,永远查不到(它只在按下帧为真)。`GetKey` 查的是"此刻是否按住",才能正确回答"松开 A 时 D 还按着吗"。

**这个函数只负责输入状态,不直接改物理。** 它把结果存在 `horizontalMoveLastFrame` 里,由 `FixedUpdate` 每物理帧消费。输入采样在 `Update`(跟随帧率),物理消费在 `FixedUpdate`(固定 50Hz),两者解耦——按键永远不丢,物理速度永远一致。

## 小结

转向闪 Idle 的根源是轴输入在转向时必然经过 0,而动画恰好以 0 为 Run/Idle 的判据。与其在动画侧掩盖,不如让输入状态根本不产生 0 值瞬间——"最后按下的键优先"直接把 1 和 -1 之间的中间态消灭在输入源头。这也让输入状态变成"谁后按谁生效"的明确语义,后续加移动功能时更可控。
