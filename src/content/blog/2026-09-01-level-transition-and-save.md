---
title: 跨关与存档
date: 2026-09-03
category: unity
reviewed: true
---

这篇记录我把 demo 从"单场景能玩"推进到"三关能通 + 进度能存"的过程。核心其实不是一个功能,而是一个**权衡**:关卡用什么方式组织、玩家状态怎么跨关。我尝试过两个实现，这篇把两条路线(每关一个场景 vs 单场景多关)都讲清楚、为什么选后者、以及切关转场和存档数据流的完整设计。

## 切关是个麻烦事

从一关到下一关,真正难的不是"换个关卡内容",而是三件事:

1. **怎么切**:玩家从哪关内容"跳"到下一关内容。
2. **状态怎么带**:玩家身上的装备效果、背包里的东西,切了关还在不在。
3. **存读盘**:退出游戏后再打开,从哪关继续。

第 2 点最容易踩坑——因为它和"关卡怎么组织"强绑定。

## 两条路线:方案 A(每关一个场景)vs 方案 B(单场景多关)

### 方案 A:每关一个 `.unity` 场景

每个关卡一个场景文件,切关就是:

```csharp
SceneManager.LoadScene("Level_2");   // Unity 自动卸载 Level1 整个场景、加载 Level2
```

**它真正的难点——玩家状态怎么跨关**:`LoadScene` 会把玩家一起销毁,身上的装备效果就没了。有两条子路线:

**子路线 1:玩家 `DontDestroyOnLoad`(玩家跨关保留)**
```csharp
DontDestroyOnLoad(gameObject);                    // 切关不销毁
SceneManager.sceneLoaded += OnSceneLoaded;        // 新场景加载后回调
// 回调里:找新关的出生点 → 把玩家挪过去、清速度
```
坑:①新场景**不能放玩家**(会重复实例),只放出生点;②相机/UI 也是场景对象,每关要摆或一起 DDOL;③DDOL 对象要防"重复进入"产生多份。

**子路线 2:GameManager 存数据,每关重建玩家**
```csharp
// 切关前:GameManager.equippedIds = 玩家身上的效果 itemId 列表;
// LoadScene → 新关场景自带玩家 → 玩家 Start 从 GameManager 读 id,重放效果
```
坑:需要"itemId → 物品 SO"的查找机制,要写恢复逻辑;玩家每关都是新的。

### 方案 B:单场景,三关内容是三个根节点

一个游戏场景,`Level1 / Level2 / Level3` 三个父对象各自装一关的内容。切关 = 开关节点 + 挪玩家:

```csharp
levelRoots[i].SetActive(i == levelIndex);   // 只开目标那关的根
player.position = spawn.position;           // 玩家挪到新关出生点
```

**为什么 B 在状态上几乎零成本**:玩家、背包(静态 `Inventory`)、装备效果都活在场景根,`SetActive` 只开关关卡内容,**玩家从没被销毁** → 跨关状态天然保留,不用 DDOL、不用存数据重建、不用管场景加载时序。相机、UI、EventSystem 全场景一份,永远不用跨关处理。

### 为什么选单场景多关

> 三关的 demo,平台跳跃的核心是"平台高度间距与手感匹配",必须在编辑器里直接摆、直接调。单场景下状态零搬运、没有场景加载时序的坑。**这是规模匹配的选择。** 若关卡数量上去、要独立迭代某一关或程序化生成,再升级成方案 A——那时玩家状态用 `DontDestroyOnLoad` 或 GameManager 存数据重建,两条子路线我都能做。



## 方案 B 的实现

### 1. `GameManager`:流程控制器

`GoToLevel(index)` 是唯一切关入口。`SwitchLevel(index)` 干三件事:关旧根、开新根、把玩家挪到出生点并更新 `GameState.spawnPoint`(让"本关死亡"回本关起点,不是上一关)。

### 2. `LevelDoor`:终点门

```csharp
private void OnTriggerEnter2D(Collider2D other)
{
    if (other.GetComponent<PlayerController>() == null) return;
    GameManager.Instance.GoToLevel(nextLevel);   // nextLevel 在 Inspector 填目标关 index
}
```
一个 Trigger,和拾取物用同一种触发机制。

### 3. 出生点

每关一个空对象标记开局位置;`GameState.spawnPoint` 在切关时更新,死亡重生自动回对的地方。

## 切关转场:黑屏 + 相机瞬移

直接切关会"啪"地一下画面全变,很生硬。加一层黑屏淡入淡出:

```
碰门 → 屏幕淡入黑(0.3s)→ (黑屏里)关旧关、开新关、挪玩家 → 相机 Snap → 淡出
```

两个关键点:

**① 黑屏遮住"世界切换的瞬间"**。玩家瞬移、关卡内容替换全在黑的 0.3 秒里完成,淡出后世界已是新关。

**② 相机必须 Snap,不能 Lerp 滑过去**。`CameraFollow` 是平滑跟随:
```csharp
Vector3 smoothedPos = Vector3.Lerp(transform.position, desiredPos, smoothSpeed * Time.deltaTime);
```
玩家瞬移到很远的新关出生点时,相机若还 Lerp,淡出黑屏时会看到镜头在半路、世界在滑动。所以给相机加一个"瞬移"方法,在切换后直接对准:
```csharp
public void SnapToTarget()
{
    Vector3 desired = new Vector3(target.position.x + offset.x, target.position.y + offset.y, transform.position.z);
    transform.position = desired;
}
```

## 启动黑幕

启动(读档恢复)也会"闪一下"——玩家先落在第 0 关一帧、再被挪到存档关。同样用黑幕解决:启动先全黑 → 等会 → 恢复/切关 → 淡出。

```csharp
private IEnumerator Start()
{
    SetFade(1f);                 // 启动瞬间全黑
    yield return null;           // 等玩家等所有 Start 跑完
    if (forceNewGame || !SaveSystem.HasSave) { if(forceNewGame) SaveSystem.Delete(); SwitchLevel(0); }
    else Restore(SaveSystem.Load());
    yield return FadeTo(0f);     // 淡出到正确关卡
}
```

`forceNewGame` 是个 Inspector 开关,勾上就从第 0 关开始(开发期反复测第一关用)。

## 存档

### 存什么

四样:当前关、关内出生点、背包物品(id)、已装备效果(id)。

**为什么只存字符串 id,不存对象?** ScriptableObject 实例不能跨进程写盘;id 是物品的"身份证",恢复时反查。

### 三个零件

**`SaveData.cs`**——纯数据蓝图,全是 public 字段 + `[Serializable]`
```csharp
public class SaveData
{
    public int currentLevel;
    public float spawnX, spawnY;
    public List<string> inventoryItemIds;
    public List<string> equippedItemIds;
}
```

**`SaveSystem.cs`**——读写盘,PlayerPrefs + JsonUtility:
```csharp
PlayerPrefs.SetString(KEY, JsonUtility.ToJson(data));  // 存:对象 → JSON 字符串
JsonUtility.FromJson<SaveData>(PlayerPrefs.GetString(KEY));  // 读:JSON → 对象
```

**`ItemDatabase.cs`**——id → 物品的查找表:
```csharp
public static class ItemDatabase
{
    static Dictionary<string, ItemDefinition> byId = new();
    public static ItemDefinition GetById(string id)
    {
        // 首次用才扫:Resources.LoadAll<ItemDefinition>("Items") 建字典
        // 所有物品 asset 放 Assets/Resources/Items/,以后加物品只是丢进文件夹,零维护
    }
}
```

### 什么时候存、什么时候恢复

- **存**:过关时(终点门切换成功)+ `OnApplicationQuit()` 兜底。
- **恢复**:启动等一帧后,有档 → `Restore`,没档 → 第 0 关。

## Lessons



### Lesson1:想清方向输入,写成了值类型局部变量

**现象**:切关后想清掉玩家"最后按的方向",写了一行代码,但实际没效果。

**写法(错)**:
```csharp
float h = playerController.horizontalMoveLastFrame;   // 读出来是值的拷贝
h = 0;                                                // 改的是局部变量
```
`horizontalMoveLastFrame` 是 `float`(**值类型**)。读对象字段拿到的是**拷贝**,不是通往字段的引用——改拷贝对原字段毫无影响。想改必须直接赋值:
```csharp
playerController.horizontalMoveLastFrame = 0;
```

**更深的:为什么这行(即便写对)也不是必须的?** `horizontalMoveLastFrame` 由 `OptimizedInput()` **每帧按 A/D 按键边沿刷新**——玩家松键那一帧它就自动归零。切关是**活体传送**:玩家手还在键盘上,切关后任意一次按/松都会把它覆盖成真实输入,残留只有几帧、几乎无感。而**死亡重生**之所以必须清,前提不同:死亡时玩家常**按住方向键不放**,重生后按键仍按着,`GetKeyDown` 不触发(不是刚按下),`lastFrame` 停在死前方向 → 角色自己走。切关没有"持续按住却无新边沿"的窗口。

结论:那行是"借鉴死亡逻辑"的防御代码,对切关非必需——所以写错(局部变量)也无害地没暴露。**防御代码写错却看不出,是因为它本来就不在关键路径上**——这也是个值得记住的调试视角。

### Lesson3:恢复装备必须"等一帧",在玩家 `Start` 之后

**现象**:如果启动立刻恢复装备,装备效果可能被覆盖/不对。

**原因**:玩家的 `PlayerController.Start()` 会执行 `RecalculateStats()`(从基础 SO 全量重算)。如果我们在它**之前** `ApplyEffect` 恢复装备,随后的重算会以"空的效果列表"重算,把刚恢复的效果冲掉。

**处理**:`yield return null` 等一帧,让玩家的 `Start` 先跑完,再补效果。此时 `ApplyEffect` 触发的重算是在干净初始状态上加,结果正确:
```csharp
yield return null;   // 等玩家等所有 Start 跑完
Restore(...);        // 这时 ApplyEffect 才安全
```

## 反思与总结



1. **关卡组织是 trade-off**:demo 规模用单场景多关(状态零搬运、可编辑器实时调),关卡多了再升级多场景 + DDOL / 数据重建。
2. **黑屏转场把"切换瞬间"藏起来**,配合相机 `SnapToTarget`(Lerp 相机会滑屏)。

4. **值类型字段读出来是拷贝**,改局部变量无效;要改对象状态必须直接赋值。
5. **恢复的时序**:等玩家 `Start` 完成再做,否则被重算覆盖。

至此 demo 有了"完整游戏循环":能玩、能死、能收集、能装备、能过关、能存档。下一步是把三关的真实内容搭出来。
