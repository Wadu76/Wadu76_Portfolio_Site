---
title: 视差滚动与无限循环背景
date: 2026-07-17
category: unity
---

本人在开发的 2D 平台跳跃 demo。这篇记录视差滚动与无限循环背景的原理、实现,以及实现中遇到的问题。



## 来历:两个概念从哪来

 **视差(parallax)** 本来是天文学概念:从地球公转轨道上相隔很远的两个位置观察同一颗恒星,它在背景星空中的位置会有微小偏移,根据这个偏移可以测算恒星距离。我们两只眼睛看到的世界略有差异,也是视差——它是最基本、最廉价的深度线索。

游戏里的"视差滚动",是把同样的道理搬进 2D:背景按深度分成几层,每层以不同速度滚动,离得"远"的层滚得慢。这个技巧从街机时代(1980 年代)就开始大量使用,后来在 Sonic、Castlevania 这类 2D 动作游戏里成为标配。它的价值在于:**不引入任何 3D 数学,只靠调整每层的滚动速度,就营造出空间纵深感。**

**无限循环背景**源自"图案重复"的思想。2D 平台跳跃里角色要持续前进,背景不可能做无限长,于是用"可无缝拼接的图 + 履带回卷"代替:一张图,左右两侧设计成能自然接上,重复排列时不露接缝。这本质上是一个**周期性**问题:把有限的图案,通过循环,伪装成无限。

## 原理:视差系数到底是什么

2D 视差的数学本质,是一次透视投影的简化。

想象一个真实相机横向移动了 Δ。画面里的某个点,离相机越近,它在屏幕上的位移越大;离得越远,位移越小。粗略地看,屏幕位移 ∝ Δ ÷ 深度,即 **位移和深度成反比**。

2D 视差的 `speed` 系数,就是在模拟这个"1 ÷ 深度"——它本质上是这一层的**相对深度**。`speed = 1` 表示层和镜头完全同步(相当于贴脸);`speed = 0.2` 表示这一层大约在 5 倍远的地方(1 ÷ 0.2)。理解了这一点,调参就有了依据:**层之间要拉开差距,是因为深度本身要拉开差距**。如果所有层系数都挤在 0.8 ~ 0.9,等于所有东西都处在同一个深度,自然没有层次感。

如下是设置三层不同速体现出来的视差效果：
![视差演示](/media/images/blog/2026-08-17-infinite-background-parallax/视差演示图.gif)

## 原理:无限循环的数学

设一张背景图的世界宽度为 W。两张相同的图并排,间距正好 W,左缘/右缘位置相差 W,拼起来是连续的。

镜头带着角色向右移动,两张图相对镜头都在向左"漏出"。回卷的判断依据是:**某张图和镜头的水平距离超过 W**。此时把它沿镜头方向平移 2W——平移后它正好落到另一张图的背后,和它"原本应该在的位置"完全重合。

为什么是 2W 而不是 W?因为要把这张图从"镜头前方已经漏出去的位置"挪到"镜头后方另一张图的位置",中间隔着整整两张图的宽度。从数学上看,这一步是在**强制周期性**:整幅背景按周期 W 重复,回卷只是把"已经出画的副本"放回它周期性等价的位置。

无缝是前提:如果图片左右边缘在视觉上不连续(比如左右各剩半截天空),那么每张图边界都会出现一条明显的缝,回卷算法再正确也盖不住。

如下是本实现方法的具体体现gif图
![无限背景移动](/media/images/blog/2026-08-17-infinite-background-parallax/无限背景移动图.gif)
## 实现

### 视差(Parallax.cs)

每层背景容器挂一个 `Parallax`,记录相机上一帧的位置,计算水平位移增量后乘以速度系数:

```csharp
public class Parallax : MonoBehaviour
{
    private Transform _mainCamera;
    private Vector3 _lastPosition;

    [SerializeField] private float speed = 1f;

    void Start()
    {
        _mainCamera = Camera.main.transform;
        _lastPosition = _mainCamera.position;
    }

    void LateUpdate()
    {
        ParallaxMove();
    }

    void ParallaxMove()
    {
        float deltaX = _mainCamera.position.x - _lastPosition.x;
        transform.position += new Vector3(deltaX * speed, 0, 0);
        _lastPosition = _mainCamera.position;
    }
}
```

我的参数:最远层 0.2,近景 0.8,中间 0.5、0.6 分档。

### 无限循环(BackGoundScroller.cs)

每张背景图挂一个 `BackGoundScroller`:

```csharp
public class BackGoundScroller : MonoBehaviour
{
    private Camera mainCamera;
    private float bgWidth;

    void Start()
    {
        mainCamera = Camera.main;
        bgWidth = GetComponent<SpriteRenderer>().bounds.size.x;
    }

    void LateUpdate()
    {
        BgMove();
    }

    void BgMove()
    {
        float distance = mainCamera.transform.position.x - transform.position.x;

        if (Mathf.Abs(distance) > bgWidth)
        {
            transform.position += Vector3.right * bgWidth * 2 * Mathf.Sign(distance);
        }
    }
}
```

`bgWidth` 从 `SpriteRenderer.bounds` 读取,不依赖硬编码。



## 遇到的问题

### 问题 1:背景完全不动

**现象**:两张背景图静止,没有回卷。

**原因**:脚本里只有 `Start()`,`BgMove()` 没有挂进任何帧回调。Unity 不会自动执行一个"看起来应该执行"的方法,它只调用挂在 `Update` / `LateUpdate` / `FixedUpdate` 等生命周期回调里的逻辑。`BgMove()` 定义了但没有被调用,等于死代码。

**处理**:加 `LateUpdate(){ BgMove(); }`。放在 `LateUpdate` 而不是 `Update`,是因为背景要读取镜头的最终位置,而镜头跟随逻辑也放在 `LateUpdate`,这样读到的是这一帧更新完成后的位置。

顺带验证了场景布局本身没有问题:两张 Background0 距离 21.73,图片世界宽度 21.72,恰好差一张图宽,回卷公式不会露缝。

### 问题 2:冲刺时背景出现明显顿挫

**现象**:正常移动时背景平滑,冲刺时背景一卡一卡,像慢半拍。

**原理(为什么物理会卡)**:物理引擎按**固定频率步进**,默认 50Hz,即每 0.02s 计算一次。刚体的 transform 只在物理步进时更新,所以刚体位置是**离散**的。渲染则按显示器帧率走(60 / 120 / 144Hz 不等),两套节奏天然不同步。

相机最初是 Player 的子物体,继承了刚体的离散位置。视差脚本逐帧读取 `camera.position`,读到的值"每 0.02s 跳变一次",背景跟着跳。

步行时不明显、冲刺时明显,是因为单次物理步进的位移 = 速度 × 0.02s。移动速度 5 时每步 0.1 单位,肉眼难以察觉;冲刺速度 15 时每步 0.3 单位,跳变清晰可见。**速度越高,问题越明显。**

**处理**分两步:

(1) 开启刚体插值。插值不改变物理计算,只让显示位置在两次物理步进之间平滑过渡:

```csharp
rb.interpolation = RigidbodyInterpolation2D.Interpolate;
```

(2) 将相机从 Player 子物体拆出,单独挂 `CameraFollow`,在 `LateUpdate` 中读取目标位置。因为已开启插值,`target.position` 是物理步进之间被平滑过的值:

```csharp
public class CameraFollow : MonoBehaviour
{
    [SerializeField] private Transform target;

    void LateUpdate()
    {
        Vector3 pos = target.position;
        pos.z = transform.position.z;   // 保留相机自己的 z,只对齐 x / y
        transform.position = pos;
    }
}
```

相机作为物理刚体子物体会继承离散的物理步进。常见的三种镜头跟随方式中,挂在角色下方实现最简单但高速时必卡;在 `LateUpdate` 里读插值后的位置、或用 `Lerp` 缓动,才是平滑的方案。

### 问题 3:远景与近景层次不明显

**现象**:各层移动速度接近,背景整体像单层。

**原因**:各层 `speed` 差距太小,原设置最远层为 0.9,等于所有层几乎处在同一深度(见"原理:视差系数"一节)。

**处理**:最远层降到 0.2,近景 0.8,拉开差距后视差效果明显。参数全部暴露在 Inspector 中,方便调整。

## 遗留问题

到达关卡尽头时,背景仍会继续循环,产生"关卡结束但背景还在"的突兀感。无限循环背景是无缝图,不关心关卡边界;图是无限的,关卡是有限的,两者结构上不对应。需要额外的收尾处理(关卡边缘的结束背景或遮罩),或把关卡边界设计在镜头范围之外。目前尚未处理。

总而言之最后的效果如下图
![最终效果](/media/images/blog/2026-08-17-infinite-background-parallax/最终效果图.gif)
