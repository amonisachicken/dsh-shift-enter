# DSH 补丁：可切换的输入框发送手势

`0001-switchable-composer-send-gesture.patch` 修改 `packages/client/ui-conversation`：

- 新增 `ComposerSendGesture`（`enter` | `shift-enter`）类型与实时策略
  `uiConversation.composerSendGesture` / `setComposerSendGesture()`；
- 输入框 keymap 按策略决定哪个 Enter 手势发送、另一个换行；`Ctrl/Cmd+Enter`
  仍然选择另一种投递方式，输入法组字时的 Enter 仍交给输入法；
- 快捷键总览（`Cmd/Ctrl+/`）里的“发送消息 / 换行”两行跟随策略显示。

**默认策略仍是 Enter 发送**，因此补丁本身不改变任何人的使用习惯；只有安装
`dsh-shift-enter` 插件才会切换到 Shift+Enter。

补丁基于 DSH `0.2.2-rc.3`（上游提交 `39163dd30f`）。

## 手动应用

```bash
git -C <dsh-checkout> apply dsh-patch/0001-switchable-composer-send-gesture.patch
cd <dsh-checkout>
node_modules/.bin/tsc -b packages/client/ui-conversation/tsconfig.client.json
pnpm --filter @deepseek-ai/dsh-client-ui-conversation run bundle
```

## 回退

```bash
git -C <dsh-checkout> apply -R dsh-patch/0001-switchable-composer-send-gesture.patch
cd <dsh-checkout>
node_modules/.bin/tsc -b packages/client/ui-conversation/tsconfig.client.json
pnpm --filter @deepseek-ai/dsh-client-ui-conversation run bundle
```

`install.sh` 与 `uninstall.sh --revert-patch` 会自动完成上面两步。

若 `git apply --check` 失败，说明 DSH 源码版本已经变化：补丁需要按同样思路手工移植
（目标文件都在 `packages/client/ui-conversation/src/client/` 下）。
