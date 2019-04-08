var ws;
var selected;
var game_id;
var click_enabled = true;
var current_board;

function draw(html) {
    current_board = html;
    $("#board").html(html);
    $("#board-msg").html("");
    $(".cell").on("click", function(event){
        if (!click_enabled) {
            return;
        }
        var row_id = parseInt(this.id[3]);
        var col_id = parseInt(this.id[8]);
        if (!selected) {
            console.log("pos: x = " + col_id + "; y = " + row_id)
            $(this).addClass("blink_me");
            selected = [this, row_id, col_id];
        } else {
            disable_moves();
            var old_id = selected[0];
            var new_id = this.id;
            $(old_id).removeClass("blink_me");
            $(old_id).swap({
                target: new_id,
                opacity: 0.75,
                speed: 250,
                callback: function() {
                    send({type: "move", "x1": selected[2],
                                        "y1": selected[1],
                                        "x2": col_id,
                                        "y2": row_id});
                    selected = undefined;
                }
            });
        }
    });
}

function enable_moves() {
    click_enabled = true;
}

function disable_moves() {
    click_enabled = false;
}

function disconnected(should_i_reconnect) {
    disable_moves();
    $("#board-msg").html("<h2>¡Disconnected!</h2>");
    if (should_i_reconnect) {
        setTimeout(function(){ connect(); }, 1000);
    }
}

function update_score(data) {
    console.log("updating: ", data)
    if (data.score >= 0) {
        $("#board-score span").html(data.score);
    }
    if (data.turns >= 0) {
        $("#board-turns span").html(data.turns);
    }
}

function blink(data) {
    if (data.points) {
        for (var i=0; i<data.points.length; i++) {
            $("#" + data.points[i]).addClass("blink_me");
            console.log("blinking " + data.points[i]);
        }
    }
}

function send(message) {
    console.log("send: ", message);
    ws.send(JSON.stringify(message));
};

function connect() {
    const hostname = document.location.href.split("/", 3)[2];
    if (ws) {
        ws.close();
    }
    ws = new WebSocket("ws://" + hostname + "/websession");
    ws.onopen = function(){
        console.log("connected!");
        if (game_id) {
            send({type: "join", id: game_id})
        } else {
            send({type: "create"})
        }
        send({type: "show"});
        enable_moves();
    };
    ws.onerror = function(message){
        console.error("onerror", message);
        disconnected(false);
    };
    ws.onclose = function() {
        console.error("onclose");
        disconnected(true);
    }
    ws.onmessage = function(message){
        console.log("Got message", message.data);
        var data = JSON.parse(message.data);

        switch(data.type) {
            case "match":
                draw(data.html);
                update_score(data);
                blink(data);
                break;
            case "gameover":
                disable_moves();
                update_score(data);
                $("#board-msg").html("<h2>GAME OVER!</h2>");
                break;
            case "draw":
                draw(data.html);
                update_score(data);
                break;
            case "id":
                game_id = data.id;
                break;
            default:
                draw(current_board);
                enable_moves();
                break;
        }
    };
}

$(document).ready(function(){
    connect();
    $("#board-restart").on("click", function(event){
        send({type: "restart"});
    });
});
