<p align="center">
  <img src="icon.svg" width="96" alt="Shift+Enter 发送">
</p>

# dsh-shift-enter

<p align="left"><b>把 DeepSeek Harness Web 输入框的发送键位换成 Shift+Enter，Enter 只换行。</b></p>

> 一句话：手滑按一下 Enter 不再把半条消息发出去；要发送就按 Shift+Enter。

| 按键 | 行为 |
| --- | --- |
| **Shift+Enter** | 发送消息（繁忙时仍按“繁忙时的发送行为”排队／插话） |
| **Enter** | 在当前草稿中换行 |
| Cmd/Ctrl+Enter | 仍然使用另一种投递方式（排队／插话），不受影响 |
| 输入法组字时的 Enter | 仍然交给输入法确认候选词，不发送、不强制换行 |

改动作用于当前 profile 的每一个会话（含首页输入框），重启后仍然生效。

---

## 目录

- [这是什么](#这是什么)
- [前置](#前置)
- [安装](#安装)
- [验证](#验证)
- [没有 DSH 源码 checkout？](#没有-dsh-源码-checkout)
- [回退](#回退)
- [仓库结构](#仓库结构)
- [实现](#实现)
- [已知限制](#已知限制)
- [许可证](#许可证)

---

## 这是什么

一个 DSH bundle（`package.json` 的 `dsh.bundle` + `dsh.client`），装进 DSH 后：

- 输入框的 keymap 把「发送」挪到 Shift+Enter，Enter 只插入换行；
- 快捷键总览（`Cmd/Ctrl+/`）里的“发送消息 / 换行”两行同步显示交换后的键位；
- 斜杠指令、`@` 引用菜单、附件上传、排队／插话等逻辑都不变。

**它需要一个 DSH 侧的小补丁。** DSH 目前把「Enter 发送 / Shift+Enter 换行」写死在
`@deepseek-ai/dsh-client-ui-conversation` 的输入框 keymap 里，插件无法从外部修改。本仓库的
[`dsh-patch/`](dsh-patch/README.md) 给该包加了一个**实时可切换的发送手势策略**（默认行为不变），
由本插件在 profile 里把它切换为 `shift-enter`。`install.sh` 会一并完成打补丁、重建客户端包和安装插件。

插件检测不到这个 API 时**安全空操作**（不报错、不改键位）——所以只装插件不打补丁，界面不会有任何变化。

## 前置

- DSH **源码 checkout**（本补丁基于 `0.2.2-rc.3`，上游提交 `39163dd30f`），并且已经 `pnpm install`；
- Node ≥ 20、`pnpm`；
- 一个 DSH profile（默认 `web`）；
- Web GUI（桌面端外壳不使用这套输入框键位）。

## 安装

```bash
git clone https://github.com/amonisachicken/dsh-shift-enter.git
cd dsh-shift-enter
./install.sh --dsh ~/devel/deepseek-harness
```

`install.sh` 会：

1. 检查 DSH 源码是否已有该补丁；没有就 `git apply` 并提交一条 `local: switchable composer send gesture`；
2. 重建 `@deepseek-ai/dsh-client-ui-conversation` 的客户端产物（`tsc -b` + `pnpm --filter … run bundle`）；
3. 把本仓库写进 `$DSH_HOME/profiles/<profile>/package.json` 的依赖和 `dsh.profile.bundles`，跑 `pnpm install`。

| 参数 | 说明 |
| --- | --- |
| `--dsh <path>` | DSH 源码 checkout。省略时依次尝试 `$DSH_CHECKOUT`、`$DSH_INSTALL_DIR` 的上级目录、`~/devel/deepseek-harness` |
| `--profile <name>` | 目标 profile，默认 `web` |
| `--no-build` | 只打补丁不重建（之后需要自己重建，否则键位不变） |
| `--no-commit` | 打补丁但不提交，改动留在工作区 |
| `--rebuild` | DSH 已有补丁时也重建客户端包（例如上次构建失败后重试） |
| `--copy` | 把仓库复制到 `$DSH_HOME/plugins/dsh-shift-enter` 再链接（适合装完就挪走源码） |
| `--dry-run` | 只打印计划，不改文件 |

重跑是安全的：补丁已存在时跳过，profile 依赖原地更新；需要重建客户端包时加 `--rebuild`。

## 验证

1. 刷新页面（或重启 `dsh web`）；
2. `Cmd/Ctrl+/` 打开快捷键总览：**发送消息**应为 `Shift+Enter`，**换行**应为 `Enter`；
3. 输入两行文字：按 Enter 只会换行，按 Shift+Enter 才发送；
4. 用中文输入法组字时按 Enter 只确认候选词，不会发送；
5. 想回退随时执行 `./uninstall.sh`。

## 没有 DSH 源码 checkout？

从 npm 安装的 `dsh` 改不了 `ui-conversation` 的 keymap，因此键位不会改变（插件会安全空操作）。
两条路：

- 用源码 checkout 安装（推荐，见上）；
- 等上游接受这个 API（补丁默认行为不变，适合上游化）。

## 回退

```bash
./uninstall.sh                                             # 只移除插件，刷新后立即恢复 Enter 发送
./uninstall.sh --dsh ~/devel/deepseek-harness --revert-patch   # 连 DSH 补丁一起回退并重建
```

## 仓库结构

```text
dsh-shift-enter/
├── package.json                # bundle 清单（dsh.bundle + dsh.client）
├── cordis.patch.yml            # 插入插件行
├── index.js                    # Host 半边（空实现）
├── client.js                   # Client 半边：把发送手势切到 shift-enter
├── locale/{zh,en}.json         # 插件管理里的标题/描述
├── icon.svg
├── docs/DETAIL.md              # 插件详情页
├── dsh-patch/                  # DSH 源码补丁 + 手动应用说明
├── install.sh                  # 打补丁 → 重建 → 装进 profile
├── uninstall.sh                # 移除插件（可选回退补丁）
└── test/plugin.test.mjs        # 清单与 Client 模块的冒烟测试（node --test）
```

## 实现

`dsh-patch/` 在 `@deepseek-ai/dsh-client-ui-conversation` 里新增：

- `ComposerSendGesture = 'enter' | 'shift-enter'` 与 `uiConversation.composerSendGesture` / `setComposerSendGesture()`；
- 输入框 keymap 按策略决定哪个 Enter 手势提交，另一个交回 Lexical 插入换行；`Ctrl/Cmd+Enter`
  仍是加速投递；输入法组字时提交手势被吞掉（交给输入法），换行手势保持原有行为；
- 快捷键总览的“发送消息 / 换行”两行订阅策略，随切换实时更新。

默认策略是 `enter`，所以补丁本身不改变任何人的使用习惯；只有本插件会把它切成 `shift-enter`。
禁用插件时 Client 半边会把策略还原为 `enter`。

## 已知限制

- 只改消息输入框；排队消息的行内编辑、目标栏、问答面板、终端等控件保留各自原有的 Enter 行为。
- 补丁针对 DSH `0.2.2-rc.3` 的源码；DSH 升级后补丁可能冲突，`install.sh` 会直接报错而不是写坏源码。
- 一个 profile 内只应安装一个键位插件；同时启用多个会互相覆盖策略（后加载者生效）。

## 许可证

[GPL-3.0-or-later](LICENSE)。
