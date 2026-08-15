# portfolio-site 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建一个 Carnival × Apple 风格的作品集 + 开发日志静态站（Astro），内容本地文件驱动，可部署 Vercel。

**Architecture:** Astro 5 内容集合（projects / blog 两套 markdown）驱动全部页面；全局 CSS 复用 `portfolio/index.html` 的 Carnival 设计系统，叠加 Apple 动效（毛玻璃导航、spring 悬停、按压反馈、reduced-motion）。无后端，构建期静态渲染。视频/图片放 `public/media/`。

**Tech Stack:** Astro 5、纯 CSS（无 Tailwind）、无 JS 框架。部署 Vercel。

**设计文档:** `docs/superpowers/specs/2026-08-15-portfolio-site-design.md`

---

## 文件结构

```
portfolio-site/
├── package.json
├── astro.config.mjs
├── tsconfig.json
├── .gitignore
├── README.md
├── public/
│   └── media/
│       ├── images/          # 封面图/截图，SVG 占位
│       └── videos/          # 演示视频（.mp4，放小片段）
└── src/
    ├── content.config.ts        # 内容集合 schema（两套）
    ├── content/
    │   ├── projects/basic-movement.md
    │   └── blog/3 篇示例
    ├── styles/global.css        # Carnival tokens + 全部组件样式
    ├── layouts/BaseLayout.astro # <html> 头 + 字体 + 导航 + 页脚
    ├── components/
    │   ├── Nav.astro            # 毛玻璃导航
    │   ├── Footer.astro
    │   ├── Hero.astro           # 大标题 + 标签
    │   ├── Marquee.astro        # 跑马灯
    │   ├── ProjectGrid.astro    # 自适应卡片布局
    │   └── LogCard.astro        # 日志条目
    └── pages/
        ├── index.astro          # 首页
        ├── projects/index.astro # 项目列表
        ├── projects/[slug].astro
        ├── blog/index.astro     # 日志列表
        ├── blog/[slug].astro
        └── about.astro
```

---

## Task 1: 初始化 Astro 项目

**Files:**
- Create: `package.json`
- Create: `astro.config.mjs`
- Create: `tsconfig.json`
- Create: `.gitignore`

- [ ] **Step 1: 写 package.json**

```json
{
  "name": "portfolio-site",
  "type": "module",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "astro": "astro"
  },
  "dependencies": {
    "astro": "^5.0.0"
  }
}
```

- [ ] **Step 2: 写 astro.config.mjs**

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://wadu76.vercel.app',
});
```

- [ ] **Step 3: 写 tsconfig.json**

```json
{
  "extends": "astro/tsconfigs/base",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"]
}
```

- [ ] **Step 4: 写 .gitignore**

```
node_modules/
dist/
.astro/
```

- [ ] **Step 5: 安装依赖**

Run: `npm install`
Expected: 安装成功，生成 `node_modules/` 与 `package-lock.json`

- [ ] **Step 6: Commit**

```bash
git init
git add -A
git commit -m "chore: scaffold astro project"
```

---

## Task 2: Carnival 全局样式（含 Apple 动效）

**Files:**
- Create: `src/styles/global.css`

- [ ] **Step 1: 写 global.css（tokens + base + 组件类）**

```css
/* Carnival tokens —— 源自 portfolio/index.html */
:root {
  --paper: #f2e7d4;
  --cream: #f8f0e0;
  --ink: #2e1f2d;
  --ink-2: #3a2a38;
  --muted: #8a6f63;
  --mustard: #f2c14e;
  --oxblood: #7d2b32;
  --rule: #6b4a45;
  --spring: cubic-bezier(0.34, 1.56, 0.64, 1);
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --font-display: 'Big Shoulders Display', 'Arial Narrow', 'PingFang SC', 'Microsoft YaHei', sans-serif;
  --font-body: 'Inter', 'PingFang SC', 'Microsoft YaHei', sans-serif;
  --font-mono: 'JetBrains Mono', 'Cascadia Code', Consolas, monospace;
  --page-w: 960px;
  --gutter: clamp(16px, 4vw, 32px);
  --dur: 0.35s;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
html { overflow-x: clip; -webkit-font-smoothing: antialiased; scroll-behavior: smooth; }
body { font-family: var(--font-body); color: var(--ink); background: var(--paper); line-height: 1.6; }
img, video { display: block; max-width: 100%; }
a { color: inherit; text-decoration: none; }
::selection { background: var(--mustard); color: var(--ink); }
.container { max-width: var(--page-w); margin: 0 auto; padding: 0 var(--gutter); }

h1, h2, h3, .display {
  font-family: var(--font-display); font-weight: 800; text-transform: uppercase;
  letter-spacing: 0.02em; line-height: 0.92; overflow-wrap: anywhere;
}

/* 按压反馈（Apple） */
button, .pressable { transition: transform 120ms var(--ease-out); }
button:active, .pressable:active { transform: scale(0.97); }

/* 毛玻璃导航 */
.nav { position: sticky; top: 0; z-index: 50; display: flex; align-items: center; gap: 18px;
  padding: 14px var(--gutter); background: rgba(242, 231, 212, 0.72);
  -webkit-backdrop-filter: blur(14px) saturate(1.6); backdrop-filter: blur(14px) saturate(1.6);
  border-bottom: 1px solid rgba(46, 31, 45, 0.14); }
.nav__brand { font-family: var(--font-display); font-weight: 800; font-size: 20px; text-transform: uppercase; letter-spacing: 0.05em; }
.nav__links { margin-left: auto; display: flex; gap: 6px; }
.nav__links a { font-size: 14px; font-weight: 600; opacity: 0.72; padding: 7px 12px; border-radius: 8px;
  transition: opacity 0.2s var(--ease-out), background 0.2s var(--ease-out); }
.nav__links a:hover { opacity: 1; background: rgba(46, 31, 45, 0.08); }

/* Hero */
.hero { text-align: center; padding: clamp(56px, 12vh, 110px) var(--gutter) 20px; }
.hero__tag { font-family: var(--font-mono); font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--oxblood); }
.hero h1 { font-size: clamp(56px, 11vw, 120px); line-height: 0.78; margin: 16px 0 12px; }
.hero p { max-width: 460px; margin: 0 auto; color: var(--muted); }

/* 跑马灯 */
.marquee { margin-top: 28px; border-top: 2px solid var(--ink); border-bottom: 2px solid var(--ink); background: var(--mustard); overflow: hidden; }
.marquee__in { display: flex; width: max-content; animation: mq 22s linear infinite; }
.marquee span { font-family: var(--font-display); font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em;
  font-size: 14px; padding: 8px 40px 8px 0; white-space: nowrap; }
@keyframes mq { from { transform: translateX(0); } to { transform: translateX(-50%); } }

/* 章节 */
.section { padding: clamp(40px, 7vh, 64px) 0; }
.section__head { display: flex; align-items: baseline; gap: 10px; margin-bottom: 20px; }
.section__head h2 { font-size: clamp(30px, 4vw, 40px); }
.section__head em { font-style: normal; font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.1em; color: var(--muted); text-transform: uppercase; }
.section--dark { background: var(--ink); color: var(--cream); }
.section--dark .section__head em { color: rgba(248, 240, 224, 0.55); }
.section--oxblood { background: var(--oxblood); color: var(--cream); }
.section--oxblood .section__head h2 { color: var(--mustard); }

/* 项目卡片 */
.pg { display: grid; gap: 14px; }
.pg--single { grid-template-columns: 1fr; justify-items: center; }
.pg--single .pcard { max-width: 620px; }
.pg--duo { grid-template-columns: repeat(2, 1fr); }
.pg--bento { grid-template-columns: repeat(3, 1fr); grid-auto-rows: auto; }
.pg--bento .pcard:first-child { grid-column: span 2; }
.pg--grid { grid-template-columns: repeat(3, 1fr); }

.pcard { background: var(--cream); border: 2px solid var(--ink); border-radius: 10px; overflow: hidden; cursor: pointer;
  box-shadow: 0 2px 0 rgba(46, 31, 45, 0.12); transition: transform var(--dur) var(--spring), box-shadow var(--dur) var(--ease-out); }
.pcard:hover { transform: translateY(-6px); box-shadow: 0 18px 34px -14px rgba(46, 31, 45, 0.38); }
.pcard:active { transform: translateY(-2px) scale(0.99); transition: transform 0.1s var(--ease-out); }
.pcard__img { aspect-ratio: 16 / 10; background: linear-gradient(135deg, var(--ink), var(--ink-2)); display: flex;
  align-items: center; justify-content: center; font-family: var(--font-display); font-weight: 800; text-transform: uppercase;
  color: var(--mustard); letter-spacing: 0.05em; position: relative; }
.pcard__img img { width: 100%; height: 100%; object-fit: cover; }
.pcard__img--2 { background: linear-gradient(135deg, var(--oxblood), #a3453f); color: var(--cream); }
.pcard__img--3 { background: linear-gradient(135deg, #3d2b3f, #5d3a4a); }
.pcard__no { position: absolute; top: 10px; left: 12px; font-style: normal; font-family: var(--font-mono); font-size: 10px; opacity: 0.8; }
.pcard__body { padding: 14px 16px 16px; }
.pcard__body h3 { font-size: 22px; }
.pcard__body p { font-size: 12.5px; color: var(--muted); line-height: 1.6; margin: 6px 0 10px; }
.pcard__tags { display: flex; gap: 4px; flex-wrap: wrap; }
.pcard__tags span { font-size: 10px; border: 1px solid var(--ink); padding: 1px 7px; border-radius: 20px; opacity: 0.7; }

/* 日志列表 */
.loglist { max-width: 640px; }
.logitem { display: flex; gap: 14px; align-items: baseline; padding: 14px 0; border-bottom: 1px dashed rgba(248, 240, 224, 0.25); }
.logitem:last-child { border-bottom: none; }
.logitem__date { font-family: var(--font-mono); font-size: 12px; color: var(--mustard); flex-shrink: 0; width: 56px; }
.logitem__title { font-family: var(--font-display); font-weight: 700; text-transform: uppercase; font-size: 19px; letter-spacing: 0.02em;
  transition: color 0.2s var(--ease-out); }
.logitem:hover .logitem__title { color: var(--mustard); }
.logitem__cat { font-size: 10px; border: 1px solid rgba(248, 240, 224, 0.4); padding: 1px 8px; border-radius: 20px;
  text-transform: uppercase; letter-spacing: 0.05em; margin-left: auto; flex-shrink: 0; }
.logmore { display: inline-flex; margin-top: 18px; font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.08em;
  text-transform: uppercase; color: var(--mustard); padding: 9px 16px; border: 1px solid var(--mustard); border-radius: 20px;
  transition: background 0.2s var(--ease-out), color 0.2s var(--ease-out); }
.logmore:hover { background: var(--mustard); color: var(--ink); }

/* 详情页正文 */
.prose { max-width: 640px; margin: 0 auto; }
.prose h1 { font-size: clamp(40px, 7vw, 64px); margin-bottom: 6px; }
.prose .meta { font-family: var(--font-mono); font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; }
.prose .cover { border: 2px solid var(--ink); border-radius: 10px; margin: 22px 0; }
.prose video { width: 100%; border: 2px solid var(--ink); border-radius: 10px; margin: 18px 0; }
.prose p { margin: 14px 0; }
.prose h2 { font-size: 26px; margin: 30px 0 8px; }
.prose h3 { font-size: 20px; margin: 24px 0 6px; }
.prose code { font-family: var(--font-mono); font-size: 0.9em; background: rgba(46, 31, 45, 0.08); padding: 2px 5px; border-radius: 4px; }
.prose pre { background: var(--ink); color: var(--cream); padding: 16px; border-radius: 8px; overflow-x: auto; margin: 16px 0; }
.prose pre code { background: none; padding: 0; }
.prose ul, .prose ol { margin: 14px 0; padding-left: 22px; }
.prose a { border-bottom: 1px solid var(--ink); }

/* 关于页 */
.about-grid { display: grid; gap: 28px; }
.about-skill { display: inline-flex; border: 1px solid var(--ink); padding: 8px 14px; border-radius: 20px; font-size: 13px; }

/* 页脚 */
.footer { font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase;
  text-align: center; padding: 24px; opacity: 0.75; }

/* 移动端 */
@media (max-width: 720px) {
  .pg--duo, .pg--grid { grid-template-columns: 1fr; }
  .pg--bento { grid-template-columns: 1fr; }
  .pg--bento .pcard:first-child { grid-column: span 1; }
}

/* Apple：reduced-motion 兜底 */
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
  .marquee__in { animation: none; }
}
```

- [ ] **Step 2: 验证**

Run: `npm run build`
Expected: 构建成功（此时还没有页面，Astro 会输出空 dist，无错误）

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "style: carnival design system with apple motion"
```

---

## Task 3: 布局 + 导航 + 页脚

**Files:**
- Create: `src/layouts/BaseLayout.astro`
- Create: `src/components/Nav.astro`
- Create: `src/components/Footer.astro`

- [ ] **Step 1: 写 Nav.astro**

```astro
---
const links = [
  { href: '/projects', label: '项目' },
  { href: '/blog', label: '日志' },
  { href: '/about', label: '关于' },
];
---
<nav class="nav container">
  <a class="nav__brand" href="/">WADU76</a>
  <div class="nav__links">
    {links.map((l) => <a href={l.href}>{l.label}</a>)}
  </div>
</nav>
```

- [ ] **Step 2: 写 Footer.astro**

```astro
<footer class="footer container">© 2026 WADU76 · 项目 · 日志 · 关于</footer>
```

- [ ] **Step 3: 写 BaseLayout.astro**

```astro
---
import '../styles/global.css';
import Nav from '../components/Nav.astro';
import Footer from '../components/Footer.astro';
const { title = 'WADU76 作品集' } = Astro.props;
---
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content="Unity 游戏开发者作品集与开发日志" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@600;700;800;900&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />
    <title>{title}</title>
  </head>
  <body>
    <Nav />
    <main><slot /></main>
    <Footer />
  </body>
</html>
```

- [ ] **Step 4: 验证**

Run: `npm run build`
Expected: 构建成功

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: base layout with nav and footer"
```

---

## Task 4: 内容集合 + schema

**Files:**
- Create: `src/content.config.ts`

- [ ] **Step 1: 写 content.config.ts**

```ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    subtitle: z.string().optional(),
    date: z.coerce.date(),
    tech: z.array(z.string()).default([]),
    cover: z.string().optional(),
    gallery: z.array(z.string()).default([]),
    video: z.string().optional(),
    featured: z.boolean().default(false),
  }),
});

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    category: z.string().default('笔记'),
    cover: z.string().optional(),
  }),
});

export const collections = { projects, blog };
```

- [ ] **Step 2: 写两个最小示例（先让 schema 有真实数据验证）**

Create `src/content/projects/basic-movement.md`:
```md
---
title: basic_movement
subtitle: 2D 平台跳跃手感 Demo
date: 2026-08-15
tech: [Unity, C#, 2D, Movement]
cover: /media/images/basic-movement.svg
video: /media/videos/demo.mp4
featured: true
---
2D 平台跳跃手感 Demo，重点演示移动 / 可变跳跃 / 全 8 向冲刺。
```

Create `src/content/blog/coyote-time.md`:
```md
---
title: 土狼时间三帧实现
date: 2026-08-15
category: movement
---
土狼时间让玩家在离开平台后还能短暂起跳，窗口通常设为 3 帧左右。
```

- [ ] **Step 3: 验证 schema（构建期校验）**

Run: `npm run build`
Expected: 构建成功，说明 frontmatter 通过 schema 校验（若字段类型错误会构建失败）

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: content collections with zod schemas"
```

---

## Task 5: 组件

**Files:**
- Create: `src/components/Hero.astro`
- Create: `src/components/Marquee.astro`
- Create: `src/components/ProjectGrid.astro`
- Create: `src/components/LogCard.astro`

- [ ] **Step 1: 写 Hero.astro**

```astro
---
const props = Astro.props;
---
<section class="hero">
  <div class="hero__tag">{props.tag}</div>
  <h1>{props.title}</h1>
  <p>{props.desc}</p>
</section>
```

- [ ] **Step 2: 写 Marquee.astro**

```astro
---
const items = Astro.props.items ?? ['Unity', 'C#', 'Movement', '3C', 'Platformer', 'Match-3'];
const line = items.join(' · ') + ' · ' + items.join(' · ');
---
<div class="marquee"><div class="marquee__in"><span>{line}</span></div></div>
```

- [ ] **Step 3: 写 ProjectGrid.astro（自适应布局核心）**

```astro
---
import { getCollection } from 'astro:content';
const { limit = 0, showAll = false } = Astro.props;
const projects = (await getCollection('projects'))
  .sort((a, b) => b.data.date - a.data.date)
  .sort((a, b) => Number(b.data.featured) - Number(a.data.featured));
const shown = limit > 0 ? projects.slice(0, limit) : projects;
const count = shown.length;
const gridClass = count === 1 ? 'pg pg--single' : count === 2 ? 'pg pg--duo' : count === 3 ? 'pg pg--bento' : 'pg pg--grid';
const fmtDate = (d) => d.toISOString().slice(0, 10);
---
<div class={gridClass}>
  {shown.map((p, i) => (
    <a class="pcard" href={`/projects/${p.id}/`}>
      <div class={`pcard__img pcard__img--${(i % 3) + 1}`}>
        {p.data.cover && <img src={p.data.cover} alt={p.data.title} loading="lazy" />}
        <i class="pcard__no">0{i + 1}</i>
      </div>
      <div class="pcard__body">
        <h3>{p.data.title}</h3>
        {p.data.subtitle && <p>{p.data.subtitle}</p>}
        <div class="pcard__tags">{p.data.tech.map((t) => <span>{t}</span>)}</div>
      </div>
    </a>
  ))}
</div>
```

- [ ] **Step 4: 写 LogCard.astro（日志条目 + 空态）**

```astro
---
const { posts, showAll = false } = Astro.props;
const fmtDate = (d) => `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
---
{posts.length === 0 && <p style="color:var(--cream);opacity:.7">暂无日志，去 content/blog 加一篇吧。</p>}
{posts.map((post) => (
  <a class="logitem" href={`/blog/${post.id}/`}>
    <span class="logitem__date">{fmtDate(post.data.date)}</span>
    <span class="logitem__title">{post.data.title}</span>
    <span class="logitem__cat">{post.data.category}</span>
  </a>
))}
{showAll && <a class="logmore" href="/blog">全部日志 →</a>}
```

- [ ] **Step 5: 验证**

Run: `npm run build`
Expected: 构建成功（组件还没被页面引用，先不报错即可）

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: hero, marquee, project grid, log card components"
```

---

## Task 6: 首页

**Files:**
- Create: `src/pages/index.astro`

- [ ] **Step 1: 写 index.astro**

```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
import Hero from '../components/Hero.astro';
import Marquee from '../components/Marquee.astro';
import ProjectGrid from '../components/ProjectGrid.astro';
import LogCard from '../components/LogCard.astro';
import { getCollection } from 'astro:content';

const posts = (await getCollection('blog')).sort((a, b) => b.data.date - a.data.date);
---
<BaseLayout>
  <Hero tag="Unity 游戏开发者 · Movement / 3C"
        title="WADU76<br>作品集"
        desc="Unity 游戏客户端开发者，方向是平台跳跃与移动手感。这里收录我的项目和开发日志。" />
  <Marquee />

  <section class="section container" style="padding-top:clamp(40px,7vh,64px)">
    <div class="section__head"><h2>Projects.</h2><em>featured</em></div>
    <ProjectGrid />
  </section>

  <section class="section section--dark container" style="max-width:none">
    <div class="container">
      <div class="section__head"><h2>开发日志.</h2><em>最近更新</em></div>
      <LogCard posts={posts.slice(0, 4)} showAll />
    </div>
  </section>

  <section class="section section--oxblood container" style="max-width:none">
    <div class="container">
      <div class="section__head"><h2>About.</h2><em>简介</em></div>
      <p style="max-width:540px">华中科技大学 CS · 2027 届 · 方向：游戏客户端 / Movement·3C。</p>
    </div>
  </section>
</BaseLayout>
```

- [ ] **Step 2: 验证**

Run: `npm run dev`
Expected: http://localhost:4321 渲染首页，Hero/跑马灯/项目卡/日志区都出现

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: home page"
```

---

## Task 7: 项目列表 + 详情页

**Files:**
- Create: `src/pages/projects/index.astro`
- Create: `src/pages/projects/[slug].astro`

- [ ] **Step 1: 写 projects/index.astro**

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import ProjectGrid from '../../components/ProjectGrid.astro';
---
<BaseLayout title="项目 · WADU76 作品集">
  <section class="section container">
    <div class="section__head"><h2>Projects.</h2><em>全部</em></div>
    <ProjectGrid />
  </section>
</BaseLayout>
```

- [ ] **Step 2: 写 projects/[slug].astro**

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import { getCollection, render } from 'astro:content';
export async function getStaticPaths() {
  const projects = await getCollection('projects');
  return projects.map((p) => ({ params: { slug: p.id }, props: { project: p } }));
}
const { project } = Astro.props;
const { Content } = await render(project);
---
<BaseLayout title={`${project.data.title} · WADU76 作品集`}>
  <article class="prose container">
    <h1>{project.data.title}</h1>
    <div class="meta">{project.data.subtitle ?? ''}</div>
    {project.data.video && <video controls preload="metadata" poster={project.data.cover} src={project.data.video}></video>}
    {!project.data.video && project.data.cover && <img class="cover" src={project.data.cover} alt={project.data.title} />}
    {project.data.gallery.length > 0 && (
      <div class="gallery">{project.data.gallery.map((src) => <img src={src} loading="lazy" />)}</div>
    )}
    <div class="pcard__tags" style="margin:18px 0">{project.data.tech.map((t) => <span>{t}</span>)}</div>
    <Content />
  </article>
</BaseLayout>
```

- [ ] **Step 3: 加 .gallery 样式（global.css 末尾追加）**

```css
.gallery { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin: 18px 0; }
.gallery img { border: 2px solid var(--ink); border-radius: 8px; }
@media (max-width: 720px) { .gallery { grid-template-columns: 1fr; } }
```

- [ ] **Step 4: 验证**

Run: `npm run dev`
Expected: `/projects` 列表正常；`/projects/basic-movement` 详情页渲染出标题、meta、正文

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: projects index and detail pages"
```

---

## Task 8: 日志列表 + 详情页

**Files:**
- Create: `src/pages/blog/index.astro`
- Create: `src/pages/blog/[slug].astro`

- [ ] **Step 1: 写 blog/index.astro**

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import LogCard from '../../components/LogCard.astro';
import { getCollection } from 'astro:content';
const posts = (await getCollection('blog')).sort((a, b) => b.data.date - a.data.date);
---
<BaseLayout title="开发日志 · WADU76 作品集">
  <section class="section section--dark container" style="max-width:none;min-height:60vh">
    <div class="container">
      <div class="section__head"><h2>开发日志.</h2><em>全部</em></div>
      <LogCard posts={posts} />
    </div>
  </section>
</BaseLayout>
```

- [ ] **Step 2: 写 blog/[slug].astro**

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import { getCollection, render } from 'astro:content';
export async function getStaticPaths() {
  const posts = await getCollection('blog');
  return posts.map((post) => ({ params: { slug: post.id }, props: { post } }));
}
const { post } = Astro.props;
const { Content } = await render(post);
const fmtDate = (d) => d.toISOString().slice(0, 10);
---
<BaseLayout title={`${post.data.title} · WADU76 作品集`}>
  <article class="prose container" style="padding-top:64px">
    <h1>{post.data.title}</h1>
    <div class="meta">{fmtDate(post.data.date)} · {post.data.category}</div>
    {post.data.cover && <img class="cover" src={post.data.cover} alt={post.data.title} />}
    <Content />
  </article>
</BaseLayout>
```

- [ ] **Step 3: 验证**

Run: `npm run dev`
Expected: `/blog` 列出示例日志；`/blog/coyote-time` 渲染正文

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: blog index and detail pages"
```

---

## Task 9: 关于页

**Files:**
- Create: `src/pages/about.astro`

- [ ] **Step 1: 写 about.astro**

```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
const skills = ['Unity', 'C#', '游戏玩法', 'Movement / 3C', '2D 平台', '三消', '钩锁'];
---
<BaseLayout title="关于 · WADU76 作品集">
  <section class="section container about-grid">
    <div>
      <div class="section__head"><h2>About.</h2><em>关于我</em></div>
      <p style="max-width:560px">华中科技大学 CS · 2027 届。方向：游戏客户端 / Movement·3C。这里用作品集和开发日志记录我的游戏开发学习。</p>
    </div>
    <div>
      <div class="section__head"><h2>技能.</h2><em>skills</em></div>
      <div>{skills.map((s) => <span class="about-skill">{s}</span>).join(' ')}</div>
    </div>
  </section>
</BaseLayout>
```

- [ ] **Step 2: 验证**

Run: `npm run dev`
Expected: `/about` 正常渲染

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: about page"
```

---

## Task 10: 示例内容 + 媒体占位

**Files:**
- Create: `public/media/images/basic-movement.svg`
- Create: `public/media/images/match3.svg`
- Create: `public/media/images/hookshot.svg`
- Create: `src/content/projects/match3.md`
- Create: `src/content/projects/hookshot.md`
- Create: `src/content/blog/8-direction-dash.md`
- Create: `src/content/blog/variable-jump.md`
- Create: `public/media/videos/demo.mp4`（可空文件 + README 说明）

- [ ] **Step 1: 写 3 张 SVG 占位封面**

`public/media/images/basic-movement.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400">
  <rect width="640" height="400" fill="#2e1f2d"/>
  <text x="32" y="70" font-family="monospace" font-size="20" fill="#f2c14e">01 / basic_movement</text>
  <rect x="420" y="120" width="90" height="90" rx="8" fill="#f2c14e"/>
  <rect x="520" y="180" width="90" height="90" rx="8" fill="#f2c14e"/>
  <rect x="140" y="260" width="360" height="14" fill="#f2c14e"/>
</svg>
```
（match3.svg、hookshot.svg 同构：fill 分别用 `#7d2b32`、`#3d2b3f`，编号 02/03）

- [ ] **Step 2: 写 match3.md / hookshot.md**

`match3.md`：frontmatter title `Match-3`、tech `[Unity, 算法]`、cover `/media/images/match3.svg`、正文「三消 Demo，完整游戏循环：消除 / 连击 / 计分。」

`hookshot.md`：frontmatter title `Hookshot`、tech `[Unity 3D, C#]`、cover `/media/images/hookshot.svg`、正文「3D 钩锁，抓取点 / 摆动 / 推进。」

- [ ] **Step 3: 写 2 篇示例日志**

`8-direction-dash.md`：title `全 8 向冲刺的实现记录`、category `unity`、正文含一个 `C#` 代码块（示演示例）。
`variable-jump.md`：title `可变跳跃高度实现`、category `手感`、正文含 markdown 列表。

- [ ] **Step 4: 视频占位说明**

Create `public/media/videos/README.md`：
```md
# 视频放这里

- 支持 .mp4（小片段，建议 < 50MB，别超过 100MB，git 会拒大文件）
- 项目 frontmatter 的 `video` 字段写 `/media/videos/文件名.mp4`
- 首页没有视频也能正常显示（详情页没有 video 就显示封面图）
```

- [ ] **Step 5: 验证**

Run: `npm run dev`
Expected: 首页 Projects 区出现 3 个卡片（bento 布局：basic_movement 大卡），日志区 3 条；`/projects` 3 个；`/blog` 3 篇

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: sample content and media placeholders"
```

---

## Task 11: 构建验证 + 收尾

- [ ] **Step 1: 生产构建**

Run: `npm run build && npm run preview`
Expected: 构建无错误；preview 本地可访问所有路由

- [ ] **Step 2: 逐页检查**

本地 dev 打开并确认：`/` `/projects` `/projects/basic-movement` `/projects/match3` `/projects/hookshot` `/blog` `/blog/coyote-time` `/blog/8-direction-dash` `/blog/variable-jump` `/about` 全部渲染正常，无 404、无报错。

- [ ] **Step 3: 减 motion 检查**

浏览器 DevTools 模拟 `prefers-reduced-motion: reduce`，确认跑马灯停动、过渡降级。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: build verification"
```

---

## Task 12: README + 部署说明

**Files:**
- Create: `README.md`

- [ ] **Step 1: 写 README.md**

```md
# WADU76 作品集

Carnival × Apple 风格的作品集 + 开发日志站（Astro）。

## 本地预览
npm install
npm run dev

## 更新内容（实时更新的方式）
1. 写日志：在 `src/content/blog/` 新建 `.md`（含 frontmatter：title/date/category）
2. 写项目：在 `src/content/projects/` 新建 `.md`（title/subtitle/date/tech/cover/gallery/video）
3. 图片：丢进 `public/media/images/`；视频（小片段）丢进 `public/media/videos/`
4. 提交推送：`git add -A && git commit -m "add post" && git push`
5. Vercel 自动构建上线（约 1 分钟）

## 部署
- GitHub 建仓库，推上去
- Vercel 导入仓库，Framework 选 Astro，自动部署
```

- [ ] **Step 2: 最终 commit**

```bash
git add -A
git commit -m "docs: readme"
```

---

## 自检清单（对照 spec）

- ✅ 首页 Hero/跑马灯/Projects/日志/About（Task 6）
- ✅ 项目列表 + 详情页（视频/截图/标签/正文）（Task 7）
- ✅ 日志列表 + 详情页，与项目分开（Task 8）
- ✅ 关于页（Task 9）
- ✅ 内容集合两套 schema（Task 4）
- ✅ Carnival 视觉 + Apple 动效 + reduced-motion（Task 2）
- ✅ 项目自适应布局 1/2/3+（ProjectGrid，Task 5）
- ✅ 视频小片段放仓库（Task 10）
- ✅ Vercel 部署说明（Task 12）
- ✅ 空态兜底（LogCard 空态、无 cover 渐变兜底，Task 5/7）
