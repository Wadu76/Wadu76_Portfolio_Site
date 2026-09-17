---
title: 背包系统开发
date: 2026-09-01
category: unity
reviewed: true
---

这篇记录背包系统的完整开发过程:**为什么做背包、系统分几层、每个脚本各自干什么、它们怎么串起来、以及开发中的若干Lessons**。这是这个项目里除了状态机之外,很能体现设计思路的一个部分,所以每个脚本都重要。

## 为什么做背包

原来的 demo 只有移动手感(状态机 + 土狼 + 缓冲 + dash + 墙滑墙跳),它是个"能跑的壳",但没有"目标"。要让作品集变成一个**完整的游戏循环**,需要一个收集/成长层:玩家捡到东西 → 东西改变玩法 → 玩家因此能做之前做不到的事。

背包就是这层的载体。它把「捡拾」和「生效」分开:**捡到 ≠ 自动生效**,玩家要在背包里主动装备,卸下后数值还原。这样一个小决策(装不装、装哪个)就让玩法有了选择,而不是"碰一下就变强"。

## 系统蓝图:三层架构

背包不是一个大脚本,而是**数据层 / 业务层 / 表现层**三层协作:

```
数据层
  ItemDefinition (ScriptableObject) ──实现──► IItemEffect(接口)
  PlayerStats (SO) ── 玩家的基础值
  Inventory (静态类) ── 物品仓库
        ▲
        │ Add / CountOf / GetAllDistinct
业务层
  EquipSystem (挂在玩家上) ── Equip / Unequip
        ▲
        │ ApplyEffect / RemoveEffect / HasEffect
        │
  PlayerController ── activeEffects / RecalculateStats
        ▲
表现层
  Pickup (场景里的拾取物) ──► FloatingTextPool(飘字)
  InventoryUI (背包面板/格子/选中/装卸按钮)
```

- **数据层**只回答"物品是什么、存了多少",不关心"怎么显示、怎么生效"。
- **业务层**只回答"装/卸一件物品"这个动作,是数据的消费者。
- **表现层**只回答"玩家怎么看到、怎么操作",是数据的展示。

**物品数据(ScriptableObject)、物品仓库(Inventory)、装备动作(EquipSystem)、UI 显示(InventoryUI)互不直接依赖,各自通过明确的入口协作。** 

## 数据层

### ItemDefinition:用 ScriptableObject 定义"一件物品"

```csharp
[CreateAssetMenu(fileName = "NewItem", menuName = "Items/New Item")]
public class ItemDefinition : ScriptableObject, IItemEffect
{
    [SerializeField] private string itemId;
    [SerializeField] private string displayName;
    [SerializeField] private Sprite icon;
    [SerializeField] private float moveSpeedMul = 1f;
    [SerializeField] private float jumpForceMul = 1f;
    [SerializeField] private float gravityMul = 1f;
    [SerializeField] private int dashBonus = 0;
    [SerializeField] private string description;   //物品介绍

    public string ItemId => itemId;
    public string DisplayName => displayName;
    public Sprite Icon => icon;
    public float MoveSpeedMul => moveSpeedMul;
    public float JumpForceMul => jumpForceMul;
    public float GravityMul => gravityMul;
    public int DashBonus => dashBonus;
    public string Description => description;

    //以后可以播音效/特效
    public void Apply(PlayerController player) { }
    public void Remove(PlayerController player) { }
}
```

**为什么用 ScriptableObject,而不是普通类?** 三个理由:

1. **数据与场景解耦**:物品不需要挂在场景里。在 Project 里右键 `Create → Items → New Item` 就生成一个资产(比如 `Gravity_Stone.asset`),它是"一个数据文件",可以被任意地方引用。
2. **调参不碰代码**:改重力倍率 0.5 → 0.6,在 Inspector 里拖一下就行,不需要重编译。整个项目的"调手感不碰代码"策略从这里开始。
3. **本质是"可被多处引用的只读数据"**:同一个资产被 `Pickup`(场景拾取物)、`Inventory`(仓库)、`InventoryUI`(格子显示)同时引用,大家读的都是同一份数据。改一处,处处生效。

字段里的 `moveSpeedMul / jumpForceMul / gravityMul / dashBonus` 是物品对玩家的**参数修改器**,这是背包和"关卡体验"结合的关键——物品不是"发一个技能",而是**改玩家的运动参数**,天然贴合这个项目"移动手感为壳"的定位。

### IItemEffect:数据契约与行为钩

```csharp
public interface IItemEffect
{
    string ItemId { get; }        //用于去重,替换
    void Apply(PlayerController player);        //装上钩子
    void Remove(PlayerController player);       //卸下钩子
    float MoveSpeedMul { get; }   //移速
    float JumpForceMul { get; }   //跳跃修改器
    float GravityMul { get; }
    int DashBonus { get; }        //dash次数修改器
}
```

这个接口的意义:**让"能改变玩家参数的东西"不局限于物品**。接口定义的是契约——你要能提供这些数据、实现这两个行为,就可以作为 `IItemEffect` 被装备系统接受。将来做 Buff、临时状态、关卡机关加成,都是"再实现一个 `IItemEffect`",装备系统一行不用改。这就是**面向接口而非面向具体类**。

接口拆成两部分:
- **数据**(`ItemId` + 四个修改器):提供"加多少"。
- **行为**(`Apply` / `Remove`):提供"装/卸时额外做什么",目前是空实现,以后播特效、音效也许能用？

`ItemDefinition` 实现这个接口(注意它 `: ScriptableObject, IItemEffect`),所以物品本身就是一个"能被装备的效果"。

### Inventory:静态的物品仓库

```csharp
public static class Inventory
{
    private static readonly List<ItemDefinition> items = new();
    public static void Add(ItemDefinition item) => items.Add(item);
    public static bool Remove(ItemDefinition item) => items.Remove(item);

    //计算有几个物品
    public static int CountOf(ItemDefinition item) { ... }

    //去重列表,每种物品一个UI
    public static List<ItemDefinition> GetAllDistinct()
    {
        var seen = new HashSet<ItemDefinition>();
        var result = new List<ItemDefinition>();
        foreach (var it in items)
            if (seen.Add(it)) result.Add(it);
        return result;
    }
}
```

**为什么用静态类?** 背包在整个游戏里只有一份,静态类直接表达"全局唯一的仓库",不用到处传引用,`Inventory.Add(item)` 在任何地方都能调。对 demo 规模这是最轻的全局状态方案——这是**有意的简化**,不是偷懒:真要做一个角色一个背包,再改成实例化持有,迁移成本也低。

两个方法说明:
- `CountOf`:数"同一种物品有几个",UI 显示 `x2` 就是用它。
- `GetAllDistinct`:用 `HashSet` 去重,返回"每种物品一个",UI 按它生成格子——**格子是"按种类"的,不重复,但格子上的数量可以 >1**。这是物品少的 demo 下最简单清晰的做法。

### PlayerStats:玩家的基础值 SO

```csharp
public class PlayerStats : ScriptableObject
{
    public float moveSpeed = 5f;
    public float jumpForce = 17.143f;
    public float baseGravity = 4.993f;
    public int maxDashes = 1;
}
```

这是"基础值"的来源。它和物品的区别是:物品是"修改器",这是"被修改的基础"。`PlayerController` 引它,每次效果变化都从它重算(见第二篇 devlog 的 `RecalculateStats`)。**为什么只有这 4 个参数?因为物品效果只会改这 4 个。** 土狼时间、dash 冷却这类"手感细节"参数留在代码里,不进 SO——它们不是物品能改的东西,塞进来只会让 SO 变成垃圾桶。

## 业务层

### EquipSystem:装卸的业务入口

```csharp
public class EquipSystem : MonoBehaviour
{
    private PlayerController player;

    private void Start() { player = GetComponent<PlayerController>(); }

    //同一种已安装,先替换掉旧的,再安新的
    public void Equip(ItemDefinition item)
    {
        if (player.HasEffect(item.ItemId)) player.RemoveEffect(item.ItemId);
        player.ApplyEffect(item);
    }

    //卸 按itemId移除并还原
    public void Unequip(ItemDefinition item) => player.RemoveEffect(item.ItemId);
}
```

它挂在玩家身上,是"装备动作"的唯一入口:

- **`Equip` 先检查"同种是否已装"**:如果已装,先卸再装(替换)。这样"重复装备同一件"不会重复叠加——这是对 `ItemId` 去重语义的维护。
- **`Unequip` 按 `itemId` 移除**:卸的是"这一种",不是"某一个引用"。因为整个系统里同一种物品是同一个 SO 实例,按 id 卸最干净。

`EquipSystem` 不关心物品从哪来、UI 怎么调用它——它只负责"执行一次装卸"。

## 表现层

### Pickup:拾取触发点

```csharp
private void OnTriggerEnter2D(Collider2D other)
{
    if (taken) return;
    PlayerController player = other.GetComponent<PlayerController>();
    if (player == null) return;
    taken = true;
    //放入背包里
    Inventory.Add(item);
    //player.GetComponent<EquipSystem>()?.Equip(item);    //自动装备变换参数
    FloatingTextPool.Instance.Show($"+{item.DisplayName}",transform.position);
    sr.enabled = false;
    col.enabled = false;
}
```

场景里的拾取物挂这个脚本,`item` 槽拖对应物品 SO。碰到玩家:
1. **进背包**:`Inventory.Add(item)`。
2. **飘字反馈**:`FloatingTextPool.Instance.Show(...)` 在物品位置飘出 `+Gravity Stone`。
3. **隐藏自身**:关 SpriteRenderer 和 Collider(防止重复触发)。

**被注释掉的自动装备** 是直接安装，但我们拾取只进背包,**不自动生效**。不然背包白弄了。

它还实现了 `IResettable`,死亡重生时恢复——和坠落平台共用同一套场景复位机制。

### InventoryUI:面板、格子、选中、装卸按钮

这是表现层最复杂的脚本,负责整块 UI 的交互状态。它维护这些引用:

```csharp
[SerializeField] private GameObject panel;          //背包面板
[SerializeField] private Transform grid;            //格子容器(GridLayoutGroup)
[SerializeField] private GameObject slotPrefab;     //格子预制体
[SerializeField] private Text descriptionText;      //物品介绍文字
[SerializeField] private Button equipButton;        //装备/卸载按钮
[SerializeField] private Text equipButtonText;      //按钮上的文字
```

核心状态:
```csharp
private ItemDefinition selectedItem;   //目前选中的物品
private readonly Dictionary<ItemDefinition, GameObject> slotBorders = new();  //每个格子自己的边框
```

按 B 开关面板,打开时 `Refresh()` **全量重建**格子(物品少,全量比增量更新简单可靠):

```csharp
private void Refresh()
{
    foreach (Transform child in grid) Destroy(child.gameObject);   //清旧格
    slotBorders.Clear();
    selectedItem = null;
    foreach (ItemDefinition item in Inventory.GetAllDistinct())
    {
        GameObject slot = Instantiate(slotPrefab, grid);
        slot.GetComponentInChildren<Image>().sprite = item.Icon;
        slot.GetComponentInChildren<Text>().text = $"x{Inventory.CountOf(item)}";

        //缓存这个格子自己的边框(找 Equipped 父物体)
        slotBorders[item] = slot.transform.Find("Equipped")?.gameObject;

        //点格子 = 选中这个物品
        Button btn = slot.GetComponent<Button>();
        if (btn != null)
        {
            ItemDefinition captured = item;
            btn.onClick.AddListener(() => SelectItem(captured));
        }
    }
    RefreshBorders();
}
```

三个交互状态,各司其职:

- **选中** → `SelectItem(item)`:记录 `selectedItem`,把 `item.Description` 写进描述文字,刷新按钮。
- **装卸按钮** → `EquipOrUnequip()`:`player.HasEffect(...)` 判断已装 → 卸,没装 → 装;装完刷新边框和按钮。
- **装备状态显示** → `slotBorders` 字典:每个格子缓存**自己**的 `Equipped` 边框,`RefreshBorders()` 遍历字典,按 `player.HasEffect(item.ItemId)` 决定亮/灭。这就是已装备的物品格子带的边框。

```csharp
//所有格子的边框亮不亮 = 该物品是否已装备(跟"选中谁"无关)
private void RefreshBorders()
{
    foreach (var pair in slotBorders)
        if (pair.Value != null)
            pair.Value.SetActive(player.HasEffect(pair.Key.ItemId));
}
```

按钮文字同理,由 `player.HasEffect` 现算:已装显示 `Unequip`,没装显示 `Equip`。

**UI 的"当前装备状态"从哪来?** 全部来自 `player.HasEffect(item.ItemId)` 这一个查询。UI 不自己记"谁装备了",它只问玩家。这是数据单一来源(单源)的体现——表现层永远向业务层要状态,而不是自己缓存一份。

### FloatingText 对象池飘字

拾取反馈用了一个对象池(预分配 + 复用):

```csharp
public class FloatingTextPool : MonoBehaviour
{
    public static FloatingTextPool Instance;
    [SerializeField] private FloatingText prefab;
    [SerializeField] private int poolSize = 10;
    private readonly Queue<FloatingText> pool = new();

    private void Awake()
    {
        Instance = this;
        for (int i = 0; i < poolSize; i++)
        {
            FloatingText ft = Instantiate(prefab, transform);
            ft.gameObject.SetActive(false);
            pool.Enqueue(ft);
        }
    }

    public void Show(string content, Vector2 worldPos) => Get().Show(content, worldPos);
    // Get():池空才新建(兜底);Release():用完 SetActive(false) 放回队列
}
```

飘字本身用 **TextMeshPro 的 3D 文本**,带 `Sorting Order`,设高之后不会被场景精灵遮挡(这个坑见下)。

**为什么飘字值得池化,而 UI 格子不池化?** 飘字是"高频瞬时"对象——每次捡东西都生成、一秒就消失,如果每次 `Instantiate` + `Destroy`,会持续产生 GC。池化后预分配 10 个反复复用,**零分配**。格子是"一次性生成、打开面板才重建",量小,池化是过度设计。**对象池用在"高频 + 瞬时"的场景才划算**,这是判断要不要池化的标准。不过我们物品也不是很多，此处对象池确实有点秀肌肉了（

## 一次完整交互的数据流

把三层串起来,一次"捡到石头 → 手动装备"的完整路径:

```
玩家碰到 Pickup
  → Inventory.Add(item)                    [数据层:进仓库]
  → FloatingTextPool.Show("+Gravity Stone") [表现层:飘字反馈]
按 B 开背包
  → InventoryUI.Refresh() 读 GetAllDistinct() 生成格子  [表现层:读仓库]
点击 Gravity Stone 格子
  → SelectItem() 显示描述、刷新按钮               [表现层:选中]
点 Equip 按钮
  → EquipSystem.Equip()                      [业务层:执行动作]
    → PlayerController.ApplyEffect(item)     [业务层 → 数据/表现]
      → RecalculateStats() 重算手感
  → RefreshBorders() + 更新按钮文字(读 HasEffect) [表现层:回显]
```

注意:表现层从不直接改数据,业务层从不直接碰 UI,数据层不知道 UI 和玩家存在。每一层只通过明确定义的入口协作。

## Lessons

### Lesson1:物品在屏幕中央竖着摆

**现象**:格子一个接一个往下竖排,不是横排。

**原因**:`GridLayoutGroup` 的 `Constraint` 默认是 `Flexible`(自由),它会根据 Grid 容器宽度决定一行放几个。容器太窄,一行放 1~2 个就换行,看起来就是竖排;加上 `Spacing.y = 0`,行贴行。

**处理**:`Constraint` 改成 **Fixed Column Count**,`Constraint Count` 设 4,`Spacing` 设 (10, 10)。用组件给我用好了啊。

### Lesson2 → `UnassignedReferenceException`

**现象**:`slotPrefab` / `panel` / `grid` 有一个没拖进 Inspector,运行时崩。

**处理**:这类 `[SerializeField]` 引用拖没拖,只能靠运行时报错暴露。**排查顺序:先看报错指向哪个字段，再回 Inspector 检查有没有空槽**。`UnassignedReferenceException` 

### Lesson3`Inventory` 是静态的,停止播放就清空

**现象**:每次重开游戏,背包里的东西没了。

**原因**:静态 List 的生命周期是"编辑器运行期间",停止播放即销毁。这是静态全局状态的固有代价。

**处理**:demo 阶段接受(每次运行从零开始,正好用来验收);要做"进度"再引入存档(PlayerPrefs 存 itemId 列表,重开反查),这也正是下一步路线。




### Lesson4:装卸后边框不变,要重开背包才刷新

**现象**:点 Equip,手感变了、按钮文字变了,但边框不亮;重开背包才亮。

**原因**:`EquipOrUnequip` 里只调了 `UpdateEquipButton()`(管按钮文字),**漏了 `RefreshBorders()`**(管边框)。边框状态只有 `Refresh()` 时才被算一次。

**处理**:装卸动作结尾同时调 `RefreshBorders()` + `UpdateEquipButton()`。教训:**一个状态变,所有依赖它的表现都要在同一处刷新**,别指望"下次刷新会带上"——那个"下次"可能远在重开背包时。


## 反思与总结

背包系统用三层架构,把"物品数据(SO)、仓库(Inventory)、装卸动作(EquipSystem)、UI 显示(InventoryUI)"拆成四个互不直接依赖的模块,通过明确的入口协作。面试时值得强调的三点:

1. **SO 作为"可被多处引用的只读数据"** 承载物品,数据与场景解耦、调参不碰代码。
2. **`IItemEffect` 接口**让"能改变玩家的东西"不局限于物品,面向接口而非具体类。
3. **表现层永远向业务层要状态**(`player.HasEffect`),不自己缓存一份——单一数据来源。

下一步路线:存档(PlayerPrefs 存背包 itemId,重开反查恢复)、把 `IItemEffect` 的参数抽成 `ICharacterStats` 接口进一步解耦。而"物品到底怎么改变角色手感"这条链路,我单独写了一篇 devlog,见《[加成物品如何施加到角色](./2026-09-01-item-effects-on-player.md)》。
