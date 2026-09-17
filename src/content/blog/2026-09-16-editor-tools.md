---
title: 自研关卡编辑器工具
date: 2026-09-16
category: unity
---

这篇记我为什么开始写 Unity 编辑器工具、第一版踩了什么、以及最后做成一个 `EditorWindow` 的过程。它和玩法代码是两条不同的线:**玩法是"给玩家做的功能",工具是"给我自己做的功能"。**

## 为什么动手:两个真实动机

**动机一:手点会点到吐。** 关卡里有一段需要沿 X 轴每隔 0.5 摆一个墙,一共 30 多个。手动 Ctrl+D 复制、拖位置、改坐标……不仅慢,还容易摆歪、漏摆。

**动机二:配错一次,排查半天。** 有一次墙滑/墙跳突然全部失效,查了很久才发现是**搭墙的时候忘了把墙设成 `WallJumpPlats` 层**——机制依赖层,层靠人手配,人手就会错。

第二个动机比第一个更重要:**工具的价值不只是"快",更是"消除人为错误"。**

## 第一版:`MenuItem` + 写死参数

最省事的做法是给 Unity 菜单栏加一条命令:

```csharp
public static class WallArrayTool
{
    [MenuItem("Tools/Wall Array/沿X阵列复制")]
    static void ArrayAlongX()
    {
        GameObject src = Selection.activeGameObject;   // 当前选中的对象
        int count = 30;  float dx = 0.5f, dy = -0.001f; // ← 参数写死在代码里

        for (int i = 1; i < count; i++)
        {
            GameObject clone = Object.Instantiate(src, src.transform.parent);
            clone.transform.position = src.transform.position + new Vector3(i * dx, i * dy, 0f);
            Undo.RegisterCreatedObjectUndo(clone, "Array");   // 让 Ctrl+Z 能撤销
        }
    }
}
```

能用。**但用几次就烦了**:换一段墙要改数量、改步进 → 就得回去改代码、等重编译。**"能用"和"好用"之间差的就是这个。**

## 第二版:`EditorWindow`

于是把它重做成一个带面板的编辑器窗口:

```csharp
public class LevelToolsWindow : EditorWindow
{
    private float gridSize = 0.5f;
    private int arrayCount = 10;
    private float arrayDx = 0.5f, arrayDy = 0f;
    private int targetLayer = 0;

    [MenuItem("Tools/关卡工具")]
    private static void Open() => GetWindow<LevelToolsWindow>("关卡工具");

    private void OnGUI()
    {
        gridSize = EditorGUILayout.FloatField("网格大小", gridSize);
        if (GUILayout.Button("把选中对象吸附到网格")) SnapToGrid();

        arrayCount = EditorGUILayout.IntField("数量", arrayCount);
        arrayDx = EditorGUILayout.FloatField("X 步进", arrayDx);
        if (GUILayout.Button("生成阵列")) ArrayAlongX();

        targetLayer = EditorGUILayout.LayerField("目标层", targetLayer);
        if (GUILayout.Button("批量设置 Layer")) ApplyLayer();

        EditorGUILayout.LabelField($"当前选中:{Selection.gameObjects.Length} 个对象");
    }
}
```

现在参数在面板上直接调,不用改代码。

### 四个功能

| 功能 | 解决什么 |
|---|---|
| **网格吸附** | 手拖永远对不齐网格,摆放不标准 |
| **轴向阵列复制** | 手点 30 次(第一版的动机) |
| **对齐 & 水平等间距分布** | 批量整理平台;等间距直接服务于**跳跃节奏设计** |
| **批量设置 Layer(含子物体)** | 从流程上消除"层配错导致机制失效" |

批量设层是这么写的:

```csharp
foreach (var go in Selection.gameObjects)
    foreach (var t in go.GetComponentsInChildren<Transform>(true))   // true = 含未激活的子物体
    {
        Undo.RecordObject(t.gameObject, "Set Layer");
        t.gameObject.layer = targetLayer;
    }
```

### 一个必须接的东西:`Undo`

**编辑器工具不接 Undo,就等于不能用**——用户按 Ctrl+Z 撤销不掉,工具就是危险的。两种场景分别用两个 API:

```csharp
Undo.RecordObject(go.transform, "操作名");            // 修改已有对象前先记录
Undo.RegisterCreatedObjectUndo(newObject, "操作名");  // 新建对象后登记
```

对齐、吸附、批次设层属于前者;阵列复制的新对象属于后者。

## 收获

1. **工具的"好用"和"能用"是两件事**:参数面板、实时反馈(选中几个对象)、可撤销(Undo)——这三样才是工具是否被真正使用的分界线。
2. **最高价值的工具往往不是"加速",而是"防错"**:阵列复制省的是几分钟,批量设层省的是"配错→机制失效→排查半天"这类**质量问题**。
3. 这几件事——`MenuItem` / `EditorWindow` / `Selection` / `Undo` / `SerializedObject`——正好是"游戏内容工业化生产工具"最基础的一块。工具做久了,关注点会自然从"这个功能怎么写"转向"**这条内容制作管线的效率和质量瓶颈在哪**"。
