# AliLedger2 iOS 安装指南

## 方法一：Xcode 直接安装（推荐，最简单）

**需要：Mac 电脑 + iPhone + USB 数据线**

1. 将项目拷贝到 Mac
2. 双击打开 `AliLedger2.xcodeproj`
3. 连接 iPhone 到 Mac（USB）
4. 在 Xcode 顶部选择你的 iPhone 作为目标设备
5. 在左侧选择 AliLedger2 → Signing & Capabilities
6. Team 选择你的 Apple ID（免费即可）
7. Bundle Identifier 改成唯一值，如 `com.你的名字.aliledger`
8. 点击 ▶️ 运行按钮
9. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任开发者

**有效期：7天（免费账号），到期后重新连接 Mac 运行一次即可**

---

## 方法二：AltStore 侧载（无线安装）

**需要：Mac/Windows 电脑 + iPhone + 同一 WiFi**

1. 下载 AltStore：https://altstore.io
2. 安装 AltStore 到 iPhone（需通过电脑安装一次）
3. 在电脑上运行 GitHub Actions 构建（见下方），下载 `AliLedger2.zip`
4. 解压得到 `AliLedger2.app`
5. 用 AltStore 的 Sideload 功能安装 `AliLedger2.app`

**有效期：7天，AltStore 会自动刷新**

---

## 方法三：GitHub Actions 自动构建

**需要：GitHub 账号**

1. 在 GitHub 创建新仓库（如 `AliLedger2-iOS`）
2. 将项目推送到仓库：
   ```bash
   cd AliLedger2-iOS
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/你的用户名/AliLedger2-iOS.git
   git push -u origin main
   ```
3. GitHub 会自动触发构建（Actions 标签页）
4. 构建完成后，下载 Artifacts 中的 `AliLedger2.zip`
5. 用 Xcode 或 AltStore 安装到 iPhone

---

## 方法四：Sideloadly（Windows 用户友好）

**需要：Windows/Mac + iPhone + USB 数据线**

1. 下载 Sideloadly：https://sideloadly.io
2. 安装 Sideloadly
3. 通过 GitHub Actions 构建获取 `AliLedger2.zip`，解压得到 `.app`
4. 连接 iPhone，在 Sideloadly 中选择 `.app` 文件
5. 输入你的 Apple ID（免费即可）
6. 点击 Start，等待安装完成
7. iPhone 上信任开发者证书

---

## 常见问题

**Q: 没有 Mac 怎么办？**
A: 用 GitHub Actions 构建（方法三），然后用 Sideloadly（方法四）安装到 iPhone。全程不需要 Mac。

**Q: 免费 Apple ID 可以用吗？**
A: 可以！免费账号能安装到真机，但每 7 天需要重新签名一次。

**Q: App 过期了怎么办？**
A: 重新安装一次即可。如果用 AltStore，它会自动刷新。

**Q: 构建失败怎么办？**
A: 确保 Xcode 版本 ≥ 15.0，iOS 部署目标 ≥ 15.0。
