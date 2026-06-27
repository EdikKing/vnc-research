---
name: vnc-research
description: >
  通用网页交互框架: 通过 VNC 共享浏览器 + Playwright CDP, 完成任何需要
  浏览器交互的任务 — 调研抓取 / 内容获取 / 自动化操作 / 监控 / 跨平台
  聚合。操作员仅在登录墙 / 验证码时介入。比 BrowserAct 更优: 永久免费、
  登录态持久、完全内网、可处理任意网页场景。
---

# VNC + Playwright CDP · 通用网页交互 Skill

> 这是给 AI agent 用的标准 skill。**接到任何"通过网页做 X"的任务时,先加载这个 skill,再开始干活**。
> 适用范围: 不只是调研,任何需要浏览器的任务 — 抓数据、发内容、操作 SaaS、监控、跨平台聚合。

---

## 核心定位

> **vnc-research = 通用网页交互框架**,不只是调研。

适用所有"需要通过浏览器访问网页"的任务。用户不需要为每种任务装不同工具。

## When to Use

| 操作员说 | 任务类型 | 用 vnc-research |
|---------|---------|----------------|
| "调研 X" / "搜 X" / "抓 X" | 调研抓取 | ✅ |
| "抓这篇文章" / "下载这个" / "导出 X 的数据" | 内容获取 | ✅ |
| "发一条微博" / "评论 X" / "回个消息" | 内容发布 | ✅ |
| "登录 X 然后做 Y" / "填这个表" / "抢个票" | 自动化操作 | ✅ |
| "监控 X 的价格" / "看 X 是否有货" | 监控告警 | ✅ |
| "在 X、Y、Z 上搜同一个东西" | 跨平台聚合 | ✅ |
| "看我的微信/邮箱/订单" | 个人数据查询 | ✅ |
| "测试这个 web 应用" | 自动化测试 | ✅ |

**触发条件**(满足任一即用):
1. 任务需要打开网页
2. 任务需要登录态(任何平台)
3. 任务需要 JS 渲染(几乎所有现代网站)
4. 任务需要交互(点击/输入/滚动/翻页)
5. 任务需要登录后才能看到内容

## When NOT to Use

- 任务能直接靠公开 API 完成(用对应 skill: arxiv/blogwatcher/etc)
- 明确指定"用 curl" / "用 BrowserAct" / "用 browser 工具" → 听用户的
- 静态文档类(markdown/PDF 直接读文件就好)
- 任务能在命令行完成(grep/awk/sed/jq)
- 已有专门 skill 的领域(用专门 skill)

---

## 🔴 操作员介入协议(最高优先级)

> **核心原则**: vnc-research 是 agent 自动化 + 操作员兜底协作的框架。
> 默认 agent 自动操作;**遇到 agent 处理不了的情况,立刻暂停 + 通知操作员,列出 VNC 地址方便直接去处理**。

### 什么情况必须暂停 + 通知

| 情况 | 检测方法 | agent 该做什么 |
|------|---------|---------------|
| **登录墙** | `page.content()` 含 "请先登录"/"登录后查看" | 暂停,通知操作员登录 |
| **滑块验证** | `page.content()` 含 `rmc.bytedance.com/verifycenter` | 暂停,通知操作员滑滑块 |
| **短信/邮箱验证码** | `page.content()` 含 "请输入验证码"/"短信验证" | 暂停,通知操作员收码 |
| **二维码扫码** | `page.content()` 含 "扫码登录"/"微信扫码"/"打开 App 扫码" | 暂停,通知操作员扫码 |
| **人脸/实名认证** | `page.content()` 含 "实名认证"/"人脸识别" | 暂停,通知操作员做人脸 |
| **支付/转账确认** | `page.content()` 含 "支付"/"输入支付密码" | 暂停,通知操作员完成支付 |
| **风控被封** | `page.content()` 含 "账号异常"/"已被封禁" | 暂停,通知操作员决定下一步 |
| **页面崩溃/打不开** | `page.goto` 抛异常或 timeout | 暂停,通知操作员确认 VNC |

### ⚠️ 通知格式(标准模板)

暂停时,**agent 必须输出**这个格式(包含 VNC 链接 + 具体任务 + 验证信号):

```python
🛑 暂停: 需要操作员介入
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
任务: <当前正在做什么,例如 "登录小红书">
原因: <具体卡在哪,例如 "搜索结果页显示 '登录后查看'">

👉 VNC 浏览器: http://<你的服务器IP>:6080/vnc.html
   (打开 → 看 chromium 当前页面 → 手动操作)

操作步骤:
1. 在 VNC 浏览器完成 <具体操作>
2. 操作完成后说 "搞定了"

agent 接下来会:
- 暂停(不调 playwright)
- 等你说 "搞定了"
- 然后自动 reload + 继续
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 验证信号(检测页面状态)

```python
def check_block(page, current_task=""):
    """检测是否需要操作员介入。返回 (need_intervene, reason, vnc_url)"""
    content = page.content()
    
    # 登录墙
    if any(kw in content for kw in ["请先登录", "登录后查看", "登录查看更多"]):
        return True, "登录墙", get_vnc_url()
    
    # 滑块/验证码
    if "rmc.bytedance.com/verifycenter" in content or "captcha" in content.lower()[:5000]:
        return True, "滑块验证", get_vnc_url()
    
    # 短信/邮箱验证码
    if "请输入验证码" in content or "短信验证" in content or "邮箱验证" in content:
        return True, "验证码", get_vnc_url()
    
    # 扫码
    if any(kw in content for kw in ["扫码登录", "打开 App 扫码", "微信扫码", "REDNote 扫码"]):
        return True, "扫码登录", get_vnc_url()
    
    # 人脸/实名
    if "实名认证" in content or "人脸识别" in content:
        return True, "实名/认证", get_vnc_url()
    
    # 支付
    if "支付密码" in content or "确认支付" in content:
        return True, "支付确认", get_vnc_url()
    
    return False, None, None


def get_vnc_url():
    """获取 VNC 地址(从配置文件或环境变量读取)"""
    import os
    server_ip = os.environ.get("VNC_SERVER_IP", "你的服务器IP")
    return f"http://{server_ip}:6080/vnc.html"
```python

### 标准流程

```
Agent 检测到需要介入
  ↓
Agent 暂停所有 playwright 操作(不再调 page.goto/click/...)
  ↓
Agent 输出标准暂停通知(含 VNC URL)
  ↓
[等待操作员操作]
  ↓
操作员: "搞定了"  ← 关键信号
  ↓
Agent: page.reload() + page.wait_for_timeout(2000)
  ↓
Agent 继续执行原任务
```text

### 重要原则(必读)

**DO**:
- ✅ 检测到需要介入时,**立刻暂停**,不要继续尝试各种自动化方案(浪费时间)
- ✅ 暂停通知里**必须包含 VNC URL**(操作员不能记住所有内网地址)
- ✅ 暂停通知里**说明具体操作**(不要只说"需要登录",要说"登录小红书账号,扫码/手机号")
- ✅ 操作员说"搞定了"之后,**先 reload 再继续**(cookie 可能没生效)
- ✅ 同一任务最多暂停 1 次,操作员操作完就该跑通

**DON'T**:
- ❌ 默认每次都让操作员介入(已登录过的平台 cookie 都在,直接用)
- ❌ 检测到登录墙还尝试用 stealth / proxy / 换 UA 解决(这套架构不解决风控)
- ❌ 在 VNC 看不到的时候输出暂停通知(必须同时显示 VNC URL)
- ❌ 用 `input("按 Enter 继续")` 阻塞(不是所有 agent 都能响应 stdin)
- ❌ 不带 VNC URL 就说 "操作员请处理" — 操作员看不到就没法处理
- ❌ 跳过暂停继续操作(可能触发账号封禁)
- ❌ 替操作员输入密码或点 OAuth(账号安全红线)

### 复盘机制

每次操作员介入,agent 应记录:
- 哪个平台
- 卡在什么步骤
- 操作员做了什么操作
- 后续 agent 怎么继续

写到 `/tmp/vnc-research-interventions.log`:
```
2026-06-26 23:50 | xiaohongshu | 登录墙 | 操作员扫码登录 | agent page.reload + 继续
2026-06-26 23:55 | douyin | 滑块 | 操作员滑过 | agent page.reload + 继续
```text

---

## Pre-flight (REQUIRED)

**开始任何任务前**:

1. **确认 VNC 浏览器在跑**:
   ```bash
   curl http://127.0.0.1:9222/json/version
   ```
   如果不响应,告诉操作员 "VNC 浏览器没在跑,要 start-all"

2. **加载本 skill**:`skill_view('vnc-research')` 读完整个 SKILL.md

3. **理解操作员的真实意图** — 不明确就 clarify

---

## Architecture (数据流)

```python
[Agent] → playwright.connect_cdp(9222) → [VNC chromium :9222]
                                              ↓ profile shared
                                       [登录态/cookie 永久]
                                              ↓
                                       [操作员在 VNC 浏览器 :6080 看]
                                              ↓
                              [需要时操作员手动操作 + 写 cookie]
```

---

## 通用任务模式(覆盖 80% 场景)

### 模式 A:抓数据(只读)

```text
navigate → wait → evaluate(抓选择器) → 整理 → 输出
```

### 模式 B:抓详情(搜索 + 详情页)

```text
navigate 搜索页 → 抓链接列表 → 循环 navigate 详情 → 抓详情 → 合并
```

### 模式 C:登录后操作(写)

```text
navigate 登录页 → 操作员手动登录(只一次)
  ↓ 后续 session cookie 自动复用
navigate 目标页 → click/input/select → submit → 验证结果
```

### 模式 D:跨平台聚合

```text
循环 platforms:
  navigate 平台 1 搜索 → 抓数据 → 加到 list
  navigate 平台 2 搜索 → 抓数据 → 加到 list
去重 + 排序 + 输出
```

### 模式 E:监控(定时 + 变化告警)

```text
while True:
  navigate 监控目标
  evaluate(抓关键指标)
  if 指标 != 上次: 通知操作员
  sleep(interval)
```

### 模式 F:操作 + 验证

```python
navigate 目标 → 执行操作(click/input/submit)
  ↓
evaluate(检查结果是否生效)
  ↓
if 失败: 重试 / 报错给操作员
```

**所有模式的核心都是 `playwright + VNC chromium + 操作员介入协议`**。

---

## 标准任务流程

### Step 1:接 CDP,准备 page

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    # 用现有 page(避免开新标签页打断操作员的 VNC 视图)
    if browser.contexts[0].pages:
        page = browser.contexts[0].pages[0]
    else:
        page = browser.contexts[0].new_page()
```python

### Step 2:导航到目标

```python
search_url = build_search_url(platform, query)  # 平台特定
page.goto(search_url, wait_until="domcontentloaded")
page.wait_for_timeout(3000)  # 等异步加载
```

### Step 3:检查登录态 / 验证码

```python
content = page.content()

if "登录后查看" in content or "请先登录" in content:
    # 登录墙 - 需要操作员介入
    print("⚠️ 需要登录。操作员, 请在 VNC 浏览器手动登录,登录完说 '搞定了'")
    input("按 Enter 继续...")  # 阻塞等操作员
    page.reload()
    page.wait_for_timeout(3000)

if "verify" in content.lower() or "rmc.bytedance.com" in content:
    # 验证码/滑块
    print("⚠️ 触发滑块验证。操作员, 请在 VNC 滑过,完事说 '搞定了'")
    input("按 Enter 继续...")
    page.reload()
    page.wait_for_timeout(3000)
```text

### Step 4:抓数据(平台特定)

见下面"平台特定"章节。

### Step 5:输出报告

按 `docs/03-使用指南.md` 的报告模板,数据落 `/tmp/`,Markdown 输出给操作员。

---

## 平台特定(已实测)

### 小红书(xiaohongshu.com)

**搜索 URL**:
```
https://www.xiaohongshu.com/search_result?keyword=<urlencoded>&source=web_explore_feed
```text

**搜索结果抓取**(返回笔记索引):
```javascript
() => Array.from(document.querySelectorAll('section.note-item')).map((s, i) => ({
    idx: i,
    title: (s.querySelector('.title, .note-title')?.innerText || '').trim().slice(0, 120),
    author: (s.querySelector('[class*=author] .name, .author-wrapper .name')?.innerText || '').trim(),
    date: (s.querySelector('[class*=date], [class*=time]')?.innerText || '').trim(),
    likes: (s.querySelector('[class*=like] [class*=count], [class*=like]')?.innerText || '').trim(),
    href: s.querySelector('a[href*="search_result/"]')?.href || ''
}))
```

**关键**: 必须用 `a[href*="search_result/"]` 抓链接(带 xsec_token)。`/explore/` 链接 = 404。

**详情页抓取**:
```javascript
() => {
    const d = {};
    d.title = (document.querySelector('#detail-title, .title')?.innerText || '').trim();
    d.desc = (document.querySelector('#detail-desc, .desc')?.innerText || '').trim().slice(0, 1500);
    d.author = (document.querySelector('.author-wrapper .username, .author .name')?.innerText || '').trim();
    d.date = (document.querySelector('.date, .publish-date')?.innerText || '').trim();
    d.likes = (document.querySelector('.like-wrapper .count')?.innerText || '').trim();
    d.collects = (document.querySelector('.collect-wrapper .count')?.innerText || '').trim();
    d.comments = (document.querySelector('.chat-wrapper .count')?.innerText || '').trim();
    return d;
}
```text

### 抖音(douyin.com)

**搜索 URL**:
```
https://www.douyin.com/search/<urlencoded>
```python

**登录墙**:
- 抖音搜索页强制登录
- 操作员在 VNC 登录(扫码/手机号)
- 登录态保留,agent 可直接抓

**滑块**:
- `rmc.bytedance.com/verifycenter/captcha/v2?subtype=slide`
- 操作员在 VNC 滑过
- 触发检测:`page.content()` 包含 "rmc.bytedance.com"

**搜索结果抓取**:
```javascript
() => Array.from(document.querySelectorAll('li[class*=search]')).map((el, i) => ({
    idx: i,
    title: el.innerText.split('\n').slice(0, 3).join(' ').slice(0, 200),
    href: el.querySelector('a')?.href || ''
}))
```

### 知乎(zhihu.com)

**搜索 URL**:
```bash
https://www.zhihu.com/search?type=content&q=<urlencoded>
```

**直接通**(VNC chromium 用真实 chrome UA,不像 HeadlessChrome 被识别)。

**搜索结果抓取**:
```javascript
() => Array.from(document.querySelectorAll('[itemprop="zhihu:question"], .ContentItem, .SearchResult-Card')).map(el => ({
    title: el.querySelector('a')?.innerText?.trim() || '',
    excerpt: el.querySelector('.RichText, .ContentItem-meta')?.innerText?.trim()?.slice(0, 300) || '',
    author: el.querySelector('.UserLink-link, .author')?.innerText?.trim() || '',
    upvotes: el.querySelector('.VoteButton--up, [aria-label*="赞同"]')?.innerText?.trim() || '',
    href: el.querySelector('a')?.href || ''
}))
```text

### B站(bilibili.com)

**搜索 URL**:
```
https://search.bilibili.com/all?keyword=<urlencoded>&order=click
```text

**直接通**(不需要登录)。

**搜索结果抓取**(已知完整):
```javascript
() => Array.from(document.querySelectorAll('.bili-video-card, .video-card')).map(el => ({
    title: el.querySelector('.bili-video-card__info--tit, .title')?.innerText?.trim() || '',
    author: el.querySelector('.bili-video-card__info--author, .up-name')?.innerText?.trim() || '',
    play: el.querySelector('.bili-video-card__stats--item, .play-count')?.innerText?.trim() || '',
    duration: el.querySelector('.bili-video-card__stats__duration, .duration')?.innerText?.trim() || '',
    href: el.querySelector('a')?.href || ''
}))
```

---

## 通用操作模板(覆盖各种场景)

不只是"抓数据",还有很多场景。下面是常用代码模板,直接复制粘贴用。

### 模板 1:点击/输入

```python
# 点按钮(按文本)
page.click("button:has-text('发布')")

# 点按钮(按选择器)
page.click("#submit-btn")

# 在输入框填内容
page.fill("input[name='content']", "要发的内容")

# 在富文本编辑器里输入(小红书/知乎的 content)
page.locator(".content-editor").type("要发的内容")

# 按键盘
page.keyboard.press("Enter")
page.keyboard.press("Control+Enter")  # Ctrl+Enter 提交
```python

### 模板 2:登录态复用 + 自动操作

```python
# 第一次:操作员手动登录(cookie 写入 profile)
# 后续:agent 直接复用登录态

page.goto("https://weibo.com")  # 已登录
page.click("text=发微博")
page.fill(".draft-editor", "今天心情不错")
page.click("text=发布")
page.wait_for_timeout(2000)
# 验证:看是否跳转/有"发布成功"提示
```

### 模板 3:翻页 / 滚动加载

```python
# 经典分页("下一页"按钮)
while True:
    # 抓当前页
    items = page.evaluate("""() => Array.from(document.querySelectorAll('.item')).map(...)""")
    all_items.extend(items)

    # 看有没有"下一页"
    next_btn = page.locator("text=下一页").first
    if not next_btn.is_visible():
        break
    next_btn.click()
    page.wait_for_timeout(2000)

# 滚动加载(无限滚动)
last_count = 0
for _ in range(20):  # 最多滚 20 次
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(2000)
    items = page.evaluate("() => document.querySelectorAll('.item').length")
    if items == last_count:
        break
    last_count = items
```python

### 模板 4:下载文件

```python
# 方法 1:触发下载,等下载完成
with page.expect_download() as download_info:
    page.click("text=下载报告")
download = download_info.value
download.save_as("/tmp/report.pdf")

# 方法 2:直接抓 URL(已知下载链接)
import requests
# 用 cookie 从 browser 拿
cookies = {c['name']: c['value'] for c in browser.contexts[0].cookies()}
response = requests.get(download_url, cookies=cookies)
with open("/tmp/file.pdf", "wb") as f:
    f.write(response.content)
```

### 模板 5:上传文件

```python
# file input 直接 set_input_files
page.set_input_files("input[type='file']", "/local/path/to/file.pdf")

# 拖拽上传(更复杂,需要坐标 + mouse events)
```python

### 模板 6:填表

```python
# 通用表单
page.fill("input[name='username']", "user")
page.fill("input[name='password']", "pass")  # 注意:密码应该从操作员那问,不要硬编码
page.select_option("select[name='role']", "admin")
page.check("input[type='checkbox'][name='agree']")
page.click("button[type='submit']")
page.wait_for_load_state("networkidle")
```

### 模板 7:抓 cookie / 注入 cookie

```python
# 抓当前 cookie(可能用于 API 调用)
cookies = browser.contexts[0].cookies()
for c in cookies:
    print(f"{c['name']}={c['value']} (domain={c['domain']})")

# 注入 cookie(比如把另一个 profile 的 cookie 拿过来)
browser.contexts[0].add_cookies([{
    "name": "sessionid",
    "value": "xxx",
    "domain": ".example.com",
    "path": "/"
}])
```python

### 模板 8:处理弹窗 / 通知 / 下载请求

```python
# 接受 alert/confirm/prompt
page.on("dialog", lambda dialog: dialog.accept())

# 监听下载事件
def handle_download(download):
    download.save_as(f"/tmp/{download.suggested_filename}")
page.on("download", handle_download)

# 处理新标签页
def handle_new_page(new_page):
    print(f"New tab: {new_page.url}")
    # 在这里处理新页面
page.on("page", handle_new_page)
```

### 模板 9:模拟滚动 / 鼠标轨迹(过滑块)

```python
# 平滑滚动到元素
page.locator(".target").scroll_into_view_if_needed()
page.wait_for_timeout(500)

# 模拟人类鼠标轨迹(过滑块有时需要)
start = page.locator(".slider-start").bounding_box()
end = page.locator(".slider-end").bounding_box()
page.mouse.move(start["x"] + 20, start["y"] + 20)
page.mouse.down()

# 多次小步移动,不是一次到底(更像人类)
import random
steps = 30
for i in range(steps):
    progress = (i + 1) / steps
    x = start["x"] + (end["x"] - start["x"]) * progress
    y = start["y"] + random.uniform(-5, 5)  # 加点抖动
    page.mouse.move(x, y, steps=2)
    page.wait_for_timeout(20)
page.mouse.up()
```python

### 模板 10:网络拦截(看 API 请求)

```python
# 监听所有 API 请求
api_calls = []
def handle_request(request):
    if "/api/" in request.url:
        api_calls.append({
            "url": request.url,
            "method": request.method,
            "headers": dict(request.headers),
            "post_data": request.post_data
        })
page.on("request", handle_request)

page.goto("https://example.com")
page.wait_for_timeout(3000)

# 看哪些 API 被调用了 → 直接调 API(绕过浏览器)
```

### 模板 11:截图 + OCR

```python
# 截图
page.screenshot(path="/tmp/screenshot.png", full_page=True)

# 如果有 tesseract 可用,OCR 提取文字
# (需要先装: apt install -y tesseract-ocr tesseract-ocr-chi-sim)
import subprocess
result = subprocess.run(["tesseract", "/tmp/screenshot.png", "-", "-l", "chi_sim+eng"],
                        capture_output=True, text=True)
print(result.stdout)
```python

### 模板 12:跨页面持久化(多轮任务)

```python
# 第一轮:搜索 → 拿链接
page.goto("https://xiaohongshu.com/search_result?keyword=X")
items = page.evaluate("""() => Array.from(document.querySelectorAll('a[href*="search_result/"]')).map(...)""")
saved = [{"href": i["href"]} for i in items[:10]]  # 只存 href

# 第二轮:用保存的链接,继续抓详情
# (第二轮不需要重新搜索)
for item in saved:
    page.goto(item["href"])
    # 抓详情...
```

---

## 跨平台/跨场景适配

### 招聘平台
- **BOSS 直聘**:`zhipin.com/web/geek/job` — 列表 + 详情 + 聊天消息
- **拉勾**:`lagou.com/wn/jobs` — 列表 + 详情
- **猎聘**:`liepin.com/zhaopin/` — 列表 + 详情
- **共同**:登录后搜索职位 → 抓列表 → 抓详情 → 投递(自动)

### 电商平台
- **淘宝/天猫**:`item.taobao.com` — 商品详情、评论、价格历史
- **京东**:`item.jd.com` — 同上
- **拼多多**:`mobile.yangkeduo.com` — 同上
- **共同**:搜索 → 商品列表 → 抓价格/评论/销量

### 社交平台
- **微博**:`weibo.com` — 搜索、发微博、评论、私信
- **微信公众号**:`mp.weixin.qq.com` — 后台发文(需要登录)
- **知乎**:已有
- **小红书/抖音**:已有
- **共同**:搜索 → 抓内容 → 评论/点赞/转发(注意频率限制)

### 个人数据
- **微信 Web**:`wx.qq.com` — 看消息(文件传输有限制)
- **邮箱**:`mail.google.com` / `outlook.live.com` — 搜索邮件
- **银行/支付**:`alipay.com` / 各银行 — **不要自动化**(合规风险)
- **订单**:`淘宝-我的订单` / `京东-我的订单`

### 内容平台
- **YouTube**:`youtube.com` — 搜索视频、抓评论、字幕
- **Medium**:`medium.com` — 抓文章
- **Substack**:`substack.com` — 抓 newsletter
- **Twitter/X**:`x.com` — 搜索、抓推文

### 工具类
- **GitHub**:`github.com` — 抓 issue/PR/代码(走 API 更优雅)
- **Notion / Linear / Jira** — 看任务、改状态、提交工单
- **Figma**:`figma.com` — 看设计稿(需要 Figma API token)
- **Google Sheets / Docs** — 读/写表格文档

### 监控类
- **价格监控**:Amazon/淘宝/京东 抓商品价格,变化通知
- **库存监控**:Nike SNKRS/StockX 监控补货
- **舆情监控**:搜关键词,新结果通知
- **可用性监控**:某网站 5 分钟 ping 一次,挂了通知

---

---

## "先试读再叫人" 原则

> 本框架反复强调。**默认 agent 自动操作,遇到登录墙/验证码才暂停叫人**。

DO:
- ✅ 默认开始抓数据,不叫人
- ✅ 真的遇到登录墙/验证码才暂停
- ✅ 暂停时**明确告诉操作员** "需要做什么" + "做完说什么"
- ✅ 操作员 "搞定了" 之后**reload 再试**,不要假设 cookie 自动生效

DON'T:
- ❌ 默认每次都叫人(平台 cookie 已在 VNC 里,直接用)
- ❌ 不暂停直接操作 VNC(那是操作员的浏览器,不是 agent 的)
- ❌ 假设登录态存在(必须 `page.content()` 先确认)
- ❌ 替操作员输入密码或点 OAuth(账号安全)

---

## 多轮对话模式

### 模式 1:Agent 单轮完成

```python
User: 调研小红书 AI 编程
Agent: [抓 20 条详情 + 排序 + 输出报告]
```

### 模式 2:多轮迭代

```python
User: 调研小红书 AI 编程
Agent: [抓搜索结果]
User: 那个 #4 展开看下完整评论
Agent: [page.goto 笔记链接 → 抓评论]
User: 收尾
```

### 模式 3:跨平台

```text
User: 调研 AI 编程(小红书 + 抖音 + B站)
Agent: [抓 3 个平台 + 合并排序]
```

---

## 数据落盘规范

### 临时数据(任务期间)

```text
/tmp/<platform>_<query>_<date>.json
```

### 正式报告

```text
/root/project/docs/<project>/<date>_<topic>.md
```

格式见 `docs/03-使用指南.md`。

---

## 关键踩坑(必读)

完整见 `/root/project/docs/vnc-research/docs/04-踩坑记录.md`。

最重要的几个:

1. **小红书 `/explore/` 链接 404,必须用 `/search_result/<hash>?xsec_token=...`**
2. **chromium 启动必须显式 `DISPLAY=:99`**,否则画到 `:0` 黑屏
3. **Xvfb 加 `-ac`** 避免 Xauthority 麻烦
4. **抖音搜索页 = 登录墙,触发滑块时需要操作员介入**
5. **JavaScript 字符串含 `\\`** 用 `r''' '''` raw 字符串或 `subprocess.run(['python3', '-c', script])`

---

## 报告模板

```markdown
# <Topic> 调研报告
> 调研日期: YYYY-MM-DD | 抓取源: VNC chromium + playwright CDP | 0 操作员介入

## Top N(按热度排序)

| # | 标题 | 作者 | 赞/藏/评 | 链接 |
|---|------|------|---------|------|
| 1 | ... | ... | ... | ... |

## 关键发现

1. ...
2. ...

## 数据来源

- 小红书: 20 条笔记详情 (`/tmp/xhs_<query>_<date>.json`)
- 抖音: ...

## 局限性

- (任何不能确认的数据)
```python

---

## Reference Files

- `references/verified-scenarios-2026-06-26.md` — **实测验证清单**:什么跑通了/什么没跑通/性能数据/服务 PID 状态。**未来 session 加载本 skill 后第一件事**:打开这个文件确认服务状态。
- `references/login-state-detection.md` — **登录墙精确检测方法**(避免"登录"裸字误报)+ 常见平台信号词清单。涉及登录判断时第一件事打开。
- 项目主页: `/root/project/docs/vnc-research/`(shareable 给朋友)
- 部署指南: `/root/project/docs/vnc-research/docs/02-部署指南.md`
- 踩坑记录: `/root/project/docs/vnc-research/docs/04-踩坑记录.md`
- 健康检查: `/root/project/docs/vnc-research/scripts/health-check.sh`(已实测可跑通)
- 演示样例: `/root/project/docs/vnc-research/examples/xiaohongshu-search.md`
- 演示脚本: `scripts/playwright-connect.py`(已实测可跑通)
- **场景应用清单**: `/root/project/docs/vnc-research/examples/use-cases.md`(15 个场景,调研/抓取/操作/监控/聚合)
- **🟢 中文平台经验沉淀**: `~/.hermes/skills/research/chinese-web-research/SKILL.md` + `references/vnc-playwright-cdp-setup.md` — 中文平台特定踩坑
- **🔴 误读指令的反面案例**: 每轮任务开头的 "用户原话 → 我的解读 → 实际意图" 三段式记录 — 防止不澄清就开干

---

## 操作边界(2026-06-26 划定)

> 哪些事 agent 干,哪些事**永远**留给操作员。

### ✅ agent 默认自动干
- 任何页面导航、点击、输入、抓数据
- 跨页面、跨平台搜索 + 抓取
- 监控价格、库存、舆情
- 表单填写(报名、登录非敏感账号)
- 内容发布到操作员自己的账号(小红书/微博/知乎草稿)
- Web 应用自动化测试

### 🔴 必须操作员在 VNC 手动干
- **输入密码 / 点 OAuth 按钮** — agent 永远不替操作员输密码(账号安全)
- **完成支付流程** — 涉及资金、合规风险
- **手机/邮箱验证码** — 需要操作员看手机/邮箱
- **首次登录新平台** — 扫码登录,建立 cookie 持久化

### ⚠️ 边界判断
- **频率限制场景**:批量关注/评论/点赞等 → 遵守平台规则,不要触发 spam 检测(被封号)
- **个人数据查询**:查微信/邮箱/订单 → 用操作员自己账号 OK,但**不导出到第三方**(数据本地落盘)
- **银行/支付**:不要自动化任何涉及资金的页面操作(合规风险)

---

## Pitfalls

- ❌ 用 `curl + grep` 抓 SPA — 100% 失败,用 playwright
- ❌ 用 `/explore/` URL 抓小红书详情 — 404,用 `/search_result/?xsec_token=`
- ❌ 启动 chromium 不指定 `DISPLAY=:99` — 黑屏
- ❌ 不 `wait_for_timeout(2000-4000)` 就 evaluate — 抓不到异步内容
- ❌ 默认每次都操作员介入 — 浪费,先试读再叫人
- ❌ 替操作员输密码或点 OAuth — 账号安全红线
- ❌ agent 操作时假设登录态存在 — 必须 `page.content()` 先确认
- ❌ 关闭 chromium(丢失 profile/登录态)— 用 `page.goto` 而非重启