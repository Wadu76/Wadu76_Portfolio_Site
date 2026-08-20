---
title: 可穿越平台
date: 2026-08-19
category: unity
---

这篇记录可穿越平台(one-way platform)的完整实现过程:两套候选方案、一轮轮判断逻辑的演进、七八个坑,以及最后为了给下一个功能(墙滑 / 墙跳 / 扒墙)让路,把大半脚本删掉、只剩三行判定的「妥协」。这一章是我目前拉扯最久、也学到最多的一次。
## 演示

从下方顶上去能穿过、从上方落能站住，S+空格可以从上穿下去的实际效果:

<video controls src="/media/videos/PlatformPenetrationVideo.mp4"></video>

## 需求:为什么不用 PlatformEffector2D

Unity 自带 `PlatformEffector2D`,默认就是「从上面落能站、从下面顶能穿」的可穿越平台。但我不用它,原因有两个:

1. 它是引擎黑盒,规则和手感都受限,不好精细控制。
2. 作品集要讲得出原理。面试官问「可穿越平台怎么做的」,答「挂了 PlatformEffector2D」等于没答。

所以手搓,规则就**从上方落下能站住,从下方顶上去能穿过**,之后再扩展 S+空格 主动下穿。

**核心思路(两套方案共用)**:穿越不是改碰撞几何,而是**切换玩家所在的 layer**——实体态碰撞平台,穿越态不碰撞平台,两态之间靠一条 bool 判断「现在该不该穿」。

- `Character`(13)× `Platform`(10)= **碰撞**(实体态)
- `CharacterIgnorePlatform`(14)× `Platform`(10)= **不碰撞**(穿越态)
- `Ignore × Ground` **必须保持碰撞**——否则切到穿越层的瞬间,脚直接穿过地板掉出世界。

真正的难点不在切层,而在**那条 bool 怎么判断才不误伤**。这就是两套方案的分歧点。

## 方案 A:脚下射线

**思路**:脚底发一条射线测「脚下有没有表面」。有表面 = 能站 = 实体;下落中且脚下悬空 = 该站住;正在上升 = 该穿(从下往上顶)。

```csharp
bool needPenetrate =
    dropThroughTimer > 0            // S+空格 显式下穿
    || rb.velocity.y > 0.1f         // 正在上升 → 从下往上顶
    || !HasGroundBelow();           // 下落中 且 脚下悬空 → 该站住

bool HasGroundBelow()
{
    float length = Mathf.Abs(rb.velocity.y) * Time.fixedDeltaTime + 0.1f; // 速度越快射越长,防隧穿
    return Physics2D.Raycast(transform.position, Vector2.down, length, platformMask);
}
```

射线长度用 `|velocity.y| * fixedDeltaTime + 余量` 动态计算:下落越快,单帧位移越大,射程就得越长,否则一帧跨过平台测不到(防隧穿)。

**优点**:

- 一条规则讲清楚:「下落中 且 脚下有表面 → 实体」,面试最好讲。
- 可复用。以后扒墙,把「脚下射线」换成「面前水平射线」,同一套骨架。

**致命缺点——单点检测**:射线只测一个点。玩家**半只脚站在平台边缘**时,射线落在平台外 → 判「脚下没表面」→ 该穿,玩家直接掉下去。

本人并不满足于这一点。

要救就得从「单点」升级到「面积」:把射线换成 **BoxCast**(宽度 ≈ 脚宽)或多条射线。复杂度立刻上来,而且 BoxCast 宽度调多少、脚踩多深才算站,全是手感玄学。且有点偏离原本用射线图方便的初衷了。

## 方案 B:sensor 触发切层

**思路**:站不站**完全交给物理**——玩家平时就在实体层,由引擎去碰撞。只在特定条件成立时切到穿越层。判断「该不该穿」用挂在玩家身上的一个 **sensor**(IsTrigger collider,从膝盖到头、朝面向方向突出一截)去碰平台,碰到就穿。

```csharp
// 每帧:计算"该不该穿"
void RefreshPlatformPenetrate()
{
    bool needPenetrate =
        dropThroughTimer > 0f                        // S+空格 显式下穿
        || rb.velocity.y > riseSpeedThreshold        // 从下往上顶
        || SensorHitsPlatform();                     // sensor 碰到平台

    SetPenetration(needPenetrate);   // 应用:切 layer
}

// 切层:层没变就不切,防止每帧重复写
void SetPenetration(bool penetrate)
{
    int target = penetrate ? _layerCharacterIgnorePlatform : _layerCharacter;
    if (moveCollider.gameObject.layer == target) return;
    moveCollider.gameObject.layer = target;
}
```

**优点**:

- **没有半脚问题**。站不站得住是物理碰撞说的算,不是一根射线说的算。玩家站平台边缘,身体一半在平台上方,引擎自然把它顶住。
- 判断收敛成一句「要不要穿」。

**sensor 摆放必须精确**:

- **不能碰脚底**——否则站平台上 sensor 永远贴着平台,永远判穿。
- **不能含头顶正上方**——否则玩家从高台跳下,头顶残留着高台边角,sensor 碰到它,误判穿越。这是后面 bug1 的根因。

## 为什么选 B

拉锯点就是那个半脚问题。A 的「单点检测」天生漏判,要用 BoxCast / 多射线去补,补出来的手感还玄;B 的半脚问题被物理引擎天然解决,代价只是 sensor 摆放要精确、判断逻辑要想清楚。

选 B。核心判断:**让物理做它擅长的事(站不站得住),脚本只做它擅长的事(要不要穿)**。A 把物理的活抢过来用射线模拟,怎么模拟都不如引擎真实。

## B 方案里最难的部分

选了 B,真正的战斗才开始:sensor 碰到平台,到底该穿还是该站?这条判断迭代了三次。

### v1:sensor 碰触即穿
这一套能做到很丝滑的，迎面撞上还能穿过墙的表现。但是疏忽了下落的判断。

```csharp
bool needPenetrate = platformSensor.IsTouchingLayers(platformMask);
```

**Bug1 高跳低穿透**:从高一点的平台跳下,会直接穿透低一点的平台。

**原因**:sensor 是「膝盖到头 + 面前突出一截」的盒子。从高台往下跳,**头顶还残留着高台**时,sensor 碰到头顶残留 → 判穿 → 保持穿越态 → 落到低平台直接穿过去。下落迎面撞上平台也碰 sensor → 判穿。「碰触即穿」这条思路太粗,分不清「从上面落下来该站」和「从下面顶上来该穿」。

### v2:速度方向门控

```csharp
bool needPenetrate = rb.velocity.y >= 0f && platformSensor.IsTouchingLayers(platformMask);
```

**被否决**:这条会把「下落中迎面撞上平台」也判成不穿——玩家高速下落迎面撞平台,本该穿过去,却被侧壁挡一下很突兀。**用速度方向分站/穿,误伤了「下落中迎面撞」这个合法穿越场景。**

现在复盘来看也许我可以用**x向速度**进行判断？以后墙体动作可以用这个思路。
### v3(最终也删掉了):按位置,不按速度方向

**sensor 碰到的平台,顶高于玩家脚底 → 穿;平台顶 ≈ 脚底 → 站**。

```csharp
// 遍历 sensor 碰到的每个平台,只要有一个平台的顶高于玩家脚底 → 该穿
bool SensorHitsPlatformAboveFeet()
{
    sensorHits.Clear();
    platformSensor.OverlapCollider(platformFilter, sensorHits);

    foreach (Collider2D col in sensorHits)
    {
        if (groundCheck.position.y < col.bounds.max.y - platformTopTolerance)
            return true;
    }
    return false;
}
```

要点:

- 用 `OverlapCollider(ContactFilter2D, List<Collider2D>)` 拿到 sensor 实际碰到的**具体平台**,而不是一个笼统的「碰没碰」。
- 比较**平台顶** `col.bounds.max.y` 和**玩家脚底** `groundCheck.position.y`。平台顶高于脚底 → 玩家「处在平台上方区域」→ 该穿;齐平 → 踩在平台顶面 → 该站。
- 五个场景全部自洽,不用分 case:

| 场景 | 平台顶 vs 脚底 | 结果 |
|---|---|---|
| 从上方落、踩顶站住 | 齐平 | 站 ✓ |
| 从下方顶上去、穿出前 | 平台顶 > 脚底 | 穿 ✓ |
| 下落中迎面撞平台 | 平台顶 > 脚底 | 穿 ✓ |
| 半脚站边缘 | 由物理碰撞决定站住 | 站 ✓ |
| 高跳低、头顶残留高台 | 头顶残留平台顶 > 脚底 | 穿 ✓ |

**最硬的一课**:区分站/穿,**看位置,别看速度方向**。位置是几何事实,方向是瞬时状态——用方向去推断,必然在「下落中迎面撞」这种方向对不上语义的场景翻车。

## 过程中的坑(按出现顺序)

### 可能会遇到的坑 1:物理碰撞矩阵调整有误

**现象**:实体层不碰撞，穿越层碰撞等bug现象



**修复**:改对——`Character×Platform=ON`、`Ignore×Platform=OFF`、`Ignore×Ground=ON`。

这种**配置型 bug 无报错**,只能靠行为反推 + 逐对核对矩阵 hex。

### 坑 2:站平台上一直在播 Fall 动画

**现象**:从平台底部跳上去,站得住,但一直播下落动画。

**原因**:起初以为是PlayerController 的 `groundLayer` 只勾了 Ground(9),**没勾 Platform(10)**。`isGrounded = Physics2D.OverlapCircle(...)` 永远查不到平台 → 恒 false → 动画机一路 Fall。

```csharp
isGrounded = Physics2D.OverlapCircle(groundCheck.position, groundCheckRadius, groundLayer);
```

但实际上是因为我们跳的时候直接就可以跳上平台，应该有`Jump → Idle`的animator状态切换，但之前没有过需要这个的机制。

**修复**:补 `Jump → Idle` 动画过渡。(在Animator里`Jump → Idle`的线) 条件为isGrouned == true && Velocity.y < 0.1f。

y向速度判断也是必须的，因为在平台中到平台可踩区域间会有一系列动画抽搐（jump&Idle），原因是我们Idle判断y向大于0.1就可以转到Jump，所以我们只当y向速度到0.1以下才允许切换到Idle，一步到位就不会抽出了



### 坑 3:高速下落穿透平台(物理隧穿)

**现象**:跳起来接一个向上 dash,高速落下来,直接穿平台掉到地上。脚本没报错,判断逻辑也对。

**原因**:**物理隧穿,不是脚本的错。** `Rigidbody2D` 默认 `Discrete`,只在**每帧位移后的终点位置**做重叠检测。高速下落一帧位移 > 平台厚度 + 玩家尺寸,终点直接跨过平台 → 这一帧根本没「经过」平台 → 漏检。

```csharp
// 修复:对静态平台做扫掠检测(sweep),整段位移都纳入检测
rb.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
```

**学到(面试知识点)**:物理仿真是**离散步进**,一帧一步。速度 × 单帧时长 = 单帧位移,超过被检测物体尺寸就会隧穿。高速移动的角色,碰撞检测必须开 Continuous。这和我之前视差篇的「物理步进」是同一个知识体系。

**要不要根据速度动态切换 Discrete / Continuous?不要,固定 Continuous 即可。**

- 2D 的 `Continuous` 只对「该刚体 vs **静态** collider」做扫掠检测,动态刚体之间仍然走离散。场景里会高速移动的只有玩家,平台是静态的,玩家固定开就够。
- 动态切换没有收益:切换有内部状态重建开销,还要为「多快算高速」多设一个阈值,徒增调参点和抖动边界。
- 真要优化,方向是「只给会高速的刚体开 Continuous,其余保持 Discrete」,而不是按速度临时切。

另外别和 interpolation 搞混:`Continuous` 管「碰撞检不检得到」,`Interpolate` 管「渲染平不平滑」,两个独立开关。

### 接入 Controller

把 `DropThrough()` 接进跳跃逻辑出过如下错:

1. **else 分支放错**:`jumpBufferTimer = jumpBufferTime` 被塞进 `platformPenetration == null` 的 else → 正常按空格既不跳也不下穿。
3. **判断用错变量**:用 `dropThroughTime`(配置值,恒 true)而不是 `dropThroughTimer`(计时器)→ 永远穿越。
4. **timer 忘了递减**:`dropThroughTimer` 只加不减 → 穿一次永久穿。

正解(现在 Controller 里的写法):

```csharp
if (Input.GetButtonDown("Jump"))
{
    // S+空格 下穿;否则普通跳跃。下穿和缓冲互斥。
    if (Input.GetKey(KeyCode.S) && platformPenetration != null)
        platformPenetration.DropThrough();
    else
        jumpBufferTimer = jumpBufferTime;
}
```

`DropThrough()` 只做一件事:给计时器充值。真正的判定在 `FixedUpdate` 里统一执行:

```csharp
void FixedUpdate()
{
    if (dropThroughTimer > 0f)
        dropThroughTimer -= Time.fixedDeltaTime;   // 计时器递减
    RefreshPlatformPenetrate();
}
```

**学到**:方法要**接进帧回调、计时器要记得递减、判断要用运行字段而不是配置字段**——这三步是「写完了」之后最容易漏的三步。

## 最终妥协:删掉大半,为墙系统让路

到这里功能其实已经全好了。但贴平台侧面的一个 edge case,把更重要的矛盾引了出来:

**现象**:从低平台跳 + dash 到高平台边缘,脚底已高于平台顶,但身体中部撞到侧壁,被挡在侧面贴住,按住方向就贴着,动画播 Fall。

**原因**:dash 上升分量让脚底超过平台顶 → 位置判定判「在上方、不穿」→ 保持实体态 → 被侧壁挡住。这本身不是 bug,是「贴墙」的正常物理。

**但它引出了真正的矛盾**:**auto 穿越逻辑和未来的墙系统冲突。** 扒墙时,玩家在墙(可穿越平台)的下方,墙顶高于玩家脚底 → 位置判定「该穿」→ 一扒就穿进墙里。auto 穿越(靠 sensor 自动判断)无法区分「从下方顶上去该穿」和「扒在墙上该站」。

所以做了这次开发里**最大的取舍:删掉大部分脚本,只留两行判定**。

最终 `PlatformPenetration.cs` 精简形态:

```csharp
public class PlatformPenetration : MonoBehaviour
{
    [SerializeField] private Collider2D moveCollider;
    [SerializeField] private Rigidbody2D rb;
    [SerializeField] private float dropThroughTime = 0.5f;      // S+空格 强制下降时长
    [SerializeField] private float riseSpeedThreshold = 1f;     // 从下往上升的速度阈值

    private int _layerCharacter;
    private int _layerCharacterIgnorePlatform;
    private float dropThroughTimer;

    public bool CanPenetratePlatform
        => moveCollider.gameObject.layer == _layerCharacterIgnorePlatform;

    void Awake()
    {
        if (rb == null) rb = GetComponent<Rigidbody2D>();
        // 层索引缓存一次,别每帧 NameToLayer
        _layerCharacter = LayerMask.NameToLayer("Character");
        _layerCharacterIgnorePlatform = LayerMask.NameToLayer("CharacterIgnorePlatform");
    }

    void FixedUpdate()
    {
        if (dropThroughTimer > 0f)
            dropThroughTimer -= Time.fixedDeltaTime;
        RefreshPlatformPenetrate();
    }

    void RefreshPlatformPenetrate()
    {
        bool needPenetrate =
            dropThroughTimer > 0f                  // S+空格 显式下穿
            || rb.velocity.y > riseSpeedThreshold; // 从下往上顶(单程平台核心)

        SetPenetration(needPenetrate);
    }

    public void DropThrough()
    {
        dropThroughTimer = dropThroughTime;
    }

    void SetPenetration(bool penetrate)
    {
        int target = penetrate ? _layerCharacterIgnorePlatform : _layerCharacter;
        if (moveCollider.gameObject.layer == target) return;   // 层没变就不切
        moveCollider.gameObject.layer = target;
    }
}
```

**删掉了什么(为后续发展)**:

- `platformSensor`(sensor collider)及其字段
- `groundCheck` 引用、`platformTopTolerance`
- `ContactFilter2D` / `sensorHits` 列表 / Awake 里的 filter 初始化
- `SensorHitsPlatformAboveFeet()`——整套「sensor 碰平台 + 比较平台顶 vs 脚底」的位置判定

**保留了什么**:

- `SetPenetration()`(层没变就不切,防每帧重复写)
- `DropThrough()`(S+空格 显式下穿入口)
- layer 缓存(Awake 里 `NameToLayer` 一次)
- `CanPenetratePlatform` 只读属性(当前没有调用方,为后续系统预留)
- **`velocity.y > riseSpeedThreshold` 这一行**——它是「从下往上顶」这个单程平台核心语义的唯一入口,没有它,玩家从平台下方跳上来会顶在底部上不去。阈值 1,低于它说明只是抖动,不穿。

**为什么敢删**:

- **「从上方落能站住」全交还给物理**。玩家平时就在实体层,物理天然站住,不需要任何脚本判断。半脚站边缘、踩顶站住,这些原本靠 sensor 判的场景,物理本来就做得更好。
- **换来的是贴墙可靠**。玩家平时实体 → 撞墙就停 → 墙检测以后用**水平射线**做,和穿越逻辑**正交**,互不干扰。扒墙、墙滑、墙跳都不会被 auto 穿越误伤。

**学到**:sensor 方案做到最后,真正值钱的不是那套越来越复杂的判定,而是**想清楚每个部分该由谁负责**——站不站由物理负责,该不该穿只留两个明确入口。**给未来功能让路时,敢删比敢加更需要判断力。** 如果墙系统做完后发现需要「半自动穿越」,再按需把 sensor 那套加回来,代码边界依然是干净的。

## 回到原点:如果用 PlatformEffector2D 会怎么解决

写完整实现之前,先认真回答开头那个问题:**直接用引擎自带的不就完了吗?** 值得算一笔账——它到底能覆盖到哪一步、到不了哪一步。

给平台挂一个 `PlatformEffector2D`(带 BoxCollider2D),四个关键设置:

```csharp
var effector = platform.AddComponent<PlatformEffector2D>();
effector.useOneWay = true;           // 开单程
effector.surfaceArc = 180f;          // 只有"顶面"算有效表面
effector.useSideFriction = false;    // 侧面不摩擦,不会被卡在侧壁
effector.useSideBounce = false;
```

**原理一句话:`surfaceArc` 决定「哪个角度的接触才算有效表面」。** 碰撞发生时,引擎检查接触点法线:落在 arc 内 → 有碰撞响应;落在 arc 外 → 无响应 → 穿过。从上方落下接触法线朝上(顶面)→ 站住;从下方顶上来接触法线朝下(底面)→ 穿过。这就是「单程」的全部秘密:**检测到碰撞,但接触面不在有效表面范围内 → 不响应**。

**它能覆盖**:从上方落站住、从下方顶穿、半脚站边缘、侧面不卡(`useSideFriction=false`)。前四坑里大半它都天然解决。

**它不能覆盖(这就是手搓的理由)**:

1. **S+空格 主动下穿——引擎没有「主动放弃支撑」的开关。** 平台永远在下面撑着,按 S+空格 不会掉下去。要补脚本,常见两招:`Physics2D.IgnoreCollision(player, platform, true)` 临时忽略这对碰撞、计时结束恢复;或临时切 layer——**这正是我手搓方案的同款招数**。
2. **高速隧穿——PlatformEffector2D 只是「碰撞响应规则」,不改「检测方式」。** 玩家刚体照样要 `Continuous` 才防隧穿。**这条坑引擎方案躲不掉,是物理仿真的共性。**
3. **手感参数——下穿窗口多长、上升速度阈值多少,引擎没有任何对应参数。**

所以手搓是为**看清引擎到哪一步为止、剩下的事自己写**。面试官问「为什么不用 PlatformEffector2D」,能答出 它覆盖哪些、不覆盖哪些、补下穿的招其实和手搓同源。

## 总结

可穿越平台 = 切 layer 实现双态 + 只保留两个穿越入口(`DropThrough` + 上升速度),其余交给物理。两套方案 → 判定的演进 → 删减重构 这条路径,比任何单个知识点都更能展示一个完整的工程思考过程:从想要一个功能到想清楚每个部分该由谁负责。

下一步:墙滑 / 墙跳 / 扒墙(水平射线,与穿越逻辑正交),状态机重构也已排上日程。


