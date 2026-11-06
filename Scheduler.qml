pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

Item {
  id: root
  property var config: Model.defaults()
  property bool ready: false
  property string errorKey: ""
  property string errorDetail: ""
  property string activeProfile: ""
  property date now: new Date()
  readonly property string desiredProfile: Model.target(config, now)
  readonly property string nextTime: Model.nextTime(config, now)
  readonly property bool busy: readProcess.running || setProcess.running
  readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
  property var pendingConfig: null
  property bool enforceAfterRead: true
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/nightshift.json"

  function fail(key, detail) {
    errorKey = key
    errorDetail = detail || ""
  }

  function load(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!Model.valid(parsed)) throw new Error("Invalid schedule")
      config = parsed
      errorKey = ""
      errorDetail = ""
    } catch (error) {
      config = Model.defaults()
      fail("invalidConfig", String(error))
    }
    ready = true
    refresh()
  }

  function save(next) {
    if (!ready || pendingConfig) return false
    if (!Model.valid(next)) { fail("invalidSchedule"); return false }
    if (next.enabled && !hasPerformance && (next.dayProfile === "performance" || next.nightProfile === "performance")) {
      fail("unavailableProfile"); return false
    }
    pendingConfig = Object.assign({}, next)
    configFile.setText(JSON.stringify(pendingConfig, null, 2) + "\n")
    return true
  }

  function refresh(applySchedule) {
    now = new Date()
    if (ready && !busy) {
      enforceAfterRead = applySchedule !== false
      readProcess.running = true
    }
  }

  function enforce() {
    now = new Date()
    if (!config.enabled || errorKey === "invalidConfig") return
    var profile = Model.target(config, now)
    if (profile === "performance" && !hasPerformance) { fail("unavailableProfile"); return }
    if (activeProfile === profile) { errorKey = ""; errorDetail = ""; return }
    setProcess.command = ["busctl", "--timeout=5", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", profile]
    setProcess.running = true
  }

  FileView {
    id: configFile
    path: root.configPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: {
      root.ready = true
      root.fail("loadFailed", String(error))
      root.refresh()
    }
    onSaved: {
      if (!root.pendingConfig) return
      root.config = root.pendingConfig
      root.pendingConfig = null
      root.errorKey = ""
      root.errorDetail = ""
      root.refresh()
    }
    onSaveFailed: {
      root.pendingConfig = null
      root.fail("saveFailed", String(error))
    }
  }

  Process {
    id: readProcess
    command: ["busctl", "--timeout=5", "--json=short", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
    stdout: StdioCollector { id: readOutput; waitForEnd: true }
    stderr: StdioCollector { id: readError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.fail("readFailed", readError.text.trim()); return }
      try {
        var profile = JSON.parse(readOutput.text).data
        if (typeof profile !== "string" || !Model.isProfile(profile)) throw new Error("Invalid profile response")
        root.activeProfile = profile
        if (root.enforceAfterRead) Qt.callLater(root.enforce)
      } catch (error) { root.fail("readFailed", String(error)) }
    }
  }

  Process {
    id: setProcess
    stderr: StdioCollector { id: setError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.fail("applyFailed", setError.text.trim()); return }
      root.errorKey = ""
      root.errorDetail = ""
      // Read back once, without fighting a daemon-level profile hold in a loop.
      Qt.callLater(function() { root.refresh(false) })
    }
  }

  Connections {
    target: PowerProfiles
    function onProfileChanged() {
      switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: root.activeProfile = "power-saver"; break
        case PowerProfile.Balanced: root.activeProfile = "balanced"; break
        case PowerProfile.Performance: root.activeProfile = "performance"; break
      }
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.ready && root.config.enabled
    onTriggered: root.refresh()
  }
}
