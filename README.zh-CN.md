# PaperFocus

[English](README.md) | 中文

## 概述

PaperFocus 是一款用于专注阅读学术文献的应用。它在本机保存文献库，在应用内打开 PDF，并提供专注计时。它面向需要把文献、阅读和计时放在一起的读者。

## 功能

- 保存在设备上的本地文献库。
- 在应用内阅读 PDF。
- 用于阅读的专注计时。
- 可选的论文摘要与翻译。相关服务的凭据在设置中填写。本仓库不包含这些凭据。

## 系统要求

`PaperFocus.xcodeproj` 中的 PaperFocus 应用目标声明了以下部署版本：

- macOS 15.7 或更高版本
- iOS 26.2 或更高版本，适用于 iPhone 与 iPad
- visionOS 26.2 或更高版本

## 编译与运行

在 Xcode 中打开 `PaperFocus.xcodeproj`。选择 PaperFocus 方案，并在所需的目标设备上运行。

## 文献库与导入

导入支持以下来源：

- Zotero 文献库
- EndNote XML 导出文件
- PaperFocus 文献库，包括应用自己的数据库或 `paperfocus.library` 文件
- 一个或多个 PDF 文件
- 包含 PDF 的文件夹

不属于上述格式的文件不会被导入。

### macOS 上的 Zotero

在 macOS 上，PaperFocus 会先查找本机 Zotero 文献库，再请你浏览文件夹。查找范围包括默认数据目录（`~/Zotero`）、`~/Documents/Zotero`、`~/Library/Application Support/Zotero`，以及 Zotero 配置文件中记录的数据目录。只有当文件夹包含具备 Zotero 预期表结构的 `zotero.sqlite` 时，才会采用该文件夹。

- 若只找到一个有效文献库，会提供关联。**优先使用本机 Zotero 文献库**默认开启；在尚未关联文献库时，启动时会关联这一个文献库，而不是另行建立空的独立文献库。
- 若找到多个文献库，由你选择其中一个。PaperFocus 不会自动选定。
- 若没有找到，或你需要其他位置，请使用系统文件选择器。所选位置会按同样的规则检查。

也可以使用你在 Zotero 网站创建的 API 密钥关联 Zotero 账户。密钥只保存在应用设置中。不提供浏览器登录。

**仅使用 Zotero 文献库**默认关闭。开启后，文献列表只显示 Zotero 条目。应用内已有的条目不会被删除。关闭该选项后，这些条目会重新显示。

**导入时复制附件**默认关闭。关闭时，PaperFocus 直接打开原始文件，包括 Zotero 存储目录中的文件，不会另行复制。开启时，导入过程可以将附件复制到应用内。

### iPhone 与 iPad

在 iPhone 和 iPad 上，PaperFocus 不会搜索 Mac 上的数据目录。请在“文件”中选择 Zotero 数据文件夹或其他文件，包括“我的 iPhone”“我的 iPad”以及你授权的其他位置。也可以填写 Zotero API 密钥。

PDF 从这些原始位置打开，不会复制到应用内。文件选择器不会取得副本，应用也不会把 PDF 存入自己的容器。

### EndNote

EndNote 导入读取 EndNote 导出的 XML。EndNote 程序库文件（`.enl`）不会被导入。请先在 EndNote 中导出 XML，再选择该文件。

## 设置与 API 密钥

论文摘要、翻译和 Zotero 账户访问使用你在设置中填写的凭据。这些内容保留在设备上。本仓库不包含 API 密钥或其他机密。

## 许可协议

本仓库采用 [PolyForm Noncommercial License 1.0.0](LICENSE)（非商业许可）。允许出于非商业目的使用、修改和分享本软件；未经事先许可，不得用于商业用途。如需商业授权，请在本仓库提交 issue。正式法律文本以英文 `LICENSE` 文件为准。
