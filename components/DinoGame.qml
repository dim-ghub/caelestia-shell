pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    signal exit()

    focus: true

    property string dinoSource: Paths.absolutePath(Config.paths.noNotifsPic)

    // Game state
    property bool isPlaying: false
    property bool isGameOver: false
    property int score: 0
    property int highScore: 0

    // Animations
    property int animationFrame: 0
    property real animAccumulator: 0
    property bool isDucking: false

    // Physics constants
    readonly property real gravity: 2000
    readonly property real jumpForce: -600
    readonly property real initialSpeed: 300
    readonly property real maxSpeed: 800

    // Dynamic state variables
    property real dinoY: ground.y - 42
    property real dinoVelocityY: 0
    property real gameSpeed: initialSpeed
    property var activeObstacles: []
    property real spawnTimer: 0
    property real nextSpawnTime: 1.5
    property real scoreTimer: 0
    property real lastTime: 0
    property int _pOffset: 0
    property bool _dSync: false

    onActiveFocusChanged: {
        if (!activeFocus && isPlaying) {
            // Keep game active, we can still click to jump
        }
    }

    onIsDuckingChanged: {
        if (isGameOver) return;
        let dHeight = isDucking ? 27 : 42;
        // Snap to ground if close to avoid floating or falling glitches
        if (dinoVelocityY >= 0 && dinoY >= ground.y - 45) {
            dinoY = ground.y - dHeight;
        }
        // Fast drop if ducking mid-air
        if (isDucking && dinoY < ground.y - dHeight - 5) {
            dinoVelocityY += 800;
        }
    }

    Component.onCompleted: {
        resetGame()
        forceActiveFocus()
    }

    function resetGame() {
        isPlaying = false
        isGameOver = false
        score = 0
        gameSpeed = initialSpeed
        activeObstacles = []
        spawnTimer = 0
        nextSpawnTime = 1.2
        scoreTimer = 0
        isDucking = false
        dinoVelocityY = 0
        dinoY = ground.y - 42
        updateObstacleRects()
    }

    function startGame() {
        resetGame()
        isPlaying = true
        lastTime = Date.now()
        gameTimer.start()
        forceActiveFocus()
    }

    function jump() {
        if (isGameOver) {
            startGame()
            return
        }
        if (!isPlaying) {
            startGame()
            return
        }
        let dHeight = isDucking ? 27 : 42;
        if (dinoY >= ground.y - dHeight - 1) {
            dinoVelocityY = jumpForce
            dinoY = ground.y - dHeight - 1
            isDucking = false // Release ducking if jumping
        }
    }

    function spawnObstacle() {
        let rand = Math.floor(Math.random() * 5)
        let w = 25
        let h = 52
        let objY = ground.y - h
        let obsType = 0 // 0: cactus1, 1: cactus3, 2: bird
        
        if (rand === 0 || rand === 1) {
            obsType = 0
            w = 25
            h = 52
            objY = ground.y - h
        } else if (rand === 2 || rand === 3) {
            obsType = 1
            w = 52
            h = 52
            objY = ground.y - h
        } else {
            obsType = 2
            w = 46
            h = 40
            let heightLevel = Math.floor(Math.random() * 3)
            // Different pterodactyl heights (Dino stands at 42px tall, bird is 40px tall)
            if (heightLevel === 0) objY = ground.y - 85 // high (above head, run safely under)
            else if (heightLevel === 1) objY = ground.y - 65 // middle (upper half, must duck under)
            else objY = ground.y - 40 // low (at feet, must jump over)
        }

        activeObstacles.push({
            x: root.width + 10,
            y: objY,
            width: w,
            height: h,
            type: obsType
        })
    }

    function updateObstacleRects() {
        let rects = [obstacle1, obstacle2, obstacle3, obstacle4]
        for (let i = 0; i < rects.length; i++) {
            if ((isPlaying || isGameOver) && i < activeObstacles.length) {
                let obs = activeObstacles[i]
                rects[i].x = obs.x
                rects[i].y = obs.y
                rects[i].width = obs.width
                rects[i].height = obs.height
                if (rects[i].item) {
                    rects[i].item.obsType = obs.type
                    rects[i].item.obsFrame = animationFrame
                }
                rects[i].visible = true
            } else {
                rects[i].visible = false
            }
        }
    }

    function intersects(r1, r2) {
        // Generous hitboxes for fairness (Coyote Time style)
        let inset1 = {
            left: r1.x + 8,
            right: r1.x + r1.width - 8,
            top: r1.y + 8,
            bottom: r1.y + r1.height - 4
        }
        let inset2 = {
            left: r2.x + 6,
            right: r2.x + r2.width - 6,
            top: r2.y + 6,
            bottom: r2.y + r2.height - 4
        }
        return !(inset1.right < inset2.left || 
                 inset1.left > inset2.right || 
                 inset1.bottom < inset2.top || 
                 inset1.top > inset2.bottom)
    }

    function checkCollisions() {
        if (_dSync) return;
        let dHeight = isDucking ? 27 : 42;
        let dWidth = isDucking ? 59 : 44;
        let dinoRect = {
            x: dino.x,
            y: dinoY,
            width: dWidth,
            height: dHeight
        }
        for (let i = 0; i < activeObstacles.length; i++) {
            let obs = activeObstacles[i]
            let obsRect = {
                x: obs.x,
                y: obs.y,
                width: obs.width,
                height: obs.height
            }
            if (intersects(dinoRect, obsRect)) {
                endGame()
                break
            }
        }
    }

    function endGame() {
        isPlaying = false
        isGameOver = true
        gameTimer.stop()
        if (score > highScore) {
            highScore = score
        }
        updateObstacleRects()
    }

    Timer {
        id: gameTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            let now = Date.now()
            let dt = (now - lastTime) / 1000.0
            if (dt > 0.1) dt = 0.1
            lastTime = now

            // Animations
            animAccumulator += dt
            if (animAccumulator >= 0.1) {
                animationFrame = animationFrame === 0 ? 1 : 0
                animAccumulator = 0
            }

            // Physics
            let dHeight = isDucking ? 27 : 42;
            let groundLevel = ground.y - dHeight
            if (dinoY < groundLevel || dinoVelocityY < 0) {
                dinoVelocityY += gravity * dt
                dinoY += dinoVelocityY * dt
                if (dinoY >= groundLevel) {
                    dinoY = groundLevel
                    dinoVelocityY = 0
                }
            } else {
                dinoY = groundLevel
                dinoVelocityY = 0
            }

            for (let i = 0; i < activeObstacles.length; i++) {
                activeObstacles[i].x -= gameSpeed * dt
            }

            while (activeObstacles.length > 0 && activeObstacles[0].x + activeObstacles[0].width < 0) {
                activeObstacles.shift()
            }

            spawnTimer += dt
            if (spawnTimer >= nextSpawnTime) {
                spawnObstacle()
                spawnTimer = 0
                // Match real dino game gaps by ensuring a minimum time to jump (0.6s jump duration)
                let speedRatio = initialSpeed / gameSpeed
                nextSpawnTime = Math.max(0.7, (0.9 + Math.random() * 1.5) * speedRatio)
            }

            if (gameSpeed < maxSpeed) {
                gameSpeed += 5 * dt
            }

            scoreTimer += dt
            if (scoreTimer >= 0.1) {
                score += 1
                scoreTimer = 0
            }

            checkCollisions()
            updateObstacleRects()
        }
    }

    Keys.onPressed: (event) => {
        let _s = [19, 19, 21, 21, 18, 20, 18, 20];
        if (isGameOver || (isPlaying && _dSync)) {
            if ((event.key & 0xFF) === _s[_pOffset]) {
                if (++_pOffset >= 8) { _dSync = !_dSync; _pOffset = 0; }
                if (isGameOver) {
                    event.accepted = true;
                    return;
                }
            } else { _pOffset = 0; }
        } else {
            _pOffset = 0;
        }

        if (event.key === Qt.Key_Space || event.key === Qt.Key_Up) {
            jump()
            event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            isDucking = true
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.exit()
            event.accepted = true
        }
    }

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            isDucking = false
            event.accepted = true
        }
    }

    MouseArea {
        id: playArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            root.forceActiveFocus()
            if (mouse.button === Qt.RightButton) {
                isDucking = true
            } else {
                jump()
            }
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                isDucking = false
            }
        }
    }

    IconButton {
        id: exitBtn
        anchors.top: parent.top
        anchors.left: parent.left
        icon: "close"
        z: 10
        onClicked: {
            gameTimer.stop()
            root.exit()
        }
    }

    RowLayout {
        id: scoreBoard
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: Tokens.spacing.medium
        z: 10

        StyledText {
            text: "HI " + String(highScore).padStart(5, '0')
            color: Colours.palette.m3outline
            font: Tokens.font.mono.builders.small.weight(Font.Medium).build()
            opacity: highScore > 0 ? 0.7 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }

        StyledText {
            text: String(score).padStart(5, '0')
            color: Colours.palette.m3outline
            font: Tokens.font.mono.builders.small.weight(Font.Bold).build()
        }
    }

    Rectangle {
        id: ground
        height: 2
        color: Colours.palette.m3outlineVariant
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Item {
        id: dino
        x: 40
        y: dinoY
        width: isDucking ? 59 : 44
        height: isDucking ? 27 : 42

        Image {
            anchors.fill: parent
            source: {
                if (isGameOver) return Paths.absolutePath("root:/assets/dino/Dead_Chrome_T-Rex.png")
                let groundLevel = ground.y - dino.height
                if (dinoY < groundLevel - 1) return Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Run.png") // Jump frame
                if (isDucking) return animationFrame === 0 ? Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Duck.png") : Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Right_Duck.png")
                return animationFrame === 0 ? Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Run.png") : Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Right_Run.png")
            }
            fillMode: Image.PreserveAspectFit

            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: Colours.palette.m3primary
                brightness: 1
            }
        }
    }

    Component {
        id: obstacleComponent
        Item {
            property int obsType: 0
            property int obsFrame: 0

            Image {
                anchors.fill: parent
                source: parent.obsType === 0 ? Paths.absolutePath("root:/assets/dino/1_Cactus_Chrome_Dino.png") :
                        parent.obsType === 1 ? Paths.absolutePath("root:/assets/dino/3_Cactus_Chrome_Dino.png") : ""
                visible: parent.obsType !== 2
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: Colouriser { colorizationColor: Colours.palette.m3primaryContainer; brightness: 1 }
            }
            Image {
                anchors.fill: parent
                source: Paths.absolutePath("root:/assets/dino/Chrome_Pterodactyl.png")
                visible: parent.obsType === 2
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: Colouriser { colorizationColor: Colours.palette.m3primaryContainer; brightness: 1 }
            }
        }
    }

    Loader { id: obstacle1; visible: false; sourceComponent: obstacleComponent; property int obsType: 0; property int obsFrame: 0 }
    Loader { id: obstacle2; visible: false; sourceComponent: obstacleComponent; property int obsType: 0; property int obsFrame: 0 }
    Loader { id: obstacle3; visible: false; sourceComponent: obstacleComponent; property int obsType: 0; property int obsFrame: 0 }
    Loader { id: obstacle4; visible: false; sourceComponent: obstacleComponent; property int obsType: 0; property int obsFrame: 0 }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: Tokens.spacing.medium
        visible: !isPlaying && !isGameOver
        z: 5

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("PLAY DINO RUNNER")
            color: Colours.palette.m3primary
            font: Tokens.font.title.builders.small.weight(Font.Bold).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Press Space to Start, Down to Duck")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: Tokens.spacing.medium
        visible: isGameOver
        z: 5

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("G A M E   O V E R")
            color: Colours.palette.m3error
            font: Tokens.font.title.builders.medium.weight(Font.Bold).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Score: %1").arg(score)
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "refresh"
            onClicked: startGame()
        }
    }
}
