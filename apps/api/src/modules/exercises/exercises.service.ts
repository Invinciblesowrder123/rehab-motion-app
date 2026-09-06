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
}
