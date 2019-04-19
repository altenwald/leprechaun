var ws;
var game_id;
var bot_id;
var current_board;
var editor;

var turns = 0;
var extra_turn = false;

function draw_hiscore(html, position) {
    $("#hiscore").html(html);
    if (position) {
        $("#hiscore-pos").html("<p>Your position is " + position + "</p>");
    }
}

function draw(html) {
    current_board = html;
    $("#board").html(html);
    $("#board-msg").html("");
}

function disconnected(should_i_reconnect) {
    $("#board-msg").html("<h2>¡Disconnected!</h2>");
    if (should_i_reconnect) {
        setTimeout(function(){ connect(); }, 1000);
    }
}

function update_score(data) {
    console.log("updating: ", data)
    if (data.score >= 0) {
        var score_text = data.score;
        if (data.add_score >= 0) {
            score_text += " (+" + data.add_score + ")";
        }
        $("#board-score span").html(score_text);
    }
    if (data.turns >= 0) {
        var turns_text = data.turns;
        switch (data.extra_turn) {
            case "extra_turn":
                turns_text += " (+1)"
                break;
            case "decr_turn":
                turns_text += " (-1)"
                break;
        }
        $("#board-turns span").html(turns_text);
    }
}

function blink(data) {
    if (data.points) {
        for (var i=0; i<data.points.length; i++) {
            blink_id = $("#" + data.points[i]);
            $(blink_id).addClass("blink_me");
            var blink_png = $(blink_id).attr("src").split(".").slice(0, -1).join() + "_blink.png";
            $(blink_id).attr("src", blink_png);
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
    var schema = (location.href.split(":")[0] == "https") ? "wss" : "ws";
    ws = new WebSocket(schema + "://" + hostname + "/websession");
    ws.onopen = function(){
        console.log("connected!");
        if (game_id) {
            send({type: "join", id: game_id, bot_id: bot_id});
        } else {
            send({type: "create"});
        }
        send({type: "show"});
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
                if (extra_turn) {
                    data.turns = turns;
                    data.extra_turn = "extra_turn";
                    extra_turn = false;
                }
                update_score(data);
                blink(data);
                break;
            case "gameover":
                $("#board-msg").html("<h2>GAME OVER!</h2>");
                if (!data.has_username && !data.error) {
                    update_score(data);
                    $("#hiscoreNameModal").modal('show');
                }
                break;
            case "draw":
                draw(data.html);
                update_score(data);
                break;
            case "id":
                game_id = data.id;
                break;
            case "bot_id":
                bot_id = data.id;
                break;
            case "hiscore":
                draw_hiscore(data.top_list, data.position);
                break;
            case "vsn":
                $("#vsn").html("v" + data.vsn);
                break;
            case "extra_turn":
                extra_turn = true;
                turns = data.turns;
                break;
            case "log":
                $("#board-logs").html(data.info);
                break;
            default:
                draw(current_board);
                update_score(data);
                break;
        }
    };
}

$(document).ready(function(){
    connect();
    $("#board-restart").on("click", function(event){
        send({type: "restart"});
    });
    $("#board-hiscore").on("click", function(event){
        send({type: "hiscore"});
    });
    $("#hiscore-ok").on("click", function(event){
        var name = $("#hiscore-name").val();
        send({type: "set-hiscore-name", name: name});
        $("#hiscoreNameModal").modal('hide');
        send({type: "hiscore"});
        $("#hiscoreModal").modal('show');
    });
    $("#board-music-button").on("click", function(event){
        var music = $("#board-music")[0];
        if (music.paused) {
            $("#board-music-button").html("Mute");
            music.play();
        } else {
            $("#board-music-button").html("UnMute");
            music.pause();
        }
    });
    $("#board-run").on("click", function(event){
        var code = editor.getValue();
        console.log("sending: ", code);
        $("#board-game-tab").tab('show');
        send({type: "run", code: code});
    });
    editor = CodeMirror.fromTextArea($("#code")[0], {
        lineNumbers: true,
        matchBrackets: true,
        mode: "application/x-httpd-php",
        indentUnit: 4,
        indentWithTabs: true
    });
});
