class Splash extends Phaser.Scene {
  constructor(scene) {
    super('Splash')
    this.scene = scene
  }

  init() {}

  preload() {
    // this.load.setBaseURL('https://leprechaun.altenwald.com')
    this.load.image('leprechaun', '/img/leprechaun.png')
    this.load.image('rainbow-pot', '/img/cell_8.png')
    this.load.image('start', '/img/start.png')
    this.load.image('background', '/img/background.jpeg')

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
  }

  update(time, delta) {}
}
