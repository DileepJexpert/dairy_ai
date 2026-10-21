import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';

export const communityRouter = new Hono<{ Bindings: Env }>();

const CreatePostSchema = z.object({
  title: z.string().min(3).max(250),
  description: z.string().min(5).max(3000),
  issue_tag: z.string().min(2).max(100),
  cattle_tag: z.string().max(50).nullable().optional(),
  image_urls: z.array(z.string()).default([]).optional(),
});

const CreateCommentSchema = z.object({
  comment: z.string().min(2).max(2000),
});

// GET /community/posts — Browse open posts
communityRouter.get('/community/posts', async (c) => {
  const db = c.env.DB;
  const tag = c.req.query('tag');

  let query = 'SELECT * FROM community_posts WHERE 1=1';
  const params: any[] = [];

  if (tag && tag.trim().length > 0 && tag !== 'All') {
    query += ' AND issue_tag LIKE ?';
    params.push(`%${tag.trim()}%`);
  }

  query += ' ORDER BY created_at DESC LIMIT 50';

  const rows = await db.prepare(query).bind(...params).all();
  const posts = (rows.results || []).map((p: any) => {
    let images: string[] = [];
    try {
      images = typeof p.image_urls === 'string' ? JSON.parse(p.image_urls) : (p.image_urls || []);
    } catch {
      images = [];
    }
    return {
      id: p.id,
      author_id: p.author_id,
      author_name: p.author_name,
      author_role: p.author_role,
      title: p.title,
      description: p.description,
      issue_tag: p.issue_tag,
      image_urls: images,
      cattle_tag: p.cattle_tag,
      likes_count: p.likes_count || 0,
      comments_count: p.comments_count || 0,
      resolved: Boolean(p.resolved),
      created_at: p.created_at,
    };
  });

  return c.json({
    success: true,
    data: posts,
    message: 'Community posts loaded',
  });
});

// GET /community/posts/:id — Get post details and comments thread
communityRouter.get('/community/posts/:id', async (c) => {
  const db = c.env.DB;
  const postId = c.req.param('id');

  const post = await db.prepare('SELECT * FROM community_posts WHERE id = ?').bind(postId).first();
  if (!post) {
    throw new HTTPException(404, { message: 'Post not found' });
  }

  let images: string[] = [];
  try {
    images = typeof post.image_urls === 'string' ? JSON.parse(post.image_urls as string) : (post.image_urls || []);
  } catch {
    images = [];
  }

  const comments = await db.prepare(
    'SELECT * FROM community_comments WHERE post_id = ? ORDER BY is_verified_vet DESC, created_at ASC'
  ).bind(postId).all();

  return c.json({
    success: true,
    data: {
      id: post.id,
      author_id: post.author_id,
      author_name: post.author_name,
      author_role: post.author_role,
      title: post.title,
      description: post.description,
      issue_tag: post.issue_tag,
      image_urls: images,
      cattle_tag: post.cattle_tag,
      likes_count: post.likes_count || 0,
      comments_count: post.comments_count || 0,
      resolved: Boolean(post.resolved),
      created_at: post.created_at,
      comments: (comments.results || []).map((comm: any) => ({
        id: comm.id,
        author_id: comm.author_id,
        author_name: comm.author_name,
        author_role: comm.author_role,
        is_verified_vet: Boolean(comm.is_verified_vet),
        vet_qualification: comm.vet_qualification,
        vet_clinic: comm.vet_clinic,
        comment: comm.comment,
        created_at: comm.created_at,
      })),
    },
  });
});

// POST /community/posts — Create new cattle question/post (requires login)
communityRouter.post('/community/posts', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = CreatePostSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid post details: title, description, and issue tag are required' });
  }

  const customer = await db.prepare('SELECT full_name, role FROM customers WHERE id = ?').bind(user.id).first();
  const authorName = (customer?.full_name as string) || user.full_name || 'Dairy Farmer';
  const authorRole = (customer?.role as string) || user.role || 'farmer';

  const postId = `post-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO community_posts (
      id, author_id, author_name, author_role, title, description, issue_tag, image_urls, cattle_tag
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    postId,
    user.id,
    authorName,
    authorRole,
    parsed.data.title.trim(),
    parsed.data.description.trim(),
    parsed.data.issue_tag.trim(),
    JSON.stringify(parsed.data.image_urls || []),
    parsed.data.cattle_tag?.trim() || null
  ).run();

  return c.json({
    success: true,
    data: { id: postId, title: parsed.data.title },
    message: 'Post published successfully to the community',
  }, 201);
});

// POST /community/posts/:id/comments — Add advice / comment
communityRouter.post('/community/posts/:id/comments', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const postId = c.req.param('id');

  const post = await db.prepare('SELECT id FROM community_posts WHERE id = ?').bind(postId).first();
  if (!post) {
    throw new HTTPException(404, { message: 'Post not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = CreateCommentSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Comment text is required' });
  }

  // Check if author is a verified vet
  const customer = await db.prepare('SELECT full_name, role FROM customers WHERE id = ?').bind(user.id).first();
  const vet = await db.prepare('SELECT qualification, city, district FROM vets WHERE user_id = ?').bind(user.id).first();

  const authorName = (customer?.full_name as string) || user.full_name || 'Community Member';
  const authorRole = (customer?.role as string) || user.role || 'farmer';
  const isVet = authorRole === 'vet' || Boolean(vet);
  const vetQualification = (vet?.qualification as string) || (isVet ? 'Veterinary Consultant' : null);
  const vetClinic = vet ? `${vet.city || 'Regional'} Veterinary Clinic` : null;

  const commentId = `comm-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO community_comments (
      id, post_id, author_id, author_name, author_role, is_verified_vet, vet_qualification, vet_clinic, comment
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    commentId,
    postId,
    user.id,
    authorName,
    authorRole,
    isVet ? 1 : 0,
    vetQualification,
    vetClinic,
    parsed.data.comment.trim()
  ).run();

  // Increment comment count
  await db.prepare('UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = ?').bind(postId).run();

  return c.json({
    success: true,
    data: {
      id: commentId,
      is_verified_vet: isVet,
      vet_qualification: vetQualification,
      comment: parsed.data.comment,
    },
    message: isVet ? 'Doctor advice posted with verified badge' : 'Comment posted successfully',
  }, 201);
});

// POST /community/posts/:id/like — Like a post
communityRouter.post('/community/posts/:id/like', async (c) => {
  const db = c.env.DB;
  const postId = c.req.param('id');

  await db.prepare('UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = ?').bind(postId).run();
  const updated = await db.prepare('SELECT likes_count FROM community_posts WHERE id = ?').bind(postId).first();

  return c.json({
    success: true,
    likes_count: updated?.likes_count || 1,
    message: 'Post liked',
  });
});
