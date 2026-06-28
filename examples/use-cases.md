# 应用场景示例

> vnc-research 不只是调研。**任何"通过网页做 X"的任务都能用**。
> 下面是真实场景 + 代码骨架(给朋友参考)。

---

## 场景 1:调研抓取(已实测)

**任务**: 小红书"AI 编程"搜索 → Top 20 笔记详情

完整示例见 [`xiaohongshu-search.md`](xiaohongshu-search.md)。

**耗时**: ~45 秒,0 操作员介入。

---

## 场景 2:跨平台聚合

**任务**: 同一关键词,在小红书 + 抖音 + B站 + 知乎搜,聚合去重。

```python
platforms = {
    "小红书": {"url": f"https://www.xiaohongshu.com/search_result?keyword={kw}", ...},
    "抖音":   {"url": f"https://www.douyin.com/search/{kw}", ...},
    "B站":    {"url": f"https://search.bilibili.com/all?keyword={kw}", ...},
    "知乎":   {"url": f"https://www.zhihu.com/search?q={kw}", ...},
}

all_results = []
for name, conf in platforms.items():
    page.goto(conf["url"])
    page.wait_for_timeout(3000)
    items = page.evaluate(conf["extract_js"])
    for item in items:
        item["platform"] = name
    all_results.extend(items)

# 去重(按标题相似度)
unique = dedup_by_title_similarity(all_results, threshold=0.7)

# 输出
print(f"总 {len(all_results)} 条,去重后 {len(unique)} 条")
for i, item in enumerate(unique[:30]):
    print(f"{i+1}. [{item['platform']}] {item['title']}")
```python

**适用**: 竞品调研、舆情监控、学术资料收集、品牌传播追踪。

---

## 场景 3:价格监控

**任务**: 监控京东某商品价格,降价时通知。

```python
import time
import subprocess

target_url = "https://item.jd.com/100012345.html"
threshold_price = 2000

while True:
    page.goto(target_url)
    page.wait_for_timeout(3000)
    price = page.evaluate("""() => {
        const el = document.querySelector('.p-price .price');
        return el ? parseFloat(el.innerText.replace(/[^\\d.]/g, '')) : null;
    }""")
    
    if price and price < threshold_price:
        # 发送通知
        subprocess.run(["curl", "-X", "POST", "https://ntfy.sh/YOUR_TOPIC",
                       "-d", f"京东商品降价!现在 ¥{price}"])
        print(f"⚠️ 降价通知已发: ¥{price}")
    
    print(f"[{time.strftime('%H:%M')}] 当前价格: ¥{price}")
    time.sleep(3600)  # 每小时检查一次
```

**适用**: 抢购、补货监控、优惠追踪、股票监控。

---

## 场景 4:抓全网文章(网状爬取)

**任务**: 看到一篇公众号文章不错,抓全文 + 作者其他文章。

```python
# Step 1:抓单篇
page.goto(article_url)
page.wait_for_timeout(2000)
content = page.evaluate("""() => ({
    title: document.querySelector('#activity-name').innerText,
    author: document.querySelector('#js_name').innerText,
    date: document.querySelector('#publish_time').innerText,
    content: document.querySelector('#js_content').innerText,
    html: document.querySelector('#js_content').innerHTML
})""")

# Step 2:去作者主页看其他文章
author_url = f"https://mp.weixin.qq.com/profile?__biz={biz}"
# ...(抓作者其他文章链接,再循环抓)

# Step 3:保存到本地
import os, json
os.makedirs(f"/root/project/docs/{author}/", exist_ok=True)
with open(f"/root/project/docs/{author}/{date}_{title}.json", "w") as f:
    json.dump(content, f, ensure_ascii=False, indent=2)
```python

**适用**: 个人知识库建立、博主追踪、媒体监测。

---

## 场景 5:登录后自动操作

**任务**: 在 VNC 手动登录 LinkedIn → agent 自动给指定公司发"打招呼"消息。

```python
# Step 1:操作员已经在 VNC 浏览器登录 LinkedIn(手动操作)
# Step 2:agent 直接用登录态

page.goto("https://www.linkedin.com/feed/")
if "登录" in page.content()[:5000]:
    print("⚠️ 需要登录,请在 VNC 操作")
    input("按 Enter 继续...")

# Step 3:搜索目标公司
page.goto("https://www.linkedin.com/search/results/people/?keywords=Google%20engineer")
page.wait_for_timeout(3000)

# Step 4:对每个 profile 发消息
profiles = page.evaluate("""() => Array.from(document.querySelectorAll('.entity-result')).map(...)""")

for profile in profiles[:10]:
    page.goto(profile["url"])
    page.wait_for_timeout(2000)
    page.click("text=Message")
    page.fill("textarea[name='message']", f"你好 {profile['name']},我是...")
    page.click("text=Send")
    page.wait_for_timeout(1500)
    print(f"✓ 已发消息给 {profile['name']}")
```

**适用**: 自动打招呼、自动报名、自动提交工单、自动关注。

⚠️ **注意频率限制** — 不要发太多,会被风控。

---

## 场景 6:Web 应用自动化测试

**任务**: 测试自家 SaaS 应用的注册流程。

```python
test_cases = [
    {"name": "正常注册", "email": "test1@example.com", "password": "ValidPass123!"},
    {"name": "邮箱已存在", "email": "existing@example.com", "password": "ValidPass123!"},
    {"name": "密码太短", "email": "test2@example.com", "password": "123"},
    {"name": "邮箱格式错", "email": "not-an-email", "password": "ValidPass123!"},
]

for tc in test_cases:
    page.goto("https://myapp.com/register")
    page.fill("input[name='email']", tc["email"])
    page.fill("input[name='password']", tc["password"])
    page.click("button[type='submit']")
    page.wait_for_timeout(2000)
    
    error_msg = page.evaluate("() => document.querySelector('.error')?.innerText || ''")
    success = "/dashboard" in page.url
    
    print(f"{tc['name']}: {'✓ 通过' if (success or error_msg) else '✗ 失败'}")
    if error_msg:
        print(f"  错误提示: {error_msg}")
```text

**适用**: E2E 测试、回归测试、自动化 QA。

---

## 场景 7:跨平台内容发布

**任务**: 同一篇文章,在小红书 + 微博 + 知乎都发一份。

```python
article = {
    "title": "今天学到的 3 个 AI 编程技巧",
    "content": "...",
    "tags": ["AI编程", "提效"]
}

# 小红书
page.goto("https://www.xiaohongshu.com/create-notes")
page.wait_for_timeout(2000)
page.fill(".title-input", article["title"])
page.fill(".content-editor", article["content"])
for tag in article["tags"]:
    page.type(".tag-input", tag + " ")
page.click("text=发布")
page.wait_for_timeout(3000)

# 微博
page.goto("https://weibo.com")
page.wait_for_timeout(2000)
page.click("text=发微博")
page.fill(".draft-editor", article["content"][:2000])
page.click("text=发布")

# 知乎(写文章)
page.goto("https://zhuanlan.zhihu.com/write")
page.wait_for_timeout(2000)
page.fill("input[placeholder='请输入标题']", article["title"])
page.fill(".RichText-root", article["content"])
page.click("text=发布")
```

⚠️ **必须遵守各平台规则**,避免 spam 检测。

---

## 场景 8:数据备份 + 迁移

**任务**: 把 A 平台的关注列表迁移到 B 平台。

```python
# 从 A 抓关注列表
page.goto("https://platform-a.com/following")
page.wait_for_timeout(3000)
following_a = page.evaluate("""() => Array.from(document.querySelectorAll('.user-card')).map(...)""")

# 到 B 平台关注
page.goto("https://platform-b.com")
page.wait_for_timeout(2000)

for user in following_a:
    page.goto(f"https://platform-b.com/search?q={user['name']}")
    page.wait_for_timeout(2000)
    # 找到匹配的用户,点关注
    page.locator(f"text={user['name']}").first.click()
    page.wait_for_timeout(1500)
    btn = page.locator("text=关注").first
    if btn.is_visible():
        btn.click()
    page.wait_for_timeout(1000)
```python

---

## 场景 9:个人数据查询

**任务**: 看自己的微信公众号后台数据(关注增长/阅读量)。

```python
# 操作员已在 VNC 登录公众号后台
page.goto("https://mp.weixin.qq.com/cgi-bin/home")
page.wait_for_timeout(3000)

# 抓最近 7 天数据
stats = page.evaluate("""() => ({
    followers: document.querySelector('.follower-count')?.innerText,
    total_reads: document.querySelector('.total-reads')?.innerText,
    articles: Array.from(document.querySelectorAll('.article-row')).map(r => ({
        title: r.querySelector('.title')?.innerText,
        reads: r.querySelector('.reads')?.innerText,
        date: r.querySelector('.date')?.innerText
    }))
})""")

print(f"关注: {stats['followers']}, 总阅读: {stats['total_reads']}")
for art in stats['articles']:
    print(f"  {art['date']}: {art['title']} ({art['reads']} 阅读)")
```

---

## 场景 10:舆情监控(关键词)

**任务**: 监控某个品牌/关键词,在小红书/微博/知乎出现新结果时通知。

```python
import time, json

keyword = "Hermes Agent"
seen_titles = set()

while True:
    for platform, url in [
        ("小红书", f"https://www.xiaohongshu.com/search_result?keyword={keyword}"),
        ("知乎", f"https://www.zhihu.com/search?q={keyword}")
    ]:
        page.goto(url)
        page.wait_for_timeout(3000)
        titles = page.evaluate("""() => Array.from(document.querySelectorAll('a')).map(a => a.innerText).filter(t => t.length > 10)""")
        
        new_titles = [t for t in titles if t not in seen_titles]
        if new_titles:
            # 通知
            subprocess.run(["curl", "-X", "POST", "https://ntfy.sh/YOUR_TOPIC",
                          "-d", f"[{platform}] {keyword} 出现 {len(new_titles)} 条新内容"])
            seen_titles.update(new_titles)
    
    time.sleep(1800)  # 30 分钟一次
```python

---

## 场景 11:批量图片下载

**任务**: 从某个 Pinterest 画板下载所有图片。

```python
page.goto("https://pinterest.com/board/X/")
page.wait_for_timeout(3000)

# 滚动到底加载所有图片
last_count = 0
while True:
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(2000)
    count = page.evaluate("() => document.querySelectorAll('img').length")
    if count == last_count:
        break
    last_count = count

# 抓所有图片 URL
images = page.evaluate("""() => Array.from(document.querySelectorAll('img'))
    .map(img => img.src)
    .filter(src => src.includes('pinimg'))""")

# 批量下载
import requests, os
os.makedirs("/tmp/pinterest-board", exist_ok=True)
for i, url in enumerate(images):
    r = requests.get(url)
    with open(f"/tmp/pinterest-board/{i:03d}.jpg", "wb") as f:
        f.write(r.content)
print(f"下载 {len(images)} 张图片")
```

---

## 场景 12:Web 应用 API 提取

**任务**: 抓某个 SPA 应用的底层 API,绕过 UI 直接调。

```python
# 监听 API 请求
api_calls = []
def handle_response(response):
    if "/api/" in response.url:
        api_calls.append({
            "url": response.url,
            "method": response.request.method,
            "status": response.status,
            "headers": dict(response.headers),
            "body": response.text()  # body 可能要 await
        })

page.on("response", handle_response)

# 触发页面
page.goto("https://app.example.com/dashboard")
page.wait_for_timeout(5000)

# 拿 API 调用记录
print(f"捕获 {len(api_calls)} 个 API 请求")
for call in api_calls:
    print(f"  {call['method']} {call['url']} -> {call['status']}")

# 之后直接调 API(绕过浏览器)
import requests
for call in api_calls:
    r = requests.get(call['url'], headers=call['headers'])
    data = r.json()
    # 处理 data...
```python

**适用**: 反向工程 SPA、绕过 UI 限制、批量操作。

---

## 场景 13:表单自动化(批量报名/填表)

**任务**: 帮操作员在某个网站批量报名会议(填同一份报名表 50 次,不同邮箱)。

```python
emails = ["user1@example.com", "user2@example.com", ...]

for email in emails:
    page.goto("https://conference.com/register")
    page.wait_for_timeout(1500)
    
    page.fill("input[name='email']", email)
    page.fill("input[name='name']", email.split("@")[0])
    page.fill("input[name='company']", "Acme Corp")
    page.click("button[type='submit']")
    page.wait_for_timeout(2000)
    
    # 验证成功
    if "报名成功" in page.content() or "/dashboard" in page.url:
        print(f"✓ {email} 报名成功")
    else:
        print(f"✗ {email} 失败")
```

⚠️ **合法使用** — 只用于操作员自己/团队同事的报名,不要用于代报名/灰产。

---

## 场景 14:跨账号管理(团队用)

**任务**: 同时管理操作员个人号 + 公司号(2 个浏览器 profile)。

需要不同端口(本项目当前不支持):

```text
# 个人 profile
chromium --user-data-dir=/home/edik/.config/chromium --remote-debugging-port=9222
# 公司 profile  
chromium --user-data-dir=/home/company/.config/chromium --remote-debugging-port=9223
```

代码里用对应端口连。

---

## 场景 15:表单填写 + 提交 + 支付(端到端)

**任务**: 在某电商网站下单商品(用 VNC 里已登录的账号)。

```python
page.goto("https://shop.com/product/123")
page.wait_for_timeout(2000)
page.click("text=立即购买")

# 自动填收货地址(VNC 已登录,cookie 自动填充)
page.click("text=使用默认地址")

# 选择支付方式
page.click("text=支付宝")
page.wait_for_timeout(1000)

# ⚠️ 支付环节:让操作员在 VNC 扫码/输密码
print("⚠️ 需要操作员在 VNC 完成支付")
input("完成后按 Enter...")

# 验证订单创建
page.wait_for_timeout(2000)
if "订单创建成功" in page.content():
    print("✓ 订单创建成功")
```text

**关键原则**: **任何涉及资金/隐私的操作,必须操作员在 VNC 手动确认**,不要自动化支付密码。

---

## 总结:什么场景适合 / 不适合

### ✅ 适合
- 公开数据抓取(评论、商品、文章)
- 跨平台聚合
- 个人账号内操作(看自己的数据、改自己的设置)
- 内部 SaaS 自动化(用操作员自己的账号)
- 价格/库存监控
- 内容发布(自己账号,不要 spam)
- 表单自动化(合法场景)
- 自动化测试(E2E)

### ❌ 不适合
- **支付密码输入**(合规风险 + 隐私)
- **绕过平台限制**(spam 检测、账号封禁风险)
- **爬取非公开数据**(合规问题)
- **灰产/黑产**(违法)
- **多账号养号**(平台规则禁止)

**核心原则**: 自动化可以**减少重复劳动**,但**不能取代关键决策**。涉及金钱/隐私/合规的操作,**始终让操作员在 VNC 手动确认**。
