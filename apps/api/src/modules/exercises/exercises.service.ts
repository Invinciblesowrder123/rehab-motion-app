import { Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { DataSource } from 'typeorm';

/**
 * ExercisesService：惰性数据库连接
 *
 * MVP 阶段不通过 TypeOrmModule.forRoot 注入（避免数据库不可用时阻塞整个应用启动）。
 * 每次请求时检查连接状态，不可用则返回 503。
 * Docker 就绪后可切回 TypeOrmModule.forRoot。
 */
let sharedDataSource: DataSource | null = null;

function getDataSource(): DataSource {
  if (!sharedDataSource) {
    const url = process.env.DATABASE_URL;
    if (!url) throw new ServiceUnavailableException('数据库未配置');
    sharedDataSource = new DataSource({ type: 'postgres', url, synchronize: false });
  }
  if (!sharedDataSource.isInitialized) {
    throw new ServiceUnavailableException('数据库暂不可用，请稍后重试。');
  }
  return sharedDataSource;
}

/** Docker 启动后调用此方法初始化连接 */
export async function initDataSource(): Promise<void> {
  const url = process.env.DATABASE_URL;
  if (!url) return;
  sharedDataSource = new DataSource({ type: 'postgres', url, synchronize: false });
  await sharedDataSource.initialize();
}

@Injectable()
export class ExercisesService {
  private readonly stopWords = new Set([
    '我', '想', '知道', '怎么', '如何', '训练', '运动', '锻炼', '做', '的', '了', '吗', '呢', '是',
    '能', '可以', '以及', '和', '或', '有', '没有', '需要', '请', '帮助', '一下', '建议', '问题',
    '咨询', '指导', '能否', '什么', '哪些', '适合', '想要', '进行', '有关', '关于', '出现', '应该',
    '该', '用', '使用', '采用', '选择', '推荐', '查找', '寻找', '找',
  ]);

  async list(input: { bodyPart?: string; q?: string; limit: number }) {
    const ds = getDataSource();
    const rows = await ds.query(
      `SELECT id, name_zh, name_en, body_part, equipment, rehab_level, rehab_label, rehab_reason
       FROM v_rehab_exercises
       WHERE ($1::text IS NULL OR body_part = $1)
         AND ($2::text IS NULL OR name_zh ILIKE '%' || $2 || '%' OR name_en ILIKE '%' || $2 || '%')
       LIMIT $3`,
      [input.bodyPart || null, input.q || null, input.limit],
    );
    return {
      items: rows,
      total: rows.length,
      safetyPolicy: '仅返回 rehab_level <= 2；实际适配性仍需治疗师/医生评估。',
    };
  }

  async detail(id: string) {
    const ds = getDataSource();
    const rows = await ds.query(
      'SELECT * FROM v_rehab_exercises WHERE id = $1 AND rehab_level <= 2',
      [id],
    );
    if (!rows[0]) throw new NotFoundException('未找到可自主查看的动作');
    return rows[0];
  }

  /**
   * AI 不可用时从动作库检索降级答案
   *
   * 从 query 中提取中文字段，在 name_zh / name_en / body_part / equipment 中模糊匹配，
   * 仅返回 rehab_level <= 2 的动作，按安全等级升序排列。
   */
  async fallbackSearch(query: string, limit = 3) {
    const tokens = this.extractTokens(query);
    if (tokens.length === 0) return [];

    const ds = getDataSource();
    const conditions = tokens
      .map((_, i) => `(name_zh ILIKE $${i + 1} OR name_en ILIKE $${i + 1} OR body_part ILIKE $${i + 1} OR equipment ILIKE $${i + 1})`)
      .join(' OR ');
    const params = tokens.map((t) => `%${t}%`);

    const sql = `
      SELECT id, name_zh, name_en, body_part, equipment, rehab_level, rehab_label, rehab_reason
      FROM v_rehab_exercises
      WHERE rehab_level <= 2
        AND (${conditions})
      ORDER BY rehab_level ASC, name_zh ASC
      LIMIT $${tokens.length + 1}
    `;
    return ds.query(sql, [...params, limit]);
  }

  private extractTokens(query: string): string[] {
    const cleaned = query.replace(/[^\u4e00-\u9fa5a-zA-Z0-9\s]/g, ' ');
    const tokens = new Set<string>();

    // 提取连续中文字段（至少 2 个字）
    const zhMatches = cleaned.match(/[\u4e00-\u9fa5]{2,}/g) || [];
    for (const m of zhMatches) {
      if (!this.stopWords.has(m)) tokens.add(m);
    }

    // 提取英文单词（至少 3 个字符）
    const enMatches = cleaned.toLowerCase().match(/[a-z]{3,}/g) || [];
    for (const m of enMatches) {
      if (!this.stopWords.has(m)) tokens.add(m);
    }

    return Array.from(tokens).slice(0, 6);
  }
}
