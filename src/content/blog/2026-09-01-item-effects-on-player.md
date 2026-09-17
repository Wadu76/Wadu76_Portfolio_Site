---
title: 加成物品如何施加到角色
date: 2026-09-01
category: unity
reviewed: true
---

这篇接着《[背包系统开发](./2026-09-01-inventory-system.md)》,讲**从玩家捡起一件物品,到它的数值真正落到角色上**这条完整链路。上一篇讲的是背包怎么"存"物品、怎么"显示"物品;这一篇讲物品怎么"改变角色参数"。本篇把这条链路的每一步都讲清楚。

## 从捡起到生效

```
玩家碰到 Pickup
   │  Inventory.Add(item)               // 进背包(只获得,不生效)
   ▼
背包 UI:玩家选中物品,点 Equip 按钮
   │  EquipSystem.Equip(item)
   ▼
PlayerController.ApplyEffect(item)
   │  activeEffects.Add(effect)
   │  RecalculateStats()                 // 全量重算
   ▼
moveSpeed  *= item.MoveSpeedMul     // 例:×1.0(不变)
jumpForce  *= item.JumpForceMul     // 例:×1.0(不变)
baseGravity *= item.GravityMul      // 例:×0.5(重力减半)
maxDashes   += item.DashBonus       // 例:+0
   ▼
手感变化:重力减半,跳跃更高更飘
```

卸下是反向:`Unequip` → `RemoveEffect(itemId)` → `RecalculateStats()` → 手感还原。

整条链的关键设计是:**拾取、装备、生效 是三件不同的事,分别在 Pickup、EquipSystem、PlayerController 三处发生**。下面逐个拆。

## 为什么"拾取 ≠ 生效":从自动装备改成手动装备

最开始,Pickup 碰到玩家时 `Inventory.Add(item)` **并且立刻 `EquipSystem.Equip(item)`**——捡到就生效。开发中我改成了只进背包,手动在背包里装。

1. 捡到是"我得到了什么",装备是"我要不要用它"。如果捡到就自动生效,玩家永远没有"打开背包,看看描述,决定装哪个"的机会——背包 UI 直接沦为摆设,这个系统等于白做。
2. **卸载才有意义**。只有手动装备,才会出现"装 A、装 B、卸 A 换回基础手感"的操作,玩法才有选择。
3. **拾取与生效解耦,更接近正式游戏设计**。正式游戏里"捡到装备"和"穿戴装备"几乎总是两个动作(尤其有装备栏位的游戏)。

这条改动的代价是:捡到物品时没有即时数值反馈了。所以我启用了**飘字** `+Gravity Stone` 作为"获得"的反馈——让"获得"有反馈,但生效与否留给玩家自己决定。当然关卡会逼迫玩家选择使用。

## 关键接口:IItemEffect

物品改变角色的方式,是通过实现 `IItemEffect` 接口:

```csharp
public interface IItemEffect
{
    string ItemId { get; }        //用于去重,替换
    void Apply(PlayerController player);        //装上钩子
    void Remove(PlayerController player);       //卸下钩子
    float MoveSpeedMul { get; }
    float JumpForceMul { get; }
    float GravityMul { get; }
    int DashBonus { get; }
}
```

`ItemDefinition` 实现(SO + 接口)。`PlayerController` 的装备系统**只知道 `IItemEffect`,不知道也不关心具体是物品还是别的**。以后无论是加临时 Buff或关卡加成,再实现`IItemEffect`即可,`PlayerController` 无需任何改动。**面向接口:调用方依赖抽象,不依赖实现。**

接口自带去重依据:`ItemId`。为什么按 id 而不是按对象引用?因为背包里同一种物品是**同一个 SO 资产**,`ItemId` 就是它的身份证。装备系统按 id 去重、按 id 卸载,语义干净。而且同一个物品也不会占多格。

## 效果的三个生命周期方法

`PlayerController` 上有三个方法,对应"装 / 卸 / 查":

```csharp
//装上:进列表 && 重算
public void ApplyEffect(IItemEffect effect)
{
    activeEffects.Add(effect);
    effect.Apply(this);
    RecalculateStats();
}

//卸下:按itemId移除 && 重算
public void RemoveEffect(string itemId)
{
    for (int i = activeEffects.Count - 1; i >= 0; i--)
    {
        if (activeEffects[i].ItemId == itemId)
        {
            activeEffects[i].Remove(this);
            activeEffects.RemoveAt(i);
        }
    }
    RecalculateStats();
}

//查询:这个效果在不在身上
public bool HasEffect(string itemId) { ... }
```

要点:

- **`RemoveEffect` 按 `itemId` 移除所有匹配项**:从后往前遍历(避免移除过程中索引错位)。它卸的是"这一种效果",不是"某个引用"。
- **`HasEffect` 是只读查询**:UI 用它问"这个物品装备了吗"→ 决定按钮显示 `Equip` 还是 `Unequip`、边框亮不亮。**表现层永远向这里要状态,不自己缓存。**
- **`effect.Apply(this)` / `effect.Remove(this)` :目前空实现,但接口留了这个口，将来物品可以在装上/卸下时播特效、音效，同样不用改 `PlayerController`。

## RecalculateStats:全量重算

这是整个系统最核心的一段，保障了重复卸/装不会影响数值计算:

```csharp
private void RecalculateStats()
{
    moveSpeed = baseStats.moveSpeed;
    jumpForce = baseStats.jumpForce;
    baseGravity = baseStats.baseGravity;
    maxDashes = baseStats.maxDashes;

    foreach (IItemEffect e in activeEffects)
    {
        moveSpeed *= e.MoveSpeedMul;
        jumpForce *= e.JumpForceMul;
        baseGravity *= e.GravityMul;
        maxDashes += e.DashBonus;
    }
    if (maxDashes < 1) maxDashes = 1;
}
```

它每次都**从 `baseStats` 基础值开始,重新把所有已装备效果乘一遍**。为什么不"在当前值上增量修改"?因为:

1. **卸载永远干净**。假设装了重力石(g×0.5)。如果是在当前值上乘,卸载就要"除回去"——浮点除法会累积误差,装 5 次卸 5 次,数值就漂了。全量重算每次从基础值开始,**卸掉 A 一定回到基础值**,数学上不可能出错。
2. **顺序无关,这是被验证过的性质**。乘法满足交换律、加法满足交换律,所以"装 A 再装 B"和"装 B 再装 A",最终 `moveSpeed * A.Mul * B.Mul` 和 `moveSpeed * B.Mul * A.Mul` 结果完全一样。玩家先捡重力石还是先捡 dash 石,手感完全一致——**这正是"无论顺序如何都没有问题"的数学原因**。
3. **不引入"脏状态"**。增量式最怕"当前值被别处改过、我再叠一次就错了"。全量重算没有"历史",状态永远由 `baseStats + activeEffects` 这一个等式决定,可预期、可调试。



### clamp:`if (maxDashes < 1) maxDashes = 1`

防御性的兜底:万一未来有"减冲刺次数"的效果,保证玩家永远至少能冲一次。**防御式编程给状态设下界/上界**,避免异常数值把玩法搞坏。

## 借助背包看效果:装备状态从哪来

整个背包 UI(上一篇文章讲的)其实只有一个"效果感知点":`player.HasEffect(item.ItemId)`。它驱动三处表现:

```csharp
//按钮文字:已装 → Unequip,没装 → Equip
equipButtonText.text = player.HasEffect(selectedItem.ItemId) ? "Unequip" : "Equip";

//格子边框:已装 → 亮
pair.Value.SetActive(player.HasEffect(pair.Key.ItemId));
```

这就是"效果系统"和"背包系统"的缝合点:**效果状态只存在 `PlayerController.activeEffects` 一处,背包 UI 和格子边框都只是它的视图**。加一个新的"已装备"表现(比如飘一个已装备标记),只需要再读一次 `HasEffect`,效果系统不用改。

## Lessons

### Lesson1:捡到就自动装备改成手动

**现象**:最初捡到石头,重力立刻变化,但玩家根本看不到背包的价值,也没法"卸下来"。

**原因**:拾取和生效揉在了一起,背包 UI 的选中/装卸逻辑没有用武之地。

**处理**:Pickup 只 `Inventory.Add`,去掉自动 `Equip` 调用,装备时机挪到背包按钮。**一个系统的每个动作都要有独立触发点**,拾取、装备、卸下,各管各的,UI 才有意义。

### Lesson2:同种替换,防止重复叠加

**现象**:装备系统最初直接 `ApplyEffect`,如果玩家对同一件物品点两次 Equip,`activeEffects` 里会有两个相同效果,数值翻倍。

**原因**:缺少"已装同种就替换"的逻辑。

**处理**:`EquipSystem.Equip` 里 `if (HasEffect) RemoveEffect; ApplyEffect;`——**先卸旧的再装新的**。这是 `ItemId` 去重语义在装备侧的落地:每种效果身上最多一份。



## 反思与总结

"加成物品如何施加到角色"这条链路,三个设计要点:

1. **拾取 ≠ 生效**:Pickup 只进背包,装备动作由玩家在背包里触发。"获得"和"决策"分开。
2. **面向接口**:`IItemEffect` 让装备系统依赖抽象;`ItemId` 提供去重依据。
3. **全量重算而非增量**:`RecalculateStats` 从基础值开始重算,卸载永远干净、装卸顺序无关(乘法交换律)、没有脏状态。速度/重力用乘法、次数用加法,各配其语义。

最喜欢的设计点是**选全量重算,而不是在当前值上叠**。它同时解决正确性(卸载还原)、可预期性(无历史)、可调试性三个问题。
