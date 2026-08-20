---
title: 全向冲刺的实现:dash 本体与三个特效
date: 2026-07-12
category: unity
---

这篇记录冲刺(dash)的完整实现:dash 本体,以及拉伸、残影、无敌三个特效。

## 需求与设计

冲刺的玩法定义:

- 地面和空中都能冲,全 8 向(8 个方向键 / 斜向都算,没按方向就朝面朝方向冲)。
- 冲刺期间速度全接管、直线不飘,且禁止跳跃。
- 三个手感特效:身体拉伸(squash & stretch)、残影(Ghost Trail)、无敌帧(闪烁提示)。
- 所有参数暴露在 Inspector,方便调手感。

对应的参数组(都在 Inspector 里):

```
dashSpeed = 15       冲刺速度
dashTime = 0.18      冲刺持续时间
dashCooldown = 0.4   冷却
dashStretch = 1.35   拉伸幅度(scale.x)
dashGravity = 0.5    冲刺期间重力缩放
dashGhostInterval = 0.03  残影生成间隔
dashIFrame = 0.3     无敌时长
dashBlink = true     无敌期间是否闪烁
```

## 结构决策:逻辑留在控制器,残影独立成组件

dash 的移动逻辑留在 `PlayerController` 里,因为它在冲刺期间每物理帧接管 `rb.velocity` 和 `gravityScale`,和移动、重力判断强耦合、执行顺序敏感。残影则抽成独立组件 `GhostTrail`,通过 public 方法 `SpawnGhost()` 被控制器调用——它只负责"生成一个残影并淡出",和 dash 本体解耦。

## 原理

冲刺用了一个协程 `DashRoutine` 做生命周期管理,而真正推着角色动的是 `FixedUpdate`:

- **协程管"按时间开/关状态"**:进入冲刺时打开 `isDashing` / `isInvincible`,等 `dashTime` 后关掉 `isDashing`,等剩余无敌时间后关掉 `isInvincible`。
- **FixedUpdate 管"每物理帧的力"**:只要 `isDashing` 为真,每帧把 `rb.velocity` 直接设成 `dashDirection * dashSpeed`,并对重力做缩放。

这样的分工让"什么时候冲"和"冲的时候怎么动"互不干扰。三个特效是三个独立协程,各自计时,并行执行。

## 实现

### 触发与方向

```csharp
void Update()
{
    // ... 移动输入、跳跃缓冲 ...
    if (Input.GetKeyDown(KeyCode.K) && !isDashing && dashCooldownTimer <= 0f)
    {
        StartCoroutine(DashRoutine());
    }
}

Vector2 GetDashDirection()
{
    Vector2 input = new Vector2(Input.GetAxisRaw("Horizontal"),
                                Input.GetAxisRaw("Vertical"));
    if (input == Vector2.zero)
    {
        input = new Vector2(sr.flipX ? -1 : 1, 0f); // 没按方向就朝面朝方向冲
    }
    return input.normalized;    // 归一化,不放大斜向速度
}
```

触发条件三连:`没在冲 && 冷却结束`,防止连按刷冲刺。方向用 `normalized`,否则斜向(对角)的位移会比水平/垂直方向大 √2 倍。

### 冲刺生命周期(协程)

```csharp
IEnumerator DashRoutine()
{
    isDashing = true;
    isInvincible = true;
    dashCooldownTimer = dashCooldown;
    dashDirection = GetDashDirection();
    anim.SetBool("IsDashing", true);

    // 并行启动三个特效
    StartCoroutine(StretchRoutine());
    StartCoroutine(GhostRoutine());
    StartCoroutine(BlinkRoutine());

    yield return new WaitForSeconds(dashTime);   // 冲刺本体

    isDashing = false;
    anim.SetBool("IsDashing", false);

    // 无敌持续到 dashIFrame,补上冲刺结束后的剩余时间
    yield return new WaitForSeconds(Mathf.Max(0f, dashIFrame - dashTime));
    isInvincible = false;
}
```

`isDashing` 是"冲刺中"的总开关,`isInvincible` 是"无敌中"的开关。无敌时间比冲刺长(`0.3 > 0.18`),所以分两段等。

### 物理帧里的速度接管

```csharp
void FixedUpdate()
{
    if (isDashing)
    {
        rb.gravityScale = dashGravity;               // 冲刺期间重力减半,抵消下落
    }
    // ... 重力、土狼/缓冲、跳跃 ...

    if (isDashing)
    {
        rb.velocity = dashDirection * dashSpeed;     // 全接管,保证直线不飘
    }
    else
    {
        rb.velocity = new Vector2(moveX * moveSpeed, rb.velocity.y);
    }
}
```

关键在"全接管":冲刺时每一物理帧都把速度设成固定值,玩家任何输入都改不了它,所以轨迹是笔直的,不会因为误按方向而飘。

### 特效一:拉伸(StretchRoutine)

冲刺前 30% 时间把 `scale.x` 拉长,后 70% 慢慢收回。**缩放必须基于 `baseScale`(Start 里存的原始缩放)**,否则会把历史拉伸累加起来越拉越长:

```csharp
IEnumerator StretchRoutine()
{
    float stretchDuration = dashTime * 0.3f;
    float t = 0f;
    while (t < stretchDuration)
    {
        t += Time.deltaTime;
        float k = Mathf.Clamp01(t / stretchDuration);
        Vector3 s = baseScale;
        s.x = baseScale.x * Mathf.Lerp(1f, 1f + dashStretch, k);
        transform.localScale = s;
        yield return null;
    }
    float relaxDuration = dashTime * 0.7f;
    t = 0f;
    while (t < relaxDuration)
    {
        t += Time.deltaTime;
        float k = Mathf.Clamp01(t / relaxDuration);
        Vector3 s = baseScale;
        s.x = baseScale.x * Mathf.Lerp(1f + dashStretch, 1f, k);
        transform.localScale = s;
        yield return null;
    }
    transform.localScale = baseScale;   // 保险:结束一定还原
}
```

### 特效二:残影(GhostTrail.cs)

残影是独立组件。`GhostRoutine` 在冲刺期间每隔 `dashGhostInterval` 调用一次 `SpawnGhost()`;`SpawnGhost` 生成一个临时的 SpriteRenderer 残影,复制本体的 sprite / 翻转 / 缩放(所以残影也会跟着拉伸),然后协程淡出并销毁:

```csharp
public void SpawnGhost()
{
    GameObject ghost = new GameObject("Ghost");
    ghost.transform.position = transform.position;
    ghost.transform.rotation = transform.rotation;
    ghost.transform.localScale = transform.localScale;  // 残影继承本体的拉伸

    SpriteRenderer g = ghost.AddComponent<SpriteRenderer>();
    g.sprite = sr.sprite;
    g.flipX = sr.flipX;
    g.sortingOrder = sr.sortingOrder - 1;   // 压在玩家下面一层
    g.color = ghostColor;

    StartCoroutine(FadeAndDestroy(ghost, g));
}

IEnumerator FadeAndDestroy(GameObject ghost, SpriteRenderer g)
{
    Color start = g.color;
    float t = 0f;
    while (t < ghostLifetime)
    {
        t += Time.deltaTime;
        g.color = new Color(start.r, start.g, start.b,
                            Mathf.Lerp(start.a, 0f, t / ghostLifetime));
        yield return null;
    }
    Destroy(ghost);
}
```

### 特效三:无敌闪烁(BlinkRoutine)

`isInvincible` 期间每 0.1s 隐藏/显示一次 SpriteRenderer,提示玩家处于无敌状态。结束时强制恢复显示,避免停在隐藏态:

```csharp
IEnumerator BlinkRoutine()
{
    while (isInvincible)
    {
        sr.enabled = !dashBlink;
        yield return new WaitForSeconds(0.1f);
        sr.enabled = true;
        yield return new WaitForSeconds(0.1f);
    }
    sr.enabled = true;
}
```

## 遇到的问题


### 1. 冲刺动画"糊"、收尾发黏:过渡时长大于冲刺时长

新建动画过渡默认 `Transition Duration = 0.25s`,而 `dashTime` 只有 0.18s——0.25s 的混合动画根本放不完,冲刺结束它还在从 Idle/Run 往 Dash 糊。改成 **`Has Exit Time` 关 + `Duration = 0`** 后,动画立即切换、干净利落。

### 2. 冲刺期间不能跳

冲刺时如果还能起跳,会和速度全接管冲突。起跳判定里加了 `!isDashing`:

```csharp
if (jumpBufferTimer > 0 && (isGrounded || coyoteTimer > 0f) && !isDashing)
```

## 小结

冲刺的实现拆成两层:**协程管"开多久"**(isDashing / isInvincible 的生命周期),**FixedUpdate 管"怎么动"**(每帧全接管速度保证直线)。三个特效各自独立协程并行,参数全部暴露在 Inspector 方便调手感。过程中踩的坑——协程没启动、类型编译顺序、过渡时长大于冲刺时长——都是"写了但没接到调度"这类问题的变体,排查时优先检查调度链。
