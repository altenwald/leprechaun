class Splash extends Phaser.Scene {
  constructor(scene) {
    super('Splash')
    this.scene = scene
    this.music = []
  }

  init() {}

  preload() {
    // this.load.setBaseURL('https://leprechaun.altenwald.com')
    this.load.image('leprechaun', '/img/leprechaun.png')
    this.load.image('rainbow-pot', '/img/cell_8.png')
    this.load.image('start', '/img/start.png')
    this.load.image('background', '/img/background.jpeg')
    this.load.audio('music-01', ['/audio/music01.mp3', '/audio/music01.ogg'])
    this.load.audio('music-02', ['/audio/music02.mp3', '/audio/music02.ogg'])
    this.load.image('music-on', '/img/music_on.png')
    this.load.image('music-off', '/img/music_off.png')
    this.load.image('hi-score', '/img/hi_score.png')

    this.sceneStopped = false
    this.width = this.game.screenBaseSize.width
    this.height = this.game.screenBaseSize.height
    this.resizerScene = this.scene.get('SplashResizer')
    sceneRunning = 'Splash'
  }

  create() {
    const { width, height } = this
    this.resizerScene.updateResize(this)

    this.add
      .image(width / 2, height / 2, 'background')
      .setDisplaySize(612 * 2, 436 * 2)
  
    this.add
      .text(width / 2, height - 50, 'Leprechaun - https://altenwald.com', {
        fontSize: 12,
        color: '#fff'
      })
      .setOrigin(0.5)
      .setDepth(2)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        window.location.href = 'https://altenwald.com'
      })

    this.add
      .image(width / 2, height / 2, 'start')
      .setDisplaySize(400, 380)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        sceneRunning = 'Game'
        this.scene.start('Game')
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

    this.add
      .image(0, 50, 'hi-score')
      .setOrigin(0, 0)
      .setDisplaySize(78, 78)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', () => {
        sceneRunning = 'HighScore'
        this.scene.start('HighScore')
      })

    musicCenter.on('play', (data) => {
      musicStatus = 'music-on'
      this.music[0].resume()
    })

    musicCenter.on('stop', (data) => {
      musicStatus = 'music-off'
      this.music[0].pause()
    })

    this.music.push(this.sound.add('music-01').on('complete', (music) => { this.djbox(music) }))
    this.music.push(this.sound.add('music-02').on('complete', (music) => { this.djbox(music) }))
    this.music[0].play()
  }

  djbox(music) {
    var prev = this.music.shift()
    this.music.push(prev)
    this.music[0].play()
  }
}
