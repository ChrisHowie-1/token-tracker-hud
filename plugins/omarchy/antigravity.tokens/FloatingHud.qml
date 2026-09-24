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

  implicitWidth: 360
  implicitHeight: isCompact ? 165 : 315

  color: "transparent"

  property var statsData: null
  property string serverUrl: "http://192.168.32.90:9587/stats"
  property bool isCompact: false
  property bool isLockedOrScreensaver: false

  property real claudeBalanceGbp: statsData && statsData.claude_balance_gbp !== undefined ? statsData.claude_balance_gbp : 13.82
  property real claudeSpendTodayGbp: statsData && statsData.claude_spend_today_gbp !== undefined ? statsData.claude_spend_today_gbp : 0.0
  property bool claudeNeedsTopup: statsData && statsData.claude_needs_topup === true

  // Status indicator dot
  property bool isBusy: statsData && statsData.is_busy === true
  readonly property color accentGreen: "#38e073"
  readonly property color accentBlue: "#59bfff"
  readonly property color accentOrange: "#ff9433"
  readonly property color accentRed: "#ff4d4d"

  readonly property color statusColor: isBusy ? accentGreen : accentBlue

  // Exact data fields matching Mac HUD
  property real weeklyRemainingPct: statsData && statsData.weekly_remaining_pct !== undefined ? statsData.weekly_remaining_pct : 98.0
  property real fiveHourRemainingPct: statsData && statsData.five_hour_remaining_pct !== undefined ? statsData.five_hour_remaining_pct : 99.0

  property string weeklyRefreshText: statsData && statsData.weekly_refresh_time ? "Refreshes in " + statsData.weekly_refresh_time : "Calculating..."
  property string fiveHourRefreshText: statsData && statsData.five_hour_refresh_time ? "Refreshes in " + statsData.five_hour_refresh_time : "Calculating..."

  function refresh() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", hud.serverUrl)
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
        try {
          hud.statsData = JSON.parse(xhr.responseText)
        } catch(e) {}
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

  // Monitor screensaver process to automatically hide when active
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
    if (pct > 50) return accentGreen
    if (pct > 20) return accentOrange
    return accentRed
  }

  // --- Liquid Glass Outer Container ---
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
      anchors.margins: 16
      spacing: 12

      // --- Header Bar ---
      RowLayout {
        width: parent.width
        spacing: 10

        // Pulsing Neon Status Dot
        Item {
          width: 16
          height: 16
          Rectangle {
            anchors.centerIn: parent
            width: 11
            height: 11
            radius: 5.5
            color: hud.statusColor

            // Specular Reflection
            Rectangle {
              anchors.fill: parent
              radius: 5.5
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.8) }
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
          text: "Gemini Quota Tracker"
          color: Qt.rgba(1, 1, 1, 0.95)
          font.pixelSize: 13
          font.bold: true
          font.family: "sans-serif"
        }

        Item { Layout.fillWidth: true }

        // Compact Mode Toggle Button
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

        // Close Button
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

      // --- Weekly Limit Card ---
      LiquidCard {
        width: parent.width
        title: "Weekly Limit Remaining"
        countdownText: hud.weeklyRefreshText
        percentage: hud.weeklyRemainingPct
        cardColor: hud.getCardColor(hud.weeklyRemainingPct)
      }

      // --- Five Hour Limit Card ---
      LiquidCard {
        width: parent.width
        visible: !hud.isCompact
        title: "Five Hour Limit Remaining"
        countdownText: hud.fiveHourRefreshText
        percentage: hud.fiveHourRemainingPct
        cardColor: hud.getCardColor(hud.fiveHourRemainingPct)
      }

      // --- Claude Reviewer Balance Bar ---
      Rectangle {
        width: parent.width
        visible: !hud.isCompact
        implicitHeight: 34
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: hud.claudeNeedsTopup ? hud.accentRed : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12

          Text {
            text: "Claude Reviewer"
            color: "white"
            font.pixelSize: 11
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            visible: hud.claudeNeedsTopup
            width: topupText.implicitWidth + 8
            height: 16
            radius: 4
            color: Qt.rgba(hud.accentRed.r, hud.accentRed.g, hud.accentRed.b, 0.25)
            Layout.alignment: Qt.AlignVCenter

            Text {
              id: topupText
              anchors.centerIn: parent
              text: "TOP-UP"
              color: hud.accentRed
              font.pixelSize: 9
              font.bold: true
            }
          }

          Text {
            text: "£" + hud.claudeBalanceGbp.toFixed(2)
            color: hud.claudeNeedsTopup ? hud.accentRed : hud.accentGreen
            font.pixelSize: 11
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: "(Today: £" + hud.claudeSpendTodayGbp.toFixed(2) + ")"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 10
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }
  }

  // --- Liquid Glass Card Component ---
  component LiquidCard: Rectangle {
    property string title: ""
    property string countdownText: ""
    property real percentage: 100
    property color cardColor: hud.accentGreen

    implicitHeight: 88
    radius: 14
    color: "#b31a1e2b"
    border.color: Qt.rgba(1, 1, 1, 0.16)
    border.width: 1

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      RowLayout {
        width: parent.width
        ColumnLayout {
          spacing: 3
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
            font.pixelSize: 11
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

      // Glowing liquid progress bar
      Rectangle {
        width: parent.width
        height: 9
        radius: 4.5
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 0.5

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: 4.5
          color: cardColor
          width: Math.max(9, parent.width * (percentage / 100.0))

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 3.5
            radius: 2
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
