/**
 * safety.ts —— P0 安全筛查规则引擎（移植自 rehab_app_dev/01_prompt/safety.py）
 *
 * 设计原则（与 safety.py 一致）：
 * 1. 纯规则，绝不用 LLM 做安全判定——可审计、可控、零延迟、兜底可靠。
 * 2. 保守优先：宁可误报，不可漏报。
 * 3. severity: 0=无命中 1=提示 2=暂停训练（阻断） 3=立即就医（阻断+urgent）。
 *
 * 本模块只负责"能不能说"的判定，不涉及 LLM 生成。
 */

// --------------------------------------------------------------------------- //
// 类型定义
// --------------------------------------------------------------------------- //
export interface RedFlagRule {
  label: string;
  category: string;
  pattern: RegExp;
  severity: 1 | 2 | 3;
  advice: string;
}

export interface SafetyResult {
  urgent: boolean;
  matched: string[];
  message: string;
  severity: 0 | 1 | 2 | 3;
  blockExercise: boolean;
  categories: string[];
}

export const DISCLAIMER = '本建议非医疗诊断，如有不适请停止并咨询治疗师。';

// --------------------------------------------------------------------------- //
// 危险信号正则词库（对应 safety.py 的 RED_FLAG_PATTERNS）
// --------------------------------------------------------------------------- //
export const RED_FLAG_RULES: RedFlagRule[] = [
  // ---------------- 心血管 ----------------
  {
    label: '胸痛/心绞痛/胸部压榨感',
    category: '心血管',
    pattern: /胸痛|心痛|心绞痛|心前区(?:疼|痛|不适|闷)|胸(?:部)?(?:压榨|压迫|憋闷|剧痛|发紧)|胸(?:口|部)?(?:(?!不|没|无|已)[^。；!！?？\n]){0,3}(?:疼|痛|闷|堵)|压榨(?:感|样)|(?:疼痛)?(?:向左|往左)(?:臂|肩|背|颈部)?(?:放射|串)/,
    severity: 3,
    advice: '立即停止活动、坐下或半卧位休息，马上拨打 120 或让家属送医，不要自行走动。',
  },
  {
    label: '胸闷/憋气',
    category: '心血管',
    pattern: /胸闷|憋气|喘憋|胸口堵|像压了(?:块)?石头/,
    severity: 3,
    advice: '立即停止训练并保持安静，若 5 分钟内不缓解请拨打 120。',
  },
  {
    label: '心悸/心跳异常',
    category: '心血管',
    pattern: /心悸|心慌|心跳(?:过|太|很)?(?:快|乱|重|漏拍|不齐)|心律(?:不齐|失常)|脉搏(?:不齐|乱|很快)|早搏/,
    severity: 2,
    advice: '暂停本次训练，记录发作时间与持续时长，当天联系治疗师或心内科医生确认后再决定是否继续。',
  },

  // ---------------- 神经（警惕卒中复发/TIA） ----------------
  {
    label: '突发无力/麻木/言语障碍（疑似卒中复发）',
    category: '神经',
    pattern: /(?:突发|突然|一下子|忽然|今早|刚才)[^。；!！?？\n]{0,8}(?:一侧|半边|单侧|左边|右边)?(?:手|脚|腿|胳膊|手臂|肢体|身体)?(?:无力|没力|使不上劲|发麻|麻木|动不了|抬不起来|不听使唤|站不住)|说不出话|说不了话|说话(?:不清|含糊|不利索|大舌头)|言语(?:不清|障碍|含糊)|口(?:角|眼)?(?:(?!不|没)[^。；!！?？\n]){0,3}(?:歪斜|歪了|歪)|嘴(?:巴)?(?:(?!不|没)[^。；!！?？\n]){0,3}(?:歪|斜)|面瘫|流口水|(?:脸|半边脸|嘴角|一侧肢体|手脚|腿)动不了|视物(?:模糊|成双|重影)|复视|一只眼看不见/,
    severity: 3,
    advice: '按卒中 FAST 原则处理：立即停止训练、记下症状出现时间，马上拨打 120，不要进食服药，等待急救期间保持侧卧或半卧位。',
  },
  {
    label: '头晕/眩晕/晕厥',
    category: '神经',
    pattern: /头晕|眩晕|晕厥|昏厥|快要晕|差点晕倒|晕倒|眼前发黑|眼前一黑|黑朦|一过性(?:黑朦|失明)|天旋地转/,
    severity: 3,
    advice: '立即坐下或平卧防止跌倒，测量血压与血糖并记录，若伴言语不清、肢体无力或持续不缓解请拨打 120。',
  },

  // ---------------- 呼吸 ----------------
  {
    label: '呼吸困难/喘不上气',
    category: '呼吸',
    pattern: /呼吸困难|喘不上气|喘不过气|气不够用|吸不上气|憋得慌|静息(?:也|时)?(?:喘|气短|呼吸困难)|夜间憋醒|平卧(?:即|就)?(?:喘|憋)|呼吸(?:急促|费力|很浅)|血氧(?:下降|低于|掉到|不足)\s?\d{0,3}/,
    severity: 3,
    advice: '立即停止训练、取端坐位休息；如伴口唇发紫、血氧低于 93% 或休息后不缓解，请拨打 120。',
  },
  {
    label: '气短/喘息加重',
    category: '呼吸',
    pattern: /气短|喘息|气促|活动后(?:明显)?(?:喘|气不够)/,
    severity: 2,
    advice: '暂停训练并放慢节律，记录什么活动会诱发；如休息 10 分钟不缓解或日渐加重，请尽快联系医生。',
  },

  // ---------------- 术后并发症 ----------------
  {
    label: '伤口裂开/化脓/术后发热',
    category: '术后并发症',
    pattern: /(?:伤口|切口|术区|刀口)(?:(?!不|没|无|已)[^。；!！?？\n]){0,6}(?:裂开|崩开|张开|化脓|流脓|渗脓|冒脓)|(?:术后|手术后|开刀后)[^。；!！?？\n]{0,8}(?:发热|发烧|高烧|体温(?:升)?高|体温超过)|体温(?:超过|高于|到)\s?3[89](?:度|℃|\.\d)?/,
    severity: 3,
    advice: '立即停止训练，用干净敷料覆盖伤口（不要自行涂抹药物），当天返回手术科室或急诊处理。',
  },
  {
    label: '伤口红肿/渗液/皮温升高',
    category: '术后并发症',
    pattern: /(?:伤口|切口|术区|刀口)(?:(?!不|没|无|已)[^。；!！?？\n]){0,6}(?:红肿|发红|肿胀|渗液|渗血|渗水|流水|流液|皮温(?:升)?高|周围(?:发)?热|跳痛|一跳一跳)|红肿热痛/,
    severity: 2,
    advice: '暂停涉及该部位的训练并保持伤口清洁干燥，拍照记录，24 小时内联系手术医生或治疗师。',
  },

  // ---------------- 其他全身危险信号 ----------------
  {
    label: '新发或加重的大小便失禁/会阴麻木（警惕马尾综合征）',
    category: '其他',
    pattern: /(?:新发|突然|最近|加重|变严重|越来越)[^。；!！?？\n]{0,6}(?:大小便|二便|小便|大便|排尿|排便)?失禁|失禁(?:加重|变严重|越来越重)|尿潴留|尿不出来|排不出尿|会阴(?:麻木|没感觉|感觉丧失)|肛门周围(?:麻木|没感觉)/,
    severity: 3,
    advice: '立即停止训练并尽快到急诊就诊（需排除马尾综合征），不要热敷、不要自行推拿。',
  },
  {
    label: '大小便失禁',
    category: '其他',
    pattern: /失禁|控制不住(?:尿|大便|小便)|漏尿/,
    severity: 2,
    advice: '请先与治疗师确认是否与训练相关，训练前排空膀胱，注意会阴皮肤护理，避免长时间压迫。',
  },
  {
    label: '剧烈头痛',
    category: '其他',
    pattern: /剧烈(?:的)?(?:头)?痛|头痛欲裂|爆炸(?:样|性)(?:头)?痛|从未有过(?:的)?头痛|这辈子最痛的头|头痛(?:得)?(?:要炸|受不了)/,
    severity: 3,
    advice: '立即停止训练、平卧休息，若伴呕吐、视物模糊或肢体无力请马上拨打 120。',
  },
  {
    label: '意识/精神状态改变或抽搐',
    category: '其他',
    pattern: /意识(?:模糊|不清|丧失|障碍)|昏迷|叫不醒|叫不应|认不清人|胡言乱语|说胡话|抽搐|抽风|癫痫发作|口吐白沫|牙关紧闭/,
    severity: 3,
    advice: '立即拨打 120；让患者侧卧防止误吸，不要往嘴里塞任何东西，不要强行按压肢体。',
  },
  {
    label: '咯血/呕血',
    category: '其他',
    pattern: /咯血|咳血|呕血|吐血|痰里带血/,
    severity: 3,
    advice: '立即停止训练并拨打 120，安静休息、侧卧，暂时禁食禁水。',
  },
  {
    label: '黑便/便血/血尿',
    category: '其他',
    pattern: /黑便|柏油(?:样)?便|便血|大便带血|血尿|尿(?:里)?带血/,
    severity: 2,
    advice: '暂停训练并在 24 小时内就诊，记录颜色、次数与是否伴头晕乏力。',
  },

  // ---------------- 运动系统 / 血栓 ----------------
  {
    label: '单侧小腿/下肢突然肿胀疼痛（警惕深静脉血栓）',
    category: '运动系统',
    pattern: /(?:单侧|一侧|一条|左腿|右腿)?(?:小腿|下肢|腿)(?:突然)?(?:肿胀|肿痛|肿了|水肿|粗了一圈)[^。；!！?？\n]{0,6}(?:疼|痛|热|发紧|发硬)?/,
    severity: 3,
    advice: '立即停止活动并抬高患肢，不要按摩、不要热敷，尽快到急诊做下肢血管超声检查。',
  },
  {
    label: '脱位/骨擦音/突发剧痛',
    category: '运动系统',
    pattern: /脱位|脱臼|错动感|骨头(?:响|摩擦感)|骨擦音|咔(?:哒|嗒)一声后(?:剧痛|不能动)|突然(?:的)?剧痛|剧痛难忍|疼得(?:受不了|哭|冒汗)|夜间痛(?:醒|加重)?/,
    severity: 2,
    advice: '立即停止该动作并制动保护关节，48 小时内冰敷、抬高，尽快由治疗师或骨科医生评估。',
  },
  {
    label: '近期跌倒/摔伤',
    category: '运动系统',
    pattern: /摔倒|跌倒|摔了一跤|摔了一脚|滑倒|摔伤|摔到(?:了)?(?:头|腰|髋|胯|手腕)/,
    severity: 2,
    advice: '先确认有无骨折或头部外伤（尤其服用抗凝药者），由医生/治疗师评估后再恢复训练，近期避免单腿站立与闭眼平衡训练。',
  },
  {
    label: '平衡差/行走不稳',
    category: '运动系统',
    pattern: /站不(?:太|大|很)?稳|走路不稳|老(?:要|是)?摔|总(?:要|是)?摔|平衡(?:差|不好)|走路(?:晃|打飘)/,
    severity: 1,
    advice: '训练时请扶稳桌面或墙，避免闭眼、单腿站立与快速转头动作，建议有人陪同。',
  },
  {
    label: '训练后疲劳/酸痛持续加重',
    category: '运动系统',
    pattern: /(?:练完|练后|运动后|训练后|做完|活动后)[^。；!！?？\n]{0,8}(?:很|特别|太)?(?:累|疲劳|没劲)|疲劳(?:不恢复|加重|越来越重)|酸痛(?:加重|越来越重|好几天)|休息(?:一晚|一天)也没缓过来|乏力加重/,
    severity: 1,
    advice: '说明当前量偏大：建议把次数/组数减半、延长组间休息，如 48 小时仍不恢复请咨询治疗师。',
  },
];

// --------------------------------------------------------------------------- //
// 否定句处理（降低"我没有胸痛"这类误报）
// --------------------------------------------------------------------------- //
const NEGATION_RE = /(?:没有|无|不(?:是|会|伴|算|觉得)?|未见|否认|排除|已排除|不再|不再有|已消失|已缓解|已好转|并非|没有再)\s*$/;
const NEGATION_WINDOW = 6;

function isNegated(text: string, matchIndex: number): boolean {
  const prefix = text.slice(Math.max(0, matchIndex - NEGATION_WINDOW), matchIndex);
  return NEGATION_RE.test(prefix);
}

// --------------------------------------------------------------------------- //
// 分级话术
// --------------------------------------------------------------------------- //
const SEVERITY_TITLES: Record<number, string> = {
  1: '提示',
  2: '⚠️ 暂停训练提示',
  3: '🚨 立即就医提示',
};
const SEVERITY_HEADLINES: Record<number, string> = {
  1: '请放慢节奏、降低强度并密切观察；如症状持续或加重，请停止训练并咨询治疗师。',
  2: '请暂停本次训练，并尽快联系您的治疗师或医生确认后再继续；在确认前不提供新的运动建议。',
  3: '请立即停止训练、就地休息，并马上联系医生或拨打 120。在医生/治疗师评估前，不提供任何运动建议。',
};

function buildMessage(hits: RedFlagRule[], severity: number): string {
  const top = hits.filter((h) => h.severity === severity);
  const labels: string[] = [];
  for (const h of top) {
    if (!labels.includes(h.label)) labels.push(h.label);
  }
  const lines: string[] = [
    SEVERITY_TITLES[severity],
    `检测到需要关注的信号：${labels.join('、')}。`,
    SEVERITY_HEADLINES[severity],
  ];
  const advices: string[] = [];
  for (const h of top) {
    if (!advices.includes(h.advice)) advices.push(h.advice);
  }
  lines.push(...advices.map((a) => `· ${a}`));
  lines.push(`${DISCLAIMER}。`);
  return lines.join('\n');
}

// --------------------------------------------------------------------------- //
// 主入口：文本危险信号筛查
// --------------------------------------------------------------------------- //
export function checkSafety(text: string | null | undefined): SafetyResult {
  if (!text || !text.trim()) {
    return { urgent: false, matched: [], message: '', severity: 0, blockExercise: false, categories: [] };
  }
  const content = text;
  const hits: RedFlagRule[] = [];
  for (const rule of RED_FLAG_RULES) {
    const match = rule.pattern.exec(content);
    if (match === null) continue;
    if (isNegated(content, match.index)) continue;
    hits.push(rule);
  }
  if (hits.length === 0) {
    return { urgent: false, matched: [], message: '', severity: 0, blockExercise: false, categories: [] };
  }
  const severity = Math.max(...hits.map((h) => h.severity)) as 0 | 1 | 2 | 3;
  hits.sort((a, b) => b.severity - a.severity);
  const matched: string[] = [];
  const categories: string[] = [];
  for (const h of hits) {
    if (!matched.includes(h.label)) matched.push(h.label);
    if (!categories.includes(h.category)) categories.push(h.category);
  }
  return {
    urgent: severity >= 3,
    matched,
    message: buildMessage(hits, severity),
    severity,
    blockExercise: severity >= 2,
    categories,
  };
}
