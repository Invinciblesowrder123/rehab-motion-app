import { Controller, Get } from '@nestjs/common';

/**
 * 健康检查端点
 * P0 安全闸门不依赖数据库，因此 /health 即使在 PostgreSQL 不可用时也返回 200。
 * 数据库可用性由 /ready 端点单独检查。
 */
@Controller()
export class HealthController {
  @Get('health')
  health() {
    return {
      status: 'ok',
      service: 'rehab-motion-api',
      safetyGate: 'enabled',
      disclaimer: '本服务不提供医疗诊断，所有建议仅供参考。',
    };
  }
}
