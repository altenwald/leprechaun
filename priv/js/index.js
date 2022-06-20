// Aspect Ratio 16:9 - Portrait
const MAX_SIZE_WIDTH_SCREEN = 1920
const MAX_SIZE_HEIGHT_SCREEN = 1080
const MIN_SIZE_WIDTH_SCREEN = 270
const MIN_SIZE_HEIGHT_SCREEN = 480
const SIZE_WIDTH_SCREEN = 540
const SIZE_HEIGHT_SCREEN = 960

var
    config = {
        type: Phaser.AUTO,
        physics: {
            default: 'arcade',
            arcade: {
                gravity: { y: 100 }
            }
        },
        scale: {
            mode: Phaser.Scale.RESIZE,
            parent: 'game',
            width: SIZE_WIDTH_SCREEN,
            height: SIZE_HEIGHT_SCREEN,
            min: {
                width: MIN_SIZE_WIDTH_SCREEN,
                height: MIN_SIZE_HEIGHT_SCREEN
            },
            max: {
                width: MAX_SIZE_WIDTH_SCREEN,
                height: MAX_SIZE_HEIGHT_SCREEN
            }
        },
        parent: 'phaser-app',
        dom: {
            createContainer: true
        },
        scene: [
            Splash,
            Game,
            GameOver,
            SplashResizer,
            GameResizer,
            GameOverResizer
        ]
    },
    game = new Phaser.Game(config),
    eventsCenter = new Phaser.Events.EventEmitter(),
    sceneRunning = '',
    ws,
    game_id,
    vsn

game.screenBaseSize = {
    maxWidth: MAX_SIZE_WIDTH_SCREEN,
    maxHeight: MAX_SIZE_HEIGHT_SCREEN,
    minWidth: MIN_SIZE_WIDTH_SCREEN,
    minHeight: MIN_SIZE_HEIGHT_SCREEN,
    width: SIZE_WIDTH_SCREEN,
    height: SIZE_HEIGHT_SCREEN
}

game.orientation = "portrait"

function disconnected(should_i_reconnect) {
    if (should_i_reconnect) {
        setTimeout(function(){
            if (!ws || ws.readyState == ws.CLOSED) {
                connect()
            }
        }, 1000)
    }
}

function send(message) {
    ws.send(JSON.stringify(message))
}

function restart_game() {
    game_id = undefined
    send({type: "create"})
    send({type: "show"})
}

function connect() {
    const hostname = document.location.href.split("/", 3)[2]
    if (ws) {
        if (ws.readyState == ws.OPEN) {
            send({type: "show"})
            return
        }
        if (ws.readyState != ws.CLOSED || ws.readyState != ws.CLOSING) {
            ws.close()
        }
    }
    const schema = (location.href.split(":")[0] == "https") ? "wss" : "ws"
    ws = new WebSocket(schema + "://" + hostname + "/websession")
    ws.onopen = function(){
        if (game_id) {
            send({type: "join", id: game_id})
        } else {
            send({type: "create"})
        }
        send({type: "show"})
        eventsCenter.emit('ws', {type: "connected"})
    };
    ws.onerror = function(message){
        console.error("onerror", message)
        eventsCenter.emit('ws', {type: "connect-error"})
        disconnected(false)
    };
    ws.onclose = function() {
        eventsCenter.emit('ws', {type: "disconnected"})
        disconnected(true)
    }
    ws.onmessage = function(message){
        var data = JSON.parse(message.data)

        switch(data.type) {
            case "id":
                game_id = data.id
                console.log("game_id", game_id)
                break
            case "vsn":
                vsn = data.vsn
                break
            default:
                eventsCenter.emit('ws', data)
                break
        }
    }
}
