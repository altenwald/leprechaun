class Resizer extends Phaser.Scene {

  create() {}

  updateResize(scene) {
    scene.scale.on('resize', this.resize, scene)

    const scaleWidth = scene.scale.gameSize.width
    const scaleHeight = scene.scale.gameSize.height

    scene.parent = new Phaser.Structs.Size(scaleWidth, scaleHeight)
    scene.sizer = new Phaser.Structs.Size(scene.width, scene.height, Phaser.Structs.Size.FIT, scene.parent)

    scene.parent.setSize(scaleWidth, scaleHeight)
    scene.sizer.setSize(scaleWidth, scaleHeight)

    this.updateCamera(scene)
  }

  resize(gameSize, gameScene) {
    // 'this' means to the current scene that is running
    if (!this.sceneStopped && sceneRunning == this.scene.key) {
      const width = gameSize.width
      const height = gameSize.height

      this.parent.setSize(width, height)
      this.sizer.setSize(width, height)

      // updateCamera - TO DO: Improve the next code because it is duplicated
      const camera = this.cameras.main
      const scaleX = this.sizer.width / this.game.screenBaseSize.width
      const scaleY = this.sizer.height / this.game.screenBaseSize.height

      camera.setZoom(Math.max(scaleX, scaleY))
      camera.centerOn(this.game.screenBaseSize.width / 2, this.game.screenBaseSize.height / 2)
    }
  }

  updateCamera(scene) {
    const camera = scene.cameras.main
    const scaleX = scene.sizer.width / this.game.screenBaseSize.width
    const scaleY = scene.sizer.height / this.game.screenBaseSize.height

    camera.setZoom(Math.max(scaleX, scaleY))
    camera.centerOn(this.game.screenBaseSize.width / 2, this.game.screenBaseSize.height / 2)
  }
}
