# CapsLock Bye

**轻点 Caps Lock 发送 Esc，按住变成 Hyper（⌘ ⌃ ⌥ ⇧）。**

[English](../README.md) · [下载](https://github.com/nixihz/capslock-bye/releases/latest) · [问题反馈](https://github.com/nixihz/capslock-bye/issues)

[![CI](https://github.com/nixihz/capslock-bye/actions/workflows/ci.yml/badge.svg)](https://github.com/nixihz/capslock-bye/actions/workflows/ci.yml)

一个轻巧的原生 macOS 菜单栏工具。按键在本机处理，不记录或上传输入内容，无需账号或驱动。

## 功能

- 自定义轻点按键或录制快捷键，自由组合长按修饰键。
- 长按判定默认 180 ms，可自行调整；接其他按键或点击鼠标时立即触发组合。
- 内置试键区、权限引导和可选登录启动。
- 支持简体中文和 English。macOS 26 使用 Liquid Glass，macOS 14–15 使用系统材质。

## 安装

需要 **macOS 14 或更新版本**，支持 Apple Silicon 和 Intel。

1. [下载 DMG](https://github.com/nixihz/capslock-bye/releases/latest/download/CapsLock-Bye-universal-notarized.dmg)。
2. 打开后，将 **CapsLock Bye.app** 拖到 **Applications（应用程序）**，再推出磁盘映像。
3. 启动应用，按引导在 **系统设置 → 隐私与安全性** 中开启 **辅助功能** 和 **输入监控**。
4. 如果 macOS 要求，重新打开应用；开启映射后，通过试键区检查效果。

正式 DMG 已签名并完成 Apple 公证，附有 [SHA-256 校验文件](https://github.com/nixihz/capslock-bye/releases/latest/download/CapsLock-Bye-universal-notarized.dmg.sha256)。下载链接在首次发布后生效；在此之前可按下方说明从源码构建。

## 使用

关闭窗口后，应用继续驻留菜单栏。左击图标重新打开，右击可暂停或退出。在设置中调整轻点快捷键、长按修饰键、判定时间和语言。

请停用其他工具对 Caps Lock 的映射，并在键盘固件和系统设置中保留 Caps Lock 的默认定义。macOS 安全输入启用时（例如部分密码框）暂停映射，退出安全输入后恢复。

## 从源码构建

需要 **Xcode 26 或更新版本**，包含 macOS 26 SDK 和 Swift 6。

```sh
git clone https://github.com/nixihz/capslock-bye.git
cd capslock-bye
./script/build_and_run.sh
```

应用生成于 `dist/CapsLock Bye.app`。开发者证书为可选项，没有证书时使用临时签名；重新构建后，macOS 可能要求重新授予权限。

## 参与贡献

欢迎使用中文或英文提交问题和 Pull Request。开发命令及检查要求见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

GitHub Actions 负责构建和发布 DMG，维护者可参考 [发布指南](releasing.md)。

## 许可证

[MIT](../LICENSE) © 2026 nixihz。
