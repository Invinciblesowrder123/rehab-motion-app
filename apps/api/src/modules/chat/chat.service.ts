import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { ChatRequestDto } from './chat.dto';
import { ExercisesService } from '../exercises/exercises.service';
import { checkSafety, DISCLAIMER, SafetyResult } from './safety';

type SlotState = Record<string, string>;

/**
 * 追问模板（对应交接文档 4.3 节 ③ 层）
 * 必须问清的 4 项：病程/分期 > 功能状态 > 合并症 > 疼痛程度
 * 用选择题，一次最多问 1 个，渐进式。
 */
const CLARIFY_TEMPLATES = [
  {
    slot: 'stage',
    question: '请问当前处于什么阶段？',
    options: [
      { label: '2 周内或术后早期', value: 'acute' },
      { label: '1-3 个月恢复中', value: 'subacute' },
      { label: '3 个月以上', value: 'chronic' },
      { label: '不清楚', value: 'unknown' },
    ],
  },
  {
    slot: 'functionLevel',
    question: '目前最接近哪种活动能力？',
    options: [
      { label: '需要卧床或他人协助', value: 'bed' },
      { label: '能独立坐', value: 'sit' },
      { label: '能站但不稳', value: 'stand' },
      { label: '能独立走', value: 'walk' },
    ],
  },
  {
    slot: 'comorbidities',
    question: '是否有需要特别注意的合并症？',
    options: [
      { label: '没有或不清楚', value: 'none_or_unknown' },
      { label: '心脏病/高血压', value: 'cardiac_or_htn' },
      { label: '骨质疏松/近期骨折', value: 'osteoporosis' },
      { label: '糖尿病/COPD 等慢病', value: 'other_chronic' },
    ],
  },
  {
    slot: 'pain',
    question: '当前疼痛程度如何？',
    options: [
      { label: '无痛', value: 'none' },
      { label: '轻度，可忍受', value: 'mild' },
      { label: '中重度或越来越痛', value: 'moderate_severe' },
    ],
  },
];

/**
 * 急性期固定安全处置（不调用 LoRA）
 * 急性期组织处于炎症反应阶段，主动抗阻训练会加重水肿疼痛并延缓愈合。
 */
const ACUTE_PHASE_RESPONSE = {
  type: 'urgent' as const,
  message:
    '当前处于急性期/术后早期，组织正在炎症修复阶段。\n' +
    '此阶段以卧床休息、保护性体位摆放、被动/助力活动为主，\n' +
    '不建议自主进行主动抗阻或负荷训练。\n' +
    '请在治疗师或医生确认进入亚急性期后再开始运动指导。\n' +
    DISCLAIMER,
  severity: 2,
  modelCalled: false,
};

@Injectable()
export class ChatService {
  // 多轮会话状态（MVP 用内存 Map；生产环境应迁移到 Redis）
  private readonly sessions = new Map<string, SlotState>();

  constructor(private readonly exercises: ExercisesService) {}

  async handle(dto: ChatRequestDto) {
    const sessionId = dto.sessionId || randomUUID();
    const text = (dto.message || '').trim();

    // ------------------------------------------------------------------ //
    // ① 安全筛查（纯规则，最高优先级，禁止调用 LLM）
    // ------------------------------------------------------------------ //
    const safety: SafetyResult = checkSafety(text);
    if (safety.blockExercise) {
      // severity >= 2：阻断运动建议，返回固定安全处置
      return {
        type: safety.urgent ? 'urgent' : 'clarify_block',
        sessionId,
        message: safety.message,
        severity: safety.severity,
        matched: safety.matched,
        categories: safety.categories,
        modelCalled: false,
        disclaimer: DISCLAIMER,
      };
    }

    // ------------------------------------------------------------------ //
    // ② 合并 slotAnswers 到会话状态
    // ------------------------------------------------------------------ //
    const state: SlotState = {
      ...(this.sessions.get(sessionId) || {}),
      ...(dto.slotAnswers || {}),
    };
    this.sessions.set(sessionId, state);

    // ------------------------------------------------------------------ //
    // ③ 急性期阻断（安全关键：急性期不直接给运动建议）
    // ------------------------------------------------------------------ //
    if (state.stage === 'acute') {
      return { ...ACUTE_PHASE_RESPONSE, sessionId };
    }

    // ------------------------------------------------------------------ //
    // ④ 信息完整性检查 → 渐进式追问（选择题）
    // ------------------------------------------------------------------ //
    const nextMissing = CLARIFY_TEMPLATES.find((item) => !state[item.slot]);
    if (nextMissing) {
      return {
        type: 'clarify',
        sessionId,
        questions: [nextMissing],
        modelCalled: false,
        disclaimer: DISCLAIMER,
      };
    }

    // ------------------------------------------------------------------ //
    // ⑤ 所有安全检查通过 → 调用 AI 服务；不可用时降级到动作库检索
    // ------------------------------------------------------------------ //
    const aiUrl = process.env.AI_SERVICE_URL;
    if (!aiUrl) {
      return this.fallbackAnswer(text, sessionId);
    }

    try {
      const response = await fetch(`${aiUrl}/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': process.env.AI_SHARED_KEY || '',
        },
        body: JSON.stringify({
          message: text,
          profile: state,
        }),
        // aixw 首字延迟实测 45–90s，30s 会稳定超时；默认值放宽，可用 AI_TIMEOUT_MS 覆盖
        signal: AbortSignal.timeout(Number(process.env.AI_TIMEOUT_MS || 240000)),
      });
      if (!response.ok) {
        throw new Error(`AI service returned ${response.status}`);
      }
      const data = (await response.json()) as {
        text: string;
        sources?: Array<{ book: string; chapter: string }>;
      };
      return {
        type: 'answer',
        sessionId,
        answer: data.text,
        referencedExercises: [],
        sources: data.sources || [],
        disclaimer: DISCLAIMER,
        modelCalled: true,
        needFollowUp: false,
      };
    } catch {
      return this.fallbackAnswer(text, sessionId);
    }
  }

  /**
   * AI 不可用时降级：从动作库检索相关低等级动作并生成保守回答
   */
  private async fallbackAnswer(query: string, sessionId: string) {
    // 数据库不可用时动作库检索会抛 503——这里必须兜住，
    // 否则 /ai/chat 会跟着 503，违背「安全网关永远在线」的设计。
    let exercises: Awaited<ReturnType<ExercisesService['fallbackSearch']>> = [];
    try {
      exercises = await this.exercises.fallbackSearch(query, 3);
    } catch {
      exercises = [];
    }
    let answer = '感谢您提供的信息。当前 AI 生成服务尚未就绪，无法提供个性化建议。\n';

    if (exercises.length > 0) {
      answer += '\n根据你的描述，从动作库中筛选出以下相对安全的低强度动作供参考：';
      for (let i = 0; i < exercises.length; i++) {
        const ex = exercises[i];
        answer += `\n${i + 1}. ${ex.name_zh}（${ex.rehab_label}）`;
        const parts: string[] = [];
        if (ex.body_part) parts.push(`部位：${ex.body_part}`);
        if (ex.equipment) parts.push(`器械：${ex.equipment}`);
        if (parts.length > 0) answer += ` — ${parts.join(' · ')}`;
      }
      answer += '\n\n请在治疗师或医生确认后尝试，并注意动作幅度和身体疼痛信号。';
    } else {
      answer += '请咨询你的康复治疗师或医生获取专业指导。';
    }
    answer += '\n\n' + DISCLAIMER;

    return {
      type: 'answer',
      sessionId,
      answer,
      referencedExercises: exercises,
      sources: [],
      disclaimer: DISCLAIMER,
      modelCalled: false,
      needFollowUp: true,
    };
  }
}
