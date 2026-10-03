# TagClip

TagClip 是一个本地标签工具：把经常需要发送的文件或文件夹绑定到标签，点击标签即可复制为系统文件剪贴板内容，然后在微信、QQ、邮件等聊天窗口中直接粘贴发送。

## 解决什么痛点

日常发送固定资料时，反复打开文件夹、寻找路径、拖拽文件既慢又容易选错；把文件放到桌面或聊天软件收藏夹，又会造成桌面混乱、资料重复和维护困难。

TagClip 用一个轻量的本地标签面板解决这个问题：

- 常用资料按业务或场景分组，点击一次即可复制
- 复制的是系统认可的文件对象，不是文件路径文本，粘贴后仍是可发送的附件
- 标签数据只保存在本机，不需要账号、服务器、网络或云端同步
- 文件被移动或删除后会提示，避免发送失效路径
- 支持 JSON 导入导出，方便备份和换机迁移

## 当前版本边界

这是单机版本。联网客户搜索、服务器端 API、网页管理端和 Nginx 部署文件已从项目中移除，应用不会访问 `search.yixiaomo.top` 或其他远程服务。

## 功能

- 新建、编辑、删除标签
- 为一个标签绑定多个文件或文件夹
- 点击标签复制文件到剪贴板
- 文件不存在时提示并跳过失效路径
- 导出/导入标签 JSON
- macOS 原生应用
- Windows PowerShell 版本

## 安装

### macOS

下载 [`dist/TagClip.dmg`](dist/TagClip.dmg)，打开后将 `TagClip.app` 拖入“应用程序”。首次打开如果 macOS 提示未验证开发者，可在“系统设置 → 隐私与安全性”中允许打开。

也可以直接下载 [`dist/TagClip-macOS.zip`](dist/TagClip-macOS.zip)，解压后将应用移动到“应用程序”。

### Windows 10/11

下载 [`dist/TagClip-Windows.zip`](dist/TagClip-Windows.zip)，解压整个文件夹，双击 `启动TagClip.bat`。PowerShell 5.1 已随 Windows 10/11 提供，无需额外安装运行时。

## 使用

1. 点击“新建标签”。
2. 填写标签名称，添加要发送的文件或文件夹并保存。
3. 在主窗口点击标签，切换到聊天窗口后按 `Cmd+V`（macOS）或 `Ctrl+V`（Windows）。
4. 右键标签可以编辑或删除。

导出功能会生成 JSON 文件；导入会覆盖当前标签，建议在导入前先导出备份。

## 数据位置

- macOS：`~/Library/Application Support/TagClip/tags.json`
- Windows：`%APPDATA%\\TagClip\\tags.json`

应用只保存标签名称和文件路径，不上传文件内容。移动文件后请编辑标签重新选择路径。

## 运行截图

![macOS 主界面](docs/screenshots/macos-main.png)

主界面只保留本地标签、导入、导出和新建操作，不再出现联网搜索或服务器登录入口。

## 从源码构建

### macOS

需要 macOS 14 或更高版本，以及 Swift 6 / Xcode 27。项目使用 Swift Package Manager：

```bash
./build.sh
```

构建结果：

- `dist/TagClip.app`
- `dist/TagClip.dmg`
- `dist/TagClip-macOS.zip`

如果本机同时安装了完整 Xcode，`build.sh` 会自动使用它，以确保 SwiftUI 宏插件可用。

### Windows

无需编译，`windows/` 目录就是可运行版本。要重新生成启动器时，双击 `生成启动器.bat`。

## 项目结构

```text
Sources/TagClip/   macOS 原生应用
windows/           Windows PowerShell 版本
Resources/         macOS 应用资源
dist/              可分发安装包
docs/screenshots/  README 截图
```

## 许可证

当前仓库未附加开源许可证。提交到 GitHub 前，如果希望允许他人使用、修改和分发，请补充合适的 `LICENSE` 文件。
