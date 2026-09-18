---
title: SwarmCutter
subtitle: 十万单位同屏割草 Demo — Burst 并行物理 · 单 DrawCall 渲染
date: 2026-07-31
tech: [Unity, C#, DOTS, Burst, Job System, Unity.Mathematics, GPU Instancing, HLSL]
featured: false
---

一个"吸血鬼幸存者"式的俯视角割草 Demo,**同一时刻 10 万个敌人**追踪玩家、互相推开、绕开障碍。所有物理模拟跑在 Burst 编译的并行 Job 里,渲染只用 1 次 DrawCall,全程零 GC 分配。

这个项目的目标不是做游戏,而是做**技术验证**:不引入 ECS/Entities 的前提下,纯 Jobs + Burst + 间接实例化渲染,能不能撑起十万单位?答案是能。

游戏 demo 下载地址:https://github.com/Wadu76/VS_demo/releases/tag/v1.0.0

## 内容

- **玩法闭环**:WASD 移动 → 敌人从场地边缘持续刷新并追踪玩家 → 每 `0.28s` 朝最后移动方向挥出扇形砍击 → 命中单位播放"缩小到消失"动画 → 回收进空闲池 → 换个位置重新复活。
- **数据布局**:十万个敌人不是 GameObject,而是 `NativeArray<float4>` 里的 16 字节数据。`xyz` 存位置,`w` 用一个分量编码三种状态:**正数 = 存活(值即缩放)/ 0 = 隐形 / 负数 = 死亡动画中**。shader 里 `abs(data.w)` 让负 w 也能正常缩放 —— 所谓"死亡"只是把 w 从正改负,不销毁任何东西。
- **邻居查找(全项目最硬核的部分)**:十万单位两两比较是 `O(n²) = 10¹⁰` 次运算,必卡死。这里**自己实现了一套空间索引管线** —— 空间哈希切 80×80 网格 → 手写 LSD 基数排序(4 趟 8bit,直方图 + 前缀和 + 乒乓缓冲)让同格单位在数组里连续 → 并行二分求出每个格子的 `[start, end)` 区间。找邻居从此只需遍历 3×3 邻格。复杂度从 `O(n²)` 降到 `O(n)`。
- **斥力分离**:每单位只在邻格内做距离衰减的推力累加,力的大小随距离线性衰减,密度自然均匀,群体看起来才是"活的"而不是塌成一个点。
- **对象池**:`NativeQueue<int>` 空闲下标池。初始化时把 `[300, 100000)` 全部入队,死亡缩小到 0 就 `Enqueue` 回池,刷新时 `TryDequeue` 复用。**全程零 `Instantiate`/`Destroy`、零 GC**。
- **渲染**:`GraphicsBuffer(Structured)` 存实例数据 + `GraphicsBuffer(IndirectArguments)` 存绘制参数 + 自定义 shader 用 `SV_InstanceID` 索引 → `DrawMeshInstancedIndirect` **一次画完十万个**。
- **工程化**:Editor 一键搭场景脚本 + 一键构建 Windows 独立包的构建脚本,已发布 v1.0.0 可直接游玩。

## 每帧数据流

```
Update:
  AssignCellJob      每个存活单位算格子 key(空间哈希)
  RadixSortPassJob×4 按 key 基数排序(乒乓缓冲)
  CellStartJob       并行二分 → 每格 [start, end) 区间
  SeparationJob      3×3 邻格斥力累加
  EnemyMovementJob   追踪 + 斥力 + 抖动 + 障碍推出 + 死亡缩小回收
  AttackJob(按间隔)  扇形内单位标记死亡
  刷新              从空闲池取下标,场地边缘激活
LateUpdate:
  PushPlayerOutOfObstacles → GraphicsBuffer.SetData → DrawMeshInstancedIndirect
```

## 我与 AI 的分工

这个项目是我和 AI **协作**完成的,分工上我负责"想清楚要做什么、判断能不能做",AI 负责"把想法变成能跑的代码"。整个过程是我不断提出实现设想 → 逐步 prompt 迭代 → 验收效果 → 调参或回退。

**我负责的部分(技术方案与技术路线)**

- **反推实现方式与可行性判断**:从参考 demo 视频出发,反推"十万单位同屏"大致是怎么实现的,判断纯 Jobs + Burst 路线(而非引入 ECS/Entities)能否达成目标,并确定这条技术路线。
- **提出核心算法设想**:三处关键设计由我提出,并最终落地到代码里 ——
  - **双缓冲异步 Job 流水**:让上一帧的物理还没算完、下一帧就开跑,使 CPU 模拟与 GPU 渲染重叠(该方案经评估后判定为"当前帧率已达标、且会引入一帧输入延迟",**主动决定暂不实现**,并在技术文档中标注为进阶优化方向)
  - **邻居斥力做群体分离**:借鉴流体/群聚模拟的邻居斥力思路解决单位重叠问题
  - **障碍碰撞策略**:明确采用"暴力遍历 + 圆柱/包围盒"的简化方案,理由是障碍数量极少(个位数),暴力遍历比建索引更快更简单
- **玩法与手感定义**:攻击间隔、扇形张角、攻击半径、斥力半径与强度、死亡缩小速率等参数由我确定并反复调试。
- **工程决策与验收**:无限地图 + 镜头跟随方案试用后判定不适合当前玩法,**主动回退**为固定 80×80 大地图;对每个功能点单独提需求、跑起来看效果、不满意就回退重来。

**AI 负责的部分(编码落地与调试)**

- 把上述设想翻译成可运行的 Unity/C# 代码,拆分成 7 个职责清晰的 Job。
- **踩坑定位与修复**(全是真实遇到的):`Unity.Mathematics.float3` 没有 `forward` 属性;NativeArray 下标必须是 `int` 不能是 `uint`;触发 Burst 安全系统的 `ReadWriteBuffers are restricted to only read & write the element at the job index` 运行时异常并修正并行维度设计;`GraphicsBuffer` 参数缓冲必须指定 `IndirectArguments` 标志;`GraphicsSettings.SetShaderList` 在 2022.3 不存在,改用 Resources 目录材质钉住 shader 防止被构建裁剪。
- 撰写技术文档(README + 完整技术拆解)与构建发布脚本。

**这套分工的实质**:我提供的是**架构判断与算法选型**,AI 提供的是**编码产能与调试效率**。其中"哪些该做、哪些不该做"(比如双缓冲不做、无限地图回退)属于我的决策,并在文档里明确区分了「已实现」与「设想但未实现」,不含糊其辞。

## 性能与瓶颈

- 同一时刻 **100,000** 单位在场,单次 DrawCall,每帧 7 个 Burst Job + 1 次全量缓冲上传。
- **已知瓶颈**(按成本排序):① `GraphicsBuffer.SetData` 每帧全量上传 160 万字节,是最大单点开销;② 4 趟基数排序串行扫描。
- **后续优化方向**:双缓冲异步流水、`AsyncGPUReadback` 局部上传、把并行排序挪到 GPU Compute Shader。

## 技术栈

Unity 2022.3 LTS · C# · Job System · Burst · Unity.Collections(NativeArray / NativeQueue)· Unity.Mathematics · GraphicsBuffer · DrawMeshInstancedIndirect · 自定义 GPU Instancing Shader(HLSL)· Unity Editor 脚本

源码与完整技术拆解:https://github.com/Wadu76/VS_demo
