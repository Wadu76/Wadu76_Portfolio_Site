---
title: 拾取物重生导致背包重复
date: 2026-09-12
category: unity
---

这篇记一个**设计层面**的冲突,而不只是代码 bug:**"场景复位"这个机制,把"关卡物件"和"玩家进度"一视同仁地复位了。**

## 现象

玩家死亡重生之后:

- 场景里**已经被捡走的物品又出现了**
- 再捡一次 → 背包里同一物品变成两份

## 原因:接口遍历是"一视同仁"的

死亡重生的场景复位是这么做的(见[死亡与重生](/blog/2026-08-27-checkpoint-death-respawn/)):

```csharp
foreach (MonoBehaviour mb in FindObjectsOfType<MonoBehaviour>())
    if (mb is IResettable r) r.ResetLevelObject();
```

而 `Pickup` 也实现了 `IResettable`:

```csharp
public void ResetLevelObject()      //旧版:一律回到"未拾取"状态
{
    transform.position = startPos;
    sr.enabled = true;
    col.enabled = true;
    taken = false;
}
```

于是重生时,拾取物被**当成"被消耗掉的关卡物件"复位了**——它重新出现、再次可捡,而背包里那份还留着 → 重复。

**根本冲突在这**:

| | 复位是正确的 | 复位是错误的 |
|---|---|---|
| 坠落平台 | ✅ 死亡后应回到原位,关卡才可重玩 | |
| 拾取物 | | ❌ 它属于**玩家进度**,捡到就是捡到了,不该退回去 |

同一个接口、同一次遍历,两种对象需要的语义相反。**所以判断必须下沉到组件自己身上。**

## 修复:让组件自己回答"我该不该复位"

```csharp
public void ResetLevelObject()
{
    //已经被拾取过(背包里还留着)→ 不再重新生成,否则能重复捡、背包出现多份
    if (Inventory.CountOf(item) > 0)
    {
        taken = true;
        sr.enabled = false;
        col.enabled = false;
        return;
    }

    transform.position = startPos;
    sr.enabled = true;
    col.enabled = true;
    taken = false;
}
```

逻辑很直白:**背包里还有这个东西 → 说明它已经被捡走了 → 保持隐藏,别复活。**

## 关于判断条件的一个取舍

这里用的是 `Inventory.CountOf(item) > 0`(当前背包里有几个),而不是新增一个 `pickedBefore` 布尔标记。

- **现在两者等价**:游戏里还没有"丢弃"或"消耗"物品的功能,所以"背包里有" == "曾经捡过"。
- **但将来会不等价**:一旦加入"使用/丢弃物品",玩家可能捡过又被消耗掉,那时 `CountOf == 0` 却不代表"没捡过"——**那时必须换成独立的 `pickedBefore` 标记**。

把这个判断写在这里、并在注释里说清它的前提,是为了**将来改的时候知道该改哪**。

## 小结

- 这类 bug 表面是"物品没消失",本质是**"通用复位机制"和"个体语义"打架**:接口遍历只能做到"一视同仁",**"我该不该被复位"必须由组件自己判断**。
- 这和坠落平台那个"[停用的组件仍会被复位](/blog/2026-08-27-falling-platform-breakdown/)"是同一枚硬币的两面:**`FindObjectsOfType` + 接口的遍历会平等地找到每一个实现者,组件必须自己决定要不要响应。**
- 顺手记一个习惯:凡是写"依赖某个隐含前提"的判断(比如这里"没有丢弃功能"),**把前提写进注释**——否则半年后加了个新功能,这段代码就会静默出错。
