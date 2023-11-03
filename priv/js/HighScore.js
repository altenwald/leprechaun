class HighScore extends Phaser.Scene {
  constructor(scene) {
    super('HighScore')
    this.scene = scene
  }

  preload() {
    this.load.scenePlugin({
      key: 'rexuiplugin',
      url: 'https://raw.githubusercontent.com/rexrainbow/phaser3-rex-notes/f71581e812f1f0cb8bcc96a5c7ec4459f9c80e34/dist/rexuiplugin.min.js',
      sceneKey: 'rexUI'
    })
    
    this.load.plugin('rextexteditplugin', 'https://raw.githubusercontent.com/rexrainbow/phaser3-rex-notes/f71581e812f1f0cb8bcc96a5c7ec4459f9c80e34/dist/rextexteditplugin.min.js', true)
  
    // this.load.setBaseURL('https://leprechaun.altenwald.com')
    this.load.image('background', '/img/background.jpeg')
    this.load.image('restart', '/img/restart.png')
    this.load.image('music-on', '/img/music_on.png')
    this.load.image('music-off', '/img/music_off.png')

    this.sceneStopped = false
    this.width = this.game.screenBaseSize.width
    this.height = this.game.screenBaseSize.height
    this.resizerScene = this.scene.get('HighScoreResizer')
  }

  create() {
    const { width, height } = this
    this.resizerScene.updateResize(this)
    this.cameras.main.backgroundColor.setTo(0, 0, 0);
    this.add
      .image(width / 2, height / 2, 'background')
      .setDisplaySize(612 * 2, 436 * 2)

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

    var scrollMode = 0 // 0: vertical
    this.gridTable = this.rexUI.add.gridTable({
      x: 0,
      y: 150,
      width: this.width,
      height: Math.floor(this.height * 0.75),
      scrollMode: scrollMode,
      background: this.rexUI.add.roundRectangle(0, 0, 20, 10, 10, COLOR_PRIMARY),
      table: {
        cellWidth: (scrollMode === 0) ? undefined : 60,
        cellHeight: (scrollMode === 0) ? 60 : undefined,
        columns: 2,
        mask: {
          padding: 2,
        },
        reuseCellContainer: false,
      },
      slider: {
        track: this.rexUI.add.roundRectangle(0, 0, 20, 10, 10, COLOR_DARK),
        thumb: this.rexUI.add.roundRectangle(0, 0, 0, 0, 13, COLOR_LIGHT),
      },
      mouseWheelScroller: {
        focus: false,
        speed: 0.2
      },
      header: this.rexUI.add.label({
        width: (scrollMode === 0) ? undefined : 30,
        height: (scrollMode === 0) ? 30 : undefined,
        background: this.rexUI.add.roundRectangle(0, 0, 20, 20, 0, COLOR_DARK),
        text: this.add.text(0, 0, 'High Score'),
        space: {
          left: 20
        }
      }),
      space: {
          left: 20,
          right: 20,
          top: 20,
          bottom: 20,

          table: 10,
          header: 10,
          footer: 10,
      },
      createCellContainerCallback: function(cell, cellContainer) {
        return cell.scene.rexUI.add.label({
          width: cell.width,
          height: cell.height,
          background: cell.scene.rexUI.add.roundRectangle(0, 0, 20, 20, 0).setStrokeStyle(2, COLOR_DARK).setDepth(0),
          text: cell.scene.add.text(0, 0, (cell.item.type === 'score') ? cell.item.score : cell.item.name, {color: COLOR_TEXT}),
          space: cell.item.type === 'score' ? { right: 25 } : { left: 25 },
          align: cell.item.type === 'score' ? 'right' : 'left'
        })
      }
    })
      .setOrigin(0, 0)
      .layout()

    connect()

    eventsCenter.on('ws', (data) => {
      console.log("received", data)
      switch(data.type) {
        case 'connected':
          send({type: "hiscore"})
          break
        case 'hiscore':
          this.update_hiscore(data.top_list)
          break
      }
    })

    this.add
      .image(0, 50, 'start')
      .setOrigin(0, 0)
      .setDisplaySize(66, 53)
      .setDepth(2)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        sceneRunning = 'Game'
        eventsCenter.off('ws', this.on_event, this)
        this.scene.start('Game')
        restart_game()
      })

    this.musicIcon = this.add
      .image(width, 50, musicStatus)
      .setOrigin(1, 0)
      .setDisplaySize(78, 78)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        if (this.musicIcon.texture.key == 'music-on') {
          musicCenter.emit('stop', {})
          this.musicIcon.setTexture('music-off')
        } else {
          musicCenter.emit('play', {})
          this.musicIcon.setTexture('music-on')
        }
      })
  }

  update_hiscore(top_list) {
    var leadership = []
    for (var i=0; i<top_list.length; i++) {
      leadership.push({type: 'name', name: top_list[i].name.slice(0, 20)})
      leadership.push({type: 'score', score: String(top_list[i].score) + ' | ' + String(top_list[i].position + 1).padStart(2)})
    }
    this.gridTable.setItems(leadership)
  }

  update(time, delta) {}
}
