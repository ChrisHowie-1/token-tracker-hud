import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: hud
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "antigravity-hud"

  anchors {
    top: true
    right: true
  }

  margins {
    top: 56
    right: 28
  }

  property var statsData: null
  property string serverUrl: "http://192.168.32.90:9587/stats"
  property bool isCompact: false
  property bool isLockedOrScreensaver: false
  property bool inflight: false
  property int consecutiveFailures: 0
  property bool isOffline: consecutiveFailures >= 3 || statsData === null
  property real nowEpoch: Date.now() / 1000.0

  property bool hasThreeP: statsData !== null && (statsData.three_p_five_hour_remaining_pct !== undefined || statsData.three_p_weekly_remaining_pct !== undefined)
  property bool threeP5hDisabled: statsData !== null && statsData.three_p_five_hour_disabled === true
  property bool isStaleRpc: !isOffline && statsData && statsData.official_sync_status === "STALE_RPC"
  implicitWidth: 360
  implicitHeight: isCompact ? 186 : (hasThreeP ? 384 : 292)

  color: "transparent"

  property bool isBusy: !isOffline && statsData && statsData.is_busy === true
  readonly property color accentGreen: "#38e073"
  readonly property color accentBlue: "#59bfff"
  readonly property color accentOrange: "#ff9433"
  readonly property color accentRed: "#ff4d4d"
  readonly property color accentMuted: "#8d96a8"

  readonly property color statusColor: isOffline ? accentMuted : (isBusy ? accentGreen : (isStaleRpc ? accentOrange : accentBlue))

  property real weeklyRemainingPct: statsData && statsData.weekly_remaining_pct !== undefined ? statsData.weekly_remaining_pct : 100.0
  property real fiveHourRemainingPct: statsData && statsData.five_hour_remaining_pct !== undefined ? statsData.five_hour_remaining_pct : 100.0
  property real threePFiveHourPct: statsData && statsData.three_p_five_hour_remaining_pct !== undefined ? statsData.three_p_five_hour_remaining_pct : 100.0
  property real threePWeeklyPct: statsData && statsData.three_p_weekly_remaining_pct !== undefined ? statsData.three_p_weekly_remaining_pct : 100.0

  function format5h(resetTs, fallbackStr) {
    if (resetTs && resetTs > hud.nowEpoch) {
      var rem = resetTs - hud.nowEpoch
      return Math.floor(rem / 3600) + "h " + Math.floor((rem % 3600) / 60) + "m"
    }
    return (fallbackStr && ("" + fallbackStr).trim().length > 0) ? fallbackStr : "Ready"
  }

  function formatWeekly(resetTs, fallbackStr) {
    if (resetTs && resetTs > hud.nowEpoch) {
      var rem = resetTs - hud.nowEpoch
      return Math.floor(rem / 86400) + "d " + Math.round((rem % 86400) / 3600) + "h"
    }
    return (fallbackStr && ("" + fallbackStr).trim().length > 0) ? fallbackStr : "Ready"
  }

  function formatCompactTokens(num) {
    if (!num) return "0"
    if (num >= 1000000) return (num / 1000000.0).toFixed(1) + "M"
    if (num >= 1000) return Math.round(num / 1000.0) + "k"
    return "" + num
  }

  property string weeklyRefreshText: "Refreshes in " + formatWeekly(statsData ? statsData.weekly_reset_timestamp : 0, statsData ? statsData.weekly_refresh_time : "Calculating...")
  property string fiveHourRefreshText: "Refreshes in " + format5h(statsData ? statsData.five_hour_reset_timestamp : 0, statsData ? statsData.five_hour_refresh_time : "Calculating...")
  property string threeP5hText: threeP5hDisabled ? "Weekly hit" : format5h(statsData ? statsData.three_p_five_hour_reset_timestamp : 0, statsData ? statsData.three_p_five_hour_refresh_time : "Ready")
  property string threeP7dText: formatWeekly(statsData ? statsData.three_p_weekly_reset_timestamp : 0, statsData ? statsData.three_p_weekly_refresh_time : "Ready")

  property string m3SummaryText: {
    if (!statsData) return "Waiting for Mac Studio..."
    var gbp = Math.max(statsData.total_context_savings_gbp || 0, statsData.total_savings_gbp || 0)
    var tok = formatCompactTokens(statsData.total_free_tokens || 0)
    var spd = statsData.last_speed_tok_s ? Math.round(statsData.last_speed_tok_s) + "/s" : (statsData.last_engine || "oMLX")
    return "£" + gbp.toFixed(2) + " · " + tok + " · " + spd
  }

  function refresh() {
    hud.nowEpoch = Date.now() / 1000.0
    if (hud.inflight) return
    hud.inflight = true

    var xhr = new XMLHttpRequest()
    xhr.open("GET", hud.serverUrl)
    xhr.timeout = 2200
    xhr.ontimeout = function() {
      hud.inflight = false
      hud.consecutiveFailures += 1
    }
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        hud.inflight = false
        if (xhr.status === 200) {
          try {
            hud.statsData = JSON.parse(xhr.responseText)
            hud.consecutiveFailures = 0
            return
          } catch(e) {}
        }
        hud.consecutiveFailures += 1
      }
    }
    xhr.send()
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: hud.refresh()
  }

  Process {
    id: screensaverCheck
    command: ["pgrep", "-f", "org.omarchy.screensaver"]
    stdout: StdioCollector {
      onTextChanged: {
        hud.isLockedOrScreensaver = (text && text.trim().length > 0)
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      screensaverCheck.running = true
    }
  }

  function getCardColor(pct) {
    if (pct >= 50) return accentGreen
    if (pct >= 20) return accentOrange
    return accentRed
  }

  Rectangle {
    anchors.fill: parent
    radius: 18
    color: "#e612151e"
    border.color: Qt.rgba(1, 1, 1, 0.22)
    border.width: 1.5
    visible: !hud.isLockedOrScreensaver

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onClicked: Qt.quit()
    }

    Column {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      RowLayout {
        width: parent.width
        spacing: 10

        Item {
          width: 16
          height: 16
          Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: hud.statusColor

            Rectangle {
              anchors.fill: parent
              radius: 5
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.75) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 1.0; color: "transparent" }
              }
            }

            SequentialAnimation on opacity {
              running: hud.isBusy
              loops: Animation.Infinite
              NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
              NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
          }
        }

        Text {
          text: hud.isOffline ? "AI Quota Tracker (Offline)" : (hud.isStaleRpc ? "AI Quota Tracker (Stale)" : "AI Quota Tracker")
          color: Qt.rgba(1, 1, 1, 0.95)
          font.pixelSize: 13
          font.bold: true
          font.family: "sans-serif"
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 24
          height: 24
          radius: 12
          color: compactArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: hud.isCompact ? "󰅃" : "󰅀"
            color: Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize: 13
          }

          MouseArea {
            id: compactArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hud.isCompact = !hud.isCompact
          }
        }

        Rectangle {
          width: 24
          height: 24
          radius: 12
          color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize: 11
            font.bold: true
          }

          MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
          }
        }
      }

      LiquidCard {
        width: parent.width
        title: "Gemini Weekly (G7)"
        countdownText: hud.weeklyRefreshText
        percentage: hud.weeklyRemainingPct
        cardColor: hud.getCardColor(hud.weeklyRemainingPct)
      }

      LiquidCard {
        width: parent.width
        visible: !hud.isCompact
        title: "Gemini 5-Hour (G5)"
        countdownText: hud.fiveHourRefreshText
        percentage: hud.fiveHourRemainingPct
        cardColor: hud.getCardColor(hud.fiveHourRemainingPct)
      }

      Rectangle {
        width: parent.width
        visible: !hud.isCompact && hud.hasThreeP
        implicitHeight: 82
        radius: 13
        color: "#b31a1e2b"
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          Text {
            text: "Claude & GPT"
            color: "#e0e6f0"
            font.pixelSize: 11
            font.bold: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              RowLayout {
                Layout.fillWidth: true
                Text { text: "5-Hour"; color: hud.threeP5hDisabled ? hud.accentMuted : "#ffffff"; font.pixelSize: 11; font.bold: true }
                Item { Layout.fillWidth: true }
                Text {
                  text: hud.threeP5hDisabled ? "Paused" : (hud.threePFiveHourPct.toFixed(0) + "%")
                  color: hud.threeP5hDisabled ? hud.accentMuted : hud.getCardColor(hud.threePFiveHourPct)
                  font.pixelSize: hud.threeP5hDisabled ? 11 : 13
                  font.bold: true
                }
              }
              Text { text: "(C5) · " + hud.threeP5hText; color: "#99a3b5"; font.pixelSize: 10 }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: Qt.rgba(1, 1, 1, 0.12) }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              RowLayout {
                Layout.fillWidth: true
                Text { text: "Weekly"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: hud.threePWeeklyPct.toFixed(0) + "%"; color: hud.getCardColor(hud.threePWeeklyPct); font.pixelSize: 13; font.bold: true }
              }
              Text { text: "(C7) · " + hud.threeP7dText; color: "#99a3b5"; font.pixelSize: 10 }
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        implicitHeight: 28
        radius: 9
        color: hud.isBusy ? Qt.rgba(0.22, 0.88, 0.45, 0.16) : "#801a1e2b"
        border.color: hud.isBusy ? hud.accentGreen : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          Text {
            text: hud.isBusy ? "⚡️ M3 Ultra" : "🖥 M3 Ultra"
            color: hud.isBusy ? hud.accentGreen : "#e0e6f0"
            font.pixelSize: 11
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: hud.m3SummaryText
            color: hud.isBusy ? hud.accentGreen : hud.accentBlue
            font.pixelSize: 10
            font.bold: true
          }
        }
      }
    }
  }

  component LiquidCard: Rectangle {
    property string title: ""
    property string countdownText: ""
    property real percentage: 100
    property color cardColor: hud.accentGreen

    implicitHeight: 80
    radius: 14
    color: "#b31a1e2b"
    border.color: Qt.rgba(1, 1, 1, 0.16)
    border.width: 1

    Column {
      anchors.fill: parent
      anchors.margins: 11
      spacing: 7

      RowLayout {
        width: parent.width
        ColumnLayout {
          spacing: 2
          Text {
            text: title
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            font.family: "sans-serif"
          }
          Text {
            text: countdownText
            color: "#99a3b5"
            font.pixelSize: 10.5
            font.family: "sans-serif"
          }
        }
        Item { Layout.fillWidth: true }
        Text {
          text: percentage.toFixed(0) + "%"
          color: cardColor
          font.pixelSize: 17
          font.bold: true
          font.family: "sans-serif"
        }
      }

      Rectangle {
        width: parent.width
        height: 8
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 0.5

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: 4
          color: cardColor
          width: Math.max(8, parent.width * Math.min(1.0, Math.max(0.0, percentage) / 100.0))

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 3
            radius: 1.5
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.6) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          Behavior on width {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
