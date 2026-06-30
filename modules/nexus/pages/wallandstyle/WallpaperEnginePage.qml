pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpaper Engine")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SliderRow {
                first: true
                icon: "volume_up"
                label: qsTr("Volume")
                valueLabel: Math.round(Wallpapers.weVolume * 100) + "%"
                value: Wallpapers.weVolume
                onMoved: v => Wallpapers.weVolume = v
            }

            ToggleRow {
                last: true
                text: qsTr("Mute")
                checked: Wallpapers.weSilent
                onToggled: Wallpapers.weSilent = checked
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: {
                    let walls = Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === "Wallpaper Engine");
                    
                    walls.sort((a, b) => a.name.localeCompare(b.name));
                    while (walls.length < Config.nexus.wallpapersPerRow)
                        walls.push(null);
                    return walls;
                }

                WallItem {
                    required property FileSystemEntry modelData

                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: modelData ? Wallpapers.getThumbnailPath(modelData.path) : ""
                    text: {
                        if (!modelData) return "";
                        let content = CUtils.readFile(modelData.path);
                        try {
                            let json = JSON.parse(content);
                            if (json.title) return json.title;
                        } catch (e) {}
                        return modelData.parentDir.split('/').pop();
                    }
                    onClicked: {
                        Wallpapers.setWallpaper(modelData.path);
                    }
                }
            }
        }
    }
}
