"""在安卓模拟器内自动走完康复 App 的追问流程，验证真模型回答能显示到界面。

用法：
    python scripts/emulator_flow_test.py

依赖：adb 在 PATH 或 ANDROID_HOME 指定；模拟器已开机；后端已启动。
注意：adb shell input text 不支持中文，问题文本用英文，用于验证链路而非语义。
"""
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ADB = str(Path(r"C:\Users\zcjte\AppData\Local\Android\Sdk\platform-tools\adb.exe"))
PACKAGE = "com.rehabmotion.rehab_motion"

# 问题关键字 -> 期望点击的选项文案
ANSWER_PLAN = {
    "什么阶段": "1-3 个月恢复中",
    "活动能力": "能独立坐",
    "合并症": "没有或不清楚",
    "疼痛程度": "轻度，可忍受",
}


def adb(*args: str, timeout: int = 60) -> str:
    return subprocess.run([ADB, *args], capture_output=True, text=True, timeout=timeout).stdout


def dump_nodes() -> list[tuple[str, str, tuple[int, int, int, int]]]:
    """返回 (content-desc, text, bounds) 列表。"""
    out = adb("exec-out", "uiautomator", "dump", "/dev/tty", timeout=90)
    xml_start = out.find("<?xml")
    if xml_start < 0:
        return []
    # uiautomator 在 XML 之后还会打印一行 "UI hierchary dumped to: ..."，必须截掉
    xml_end = out.find("</hierarchy>")
    blob = out[xml_start : xml_end + len("</hierarchy>")] if xml_end > 0 else out[xml_start:]
    root = ET.fromstring(blob)
    nodes = []
    for node in root.iter("node"):
        desc = node.get("content-desc") or ""
        text = node.get("text") or ""
        bounds = node.get("bounds") or ""
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        if not m:
            continue
        box = tuple(int(x) for x in m.groups())
        nodes.append((desc, text, box))
    return nodes


def find_question(nodes) -> str | None:
    for desc, _text, _box in nodes:
        for key in ANSWER_PLAN:
            if key in desc:
                return key
    return None


def tap_center(box) -> None:
    x1, y1, x2, y2 = box
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))


def main() -> None:
    print("== 重置会话 ==")
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "monkey", "-p", PACKAGE, "1")
    time.sleep(12)

    print("== 输入问题 ==")
    adb("shell", "input", "tap", "540", "800")
    time.sleep(3)
    adb("shell", "input", "text", "knee%sexercise%safter%ssurgery")
    time.sleep(3)
    # 诊断：确认文本真的进了输入框（Flutter 文案里应出现 knee）
    probe = [d for d, _t, _b in dump_nodes() if "knee" in d.lower()]
    print("输入框状态：", "已填入" if probe else "未检测到文本")
    adb("shell", "input", "tap", "948", "2243")
    print("已发送，等待追问…")
    time.sleep(30)

    for step in range(1, 9):
        nodes = dump_nodes()
        q = find_question(nodes)
        if q:
            wanted = ANSWER_PLAN[q]
            target = next((box for desc, _t, box in nodes if desc.strip() == wanted), None)
            if target is None:
                print(f"[step {step}] 未找到选项：{wanted}")
                break
            print(f"[step {step}] 回答「{q}」→ {wanted}")
            tap_center(target)
            time.sleep(20)
            continue

        # 没有追问 → 看是否已经出现回答
        long_texts = [d for d, _t, _b in nodes if len(d) > 120]
        if long_texts:
            print("\n== 已收到回答 ==")
            print(long_texts[-1][:900])
            return
        print(f"[step {step}] 等待中（无追问、无长文本），继续等待…")
        time.sleep(20)

    print("\n流程未走完，最后界面节点：")
    for desc, _t, _b in dump_nodes():
        if desc.strip():
            print(" -", desc.strip()[:120])


if __name__ == "__main__":
    main()
