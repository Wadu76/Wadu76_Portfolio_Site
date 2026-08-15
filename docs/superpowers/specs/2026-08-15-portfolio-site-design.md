# portfolio-site 设计文档

日期：2026-08-15
状态：已与用户确认

## 1. 目标

给 Wadu76（游戏客户端 / Movement·3C 方向，2027 届）做一个个**可投放的作品集 + 开发学习碎片站**：
- 展示游戏项目（视频、截图、简介、开发过程）
- 记录开发学习碎片（独立于项目的博客）
- 内容全部**本地文件驱动**：写 markdown、丢图片/视频进文件夹 → git push → Vercel 自动构建上线
- 部署后招聘方可直接访问

## 2. 技术栈

- **Astro**（静态站点生成器，内容集合驱动）
- 全局 CSS（复用 `C:\Users\Wadu76\portfolio\index.html` 的 Carnival 设计系统，不重新发明）
- 无后端、无数据库
- 部署：**Vercel**，git push 自动构建

## 3. 站点结构（纯中文）

| 页面 | 路由 | 内容 |
|---|---|---|
| 首页 | `/` | Hero → 跑马灯 → Projects（自适应卡片）→ 最新日志（4 条 + 全部日志→）→ About → 页脚 |
| 项目列表 | `/projects` | 所有项目卡片 |
| 项目详情 | `/projects/[slug]` | 视频 + 截图画廊 + 技术标签 + 简介 + 详细正文（开发过程/设计思路/代码亮点） |
| 日志列表 | `/blog` | 所有学习碎片，按时间倒序 |
| 日志详情 | `/blog/[slug]` | markdown 正文，可嵌图片/视频 |
| 关于 | `/about` | 自我介绍、技能、联系方式、简历链接 |

导航：**项目 / 日志 / 关于** 三个独立入口。

## 4. 内容模型

两类内容严格分开。

### 项目 `src/content/projects/*.md`
```
---
title: 项目名
subtitle: 一句话副标题
date: 2026-08-15
tech: [Unity, C#, 2D]
cover: /media/images/xxx.jpg
gallery: [/media/images/a.jpg, /media/images/b.jpg]   # 截图列表，可空
video: /media/videos/xxx.mp4                          # 演示视频，可空
featured: true                                        # 是否首页大卡
---
正文：简介 + 详细内容（markdown，可写开发过程、设计思路、代码片段）
```

### 开发日志 `src/content/blog/*.md`
```
---
title: 标题
date: 2026-08-15
category: movement | unity | 手感 | 算法 | ...   # 自由标签
cover: /media/images/xxx.jpg                       # 可空
---
正文：学习碎片（markdown，可插图片 / 视频）
```

## 5. 视觉设计：Carnival × Apple

### Carnival（复用自 portfolio/index.html 的 tokens.css）
- 纸底：奶油粉 `oklch(92% 0.045 50)`（#f2e7d4）
- 墨：深茄子紫 `oklch(18% 0.080 20)`（#2e1f2d）
- 强调：芥末黄 `oklch(86% 0.18 95)`（#f2c14e）+ 酒红 `oklch(40% 0.21 25)`（#7d2b32）
- 展示字体：Big Shoulders Display（大写、重字重、窄体）
- 正文：Inter；等宽：JetBrains Mono
- 半调网点、粗描边、硬阴影、跑马灯
- 内容宽度 **960px**

### Apple 动效
- 导航毛玻璃：`backdrop-filter: blur(14px) saturate(1.6)`，半透明纸底
- 卡片入场 / 悬停用 **spring**（`cubic-bezier(0.34,1.56,0.64,1)` 或 spring 库），可打断、有速度感
- 按压反馈：`pointer-down` 立刻 `scale(0.97)`
- 进退场同路径、对称
- 版块入场依次错开（stagger 30–80ms）
- `prefers-reduced-motion` 全套兜底：降级为淡入，移除位移动画

### Projects 自适应布局
- **1 个**：居中限宽大卡（顶部图 16:9 + 底部文字），不横贯整页
- **2 个**：并排两张卡
- **3 个**：bento 一大两小
- **4+**：网格延伸
- 卡片缩略图一律**一张图**；视频在详情页播放

## 6. 内容工作流（"实时更新"）

1. 写文章：在 `src/content/blog/` 新建 `.md`（项目同理在 `src/content/projects/`）
2. 图片/视频：丢进 `public/media/images/`、`public/media/videos/`，正文里引用 `/media/...` 路径
3. `git add / commit / push`
4. Vercel 自动构建上线（约 1 分钟）
- 视频限制：**小片段**（< 100MB），大视频另想办法（bilibili 外链备选）
- 本地预览：`npm run dev`

## 7. 边界情况

- 项目/日志为空 → 版块显示友好占位（"暂无"），不报错
- 无封面图 → 用渐变 + 文字兜底
- 标题过长 → overflow-wrap: anywhere 兜底
- 视频缺失/路径错 → 显示占位，不崩
- 移动端 → 网格塌成单列，跑马灯照常

## 8. 测试

- `npm run build` 通过
- 本地 `npm run dev` 逐页检查：首页 / 项目列表 / 项目详情 / 日志列表 / 日志详情 / 关于
- 每个项目、每篇日志各建一篇样例内容验证渲染
- 检查 reduced-motion

## 9. 部署

- GitHub 新建仓库 → 推代码
- Vercel 导入该仓库 → 自动部署
- 后续更新 = 本地改文件 + push

## 10. 样例内容

建站时预置 1 个示例项目（basic_movement）和 2-3 篇示例日志，方便用户看到真实效果并照着改。
