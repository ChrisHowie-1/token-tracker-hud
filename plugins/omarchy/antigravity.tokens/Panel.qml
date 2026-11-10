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
  property bool inflight: false
  property int consecutiveFailures: 0
  property bool isOffline: consecutiveFailures >= 3 || statsData === null
  property real nowEpoch: Date.now() / 1000.0

  property bool isBusy: !isOffline && statsData && statsData.is_busy === true
  property real weeklyRemainingPct: statsData && statsData.weekly_remaining_pct !== undefined ? statsData.weekly_remaining_pct : 100.0
  property real fiveHourRemainingPct: statsData && statsData.five_hour_remaining_pct !== undefined ? statsData.five_hour_remaining_pct : 100.0
  property bool hasThreeP: statsData !== null && (statsData.three_p_five_hour_remaining_pct !== undefined || statsData.three_p_weekly_remaining_pct !== undefined)
  property real threePFiveHourPct: statsData && statsData.three_p_five_hour_remaining_pct !== undefined ? statsData.three_p_five_hour_remaining_pct : 100.0
  property real threePWeeklyPct: statsData && statsData.three_p_weekly_remaining_pct !== undefined ? statsData.three_p_weekly_remaining_pct : 100.0

  readonly property string lowestKind: {
    var bestKind = "G7"
    var bestVal = weeklyRemainingPct
    if (fiveHourRemainingPct <= bestVal) {
      bestVal = fiveHourRemainingPct
      bestKind = "G5"
    }
    if (hasThreeP) {
      if (threePFiveHourPct < bestVal) {
        bestVal = threePFiveHourPct
        bestKind = "C5"
      }
      if (threePWeeklyPct < bestVal) {
        bestVal = threePWeeklyPct
        bestKind = "C7"
      }
    }
    return bestKind
  }

  readonly property real lowestPct: {
    if (lowestKind === "G5") return fiveHourRemainingPct
    if (lowestKind === "C5") return threePFiveHourPct
    if (lowestKind === "C7") return threePWeeklyPct
    return weeklyRemainingPct
  }

  readonly property string lowestTag: "(" + lowestKind + ")"

  function format5h(resetTs, fallbackStr) {
    if (resetTs && resetTs > root.nowEpoch) {
      var rem = resetTs - root.nowEpoch
      var hrs = Math.floor(rem / 3600)
      var mins = Math.floor((rem % 3600) / 60)
      return hrs + "h " + mins + "m"
    }
    return fallbackStr ? fallbackStr : "Ready"
  }

  function formatWeekly(resetTs, fallbackStr) {
    if (resetTs && resetTs > root.nowEpoch) {
      var rem = resetTs - root.nowEpoch
      var days = Math.floor(rem / 86400)
      var hrs = Math.round((rem % 86400) / 3600)
      return days + "d " + hrs + "h"
    }
    return fallbackStr ? fallbackStr : "Ready"
  }

  function formatCompactTokens(num) {
    if (!num) return "0"
    if (num >= 1000000) return (num / 1000000.0).toFixed(1) + "M"
    if (num >= 1000) return Math.round(num / 1000.0) + "k"
    return "" + num
  }

  property string weeklyRefreshText: "Refreshes in " + formatWeekly(statsData ? statsData.weekly_reset_timestamp : 0, statsData ? statsData.weekly_refresh_time : "Calculating...")
  property string fiveHourRefreshText: "Refreshes in " + format5h(statsData ? statsData.five_hour_reset_timestamp : 0, statsData ? statsData.five_hour_refresh_time : "Calculating...")
  property string threeP5hText: format5h(statsData ? statsData.three_p_five_hour_reset_timestamp : 0, statsData ? statsData.three_p_five_hour_refresh_time : "Ready")
  property string threeP7dText: formatWeekly(statsData ? statsData.three_p_weekly_reset_timestamp : 0, statsData ? statsData.three_p_weekly_refresh_time : "Ready")

  property string m3SummaryText: {
    if (!statsData) return "Waiting for Mac Studio..."
    var gbp = Math.max(statsData.total_context_savings_gbp || 0, statsData.total_savings_gbp || 0)
    var tok = formatCompactTokens(statsData.total_free_tokens || 0)
    var spd = statsData.last_speed_tok_s ? Math.round(statsData.last_speed_tok_s) + " tok/s" : (statsData.last_engine || "oMLX")
    return "£" + gbp.toFixed(2) + " saved · " + tok + " tok · " + spd
  }

  readonly property color accentGreen: "#70c040"
  readonly property color accentBlue: "#59bfff"
  readonly property color accentOrange: "#ff9433"
  readonly property color accentRed: "#ff4d4d"
  readonly property color accentMuted: "#8d96a8"
  readonly property color statusColor: isOffline ? accentMuted : (isBusy ? accentGreen : accentBlue)

  function getCardColor(pct) {
    if (pct >= 50) return accentGreen
    if (pct >= 20) return accentOrange
    return accentRed
  }

  function refresh() {
    root.nowEpoch = Date.now() / 1000.0
    if (root.inflight) return
    root.inflight = true

    var xhr = new XMLHttpRequest()
    xhr.open("GET", root.serverUrl)
    xhr.timeout = 2200
    xhr.ontimeout = function() {
      root.inflight = false
      root.consecutiveFailures += 1
    }
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        root.inflight = false
        if (xhr.status === 200) {
          try {
            root.statsData = JSON.parse(xhr.responseText)
            root.consecutiveFailures = 0
            return
          } catch(e) {}
        }
        root.consecutiveFailures += 1
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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.isOffline ? "⚪️ " : (root.isBusy ? "⚡️ " : "🟢 ")) + (statsData ? root.lowestPct.toFixed(0) + "%" : "--%") + "        "
    slotSize: Style.bar.iconSlot * 3.15
    tooltipText: {
      var lines = [
        root.isOffline ? "AI Quota Tracker (Offline)" : "AI Quota Tracker (Live Sync)",
        "Gemini — 5h: " + root.fiveHourRemainingPct.toFixed(0) + "% | 7d: " + root.weeklyRemainingPct.toFixed(0) + "%"
      ]
      if (root.hasThreeP) {
        lines.push("Claude/GPT — 5h: " + root.threePFiveHourPct.toFixed(0) + "% | 7d: " + root.threePWeeklyPct.toFixed(0) + "%")
      }
      lines.push("M3 Ultra — " + root.m3SummaryText)
      return lines.join("\n")
    }
    onPressed: root.toggle()

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: root.lowestTag
      color: root.isOffline ? root.accentMuted : root.getCardColor(root.lowestPct)
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

    contentWidth: panel.fittedContentWidth(Style.space(336))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(10)

      // Header Bar
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
          text: root.isOffline ? "AI Quota Tracker (Offline)" : "AI Quota Tracker"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // Card 1: Gemini Weekly (Top, matching macOS)
      LiquidCard {
        width: parent.width
        title: "Gemini Weekly"
        countdownText: root.weeklyRefreshText
        percentage: root.weeklyRemainingPct
        cardColor: root.getCardColor(root.weeklyRemainingPct)
        isLowest: root.lowestKind === "G7"
        limitTag: "(G7)"
      }

      // Card 2: Gemini 5-Hour
      LiquidCard {
        width: parent.width
        title: "Gemini 5-Hour"
        countdownText: root.fiveHourRefreshText
        percentage: root.fiveHourRemainingPct
        cardColor: root.getCardColor(root.fiveHourRemainingPct)
        isLowest: root.lowestKind === "G5"
        limitTag: "(G5)"
      }

      // Card 3: Claude & GPT Dual-Pool Row
      Rectangle {
        width: parent.width
        visible: root.hasThreeP
        implicitHeight: Style.space(66)
        radius: Style.space(12)
        color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
        border.color: (root.lowestKind === "C5" || root.lowestKind === "C7")
          ? root.getCardColor(Math.min(root.threePFiveHourPct, root.threePWeeklyPct))
          : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16)
        border.width: (root.lowestKind === "C5" || root.lowestKind === "C7") ? 1.5 : 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          MiniPoolCell {
            Layout.fillWidth: true
            label: "Claude/GPT 5h"
            tag: "(C5)"
            countdown: root.threeP5hText
            percentage: root.threePFiveHourPct
            cellColor: root.getCardColor(root.threePFiveHourPct)
          }

          Rectangle {
            width: 1
            Layout.fillHeight: true
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.14)
          }

          MiniPoolCell {
            Layout.fillWidth: true
            label: "Claude/GPT 7d"
            tag: "(C7)"
            countdown: root.threeP7dText
            percentage: root.threePWeeklyPct
            cellColor: root.getCardColor(root.threePWeeklyPct)
          }
        }
      }

      // Footer Strip: M3 Ultra Savings & Throughput
      Rectangle {
        width: parent.width
        implicitHeight: Style.space(30)
        radius: Style.space(9)
        color: root.isBusy ? Qt.rgba(0.44, 0.75, 0.25, 0.16) : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)
        border.color: root.isBusy ? root.accentGreen : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.14)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(6)

          Text {
            text: root.isBusy ? "⚡️ M3 Ultra Active" : "🖥 M3 Ultra"
            color: root.isBusy ? root.accentGreen : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.m3SummaryText
            color: root.isBusy ? root.accentGreen : root.accentBlue
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }
    }
  }

  component MiniPoolCell: Column {
    property string label: ""
    property string tag: ""
    property string countdown: ""
    property real percentage: 100
    property color cellColor: root.accentGreen
    spacing: Style.space(4)

    RowLayout {
      width: parent.width
      Text {
        text: label
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Item { Layout.fillWidth: true }
      Text {
        text: percentage.toFixed(0) + "%"
        color: cellColor
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    Text {
      text: tag + " · " + countdown
      color: "#99a3b5"
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption - 1
      font.bold: true
    }

    Rectangle {
      width: parent.width
      height: Style.space(6)
      radius: height / 2
      color: Qt.rgba(0, 0, 0, 0.45)

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: parent.radius
        color: cellColor
        width: Math.max(parent.height, parent.width * Math.min(1.0, Math.max(0.0, percentage) / 100.0))

        Behavior on width {
          NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  component LiquidCard: Rectangle {
    property string title: ""
    property string countdownText: ""
    property real percentage: 100
    property color cardColor: root.accentGreen
    property bool isLowest: false
    property string limitTag: ""

    implicitHeight: Style.space(70)
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
          width: Math.max(parent.height, parent.width * Math.min(1.0, Math.max(0.0, percentage) / 100.0))

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
