class GameOver extends Phaser.Scene {
  constructor(scene) {
    super('GameOver')
    this.scene = scene
  }

  init() {
    eventsCenter.on('ws', this.on_event, this)
  }

  on_event(data) {
    console.log(data.type)
    switch(data.type) {
      case "hiscore":
        this.show_hiscore(data.top_list, data.position)
        break;
      default:
        console.log(data)
        break;
    }
  }

  show_hiscore(top_list, position) {
    for (var i=0; i<10; i++) {
      const entry = top_list[i]
      if (entry) {
        var position = this.hiscore[i]
        position.name.setText(entry.name)
        position.score.setText(entry.score)
      }
    }
  }

  preload() {
    this.load.scenePlugin({
      key: 'rexuiplugin',
      url: 'https://raw.githubusercontent.com/rexrainbow/phaser3-rex-notes/master/dist/rexuiplugin.min.js',
      sceneKey: 'rexUI'
    })
    
    this.load.plugin('rextexteditplugin', 'https://raw.githubusercontent.com/rexrainbow/phaser3-rex-notes/master/dist/rextexteditplugin.min.js', true)
  
    // this.load.setBaseURL('https://leprechaun.altenwald.com')
    this.load.image('cell-background', '/img/cell_0_background.png')
    this.load.image('start', '/img/start.png')

    this.load.image('bronze', '/img/cell_1.png')
    this.load.image('silver', '/img/cell_2.png')
    this.load.image('gold', '/img/cell_3.png')
    this.load.image('sack', '/img/cell_4.png')
    this.load.image('chest', '/img/cell_5.png')
    this.load.image('big-chest', '/img/cell_6.png')
    this.load.image('pot', '/img/cell_7.png')
    this.load.image('rainbow-pot', '/img/cell_8.png')
    this.load.image('clover', '/img/cell_A.png')
    this.load.image('leprechaun-head', '/img/cell_9.png')

    this.sceneStopped = false
    this.width = this.game.screenBaseSize.width
    this.height = this.game.screenBaseSize.height
    this.resizerScene = this.scene.get('GameOverResizer')
  }

  create() {
    const { width, height } = this
    this.resizerScene.updateResize(this)
    this.cameras.main.backgroundColor.setTo(0, 0, 0);
    this.add
      .image(width / 2, height / 2, 'background')
      .setDisplaySize(612 * 2, 436 * 2)

    this.add
      .image(270, 475, 'cell-background')
      .setDisplaySize(555, 700)
      .setActive(false)
      .setDepth(1)

    this.add
      .text(width / 2, height - 50, 'Leprechaun v' + vsn + ' - https://altenwald.com', {
        fontSize: 12,
        color: '#fff'
      })
      .setOrigin(0.5)
      .setDepth(2)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        window.location.href = 'https://altenwald.com'
      })

    const fontOptions = {
      fontSize: 24,
      color: '#000'
    }
    this.score = this.add
      .text(50, 200, 'You got ' + this.score + ' points!', fontOptions)
      .setDepth(2)

    const fontUserNameOptions = {
      fontSize: 24,
      fontSyle: 'bold',
      color: '#000'
    }
    const username = this.add
      .text(50, 230, 'My name here!', fontUserNameOptions)
      .setDepth(2)
      .setInteractive()
      .on('pointerdown', () => {
        this.rexUI.edit(username, {
          onClose: (textObject) => {
            send({type: "set-hiscore-name", name: textObject.text})
          }
        })
      })

    const fontNameOptions = {
      fontSize: 24,
      color: '#000'
    }
    const fontScoreOptions = {
      fontSize: 24,
      color: '#000',
      align: 'right',
      fixedWidth: 100
    }
    this.hiscore = []
    for (var i=0; i<10; i++) {
      const icon = this.img(i + 1)
      if (icon) {
        this.add
          .image(60, 310 + (i * 50), icon)
          .setDisplaySize(30, 30)
          .setDepth(2)
      }
      this.hiscore[i] = {
        name: this.add.text(120, 300 + (i * 50), 'Unnamed', fontNameOptions).setDepth(2),
        score: this.add.text(400, 300 + (i * 50), '0', fontScoreOptions).setDepth(2)
      }
    }
    send({type: "hiscore"})

    this.add
      .image(450, 220, 'start')
      .setDisplaySize(100, 95)
      .setDepth(2)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        sceneRunning = 'Game'
        eventsCenter.off('ws', this.on_event, this)
        this.scene.start('Game')
        restart_game()
      })
  }

  img(i) {
    switch(i) {
      case 1: return 'leprechaun-head'
      case 2: return 'clover'
      case 3: return 'rainbow-pot'
      case 4: return 'pot'
      case 5: return 'big-chest'
      case 6: return 'chest'
      case 7: return 'sack'
      case 8: return 'gold'
      case 9: return 'silver'
      case 10: return 'bronze'
      default: return false
    }
  }

  update(time, delta) {
  }
}
