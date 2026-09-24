import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "antigravity.tokens"
  ipcTarget: "antigravity.tokens"
  manageIpc: true

  property var statsData: null
  property string serverUrl: "http://192.168.32.90:9587/stats"

  property bool isBusy: statsData && statsData.is_busy === true
  property real weeklyRemainingPct: statsData && statsData.weekly_remaining_pct !== undefined ? statsData.weekly_remaining_pct : 98.0
  property real fiveHourRemainingPct: statsData && statsData.five_hour_remaining_pct !== undefined ? statsData.five_hour_remaining_pct : 81.0

  property real claudeBalanceGbp: statsData && statsData.claude_balance_gbp !== undefined ? statsData.claude_balance_gbp : 13.82
  property real claudeSpendTodayGbp: statsData && statsData.claude_spend_today_gbp !== undefined ? statsData.claude_spend_today_gbp : 0.0
  property bool claudeNeedsTopup: statsData && statsData.claude_needs_topup === true

  readonly property bool isFiveHourLower: fiveHourRemainingPct <= weeklyRemainingPct
  readonly property real lowestPct: isFiveHourLower ? fiveHourRemainingPct : weeklyRemainingPct
  readonly property string lowestTag: isFiveHourLower ? "(5)" : "(7)"

  property string weeklyRefreshText: statsData && statsData.weekly_refresh_time ? "Refreshes in " + statsData.weekly_refresh_time : "Calculating..."
  property string fiveHourRefreshText: statsData && statsData.five_hour_refresh_time ? "Refreshes in " + statsData.five_hour_refresh_time : "Calculating..."

  readonly property color accentGreen: "#70c040"
  readonly property color accentBlue: "#59bfff"
  readonly property color accentOrange: "#ff9433"
  readonly property color accentRed: "#ff4d4d"
  readonly property color statusColor: isBusy ? accentGreen : accentBlue

  function getCardColor(pct) {
    if (pct > 50) return accentGreen
    if (pct > 20) return accentOrange
    return accentRed
  }

  function refresh() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", root.serverUrl)
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
        try {
          root.statsData = JSON.parse(xhr.responseText)
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
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Top Bar Slot: Tag font size matching exactly with percentage font size (Style.font.body)
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.isBusy ? "⚡️ " : "🟢 ") + root.lowestPct.toFixed(0) + "%      "
    slotSize: Style.bar.iconSlot * 2.8
    tooltipText: "Gemini Quota Tracker\n5h: " + root.fiveHourRemainingPct.toFixed(0) + "%\n7d: " + root.weeklyRemainingPct.toFixed(0) + "%\nShowing lowest: " + root.lowestTag
    onPressed: root.toggle()

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: root.lowestTag
      color: "#70c040"
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: button.fontSize
      font.bold: true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened

    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      // Header Bar matching Mac
      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: 14
          height: 14
          Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: root.statusColor

            Rectangle {
              anchors.fill: parent
              radius: 5
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.75) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                GradientStop { position: 1.0; color: "transparent" }
              }
            }

            SequentialAnimation on opacity {
              running: root.isBusy
              loops: Animation.Infinite
              NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
              NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
          }
        }

        Text {
          text: "Gemini Quota Tracker"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // Card 1: Five Hour Limit Remaining
      LiquidCard {
        width: parent.width
        title: "Five Hour Limit Remaining"
        countdownText: root.fiveHourRefreshText
        percentage: root.fiveHourRemainingPct
        cardColor: root.getCardColor(root.fiveHourRemainingPct)
        isLowest: root.isFiveHourLower
        limitTag: "(5)"
      }

      // Card 2: Weekly Limit Remaining
      LiquidCard {
        width: parent.width
        title: "Weekly Limit Remaining"
        countdownText: root.weeklyRefreshText
        percentage: root.weeklyRemainingPct
        cardColor: root.getCardColor(root.weeklyRemainingPct)
        isLowest: !root.isFiveHourLower
        limitTag: "(7)"
      }

      // Claude Reviewer Balance Bar
      Rectangle {
        width: parent.width
        implicitHeight: Style.space(34)
        radius: Style.space(8)
        color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)
        border.color: root.claudeNeedsTopup ? root.accentRed : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)

          Text {
            text: "Claude Reviewer"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            visible: root.claudeNeedsTopup
            width: topupText.implicitWidth + 8
            height: 16
            radius: 4
            color: Qt.rgba(root.accentRed.r, root.accentRed.g, root.accentRed.b, 0.25)
            Layout.alignment: Qt.AlignVCenter

            Text {
              id: topupText
              anchors.centerIn: parent
              text: "TOP-UP"
              color: root.accentRed
              font.family: root.bar.fontFamily
              font.pixelSize: 9
              font.bold: true
            }
          }

          Text {
            text: "£" + root.claudeBalanceGbp.toFixed(2)
            color: root.claudeNeedsTopup ? root.accentRed : root.accentGreen
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: "(Today: £" + root.claudeSpendTodayGbp.toFixed(2) + ")"
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.6)
            font.family: root.bar.fontFamily
            font.pixelSize: 10
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }
  }

  // Liquid Glass Card Component with High-Contrast Typography
  component LiquidCard: Rectangle {
    property string title: ""
    property string countdownText: ""
    property real percentage: 100
    property color cardColor: root.accentGreen
    property bool isLowest: false
    property string limitTag: ""

    implicitHeight: Style.space(72)
    radius: Style.space(12)
    color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
    border.color: isLowest ? cardColor : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16)
    border.width: isLowest ? 1.5 : 1

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(6)

      RowLayout {
        width: parent.width
        ColumnLayout {
          spacing: Style.space(2)
          RowLayout {
            spacing: 6
            Text {
              text: title
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Text {
              text: limitTag
              color: cardColor
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
          Text {
            text: countdownText
            color: "#99a3b5"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
        Item { Layout.fillWidth: true }
        Text {
          text: percentage.toFixed(0) + "%"
          color: cardColor
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // Progress bar tube
      Rectangle {
        width: parent.width
        height: Style.space(8)
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 0.5

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: parent.radius
          color: cardColor
          width: Math.max(parent.height, parent.width * (percentage / 100.0))

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Style.space(3)
            radius: height / 2
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
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
