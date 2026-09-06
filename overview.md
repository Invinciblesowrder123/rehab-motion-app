# 康复运动 App MVP：本轮交付概览

## 已完成（按交接文档 2.5 P0-P3 顺序）

| 阶段 | 内容 | 验证 |
|---|---|---|
| **P0-a** | 单仓工程 + Docker Compose（PostgreSQL 16+pgvector、Redis 7、NestJS API、FastAPI AI 服务） | YAML 校验通过 |
| **P0-b** | 规则安全闸门 + 追问 API：从 `safety.py` 移植 20 条红旗正则规则到 TypeScript；急性期固定阻断；四项渐进式选择题追问（病程→功能状态→合并症→疼痛） | **9/9 冒烟测试通过** |
| **P1** | 动作库 + RAG 骨架：PostgreSQL 首启自动导入现有 3 个 SQL；`v_rehab_exercises` 视图硬排 `rehab_level=3`；知识切块表 `knowledge_chunks vector(1024)` + Markdown 切块脚本 | 脚本语法校验通过 |
| **P2** | AI 服务边界：FastAPI 默认 `stub` 模式；NestJS 仅在安全闸门通过后调用；GPU 就绪后切 `vllm` 加载 Qwen3-8B + LoRA | 编译通过 |
| **P3** | Flutter 正式工程（`flutter create` 生成）：安全提示、选择式追问、动作卡片、聊天回答四个状态 | `flutter analyze` 0 error |

## 环境验证结果

| 工具 | 状态 | 说明 |
|---|---|---|
| Flutter SDK 3.47.2 (Dart 3.13.2) | ✅ 可用 | `D:\dev\flutter`，首次运行自动下载依赖 |
| Node.js v22.22.2 + npm 10.9.7 | ✅ 可用 | |
| Docker Desktop 4.89.0 | ❌ 安装回滚 | 日志显示安装后立即 uninstall，`docker.exe` 不存在 |

## P0 安全闸门冒烟测试结果

| # | 输入 | 预期 | 实际 |
|---|---|---|---|
| 1 | 胸痛+左肩放射 | urgent (severity=3) | ✅ |
| 2 | 突发无力+言语不清 | urgent (severity=3) | ✅ |
| 3 | 呼吸困难 | urgent (severity=3) | ✅ |
| 4 | 正常输入 | clarify (追问病程) | ✅ |
| 5 | stage=subacute | clarify (追问功能状态) | ✅ |
| 6 | stage=acute | urgent (急性期阻断) | ✅ |
| 7 | 全部补齐 | answer (AI 未配置→保守提示) | ✅ |
| 8 | /health | ok | ✅ |
| 9 | "我没有胸痛" | 不命中→clarify | ✅ |

## 关键决策

- NestJS 是唯一面向移动端的编排层，FastAPI 不直接暴露给 App。
- P0 安全闸门纯规则引擎，不依赖数据库——即使 PostgreSQL/Redis/AI 全部不可用，安全筛查和追问仍能正常工作。
- AI 原始输出默认不可见（`AI_MODE=stub`）；所有生成前强制通过 P0。
- 动作 `rehab_level <= 2` 只是最低技术闸门，不等价于对个体患者的适用性判定。

## 后续事项

1. **Docker Desktop 需重新安装**——当前安装回滚，`docker.exe` 不存在。
2. 康复专业人员审核适应症、禁忌症、剂量。
3. BGE-M3 向量 worker 部署与检索质量评估。
4. GPU 环境就绪后切换 `AI_MODE=vllm` 加载 Qwen3-8B + LoRA。
5. Flutter 真机调试（优先于模拟器）。
