/**
 * Client half: move submission to Shift+Enter so a stray Enter only breaks
 * the line. The Conversation plugin owns the live policy; this module sets it
 * for every composer and restores the standard gesture when disabled.
 */
window.__ModuleLoader__.load({
  id: 'dsh-shift-enter',
  factory() {
    return {
      name: 'dsh-shift-enter',
      inject: ['uiConversation'],
      apply(ctx) {
        const conversation = ctx.uiConversation
        // DSH builds without the switchable policy (the dsh-patch in this
        // repository) stay inert instead of failing the client plugin graph.
        if (typeof conversation.setComposerSendGesture !== 'function') return
        ctx.effect(() => {
          conversation.setComposerSendGesture('shift-enter')
          return () => { conversation.setComposerSendGesture('enter') }
        }, 'dsh-shift-enter: Shift+Enter sends, Enter breaks the line')
      },
    }
  },
})
