# Changelog

## 0.1.0 — 2026-11-24

- 首个版本：Shift+Enter 发送、Enter 换行，Cmd/Ctrl+Enter 与输入法组字行为不变。
- 附带 `dsh-patch/0001-switchable-composer-send-gesture.patch`，给
  `@deepseek-ai/dsh-client-ui-conversation` 增加实时可切换的发送手势策略（默认仍是 Enter 发送）。
- `install.sh` 一条命令完成打补丁、重建客户端包、写入 profile；`uninstall.sh` 可移除插件并回退补丁。
- 插件检测不到策略 API 时安全空操作。
