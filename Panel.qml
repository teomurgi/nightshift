import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "."

Ui.Panel {
  id: root
  moduleName: "teomurgi.nightshift"
  ipcTarget: "teomurgi.nightshift"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  property string draftDay: "07:00"
  property string draftNight: "21:00"
  property string draftDayProfile: "balanced"
  property string draftNightProfile: "power-saver"
  property bool saved: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function profileLabel(profile) {
    return strings.t(profile)
  }

  readonly property var profileOptions: {
    var options = [ {value: "balanced", label: strings.t("balanced")}, {value: "power-saver", label: strings.t("power-saver")} ]
    if (Scheduler.hasPerformance) options.push({value: "performance", label: strings.t("performance")})
    return options
  }

  function resetDraft() {
    draftDay = Scheduler.config.dayStart
    draftNight = Scheduler.config.nightStart
    draftDayProfile = Scheduler.config.dayProfile
    draftNightProfile = Scheduler.config.nightProfile
    saved = false
  }

  function saveDraft() {
    saved = Scheduler.save({enabled: Scheduler.config.enabled, dayStart: draftDay, nightStart: draftNight, dayProfile: draftDayProfile, nightProfile: draftNightProfile})
  }

  onOpenedChanged: if (opened) { resetDraft(); Scheduler.refresh() }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      if (!Scheduler.config.enabled) return "⏻"
      switch (Scheduler.activeProfile) {
        case "power-saver": return "󰌪"
        case "balanced": return "󰊚"
        case "performance": return "󰓅"
        default: return "󰥔"
      }
    }
    dimmed: !Scheduler.config.enabled
    // Only catalog-owned text reaches the shell's tooltip renderer.
    tooltipText: strings.t(!Scheduler.config.enabled ? "tooltipDisabled"
      : Scheduler.activeProfile === "power-saver" ? "tooltipSaver"
      : Scheduler.activeProfile === "balanced" ? "tooltipBalanced"
      : Scheduler.activeProfile === "performance" ? "tooltipPerformance" : "tooltipUnknown")
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)
    focusTarget: column

    ColumnLayout {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(12)
      Keys.onEscapePressed: root.close()

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: strings.t("title")
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: strings.t("current").arg(root.profileLabel(Scheduler.activeProfile || "unknown"))
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Ui.Toggle {
        Layout.fillWidth: true
        label: strings.t("enable")
        description: strings.t("enableHint")
        checked: Scheduler.config.enabled
        enabled: Scheduler.ready && !Scheduler.pendingConfig
        onClicked: Scheduler.save(Object.assign({}, Scheduler.config, {enabled: !Scheduler.config.enabled}))
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: strings.t("daytime")
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)
        Ui.TextField {
          id: dayField
          Layout.preferredWidth: Style.space(90)
          text: root.draftDay
          placeholderText: "HH:mm"
          maximumLength: 5
          onTextEdited: { root.draftDay = text; root.saved = false }
          onAccepted: root.saveDraft()
        }
        Ui.Dropdown {
          Layout.fillWidth: true
          showLabel: false
          options: root.profileOptions
          value: root.draftDayProfile
          onChanged: function(value) { root.draftDayProfile = value; root.saved = false }
        }
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: strings.t("nighttime")
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)
        Ui.TextField {
          Layout.preferredWidth: Style.space(90)
          text: root.draftNight
          placeholderText: "HH:mm"
          maximumLength: 5
          onTextEdited: { root.draftNight = text; root.saved = false }
          onAccepted: root.saveDraft()
        }
        Ui.Dropdown {
          Layout.fillWidth: true
          showLabel: false
          options: root.profileOptions
          value: root.draftNightProfile
          onChanged: function(value) { root.draftNightProfile = value; root.saved = false }
        }
      }
      Ui.Button {
        Layout.fillWidth: true
        text: strings.t(root.saved && !Scheduler.pendingConfig && !Scheduler.errorKey ? "saved" : "save")
        focusable: true
        bordered: true
        enabled: Scheduler.ready && !Scheduler.pendingConfig
        onClicked: root.saveDraft()
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: Scheduler.config.enabled
          ? strings.t("next").arg(Scheduler.nextTime).arg(root.profileLabel(Scheduler.desiredProfile))
          : strings.t("disabledHint")
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        Layout.fillWidth: true
        visible: Scheduler.errorKey !== ""
        textFormat: Text.PlainText
        text: strings.t(Scheduler.errorKey) + (Scheduler.errorDetail ? "\n" + Scheduler.errorDetail : "")
        wrapMode: Text.WrapAnywhere
        color: Commons.Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
