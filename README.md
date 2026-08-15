# WADU76 作品集

Carnival × Apple 风格的作品集 + 开发日志站（Astro）。

## 本地预览
npm install
npm run dev

## 更新内容（实时更新的方式）
1. 写日志：在 `src/content/blog/` 新建 `.md`（含 frontmatter：title/date/category）
2. 写项目：在 `src/content/projects/` 新建 `.md`（title/subtitle/date/tech/cover/gallery/video）
3. 图片：丢进 `public/media/images/`；视频（小片段）丢进 `public/media/videos/`
4. 双击 `update.bat` 自动提交推送（或手动 `git add -A && git commit -m "add post" && git push`）
5. Vercel 自动构建上线（约 1 分钟）

## 改页面文案（改哪里）
| 想改什么 | 文件 |
|---|---|
| 首页大标题 / 副标题 | `src/pages/index.astro` 里的 `<Hero ...>` 一行 |
| 跑马灯词条 | `src/components/Marquee.astro` 的 `items` 数组 |
| 首页 About 区一句话 | `src/pages/index.astro` 里 `section--oxblood` 那一节 |
| 关于页简介 / 技能列表 | `src/pages/about.astro` 的 `skills` 数组和 `<p>` 文字 |
| 导航链接文字 | `src/components/Nav.astro` 的 `links` 数组 |
| 全局颜色 / 间距 / 动效 | `src/styles/global.css`（顶部 `:root` 是颜色 token） |

## 部署
- GitHub 建仓库，推上去
- Vercel 导入仓库，Framework 选 Astro，自动部署
