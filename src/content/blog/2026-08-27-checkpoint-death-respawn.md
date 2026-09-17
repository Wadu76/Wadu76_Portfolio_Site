---
title: 死亡与重生(存档点)
date: 2026-08-27
category: unity
reviewed: true
---

接状态机重构之后的另一块地基:**"玩家会死、死了回到最近存档点重来"**。没有它,关卡里的一切(尖刺、坠落平台、需要技巧的跳跃)都没意义了。这篇记三个设计决策,以及纯代码弄的"死亡动画/重生弹入"。

## 设计决策

### 1. 死亡不进状态机,用 `isDead` bool + 协程

状态机已经有 6 个状态。死亡为什么不加 `Dead` 状态?

**状态机装的是"可操作的行为"**——每个状态有输入响应、有转换条件、会被别的状态切走。而死亡是一段**玩家没有任何操作**的固定流程:播死亡表现 → 等 0.5s → 重生。这不是"行为",是"流程",用协程表达最自然:

```csharp
isDead = true;
// Update/FixedUpdate 顶部:if (isDead) return —— 挡掉一切输入和物理
StartCoroutine(DeathRoutine());   // 压扁消失 → 0.5s → Respawn()
```

如果硬加 `Dead` 状态,要动整个 switch:每个状态都要加"→ Dead"的转换,侵入大、收益小。**能用简单流程表达的,别塞进复杂框架。**

### 2. 重生点用静态类 `GameState`,不用单例

重生点就是"一个坐标,一个布尔标记"。`GameState` 静态类只存:

```csharp
public static Vector3 spawnPoint;
public static bool hasSpawnPoint;
```

Checkpoint 写它、玩家重生读它。

### 3. 场景复位用 `IResettable` + `FindObjectsOfType`

重生不只是玩家复位。**场景里"被消耗掉的东西"也要复位**:坠落平台回原位、拾取物重新出现（后续捡起的就不重新出现了）。做法是一个接口 + 一次遍历:

```csharp
public interface IResettable { void ResetLevelObject(); }

// 重生时:
foreach (MonoBehaviour mb in FindObjectsOfType<MonoBehaviour>())
    if (mb is IResettable r) r.ResetLevelObject();
```

场景物体几十个,遍历开销可忽略;比事件总线/对象池简单直白,加新"可再生"的东西只要实现接口,这里一行不用改。坠落平台的 `ResetLevelObject()` 就是这么被调到的(见坠落平台 devlog)。

## Lessons

### Lesson1:`GetComponent` 取错了对象

**现象**:DamageSource(尖刺)碰到了玩家,但代码里 `PlayerController player = GetComponent<PlayerController>();` 拿到 null,伤害永远不触发。

**根因**:这个 `GetComponent` 是在**尖刺自己身上**找玩家——尖刺上当然没有 `PlayerController`。

**修法**:在碰撞回调的参数上找,`other` 才是"撞进来的那个对象":
```csharp
PlayerController player = other.GetComponent<PlayerController>();
```
**`OnTriggerEnter2D(Collider2D other)` 的第一个参数就是干这个的**——回调方法就是"它和别的对象发生关系"的时刻,别在自己身上找对象。

### Lesson2:Checkpoint 缺"单一激活"

**现象**:第一版每个 Checkpoint 独立记 `isActive`,碰 A 亮、碰 B 亮、**A 永远不灭**。经典"旗帜存档点"的语义应该是:激活新的,旧的变灰。

**修法**:激活时把**所有** Checkpoint 复位成灰色,再点亮自己、更新重生点:
```csharp
foreach (Checkpoint cp in FindObjectsOfType<Checkpoint>()) cp.SetActiveVisual(false);
// 然后自己点亮 + GameState.spawnPoint = transform.position
```
"单一激活"是这类"最近存档点"机制的隐含契约,不做就变成"多个复活点,玩家懵了往哪回"。

### Lesson3:插值刚体 teleport 会闪现一帧

**现象**:重生时 `rb.position = spawnPoint`,角色先**在死亡点闪一下**,再瞬移回出生点。

**根因**:`Rigidbody2D` 开了 **Interpolate**(渲染插值,平时防抖动)。所以用rigidbody teleport 到远处时,渲染插值会把角色画在中间/旧位置一帧。

**修法**:重生位置用 `transform.position`(立即生效),再同步给 `rb.position`:
```csharp
transform.position = spawnPoint;   // 立即,子物体 visual 跟着
rb.position = spawnPoint;          // 同步给物理
```
**插值刚体的瞬移(teleport)要绕开渲染插值,直接改 transform。**

### Lesson4:重生后带着死前的输入继续跑

**现象**:复活后角色自己朝死前方向跑。（Only 动画）

**根因**:重生只复位了位置/速度,没复位我们优化左右移动的 `horizontalMoveLastFrame`——它是"最后按的方向"的记忆,死亡时玩家很可能按着方向键,这个记忆留到了复活。

**修法**:重生里加 `horizontalMoveLastFrame = 0`,玩家复活后 Idle。(后来切关场景里又遇到它一次,想"清方向"还踩了值类型拷贝的坑,见《[跨关与存档](/blog/2026-09-01-level-transition-and-save/)》。)

### Lesson5:依旧懒得找美术 → 纯代码缩放演死亡/重生

**现象**:没有死亡动画美术。

**处理**:用**现有 sprite 的缩放**演(又是"视觉与物理分离"):
- 死亡:`DeathRoutine` 里 `visual.localScale` 从 1 压扁到 0.1(0.2s)→ 隐藏 sprite → 停 0.3s → 重生。
- 重生:`SpawnPop` 从 scale 0 **过冲到 1.2 再回落 1**(0.25s)——"弹入"感,配合死亡压扁很自然。
- 全程只动 `visual`,不碰本体 collider,物理不受影响。

## 验收

1. 不碰 Checkpoint 就死 → 回初始出生点。
2. 碰尖刺 → 压扁消失 → 回最近 Checkpoint(弹入动画)。
3. 两个 Checkpoint,先 A 后 B → 死回 B,且 A 变灰。
4. 无敌帧(dash)穿过尖刺不受伤。
5. 重生后状态机/动画/dash 次数全复位,不带旧输入。
6. 回归:土狼/缓冲/dash/墙/平台全过。

## 反思与总结

"死亡不进状态机"是反直觉但正确的决定——**状态机的价值是行为分派,死亡不是行为是流程**。而"视觉与物理分离"(死亡动画动 visual 不动 collider)这个思路,在后面坠落平台震动又用了一次,是这个项目反复出现的主线:物理要稳,表现随便玩,两者用"子物体"隔开。
