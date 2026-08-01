import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string listCommand: "/usr/bin/kernel_reboot --list"
    property var entries: []
    property string errorText: ""

    function refresh() {
        errorText = "";
        executable.connectSource(listCommand);
    }

    function reboot(index) {
        const command = "/usr/bin/pkexec /usr/bin/kernel_reboot --boot " + index;
        executable.connectSource(command);
        root.expanded = false;
    }

    Plasmoid.icon: "system-reboot"
    toolTipMainText: i18n("GRUB Reboot")
    toolTipSubText: i18n("Select the next boot entry")

    onExpandedChanged: function() {
        if (root.expanded)
            refresh();
    }

    compactRepresentation: PlasmaComponents3.ToolButton {
        icon.name: "system-reboot"
        onClicked: root.expanded = !root.expanded

        PlasmaComponents3.ToolTip {
            text: i18n("GRUB Reboot")
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            contentItem: RowLayout {
                PlasmaComponents3.Label {
                    text: i18n("Select a GRUB entry")
                    font.bold: true
                    Layout.fillWidth: true
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refresh()

                    PlasmaComponents3.ToolTip {
                        text: i18n("Refresh")
                    }
                }
            }
        }

        PlasmaComponents3.ScrollView {
            anchors.fill: parent

            contentItem: ListView {
                id: entryView
                clip: true
                model: root.entries

                delegate: PlasmaComponents3.ItemDelegate {
                    required property var modelData

                    width: ListView.view.width
                    text: modelData.title
                    icon.name: modelData.depth > 0 ? "arrow-right" : "drive-harddisk-root"
                    leftPadding: Kirigami.Units.largeSpacing
                        + modelData.depth * Kirigami.Units.gridUnit
                    onClicked: root.reboot(modelData.index)

                    PlasmaComponents3.ToolTip {
                        text: modelData.target
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: entryView.count === 0
                    iconName: root.errorText ? "dialog-error" : "view-refresh"
                    text: root.errorText || i18n("Loading GRUB entries…")
                }
            }
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            if (sourceName !== root.listCommand) {
                if (data.stderr)
                    root.errorText = data.stderr.trim();
                return;
            }

            try {
                root.entries = JSON.parse(data.stdout || "[]");
                root.errorText = "";
            } catch (error) {
                root.entries = [];
                root.errorText = data.stderr || i18n("Cannot parse GRUB entries");
            }
        }
    }

    Component.onCompleted: refresh()
}
