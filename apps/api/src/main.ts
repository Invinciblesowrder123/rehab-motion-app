import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { initDataSource } from './modules/exercises/exercises.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: ['log', 'warn', 'error'] });
  app.enableCors({ origin: (process.env.CORS_ORIGINS || '').split(',').filter(Boolean), credentials: false });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));

  // 数据库连接是「可选」的：
  // - 连得上 → 动作库（/exercises）可用
  // - 连不上 → 只警告，应用照常启动，P0 安全闸门（/ai/chat）依然工作
  // 这样保证安全网关永远在线，不被数据库故障拖垮。
  await initDataSource().catch((err: Error) => {
    console.warn(
      `[WARN] 数据库连接失败，动作库不可用，但安全闸门仍可正常工作：${err.message}`,
    );
  });

  await app.listen(Number(process.env.PORT || 3000), '0.0.0.0');
}
bootstrap();
