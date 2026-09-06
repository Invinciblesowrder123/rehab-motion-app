import os
from pathlib import Path
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

SYSTEM_PROMPT = '你是一名康复医学与物理治疗领域的资深专家助手。请基于康复医学教材与临床指南的专业知识，准确、简洁地回答用户的问题。'
MODE = os.getenv('AI_MODE', 'stub').lower()
API_KEY = os.getenv('AI_SHARED_KEY', '')
MODEL_PATH = Path(os.getenv('MODEL_PATH', '/models/Qwen3-8B'))
LORA_PATH = Path(os.getenv('LORA_PATH', '/models/rehab-lora'))

class GenerateRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    profile: dict[str, str]

app = FastAPI(title='Rehab Motion AI Gateway', version='0.1.0')

def verify(key: str | None) -> None:
    if API_KEY and key != API_KEY:
        raise HTTPException(status_code=401, detail='unauthorized')

@app.get('/health')
def health():
    if MODE == 'vllm':
        ready = MODEL_PATH.exists() and (LORA_PATH / 'adapter_config.json').is_file()
        return {'status': 'ready' if ready else 'error', 'mode': MODE, 'loraConfigured': ready, 'rawOutputExposure': False}
    return {'status': 'ready', 'mode': 'stub', 'loraConfigured': False, 'rawOutputExposure': False}

@app.post('/generate')
def generate(req: GenerateRequest, x_api_key: str | None = Header(default=None)):
    verify(x_api_key)
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
