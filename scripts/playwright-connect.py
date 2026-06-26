#!/usr/bin/env python3
"""
playwright-connect.py - 演示怎么用 playwright 连 VNC 上的 chromium

用法:
    # 基本连接测试
    python3 playwright-connect.py

    # 自定义 URL 和操作
    python3 playwright-connect.py --url https://www.baidu.com

前置:
    - VNC chromium 跑在 9222
    - playwright Python 库已装
    - $ pip3 install --break-system-packages playwright
"""

import sys
import argparse
from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser(description="Playwright CDP connect demo")
    parser.add_argument("--url", default="https://www.baidu.com",
                        help="URL to navigate to (default: baidu)")
    parser.add_argument("--host", default="127.0.0.1",
                        help="CDP host (default: 127.0.0.1)")
    parser.add_argument("--port", default="9222", type=int,
                        help="CDP port (default: 9222)")
    args = parser.parse_args()

    cdp_url = f"http://{args.host}:{args.port}"

    print(f"Connecting to {cdp_url} ...")

    try:
        with sync_playwright() as p:
            browser = p.chromium.connect_over_cdp(cdp_url)
            print(f"✓ Connected! Browser: {browser.browser.name if hasattr(browser, 'browser') else 'chromium'}")

            # 找现有 page 或新建
            ctx = browser.contexts[0]
            if ctx.pages:
                page = ctx.pages[0]
                print(f"  Using existing page: {page.url[:80]}")
            else:
                page = ctx.new_page()
                print(f"  Created new page")

            # 导航
            print(f"\nNavigating to {args.url} ...")
            page.goto(args.url, wait_until="domcontentloaded", timeout=15000)
            page.wait_for_timeout(2000)

            title = page.title()
            print(f"✓ Title: {title}")

            # 显示登录态检查
            content = page.content()
            has_login_wall = any(kw in content for kw in ["登录", "请先登录", "登录后查看"])
            has_captcha = "rmc.bytedance.com" in content or "verify" in content.lower()[:5000]

            print(f"\n状态检查:")
            print(f"  登录墙: {'⚠️ 检测到' if has_login_wall else '✓ 无'}")
            print(f"  验证码: {'⚠️ 检测到' if has_captcha else '✓ 无'}")

            if has_login_wall:
                print("\n💡 操作员需要在 VNC 浏览器手动登录,登录完说 '搞定了'")
            elif has_captcha:
                print("\n💡 操作员需要在 VNC 浏览器滑过滑块,完事说 '搞定了'")
            else:
                print("\n✓ 一切正常,可以继续抓数据")

            # 演示抓取
            print("\n演示抓取 (headings):")
            headings = page.evaluate("""
                () => Array.from(document.querySelectorAll('h1, h2, h3'))
                    .slice(0, 10)
                    .map(h => h.tagName + ': ' + h.innerText.trim().slice(0, 60))
            """)
            for h in headings:
                print(f"  {h}")

            print("\n=== Done ===")
            print(f"Chromium 保持运行(没关),其他 agent 可以继续用")

    except Exception as e:
        print(f"\n✗ 连接失败: {e}")
        print("\n排查清单:")
        print("  1. chromium 跑了吗?  pgrep -af 'chromium.*remote-debugging-port'")
        print("  2. 9222 监听了吗?    ss -tln | grep 9222")
        print("  3. DevTools 通吗?    curl http://127.0.0.1:9222/json/version")
        print("  4. playwright 装了?  pip3 list | grep playwright")
        sys.exit(1)


if __name__ == "__main__":
    main()