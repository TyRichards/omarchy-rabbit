import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Rabbit: one-click "always on" mode for the Omarchy bar. Keeps going and going.
// It keeps going and going. Bright = suspend, idle, and lid close are blocked.
// Dim = normal power behavior.
BarWidget {
  id: root
  moduleName: "io.github.tyrichards.rabbit"

  readonly property string script: String(Qt.resolvedUrl("bin/omarchy-rabbit")).replace(/^file:\/\//, "")
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/rabbit"

  property bool enabled: false

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggle() {
    if (toggleProc.running) return
    toggleProc.running = true
  }

  function applyStatus(line) {
    try {
      var data = JSON.parse(line)
      root.enabled = data.enabled === true
    } catch (error) {
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "io.github.tyrichards.rabbit"

    function toggle(): void { root.broadcast("toggle") }
    function refresh(): void { root.broadcast("refresh") }
    function status(): string { return root.enabled ? "on" : "off" }
  }

  Process {
    id: statusProc
    command: ["bash", "-c", root.script + " status"]
    stdout: SplitParser { onRead: function(line) { root.applyStatus(line) } }
  }

  Process {
    id: toggleProc
    command: ["bash", "-c", root.script + " toggle"]
    stdout: SplitParser { onRead: function(line) { root.applyStatus(line) } }
    onExited: function() { root.broadcast("refresh") }
  }

  // Instant updates when the CLI is used outside the bar (keybinding, terminal).
  FileView {
    path: root.stateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰤇"
    fontSize: Style.bar.iconFont * 2
    active: root.enabled
    opacity: root.enabled ? 1 : 0.45
    tooltipText: root.enabled ? "Always on: lid close, suspend, and idle blocked" : "Normal power: click to keep going and going"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.bar) root.bar.run("xdg-terminal-exec -e bash -c 'systemd-inhibit --list; read -n1'")
        return
      }
      root.toggle()
    }

    Behavior on opacity { NumberAnimation { duration: 160 } }
  }
}
