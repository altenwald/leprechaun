class Game extends Phaser.Scene {
  constructor(scene) {
    super('Game')
    this.scene = scene
  }

  init() {
    this.addScore = 0
    eventsCenter.on('ws', this.on_event, this)
  }

  on_event(data) {
    console.log(data.type)
    switch(data.type) {
      case "new_kind":
        this.new_kind(data.row, data.col, data.piece)
        break;
      case "slide_new":
        this.slide_new(data.row, data.col, data.piece)
        break;
      case "slide":
        this.slide(data.orig["row"], data.orig["col"], data.dest["row"], data.dest["col"])
        break;
      case "match":
        this.save_board(data.cells)
        this.update_info(data)
        this.blink(data.points)
        break;
      case "gameover":
        sceneRunning = 'GameOver'
        this.input.off('pointerdown', this.startDrag, this)
        eventsCenter.off('ws', this.on_event, this)
        this.scene.start('GameOver')
        this.scene.get('GameOver').score = data.score
        break;
      case "draw":
        this.save_board(data.cells)
        this.update_info(data)
        break;
      case "hiscore":
        break;
      case "extra_turn":
        this.update_info(data)
        break;
      case "play":
        this.addScore = 0
        this.update_info(data)
        this.input.on('pointerdown', this.startDrag, this)
        break;
      case "illegal_move":
        this.undoMove()
        this.input.on('pointerdown', this.startDrag, this)
        break;
      default:
        if (data.cells) {
          this.save_board(data.cells)
        }
        this.update_info(data)
        break;
    }
  }

  new_kind(row, col, piece) {
    this.board[row][col].setTexture(piece)
  }

  slide_new(row, col, piece) {
    this.board[row][col].setTexture(piece)
  }

  slide(row1, col1, row2, col2) {
    // TODO: animation?
    var p1 = this.board[row1][col1], p2 = this.board[row2][col2]
    p2.setTexture(p1.texture)
    p1.setTexture('blank')
  }

  preload() {
    // this.load.setBaseURL('https://leprechaun.altenwald.com')
    this.load.image('blank', '/img/cell_0.png')
    this.load.image('cell-background', '/img/cell_0_background.png')

    this.load.image('bronze', '/img/cell_1.png')
    this.load.image('silver', '/img/cell_2.png')
    this.load.image('gold', '/img/cell_3.png')
    this.load.image('sack', '/img/cell_4.png')
    this.load.image('chest', '/img/cell_5.png')
    this.load.image('big-chest', '/img/cell_6.png')
    this.load.image('pot', '/img/cell_7.png')
    this.load.image('rainbow-pot', '/img/cell_8.png')

    this.load.image('bronze-blink', '/img/cell_1_blink.png')
    this.load.image('silver-blink', '/img/cell_2_blink.png')
    this.load.image('gold-blink', '/img/cell_3_blink.png')
    this.load.image('sack-blink', '/img/cell_4_blink.png')
    this.load.image('chest-blink', '/img/cell_5_blink.png')
    this.load.image('big-chest-blink', '/img/cell_6_blink.png')
    this.load.image('pot-blink', '/img/cell_7_blink.png')
    this.load.image('rainbow-pot-blink', '/img/cell_8_blink.png')

    this.sceneStopped = false
    this.width = this.game.screenBaseSize.width
    this.height = this.game.screenBaseSize.height
    this.resizerScene = this.scene.get('GameResizer')
  }

  position_x(col) { return col * 60 }
  position_y(row) { return 295 + (row * 60) }

  create() {
    connect()
    const { width, height } = this
    this.resizerScene.updateResize(this)
    this.cameras.main.backgroundColor.setTo(0, 0, 0);
    this.add
      .image(width / 2, height / 2, 'background')
      .setDisplaySize(612 * 2, 436 * 2)

    this.add
      .image(270, 275, 'cell-background')
      .setDisplaySize(480, 75)
      .setActive(false)
      .setDepth(1)

    var fontOptions = {
      fontSize: 24,
      color: '#000'
    }
    this.score = this.add
      .text(50, 250, 'Score: 0', fontOptions)
      .setDepth(2)

    this.turns = this.add
      .text(50, 280, 'Turns: 0', fontOptions)
      .setDepth(2)

    this.board = []
    for (var row=1; row<=8; row++) {
      this.board[row] = []
      for (var col=1; col<=8; col++) {
        var image = "pot"
        var x_pos = this.position_x(col)
        var y_pos = this.position_y(row)
        this.add
          .image(x_pos, y_pos, 'cell-background')
          .setDisplaySize(60, 60)
          .setActive(false)
          .setDepth(1)

        var cell = this.add
          .image(x_pos, y_pos, image)
          .setDisplaySize(50, 50)
          .setInteractive({ useHandCursor: true })
          .setData({row: row, col: col, x: x_pos, y: y_pos})
          .setDepth(2)

        this.board[row][col] = cell
      }
    }
    this.input.on('pointerdown', this.startDrag, this)
  }

  blink(points) {
    for(var i=0; i<points.length; i++) {
      var point = points[i]
      var cell = this.board[point["row"]][point["col"]]
      cell.setTexture(cell.texture.key + "-blink")
    }
  }

  startDrag(pointer, targets) {
    this.dragObject = targets[0]
    if (this.dragObject) {
      this.input.off('pointerdown', this.startDrag, this)
      this.initialPointerX = pointer.x
      this.initialPointerY = pointer.y
      this.dragObjectX = this.dragObject.getData('x')
      this.dragObjectY = this.dragObject.getData('y')
      this.dragObjectDir = ''
      this.input.on('pointermove', this.doDrag, this)
      this.input.on('pointerup', this.stopDrag, this)
    }
  }

  offset(value) {
    if (value > 60) {
      return 60
    } else if (value < -60) {
      return -60
    }
    return value
  }

  should_drag(dir, offset_y, offset_x) {
    switch (dir) {
      case 'Y':
        return Math.abs(offset_y) - 5 > Math.abs(offset_x)

      case 'X':
        return Math.abs(offset_x) - 5 > Math.abs(offset_y)
    }
    return false
  }

  doDrag(pointer) {
    var offset_x = this.offset(this.initialPointerX - pointer.x)
    var offset_y = this.offset(this.initialPointerY - pointer.y)
    var row = this.dragObject.getData('row')
    var col = this.dragObject.getData('col')
    if (this.dragObjectDir == 'X') {
      this.dragObject.x = this.dragObjectX - offset_x
    } else if (this.dragObjectDir == 'Y') {
      this.dragObject.y = this.dragObjectY - offset_y
    } else if (this.dragObjectDir == '' && this.should_drag('Y', offset_y, offset_x)) {
      this.dragObjectDir = 'Y'
      this.dragObject.y = this.dragObjectY - offset_y
    } else if (this.dragObjectDir == '' && this.should_drag('X', offset_y, offset_x)) {
      this.dragObjectDir = 'X'
      this.dragObject.x = this.dragObjectX - offset_x
    }
    // check borders
    if (this.dragObjectDir == 'X') {
      if ((col == 8 && this.initialPointerX < pointer.x) || (col == 1 && this.initialPointerX > pointer.x)) {
        this.dragObject.x = this.dragObjectX
        this.dragObjectDir = ''
      }
    } else if (this.dragObjectDir == 'Y') {
      if ((row == 8 && this.initialPointerY < pointer.y) || (row == 1 && this.initialPointerY > pointer.y)) {
        this.dragObject.y = this.dragObjectY
        this.dragObjectDir = ''
      }
    }
    // swap the other object
    if (this.dragObjectDir == 'X') {
      if (offset_x > 0) {
        if (this.dragObjectSwap != this.board[row][col - 1]) {
          this.dragObjectSwap = this.board[row][col - 1]
          this.dragObjectSwapX = this.dragObjectSwap.x
        }
      } else if (offset_x < 0) {
        if (this.dragObjectSwap != this.board[row][col + 1]) {
          this.dragObjectSwap = this.board[row][col + 1]
          this.dragObjectSwapX = this.dragObjectSwap.x
        }
      }
      this.dragObjectSwap.x = this.dragObjectSwapX + offset_x
    } else if (this.dragObjectDir == 'Y') {
      if (offset_y > 0) {
        if (this.dragObjectSwap != this.board[row - 1][col]) {
          this.dragObjectSwap = this.board[row - 1][col]
          this.dragObjectSwapY = this.dragObjectSwap.y
        }
      } else if (offset_y < 0) {        
        if (this.dragObjectSwap != this.board[row + 1][col]) {
          this.dragObjectSwap = this.board[row + 1][col]
          this.dragObjectSwapY = this.dragObjectSwap.y
        }
      }
      this.dragObjectSwap.y = this.dragObjectSwapY + offset_y
    }
    this.dragObjectValid =  this.dragObjectDir != '' && (Math.abs(offset_x) > 20 || Math.abs(offset_y) > 20);
  }

  undoMove() {
    // TODO: animation here?
    var p1 = this.dragObject, p2 = this.dragObjectSwap
    var t = p1.texture
    p1.setTexture(p2.texture)
    p2.setTexture(t)
  }

  stopDrag() {
    this.input.off('pointerup', this.stopDrag, this)
    this.input.off('pointermove', this.doDrag, this)
    if (this.dragObjectValid) {
      var p1 = this.dragObject, p2 = this.dragObjectSwap
      p1.x = p1.getData('x')
      p2.x = p2.getData('x')
      p1.y = p1.getData('y')
      p2.y = p2.getData('y')
      var t = p1.texture
      p1.setTexture(p2.texture)
      p2.setTexture(t)

      send({
        type: "move",
        x1: p1.getData("col"),
        y1: p1.getData("row"),
        x2: p2.getData("col"),
        y2: p2.getData("row")
      })
    } else if (this.dragObjectSwap) {
      // TODO: animation?
      var p1 = this.dragObject, p2 = this.dragObjectSwap
      p1.x = p1.getData('x')
      p2.x = p2.getData('x')
      p1.y = p1.getData('y')
      p2.y = p2.getData('y')
      this.input.on('pointerdown', this.startDrag, this)
    } else {
      this.input.on('pointerdown', this.startDrag, this)
    }
  }

  save_board(cells) {
    for (var row=1; row<=8; row++) {
      for (var col=1; col<=8; col++) {
        var cell = cells[row - 1][col - 1]
        var image = this.board[row][col]
        var x_pos = this.position_x(col)
        var y_pos = this.position_y(row)
        image.setTexture(cell["image"])
        image.y = y_pos
        image.x = x_pos
        image.setData({row: row, col: col, x: x_pos, y: y_pos})
      }
    }
  }

  update_info(data) {
    if (data.score) {
      var text = 'Score: ' + data.score
      if (data.add_score) {
        this.addScore += data.add_score
      }
      if (this.addScore > 0) {
        text += " (+" + this.addScore + ")"
      }
      this.score.setText(text)
    }
    if (data.turns) {
      this.turns.setText('Turns: ' + data.turns)
    }
  }

  update(time, delta) {
  }
}
