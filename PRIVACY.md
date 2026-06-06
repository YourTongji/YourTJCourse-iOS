# 隐私政策 / Privacy Policy

**更新日期 / Last updated:** 2026 年 6 月

YourTJ Course（以下简称"本应用"）尊重并保护您的隐私。本隐私政策说明我们如何收集、使用和保护您的信息。

---

## 1. 信息收集 / Information We Collect

### 1.1 我们主动收集的信息

本应用**不收集任何个人身份信息**。所有数据仅用于实现核心功能，且严格遵循最小化原则：

- **本地客户端标识（clientId）**：应用首次启动时自动生成一个随机 UUID，用于点赞操作的防重复与计数。此标识仅用于单次 API 请求的实时处理，不做长期追踪。
- **钱包凭据**：如您选择使用积分钱包功能，学号、PIN 码和助记词仅保存在本机 Keychain 中。这些信息**不会**上传到本应用的服务器。

### 1.2 第三方代码

本应用不包含任何第三方分析 SDK、广告 SDK 或数据收集代码。
唯一的第三方依赖是 `swift-markdown-ui`（开源的 Markdown 渲染库），该库不传输任何数据。

---

## 2. 数据传输与存储 / Data Transmission & Storage

- 应用向您自行部署或由 YourTJ 运营的**后端服务**发送请求，以获取课程数据、提交评价、查询排课信息等。这些请求**不包含**可用于识别您个人身份的信息。
- 钱包查询和积分相关请求发往 Credit 服务（`core.credit.yourtj.de`），传输内容仅限于您钱包的公钥哈希（`userHash`），不包含学号、PIN 或助记词。
- 所有网络通信使用 HTTPS 加密（发布版本），确保传输安全。

---

## 3. 数据安全 / Data Security

- 钱包密钥和助记词仅存储在设备的 **Keychain** 中，可选择启用生物识别（Face ID / Touch ID）保护。
- 评价编辑使用 HMAC-SHA256 本地签名，私钥不出设备。
- 我们**不**将您的数据用于广告投放、用户画像、机器学习训练或分享给第三方。

---

## 4. 数据保留与删除 / Data Retention & Deletion

- 由于应用不收集个人身份信息，我们没有需要保留或删除的用户账户数据。
- 您可以在应用内随时删除本机钱包数据（设置 → 钱包 → 删除钱包）。
- 已发表的评价内容可联系后端管理员处理。

---

## 5. 儿童隐私 / Children's Privacy

本应用面向大学生和成人用户，不针对 13 岁以下儿童。我们不会故意收集儿童的个人信息。

---

## 6. 本政策的变更 / Changes to This Policy

本隐私政策可能不时更新。重大变更将通过应用内的公告通知您。

---

## 7. 联系我们 / Contact Us

如有任何关于本隐私政策的问题，请通过以下方式联系我们：

- GitHub Issues：[https://github.com/YourTongji/YourTJCourse-iOS/issues](https://github.com/YourTongji/YourTJCourse-iOS/issues)
- 项目仓库：[https://github.com/YourTongji/YourTJCourse-iOS](https://github.com/YourTongji/YourTJCourse-iOS)
