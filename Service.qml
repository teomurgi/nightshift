import QtQuick
import "."

Item {
  // The service keeps the single scheduler alive even when the bar icon is hidden.
  readonly property var scheduler: Scheduler
}
