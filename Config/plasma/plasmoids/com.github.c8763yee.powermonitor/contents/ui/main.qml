import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string command: "/bin/sh -c \"$HOME/.local/bin/power-monitor-read\""
    property string cpuPower: "N/A"
    property string gpuPower: "N/A"

    Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        ? fullRepresentationItem?.implicitWidth ?? 0
        : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        ? fullRepresentationItem?.implicitHeight ?? 0
        : 0
    Layout.preferredHeight: Layout.minimumHeight

    function updatePower(rawOutput) {
        try {
            const snapshot = JSON.parse(rawOutput);
            cpuPower = snapshot.cpu ? snapshot.cpu + " W" : "N/A";
            gpuPower = snapshot.gpu ? snapshot.gpu + " W" : "N/A";
        } catch (error) {
            cpuPower = "N/A";
            gpuPower = "N/A";
        }
    }

    function refresh() {
        executable.connectSource(command);
    }

    Plasmoid.icon: "battery-profile"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("CPU/GPU Power Monitor")
    toolTipSubText: i18n("CPU: %1\nGPU: %2", cpuPower, gpuPower)
    preferredRepresentation: fullRepresentation

    fullRepresentation: Item {
        implicitWidth: values.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: values.implicitHeight + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight

        GridLayout {
            id: values
            anchors.centerIn: parent
            columns: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 1 : 2
            rowSpacing: 0
            columnSpacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: i18n("CPU: %1", root.cpuPower)
                textFormat: Text.PlainText
                Layout.alignment: Qt.AlignCenter
            }

            PlasmaComponents3.Label {
                text: i18n("GPU: %1", root.gpuPower)
                textFormat: Text.PlainText
                Layout.alignment: Qt.AlignCenter
            }
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            root.updatePower(data.stdout || "");
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
