---
title: 状态机重构
date: 2026-08-21
category: unity
---

这篇记录我把 `PlayerController` 从 flag 式控制器 重构为 轻量 switch 状态机 的完整过程:**为什么重构、每个功能怎么从旧代码搬进新架构、以及重构中踩的两个输入坑**。这是一次结构性重构——手感、行为完全不变,变的只是代码怎么组织。

## 为什么重构
flag 式到临界点了。
重构前的控制器是 300 行 flag 式:**没有"状态"这个概念**。一个方法里同时管移动、重力、跳跃缓冲、土狼、冲刺、下穿、动画——行为全靠 `isGrounded` / `isDashing` / `jumpBufferTimer` / `coyoteTimer` / `rb.velocity.y` 这一堆 flag 和瞬时值凑出来:

```csharp
// 重构前的样子(示意):一堆 flag 在 FixedUpdate 里纠缠
if (isDashing) { rb.gravityScale = dashGravity; }
else if (rb.velocity.y < 0f) { rb.gravityScale = baseGravity * fallMutiplier; }
else if (rb.velocity.y > 0f && !jumpHeld) { rb.gravityScale = baseGravity * jumpCutMultiplier; }
else { rb.gravityScale = baseGravity; }

if (jumpBufferTimer > 0 && (isGrounded || coyoteTimer > 0f) && !isDashing)
{
    rb.velocity = new Vector2(rb.velocity.x, jumpForce);
    jumpBufferTimer = 0f;
    coyoteTimer = 0f;
}

rb.velocity = new Vector2(moveX * moveSpeed, rb.velocity.y);
```

小规模没问题。但下一步要做**墙滑 / 墙跳 / 扒墙**,它们本质都是「新状态 + 状态转换」;再往后是钩锁(荡摆/附着/释放,强状态功能)。在 flag 式里加这些,每帧要多一堆 `isOnWall` / `wallSlideHeld` / `wallJumped` 的 if 去理状态优先级——逻辑会纠缠到没法调。**趁复杂度上来之前整理结构**,时机在可穿越平台写完、墙之前。

## 为什么用简洁 switch,而不是每状态一个类

两条路线:

- **轻量 switch**(选了):`enum PlayerState` + `ChangeState()` 集中切换 + `switch` 分发。单文件,逻辑集中,逐行可讲。
- **类式 State 模式**:每个状态一个类(基类 + 4~8 个子类 + 状态间引用)。扩展性好,但文件从 1 个变 8、9 个,间接层多。

选轻量的理由:

1. **规模**:现在 4 个状态,未来加墙、钩锁也就 7~8 个。switch 在 10 个以内完全 hold 住。
2. **收益**:类式的好处(状态行为多态复用、运行时动态替换状态)在「状态少、每个状态行为简单」的 demo 里**体现不出来**,纯增加书写成本。
3. **面试**:能逐行讲清"状态怎么划分、转换在哪判断、每个状态做什么";还能主动说出"我为什么用 switch、到什么规模会升级成类式"——**这种权衡意识本身就是加分项**,比"用了复杂方案但讲不透"强。

**后面也别怕重构**:真到了状态 >10、要共享行为的时候,再演进成类式,那是正常演进,不是推倒重来。

## 目标架构

```csharp
enum PlayerState { Ground, Jump, Fall, Dash }   // 预留:WallSlide, WallJump, Grapple
```

三个核心:

- `PlayerState currentState` — 当前状态
- `float stateTime` — 状态内计时(目前只有 Dash 用)
- `ChangeState(PlayerState next)` — **唯一**的状态切换入口,「进入状态要做的事」(enter 行为)全放这里

```
                ┌───────┐      落地      ┌──────┐  速度≤0   ┌──────┐
   起跳(缓冲/土狼)→ │ Ground│ ←───────── │ Fall │ ←──────── │ Jump │
                └──┬────┘           └──┬───┘ └────┬─────┘
                   │                   │          │
                   └──── 冲刺触发(K) ──┴──────────┴──→ ┌──────┐
                                                       │ Dash │
                                                       └──────┘
```

FixedUpdate 每帧的流程重组:

```csharp
void FixedUpdate()
{
    UpdateGravity();   // ① 重力(只看速度和输入,与状态正交)
    isGrounded = Physics2D.OverlapCircle(...);   // ② 地面检测 + 土狼计时
    if (isGrounded) coyoteTimer = coyoteTime; else coyoteTimer -= Time.deltaTime;

    if (!TryStartDash()) TryStartJump();   // ③ 通用转换:冲刺优先于起跳

    switch (currentState)                  // ④ 按当前状态分发
    {
        case PlayerState.Ground: UpdateGround(); break;
        case PlayerState.Jump:   UpdateJump();   break;
        case PlayerState.Fall:   UpdateFall();   break;
        case PlayerState.Dash:   UpdateDash();   break;
    }

    anim.SetBool("IsGrounded", isGrounded);   // ⑤ 动画参数(仍放末尾)
    anim.SetFloat("VelocityY", rb.velocity.y);
    anim.SetBool("IsDashing", currentState == PlayerState.Dash);
}
```

**输入采集全在 Update,状态逻辑全在 FixedUpdate**。Update 只负责把"按键瞬间"变成持久一点的东西(缓冲、dashPressed),FixedUpdate 里才消费——这是重构后最关键的时序约定。

## 每个功能怎么搬

以跳跃为例。跳跃最能说明 **判断** 和 **动作** 怎么分离。重构前, 能不能跳 和 跳了干嘛 揉在一个 if 里;重构后拆成两半:

**能不能跳 → `TryStartJump()`,在状态分发前统一判断。** buffer 和 coyoteTimer 这两个宽容窗现在都在这一个方法里:

```csharp
private bool TryStartJump()
{
    if (jumpBufferTimer > 0f && (isGrounded || coyoteTimer > 0f)
        && currentState != PlayerState.Dash)
    {
        ChangeState(PlayerState.Jump);
        return true;
    }
    return false;
}
```

**跳了干嘛(设速度) → 挪进 `ChangeState(Jump)` 的 enter 行为:**

```csharp
void ChangeState(PlayerState next)
{
    currentState = next;
    stateTime = 0f;
    if (next == PlayerState.Jump)
    {
        rb.velocity = new Vector2(rb.velocity.x, jumpForce);   // 设跳跃速度在这
        jumpBufferTimer = 0f;   // 清缓冲也在这
        coyoteTimer = 0f;       // 清土狼也在这
    }
    else if (next == PlayerState.Dash)
    {
        // 冲刺 enter:设 isDashing/isInvincible/冷却/方向,启动特效协程
    }
}
```

**输入判断的"口"还在 Update**(`jumpBufferTimer` 由按跳设置、递减都在 Update),只是它只负责攒缓冲。判断和动作分开后,状态切换有了唯一入口——将来加 double jump / 墙跳,就是"加一个新的转换条件",起跳动作本身不用动。

其他状态类似地搬:

- **移动**:同一句 `rb.velocity = new Vector2(moveX * moveSpeed, rb.velocity.y)` 在 Ground/Jump/Fall 三个状态方法里各写一次;Dash 不写,由 `UpdateDash` 接管。
- **转换**:Ground 走出平台边(`!isGrounded && velocity.y<0`)→ Fall;Jump 到顶点(`velocity.y<=0`)→ Fall;Fall 触地 → Ground。
- **重力**:原样搬进 `UpdateGravity()`,唯一变化是 `isDashing` 换成 `currentState == Dash`。它和状态机正交,所以留在分发之前。
- **动画**:唯一变化是 `IsDashing` 变成 `currentState == Dash`,动画机一个字没动。

## dash:从协程到状态

重构前 dash 是一个协程,时间线全在 `WaitForSeconds` 里:

```csharp
IEnumerator DashRoutine()
{
    isDashing = true; isInvincible = true;
    dashCooldownTimer = dashCooldown;
    dashDirection = GetDashDirection();
    anim.SetBool("IsDashing", true);
    StartCoroutine(StretchRoutine()); StartCoroutine(GhostRoutine()); StartCoroutine(BlinkRoutine());
    yield return new WaitForSeconds(dashTime);
    isDashing = false; anim.SetBool("IsDashing", false);
    yield return new WaitForSeconds(Mathf.Max(0f, dashIFrame - dashTime));
    isInvincible = false;
}
```

重构后,dash 成为状态,**时间改用 `stateTime` 计时**(不再靠协程),特效协程原样保留:

```csharp
private void UpdateDash()
{
    stateTime += Time.fixedDeltaTime;
    rb.velocity = dashDirection * dashSpeed;
    if (stateTime >= dashTime)
    {
        isDashing = false;
        anim.SetBool("IsDashing", false);
        invincibleTimer = dashIFrame - dashTime;   // 无敌延续(原来由协程管)
        if (isGrounded) ChangeState(PlayerState.Ground);
        else ChangeState(rb.velocity.y > 0f ? PlayerState.Jump : PlayerState.Fall);
    }
}
```

关键点:**特效协程一字没动**——`GhostRoutine` 靠 `while (isDashing)` 退出、`BlinkRoutine` 靠 `while (isInvincible)` 退出,状态机在 enter/exit 里正确维护这两个 bool,协程自己会自然结束。这就是"时间管理归状态机,表现层(拉伸/残影/闪烁)归协程"的边界。

## 重构中踩的两个坑

都出在同一处:**「Update 采集、FixedUpdate 消费」的时序约定**。两个本质上都是设计时没想好时序。

### 坑 1:dashPressed 采集竞态——按键被下一次 Update 覆盖

**现象**:重构后 dash 完全/偶尔触发不了,其他(移动/跳跃)都正常。

**原因**:`dashPressed = Input.GetKeyDown(KeyCode.K)` 是**每帧覆盖**赋值,消费在 FixedUpdate。但物理步进 50Hz、渲染 60fps——**不是每个渲染帧都会跑 FixedUpdate**。按下 K 那一帧的 Update 设了 `dashPressed=true` 后,如果下一次 FixedUpdate 之前又夹了一次 Update,那次 Update 里 `GetKeyDown` 已经变 false(只在按下那帧为 true)→ **按键被覆盖丢失**。

**修复**:累积 + 消费端清除,而不是每帧覆盖:

```csharp
// Update 里:
dashPressed = Input.GetKeyDown(KeyCode.K) || dashPressed;   // true 后保持,直到被消费

// TryStartDash 里:
if (!dashPressed) return false;
dashPressed = false;   // 消费掉
if (currentState != PlayerState.Dash && dashCooldownTimer <= 0f) { ChangeState(...); }
```

### 坑 2:先清除、又在条件里判断

**现象**:修完坑 1,依旧完全无法 dash。

**原因**:消费清除之后,条件里还写着 `dashPressed &&`:

```csharp
dashPressed = false;                                      // 先清掉了
if (dashPressed && currentState != Dash && cooldown <= 0) // 又拿它做判断 → 永远 false
```

`ChangeState(Dash)` 永远执行不到。**变量状态在逻辑中途被改、后面又拿它做判断,顺序一错就静默失效。**

**修复**:消费后条件不再判断 `dashPressed`。

这两个坑的价值在调试习惯:改完一段逻辑,要顺着变量的生命周期读一遍——**它在哪里被设、哪里被消费、消费后还会不会出现在别的判断里**。这类 bug 编译器不报,只能靠"读变量轨迹"排查。

## 总结:够用了,别怕重构

现在 4 个状态的 switch 状态机,逐行能讲,面试能讲清"为什么用这个、什么情况下会升级"。**它现在完全够用,不是为了展示深度而过早用复杂架构。**

接下来的路:墙滑 / 墙跳 / 扒墙 = 加两个 enum 值 + 两个状态方法 + 几个转换条件(墙检测用水平射线,和可穿越平台正交);钩锁 = 加一个 `Grapple` 状态。真到了状态 >10、需要共享行为的时候,再演进成类式——那是正常演进,不是推倒重来。现在选的简单方案,正是为了那时候的演进留了清晰的边界。
