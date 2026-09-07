import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { initDataSource } from './modules/exercises/exercises.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: ['log', 'warn', 'error'] });
  // CORS：浏览器从 flutter run -d web-server 的 8080 端口跨源调用 3000，
  // 必须正确响应预检（OPTIONS）。origin:true 让后端 echo 回请求的 origin，
  // 比 ['*'] 更兼容浏览器（部分浏览器对 '*' 不通过预检）。
  // 仅限本地开发；生产环境要写明允许的 origin 域名。
  app.enableCors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: false,
  });
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
