import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthController } from './common/health.controller';
import { ChatModule } from './modules/chat/chat.module';
import { ExercisesModule } from './modules/exercises/exercises.module';

/**
 * MVP 阶段架构决策：
 *
 * P0 安全闸门（ChatModule）是纯规则引擎，不依赖任何外部服务。
 * 即使 PostgreSQL、Redis、AI 服务全部不可用，安全筛查和追问仍能正常工作。
 *
 * ExercisesModule 内部惰性获取 DataSource——数据库可用时查动作库，
 * 不可用时端点返回 503，不影响 /ai/chat。
 *
 * 这样设计的目的：保证安全网关永远在线。
 *
 * ConfigModule 负责读取项目根目录的 .env（本地 npm run start:dev 时
 * 需要它提供 DATABASE_URL；容器内部由 docker compose 的环境变量覆盖）。
 */
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      // 本地从 apps/api 启动时 .env 在项目根目录，两个位置都找一遍
      envFilePath: ['.env', '../../.env'],
    }),
    ChatModule,
    ExercisesModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
