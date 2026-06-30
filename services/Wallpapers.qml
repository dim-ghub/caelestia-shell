pragma Singleton

import QtQuick
import Quickshell
import QtCore
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    readonly property var categories: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let cats = [];
        for (let i = 0; i < root.list.length; i++) {
            let p = root.list[i].parentDir;
            if (p.includes("steamapps/workshop/content/431960")) {
                let cat = "Wallpaper Engine";
                if (!cats.includes(cat)) cats.push(cat);
                continue;
            }
            if (p !== baseDir) {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!cats.includes(cat)) cats.push(cat);
            }
        }
        return ["Main"].concat(cats.sort());
    }

    readonly property var grouped: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let grp = { "Main": [] };
        for (let i = 0; i < root.list.length; i++) {
            let w = root.list[i];
            let p = w.parentDir;
            if (p.includes("steamapps/workshop/content/431960")) {
                let cat = "Wallpaper Engine";
                if (!grp[cat]) grp[cat] = [];
                grp[cat].push(w);
                continue;
            }
            if (p === baseDir) {
                grp["Main"].push(w);
            } else {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!grp[cat]) grp[cat] = [];
                grp[cat].push(w);
            }
        }
        return grp;
    }

    function getCategoryFor(w: FileSystemEntry): string {
        if (w.parentDir.includes("steamapps/workshop/content/431960")) {
            return "Wallpaper Engine";
        }
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        let targetPath = path;
        let isWE = false;
        let weId = "";
        if (path.endsWith("project.json")) {
            isWE = true;
            let parts = path.split("/");
            weId = parts[parts.length - 2];
            let content = CUtils.readFile(path);
            try {
                let json = JSON.parse(content);
                if (json.preview) {
                    targetPath = path.substring(0, path.length - 12) + json.preview;
                }
            } catch (e) {
                console.warn("Failed to parse project.json:", e);
            }
        }
        actualCurrent = targetPath;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", targetPath, ...smartArg]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    function getThumbnailPath(path: string): string {
        if (path.endsWith("project.json")) {
            let content = CUtils.readFile(path);
            try {
                let json = JSON.parse(content);
                if (json.preview) {
                    return path.substring(0, path.length - 12) + json.preview;
                }
            } catch (e) {
                console.warn("Failed to parse project.json:", e);
            }
            return path;
        }
        if (Images.isVideo(path)) {
            return `${Paths.cache}/wallpapers/${CUtils.sha256(path)}/first_frame.png`;
        }
        return path;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    function updateCombinedList() {
        let arr = [];
        for (let i = 0; i < wallpapers.entries.length; i++) {
            arr.push(wallpapers.entries[i]);
        }
        for (let i = 0; i < weWallpapers.entries.length; i++) {
            arr.push(weWallpapers.entries[i]);
        }
        root.list = arr;
    }

    property alias weVolume: weSettings.volume
    property alias weSilent: weSettings.silent
    
    Settings {
        id: weSettings
        property real volume: 0.15
        property bool silent: false
    }


    FileSystemModel {
        id: wallpapers
        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: Images.validImageExtensions.concat(Images.validVideoExtensions).map(e => `*.${e}`).concat(["project.json"])
        onEntriesChanged: root.updateCombinedList()
    }

    FileSystemModel {
        id: weWallpapers
        recursive: true
        path: Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960"
        filter: FileSystemModel.Files
        nameFilters: ["project.json"]
        onEntriesChanged: root.updateCombinedList()
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
