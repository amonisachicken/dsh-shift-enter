/**
 * Smoke tests for the bundle manifest, the DSH patch, and the Client module.
 * Run with: node --test test/plugin.test.mjs
 */
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')

let loaded
globalThis.window = { __ModuleLoader__: { load: (mod) => { loaded = mod } } }
await import(new URL('../client.js', import.meta.url))

test('package manifest declares the bundle and client faces', () => {
  const pkg = JSON.parse(read('package.json'))
  assert.equal(pkg.name, 'dsh-shift-enter')
  assert.equal(pkg.dsh.bundle.patch, './cordis.patch.yml')
  assert.equal(pkg.dsh.client.platform, 'web')
  assert.deepEqual(pkg.dsh.client.inject, ['@deepseek-ai/dsh-client-ui-conversation'])
  for (const file of ['index.js', 'client.js', 'cordis.patch.yml', 'docs', 'icon.svg']) {
    assert.ok(pkg.files.includes(file), file)
  }
})

test('bundle patch inserts the plugin row', () => {
  const patch = read('cordis.patch.yml')
  assert.match(patch, /id: dsh-shift-enter/)
  assert.match(patch, /name: 'dsh-shift-enter'/)
})

test('locale metadata is complete and points at the detail document', () => {
  for (const locale of ['en', 'zh']) {
    const meta = JSON.parse(read(`locale/${locale}.json`)).meta
    assert.ok(meta.title.length > 0, `${locale}: title`)
    assert.ok(meta.description.length > 0, `${locale}: description`)
    assert.equal(meta.detail, 'docs/DETAIL.md')
    assert.ok(read(meta.detail).length > 0)
  }
})

test('client module switches the gesture and restores it on dispose', () => {
  assert.equal(loaded.id, 'dsh-shift-enter')
  const plugin = loaded.factory()
  assert.deepEqual(plugin.inject, ['uiConversation'])
  const calls = []
  let cleanup
  plugin.apply({
    uiConversation: { setComposerSendGesture: (gesture) => calls.push(gesture) },
    effect: (fn) => { cleanup = fn() },
  })
  assert.deepEqual(calls, ['shift-enter'])
  cleanup()
  assert.deepEqual(calls, ['shift-enter', 'enter'])
})

test('client module stays inert without the DSH policy', () => {
  const plugin = loaded.factory()
  const ctx = { uiConversation: {}, effect: () => { throw new Error('must not run') } }
  assert.doesNotThrow(() => plugin.apply(ctx))
})

test('the DSH patch touches the composer keymap and the policy surface', () => {
  const patch = read('dsh-patch/0001-switchable-composer-send-gesture.patch')
  for (const file of ['send-gesture.ts', 'input/editor/keymap.ts', 'conversation/assembly.ts']) {
    assert.ok(patch.includes(file), file)
  }
  assert.match(patch, /setComposerSendGesture/)
  assert.match(patch, /shift-enter/)
})
