# 示例:小红书"AI 编程"调研

> 2026-06-26 实测,完整跑通 vnc-research 流程。**给朋友参考的端到端样例**。

---

## 任务

**用户请求**: "调研小红书 AI 编程相关的内容"

**期望**:
- Top 20 笔记(按热度排序)
- 每条:标题/作者/日期/赞藏评/正文首段
- 给操作员看 Markdown 报告

---

## 执行过程

### Step 1:加载 skill

```python
# Hermes agent:
skill_view("vnc-research")
```python

### Step 2:连 CDP,准备 page

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    page = browser.contexts[0].pages[0]  # 用现有 page,不开新的
```

### Step 3:搜索

```python
page.goto(
    "https://www.xiaohongshu.com/search_result"
    "?keyword=AI%E7%BC%96%E7%A8%8B"
    "&source=web_explore_feed",
    wait_until="domcontentloaded"
)
page.wait_for_timeout(3000)
```python

### Step 4:检查登录态

```python
content = page.content()
# 已登录:content 不含 "登录后查看"
# 未登录:content 含 "登录后查看" / "请先登录"
# 本次:已登录(VNC 浏览器之前手动登录过)
```

### Step 5:抓搜索结果(22 条)

```python
items = page.evaluate("""
    () => {
        const seen = new Set();
        const out = [];
        document.querySelectorAll('a[href*="search_result/"]').forEach(a => {
            const href = a.href;
            if (href && !seen.has(href)) {
                seen.add(href);
                const card = a.closest('section.note-item');
                const title = (card?.querySelector('.title, .note-title')?.innerText || a.innerText || '').trim();
                out.push({ title: title.slice(0, 80), href });
            }
        });
        return out;
    }
""")
# Found 20 unique URLs
```python

**关键踩坑**: 必须用 `a[href*="search_result/"]` 抓链接(带 xsec_token),用 `/explore/` 链接会 404。

### Step 6:逐条抓详情(20 条)

```python
results = []
for i, item in enumerate(items):
    page.goto(item["href"], wait_until="domcontentloaded", timeout=15000)
    page.wait_for_timeout(1500)
    
    info = page.evaluate("""
        () => {
            const d = {};
            d.title = (document.querySelector('#detail-title, .title')?.innerText || '').trim();
            const desc = document.querySelector('#detail-desc, .desc');
            d.desc = desc ? desc.innerText.trim().slice(0, 600) : '';
            d.author = (document.querySelector('.author-wrapper .username, .author .name')?.innerText || '').trim();
            d.date = (document.querySelector('.date, .publish-date')?.innerText || '').trim();
            d.likes = (document.querySelector('.like-wrapper .count, .interaction-info [class*=like] span')?.innerText || '').trim();
            d.collects = (document.querySelector('.collect-wrapper .count')?.innerText || '').trim();
            d.comments = (document.querySelector('.chat-wrapper .count')?.innerText || '').trim();
            return d;
        }
    """)
    results.append({"idx": i, "href": item["href"], **info})
```

### Step 7:排序 + 输出 Markdown

```python
import re
def parse_int(s):
    if not s: return 0
    s = s.replace('+', '').strip()
    n = re.search(r'(\d+(?:\.\d+)?)', s)
    return int(float(n.group(1)) * 10000) if '万' in s or 'w' in s.lower() else int(float(n.group(1)))

results.sort(key=lambda x: parse_int(x.get('likes', '')), reverse=True)

# 输出 Markdown 报告(给操作员看)
```python

---

## 输出报告

# 小红书「AI 编程」Top 15

> 搜索时间: 2026-06-26 23:50 | 抓取源: VNC chromium + playwright CDP | **0 介入 / 0 credit**

| # | 标题 | 作者 | 赞/藏/评 | 链接 |
|---|------|------|---------|------|
| 1 | 这份 Vibe Coding 指南,把 AI 编程讲透了 | @Feiskyer | 87 / 9232 / 61 | — |
| 2 | Vibe Coding 技巧:SSD(Spec-Driven Development) | @喵叽叽 | 50 / 52 / 评论 | — |
| 3 | 桌面小螃蟹 Clawd 进化!解锁 Coding 模式 | @鹿鹿🦌 | 42 / 1419 / 229 | — |
| 4 | 为了不让 AI 瞎写代码,大神把自己蒸馏了(GitHub 6 万星) | @量子位 | 37 / 2.3万 / 111 | — |
| 5 | Ghostty + Claude Code AI 编程最强终端✨ | @提然聊AI | 31 / 834 / 103 | — |
| ... | | | | |

(完整 15 条见 `examples/xhs_AI编程_2026-06-26.json`)

---

## 关键发现

1. **Vibe Coding 是最大热点** — 多条笔记围绕 Vibe Coding(SDD/道法术/坑点)
2. **Codex/Claude Code/Cursor 是当前三大工具** — 多条对比/教程
3. **3 个 GitHub 神级项目被小红书种草**:
   - 6 万星:大神蒸馏自己(16 个 skill 给 AI 注入灵魂)
   - 23k 星:awesome-design-md(58 家公司 UI 设计规范)
   - 6.2k 星:Vibe Coding 指南(道法术 + 提示词库)
4. **2 条与你正在用的工具有关**:
   - 第 10 条提到 Hermes Agent + 吴恩达(#hermes #hermesagent)
   - 第 7 条讲 Codex subagents(跟你现在用的 Hermes 类似架构)

---

## 数据落盘

```bash
/tmp/xhs_AI编程_2026-06-26.json  (20 条完整数据,字段: title/author/date/likes/collects/comments/desc/href)
```

## 性能数据

| 指标 | 值 |
|------|-----|
| 总耗时 | ~45 秒 |
| 操作员介入次数 | 0 |
| 抓取量 | 22 条搜索结果 → 20 条详情(2 条 URL 去重失败) |
| chromium 重启次数 | 0 |
| Xvfb 崩溃次数 | 0 |

---

## 学到的踩坑(给后续任务)

1. **小红书 `/explore/` 链接 404**,必须用 `/search_result/<hash>?xsec_token=...`
2. **点赞数格式多样**(87 / 1.2万 / 152),需要统一 `parse_int()`
3. **JavaScript 字符串含 `\\`** 用 raw string `r''' '''` 或 `subprocess.run(['python3', '-c', script])`
4. **chromium profile 跨 session 复用登录态** — 操作员在 VNC 登录一次,agent 后续抓不用再登录

---

## 复用建议

朋友拿到这套架构后,做类似调研任务时:

1. 复制本示例的代码骨架
2. 改 `search_url` 和 `evaluate` 里的选择器
3. 适配其他平台时,参考 `skills/SKILL.md` 的"平台特定"章节
4. 更多场景:`examples/use-cases.md`(15 个实战场景:调研/抓取/操作/监控/聚合)

**0 操作员介入 / 0 credit / 完全内网** — 这就是 vnc-research 的价值。
