#!/usr/bin/env python3
"""judge-api.py <image> : send the montage + PROMPT_FILE to an OpenAI-compatible vision endpoint.
Prints two lines: LIKE-lean|LIKE-default|SKIP and a short reason. Standard library only.
Env: JUDGE_API_URL, JUDGE_API_KEY, JUDGE_MODEL, PROMPT_FILE."""
import base64, json, os, re, sys, urllib.request

def main():
    img = sys.argv[1]
    url = os.environ.get("JUDGE_API_URL", "https://api.openai.com/v1/chat/completions")
    key = os.environ.get("JUDGE_API_KEY", "")
    model = os.environ.get("JUDGE_MODEL", "")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pf = os.environ.get("PROMPT_FILE", "./prompt.example.txt")
    if not os.path.isabs(pf):
        pf = os.path.join(root, pf)
    if not key or key.startswith("<") or not model or model.startswith("<"):
        sys.exit("set JUDGE_API_KEY and JUDGE_MODEL in config.env")
    prompt = open(pf, encoding="utf-8").read()
    b64 = base64.b64encode(open(img, "rb").read()).decode()
    body = {"model": model, "temperature": 0, "max_tokens": 60, "messages": [{"role": "user", "content": [
        {"type": "text", "text": prompt},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}}]}]}
    req = urllib.request.Request(url, json.dumps(body).encode(), {
        "Content-Type": "application/json", "Authorization": "Bearer " + key})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            text = json.load(r)["choices"][0]["message"]["content"]
    except Exception as e:  # never block the run on the judge: default rule
        print("LIKE-default\njudge error: %s" % type(e).__name__)
        return
    m = re.search(r"\b(LIKE-lean|LIKE-default|SKIP)\b", text, re.I)
    decision = {"like-lean": "LIKE-lean", "like-default": "LIKE-default", "skip": "SKIP"}[m.group(1).lower()] if m else "LIKE-default"
    lines = [l.strip() for l in text.strip().splitlines() if l.strip()]
    reason = lines[1] if len(lines) > 1 else (lines[0] if lines else "no reason")
    print(decision)
    print(reason[:120])

if __name__ == "__main__":
    main()
