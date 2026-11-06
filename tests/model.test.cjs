const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const model = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Model.js'), 'utf8'), model)
const at = (hour, minute = 0) => new Date(2026, 10, 6, hour, minute)

test('day and night transitions include the starting minute', () => {
  const config = model.defaults()
  assert.equal(model.target(config, at(6, 59)), 'power-saver')
  assert.equal(model.target(config, at(7)), 'balanced')
  assert.equal(model.target(config, at(20, 59)), 'balanced')
  assert.equal(model.target(config, at(21)), 'power-saver')
})

test('midnight stays in the night interval', () => {
  const config = model.defaults()
  assert.equal(model.target(config, at(23, 59)), 'power-saver')
  assert.equal(model.target(config, at(0)), 'power-saver')
  assert.equal(model.nextTime(config, at(0)), '07:00')
})

test('day intervals can cross midnight', () => {
  const config = { ...model.defaults(), dayStart: '22:30', nightStart: '06:15' }
  assert.equal(model.target(config, at(22, 29)), 'power-saver')
  assert.equal(model.target(config, at(22, 30)), 'balanced')
  assert.equal(model.target(config, at(0)), 'balanced')
  assert.equal(model.target(config, at(6, 14)), 'balanced')
  assert.equal(model.target(config, at(6, 15)), 'power-saver')
  assert.equal(model.nextTime(config, at(23)), '06:15')
})

test('invalid and ambiguous schedules are rejected', () => {
  for (const time of ['24:00', '12:60', '7:00', '-1:00', '', null, '<img>']) {
    assert.equal(!!model.valid({ ...model.defaults(), dayStart: time }), false)
  }
  assert.equal(!!model.valid({ ...model.defaults(), nightStart: '07:00' }), false)
  assert.equal(!!model.valid({ ...model.defaults(), dayProfile: 'turbo' }), false)
  assert.equal(!!model.valid({ ...model.defaults(), enabled: 'true' }), false)
})
