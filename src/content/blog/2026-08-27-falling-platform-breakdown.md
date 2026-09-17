---
title: 坠落平台
date: 2026-08-27
category: unity
reviewed: true
---

# 坠落平台(2026-08-27)

死亡循环之后的关卡构件:**玩家一碰(踩上去或墙滑贴上),平台延迟 0.5s 后下坠**。它是"会变的地形",让关卡编排"风险-回报"有了素材。这篇记机制 + 两个物理时序的坑。

## 设计决策

### 1. 接触延迟下坠 + 消失/保留两变体

- 触发:`OnCollisionEnter2D` 玩家身体接触平台(踩、墙滑贴都算)→ `Delay` 阶段 0.5s(震动 + 变红,玩家看得出要塌)→ `Falling` 下坠 `fallDistance` → 结束。
- **变体**:
  - `disappear=true` 掉落后消失(过 `resetTime` 秒或重生时重新出现);`disappear=false` 掉落后停在原地(保留)。
  - `shake`参数决定平台晃动与否，不过颜色渐变还是保留。
- 参数全 Inspector 暴露(delayBeforeFall / fallSpeed / fallDistance / disappear / resetTime / shake)。

### 2. 重生复位接 `IResettable`

坠落平台实现 `ResetLevelObject()`:回到初始位置、恢复颜色/sprite/collider、回 `Idle`。玩家死亡重生时由死亡循环的遍历统一复位(见死亡重生 devlog)。

## 踩的坑

### Lesson1:瞬间接触不触发塌落 —— 事件回调 vs 实时查询

**现象**:玩家"贴上平台瞬间就墙跳弹开"时,平台**偶尔不塌**。同样的操作,有时触发有时不触发——不稳定比不触发更糟。

**根因**:`OnCollisionEnter2D` 是**事件回调**——物理引擎在特定物理步里把"接触发生"排队才调它。接触只持续一个物理帧(贴上瞬间又弹开)时,这个事件上报**有时被时序吞掉**。所以同样的极短接触,落在物理步边界上就漏报。

**修法**:改用 **`col.IsTouching(playerCol)` 每帧实时查询**——每帧问"玩家现在接触吗",不依赖事件队列,瞬时接触也能抓住。Update 开头:

```csharp
if (state == State.Idle && playerCol != null && col.IsTouching(playerCol))
{
    state = State.Delay;
    timer = delayBeforeFall;
}
```

**教训**:"事件回调(Enter/Exit)"和"实时查询(IsTouching/Overlap)"是两套语义。**回调适合"持续状态变化的通知",查询适合"我就要这一刻的接触事实"**。对"瞬间也要可靠"的检测,查询比回调稳。

### Lesson2:震动反馈把 collider 也震了，视觉和物理要分离

**现象**:延迟阶段加的"震动 + 变红"反馈,用 `transform.position` 做水平抖动——**整个物体(含 Collider2D)跟着抖**,玩家在墙上墙滑/墙跳判定被震乱,手感稀烂。

**根因**:震动改的是本体 transform,collider 是本体的一部分,物理接触关系每帧被震。

**修法**:把 **SpriteRenderer 挪到子物体 `Visual`**,本体现在只留 Collider2D(不动),其他的prefab也按照这个改了。震动只改 `visual.localPosition`:

```csharp
visual.localPosition = new Vector3(Mathf.Sin(Time.time * 50f) * shake, 0f, 0f);   // 只震视觉
```

collider 稳稳在本体,物理判定不受影响,视觉照样震。

**教训**:这跟 PlayerController 的 `visual` 子物体是同一个思路——**表现跟物理分离,特效随便动 visual,物理永远稳**。这个项目已经第三次用到它了(玩家拉伸/dash、死亡动画、坠落平台震动)。

### Lesson3:停用的组件,重生时照样被复位 —— disabled ≠ 移出系统

**现象**:把一个平台取消勾选 `FallingPlatform`(想当普通静置平台用),玩家死亡重生后,这个平台**瞬移回出生点,和玩家挤在一起**。

**根因**:取消勾选只是让组件 disabled,它**仍然挂在场景里、仍然实现 `IResettable`**。而死亡重生的场景复位是:

```csharp
foreach (MonoBehaviour mb in FindObjectsOfType<MonoBehaviour>())
    if (mb is IResettable r) r.ResetLevelObject();
```

**`FindObjectsOfType` 会把 disabled 的 MonoBehaviour 也找出来**(它只要求 GameObject 是 active 的,不要求组件 enabled)。于是这个"停用的坠落平台"照样被复位 → `ResetLevelObject()` 把它拉回 `startPos`——如果它初始就摆在出生点附近,就和重生的玩家叠在一起。

**修法**:
- 真想让它当普通静置平台:组件右键 → **Remove Component**,它不再是 `IResettable`,遍历自然跳过。
- 当然如果想保留组件临时停用就可以在复位方法开头筛查一下:

```csharp
public void ResetLevelObject()
{
    if (!enabled) return;   // 停用的平台不随重生复位
    // ...原复位逻辑
}
```

**教训**:"停用组件"和"把它从系统里去掉"是两回事。凡是 `FindObjectsOfType` + 接口遍历的地方(这里是 `IResettable`),**disabled 的对象也会被拉进来**——想让它"不参与"就得在方法里自己守卫 `enabled`,或直接移除组件/对象。

## 验收

1. 踩上 → 震动变红(只震贴图不震物理)→ 延迟塌落 → 消失/保留。
2. 墙滑贴上 → 也触发。
3. **贴上瞬间墙跳弹开 → 平台照样塌**(IsTouching 修后不再偶发)。
4. 下坠中/塌落后玩家无法再站。
5. 死亡重生 → 平台复位。
6. 墙滑/墙跳手感不受震动影响。

## 反思与总结

两个坑其实是同一个主题的两面:**"物理可靠"和"视觉表现"是两回事**。检测用实时查询保可靠,表现用子物体保不干扰物理。做移动/关卡构件时,"哪些该动、哪些不该动(物理)、怎么让它们互不干扰"想清楚,能少踩很多坑。
有些事情就是这样，做的时候看起来复杂，多余。但实际上这些正是为你以后铺好的稳稳的地基。
