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
    date: z.coerce.date().optional(),
    category: z.string().default('笔记'),
    cover: z.string().optional(),
  }),
});

export const collections = { projects, blog };
