import json
import os
import time
import urllib.request
from pathlib import Path
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

SYSTEM_PROMPT = '你是一名康复医学与物理治疗领域的资深专家助手。请基于康复医学教材与临床指南的专业知识，准确、简洁地回答用户的问题。'
# 安全边界：模型侧的软约束。真正的硬闸门在 NestJS（/ai/chat 的红旗规则），
# 即便模型漏掉这里，NestJS 也会在返回给用户之前拦截。
SAFETY_INSTRUCTION = (
    '安全要求：不作诊断、不开具统一剂量或固定时间表；给出红旗症状的停止与就医条件；'
    '强调个体化评估与循序渐进；结尾提醒本建议不能替代医生面诊。'
)
MODE = os.getenv('AI_MODE', 'stub').lower()
API_KEY = os.getenv('AI_SHARED_KEY', '')
MODEL_PATH = Path(os.getenv('MODEL_PATH', '/models/Qwen3-8B'))
LORA_PATH = Path(os.getenv('LORA_PATH', '/models/rehab-lora'))

# aixw（Responses API）：端点无 /v1；必须带 User-Agent，否则网关返回 Upstream access forbidden
AIXW_API_KEY = os.getenv('AIXW_API_KEY', '')
AIXW_BASE_URL = os.getenv('AIXW_BASE_URL', 'https://api.aixw.org').rstrip('/')
AIXW_MODEL = os.getenv('AIXW_MODEL', 'gpt-5.6-sol')
# aixw 首次响应延迟较大（实测 45–90s，抖动时更久），超时必须留足余量
AIXW_TIMEOUT = float(os.getenv('AIXW_TIMEOUT', '300'))

class GenerateRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    profile: dict[str, str]

app = FastAPI(title='Rehab Motion AI Gateway', version='0.1.0')

def verify(key: str | None) -> None:
    if API_KEY and key != API_KEY:
        raise HTTPException(status_code=401, detail='unauthorized')

def _sse_text(resp, deadline: float) -> str:
    """解析 Responses API 的 SSE 流；带墙钟 deadline，防止上游挂起导致死循环。"""
    buf: list[str] = []
    for raw_line in resp:
        if time.time() > deadline:
            raise RuntimeError('aixw 流式读取超时（上游挂起，已强制中断）')
        line = raw_line.decode('utf-8', 'replace').strip()
        if not line or line.startswith(':') or not line.startswith('data:'):
            continue
        data = line[len('data:'):].strip()
        if data == '[DONE]':
            break
        try:
            evt = json.loads(data)
        except json.JSONDecodeError:
            continue
        delta = evt.get('delta')
        if delta:
            buf.append(delta)
        elif evt.get('type') == 'response.output_text' and evt.get('text'):
            buf.append(evt['text'])
    return ''.join(buf).strip()

def call_aixw(message: str, profile: dict[str, str]) -> str:
    if not AIXW_API_KEY:
        raise RuntimeError('AIXW_API_KEY 未配置')
    body = {
        'model': AIXW_MODEL,
        # instructions 必传：aixw 网关在缺失时会注入 Codex 编码助手人格，污染回答并浪费 token
        'instructions': SYSTEM_PROMPT + '\n' + SAFETY_INSTRUCTION,
        'input': f'用户资料：{json.dumps(profile, ensure_ascii=False)}\n\n用户问题：{message}',
        'temperature': 0.3,
        'max_tokens': 700,
        'top_p': 0.95,
        'stream': True,  # 流式：规避官方对非流式调用的限流
    }
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': f'Bearer {AIXW_API_KEY}',
        'User-Agent': 'OpenAI/Python 3.5.0',
    }
    req = urllib.request.Request(
        f'{AIXW_BASE_URL}/responses',
        data=json.dumps(body, ensure_ascii=False).encode('utf-8'),
        headers=headers,
        method='POST',
    )
    deadline = time.time() + AIXW_TIMEOUT
    with urllib.request.urlopen(req, timeout=AIXW_TIMEOUT) as resp:
        text = _sse_text(resp, deadline)
    if not text:
        raise RuntimeError('aixw 返回空内容')
    return text

@app.get('/health')
def health():
    if MODE == 'vllm':
        ready = MODEL_PATH.exists() and (LORA_PATH / 'adapter_config.json').is_file()
        return {'status': 'ready' if ready else 'error', 'mode': MODE, 'loraConfigured': ready, 'rawOutputExposure': False}
    if MODE == 'aixw':
        return {
            'status': 'ready' if AIXW_API_KEY else 'error',
            'mode': MODE,
            'aixwConfigured': bool(AIXW_API_KEY),
            'model': AIXW_MODEL,
            'rawOutputExposure': False,
        }
    return {'status': 'ready', 'mode': 'stub', 'loraConfigured': False, 'rawOutputExposure': False}

@app.post('/generate')
def generate(req: GenerateRequest, x_api_key: str | None = Header(default=None)):
    verify(x_api_key)

    if MODE == 'aixw':
        try:
            return {'text': call_aixw(req.message, req.profile), 'sources': []}
        except Exception as exc:
            # 超时/限流/网络错误 → 交给 NestJS 保守降级，不把上游异常直接抛给用户
            raise HTTPException(status_code=504, detail=f'ai_upstream_unavailable: {type(exc).__name__}') from exc

    if MODE != 'vllm':
        return {'text': '当前为安全联调模式：已完成红旗症状筛查和关键信息收集。GPU 推理服务部署并经人工安全验收前，不展示模型生成内容。', 'sources': []}
    if not MODEL_PATH.exists() or not (LORA_PATH / 'adapter_config.json').is_file():
        raise HTTPException(status_code=503, detail='model_or_lora_not_ready')
    # Production image must provide vLLM + CUDA. Keep model access internal; NestJS is the only caller.
    try:
        from vllm import LLM, SamplingParams
        from vllm.lora.request import LoRARequest
    except ImportError as exc:
        raise HTTPException(status_code=503, detail='vllm_gpu_runtime_not_installed') from exc
    llm = LLM(model=str(MODEL_PATH), enable_lora=True, max_lora_rank=8, gpu_memory_utilization=0.90)
    prompt = f'{SYSTEM_PROMPT}\n\n用户资料：{req.profile}\n\n用户问题：{req.message}\n\n回答要求：只依据给定资料；分点、避免重复；不作诊断；如不适请停止并咨询治疗师。'
    output = llm.generate([prompt], SamplingParams(temperature=0.3, top_p=0.9, repetition_penalty=1.1, max_tokens=512), lora_request=LoRARequest('rehab', 1, str(LORA_PATH)))
    return {'text': output[0].outputs[0].text, 'sources': []}
