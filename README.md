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
