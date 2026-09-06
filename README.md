# 康复运动 App MVP

> 面向残障人士与康复群体的运动指导 App。**非医疗器械**，所有输出须标注"非医疗诊断"。

## 已实现阶段（按交接文档 2.5 P0-P3 顺序）

| 阶段 | 内容 | 验证状态 |
|---|---|---|
| **P0-a** | 单仓工程 + Docker Compose（PostgreSQL+pgvector、Redis、NestJS API、FastAI AI 服务） | ✅ YAML 校验通过 |
| **P0-b** | 规则安全闸门 + 追问 API：20 条红旗规则（移植自 safety.py）、急性期阻断、四项渐进式选择题追问 | ✅ **9/9 冒烟测试通过** |
| **P1** | 动作库导入 + 教材 RAG 骨架：PostgreSQL 首启自动导入 3 个 SQL；`v_rehab_exercises` 视图硬排 `rehab_level=3`；知识切块表 + 脚本就绪 | ✅ 脚本语法校验通过 |
| **P2** | AI 服务边界：FastAPI 默认 `stub` 模式，安全闸门通过后才调用；GPU/vLLM 就绪后切换 | ✅ 编译通过 |
| **P3** | Flutter 最小界面：安全提示、选择式追问、动作卡片、聊天回答四个状态 | ✅ `flutter analyze` 0 error |

## 本地启动

### 前置条件
- Docker Desktop（当前**安装回滚**，需重新安装）
- Flutter SDK（`D:\dev\flutter`，已就绪）
- Node.js v22+（已就绪）

### 1. Docker 启动（Docker 修复后）
```bash
cd D:/AI/R/rehab-motion-mvp
cp .env.example .env
# 编辑 .env 设置密码
docker compose up -d --build
# 验证
curl http://localhost:3000/health
# 期望: {"status":"ok","safetyGate":"enabled"}
```

### 2. NestJS API 本地运行（无 Docker）
```bash
cd D:/AI/R/rehab-motion-mvp/apps/api
npm install
npm run build
# 不需要数据库即可测试安全闸门
PORT=3000 CORS_ORIGINS=* node dist/main.js
```

### 3. 测试安全闸门
```bash
# 红旗症状 → urgent（不调用 AI）
curl -X POST http://localhost:3000/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"我刚才练着练着胸痛，还有点向左肩放射"}'

# 正常输入 → clarify（追问病程）
curl -X POST http://localhost:3000/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"脑卒中后想了解上肢摆放"}'
```

### 4. Flutter 运行
```bash
cd D:/AI/R/rehab-motion-mvp/apps/mobile
flutter pub get
# Android 模拟器（10.0.2.2 映射到宿主机 localhost）
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
# 真机
flutter run --dart-define=API_BASE_URL=http://<本机IP>:3000
```

## 关键文件索引

| 文件 | 作用 |
|---|---|
| `apps/api/src/modules/chat/safety.ts` | P0 安全闸门规则引擎（20 条红旗规则 + 否定句处理） |
| `apps/api/src/modules/chat/chat.service.ts` | 聊天编排：安全筛查→急性期阻断→追问→AI 调用 |
| `apps/api/src/modules/exercises/exercises.service.ts` | 动作库查询（惰性 DB 连接，硬排 level=3） |
| `apps/mobile/lib/main.dart` | Flutter 四状态界面（urgent/clarify/answer/error） |
| `docker-compose.yml` | PostgreSQL+pgvector / Redis / NestJS / FastAPI 编排 |
| `infra/postgres/init/` | 数据库首启初始化 SQL |
| `infra/scripts/ingest_knowledge.py` | 教材 Markdown 切块入库（P2 RAG） |

## 上线前阻断项

1. **🚨 不得**将当前 LoRA 原始回答直接暴露给用户。评估 61.5/100，5/12 安全关键题未达标。
2. Docker Desktop 安装回滚，需修复后才能启动容器化环境。
3. BGE-M3 向量 worker 需独立部署并通过检索质量评估后才接入 RAG 链路。
4. 动作 `indications`/`contraindications`/`dose_recommend` 需康复治疗师审核补充。
5. vLLM 部署需 ≥24GB GPU 显存 + CUDA 专用镜像。
6. 健康数据存储需补齐 PIPL 合规：单独同意、加密、删除机制。
