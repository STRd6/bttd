{Container, Filter, Rectangle, Sprite, Texture} = PIXI
{screenWidth, screenHeight} = game.config
{PI, abs, floor, max, sin, cos} = Math
{cullCheckSym} = require "./util"
{clamp} = TinyGame.util

#@ts-ignore https://github.com/microsoft/TypeScript/issues/17867
game.addBehaviors
  "display:camera:default":
    #
    ###*
    @param e {CameraEntity}
    ###
    create: (e) ->
      e.id ?= 0
      # Screen coordinates
      e.x ?= screenWidth / 2
      e.y ?= screenHeight / 2
      e.hw ?= screenWidth / 2
      e.hh ?= screenHeight / 2

    ###*
    @param e {CameraEntity}
    ###
    display: (e) ->
      #
      ###* @type {Camera} ###
      #@ts-ignore
      camera = new Container
      camera.filters = [new Filter]
      camera.filterArea = new Rectangle(e.x - e.hw, e.y - e.hh, 2 * e.hw, 2 * e.hh)

      viewport = new Container
      camera.viewport = viewport
      camera.addChild viewport

      canvas = document.createElement 'canvas'
      canvas.width = screenWidth
      canvas.height = screenHeight
      ctx = canvas.getContext('2d')

      lightingTexture = Texture.from(canvas)
      #
      ###* @type {Camera["lighting"]} ###
      lighting = new Sprite lightingTexture
      camera.addChild lighting
      assert ctx
      lighting.ctx = ctx
      camera.lighting = lighting

      border = new Sprite Texture.WHITE
      border.tint = 0x888888
      border.width = 2 * e.hw
      border.height = 1
      border.visible = false
      if e.id is 0
        border.y = e.hh - 1
      else
        border.y = 1 - e.hh
      camera.border = border
      camera.addChild border

      return camera

    ###*
    @param e {CameraEntity}
    @param camera {Camera}
    ###
    render: (e, camera) ->
      {viewport, border} = camera
      close = false
      #
      ###* @type {Point | undefined}###
      target = undefined

      #
      ###* @type {Player[]} ###
      #@ts-ignore
      players = game.entities.filter (p) ->
        # Locally controlled players
        #@ts-ignore TODO: Better typed filter functions
        p.player and p.local

      if players.length is 2
        [p1, p2] = players
        assert p1
        assert p2
        {x: x1, y:y1} = p1
        {x: x2, y:y2} = p2
        if abs(x2 - x1) < 2 * screenWidth / 3 and abs(y2 - y1) < 2 * screenHeight / 3
          close = true

          # Track average position between players
          [x, y] = players.reduce ([x, y], {x:px, y:py}) ->
            [x + px, y + py]
          , [0, 0]

          x /= players.length
          y /= players.length

          target = {x, y}
      else if players.length is 1
        target = players[0]

      # one screen
      if players.length <= 1 or close
        if e.id is 0
          border.visible = false

          Object.assign e,
            x: screenWidth / 2
            y: screenHeight / 2
            hw: screenWidth / 2
            hh: screenHeight / 2

        else
          camera.visible = false
          return
      else # split screen
        Object.assign e,
          x: screenWidth / 2
          y: e.id * screenHeight / 2 + screenHeight / 4
          hw: screenWidth / 2
          hh: screenHeight / 4

        camera.visible = true
        target = players[e.id]

        # border
        border.visible = true

      shw = e.hw
      shh = e.hh
      camera.filterArea.x = e.x - e.hw
      camera.filterArea.y = e.y - e.hh
      camera.filterArea.width = shw * 2
      camera.filterArea.height = shh * 2

      if target
        {x, y} = target

        x = floor -x + e.x
        y = floor -y + e.y

        # Clamp to region
        regionWidth = 80 * 16
        regionHeight = 46 * 16
        viewport.x = clamp x, shw - regionWidth + e.x, e.x - e.hw
        viewport.y = clamp y, shh - regionHeight + e.y, e.y - e.hh

      # Update Lighting
      ctx = camera.lighting.ctx
      assert ctx
      {width:cw, height:ch} = ctx.canvas
      ctx.globalCompositeOperation = "source-over"
      ctx.fillStyle = "#000"
      ctx.globalAlpha = 1
      ctx.clearRect 0, 0, cw, ch
      ctx.globalAlpha = 0.875
      ctx.fillRect 0, 0, cw, ch
      ctx.globalCompositeOperation = "destination-out"
      game.entities.filter (e) ->
        #@ts-ignore TODO: Better type filter functions
        e.light
      #@ts-ignore
      .forEach ({r1, r2, x, y}) ->
        dx = floor -x + shw + e.x - viewport.x
        dy = floor -y + shh + e.y - viewport.y

        r1 = max 0, r1 + 2 * cos(game.tick / 17)
        r2 = max 0, r2 + 8 * sin(game.tick / 20)

        assert ctx
        ctx.globalAlpha = 0.5
        ctx.beginPath()
        ctx.arc(shw - dx + e.x, shh - dy + e.y, r2, 0, 2 * PI)
        ctx.fill()
        ctx.globalAlpha = 1
        ctx.beginPath()
        ctx.arc(shw - dx + e.x, shh - dy + e.y, r1, 0, 2 * PI)
        ctx.fill()

      camera.lighting.texture.update()

      cullViewport(e, camera)

# TODO: need to add cull to tilemap
###*
@param e {CameraEntity}
@param camera {Camera}
###
cullViewport = (e, camera) ->
  {viewport} = camera

  worldBounds = cameraToWorldBounds e, camera

  children = viewport.children
  i = 0
  l = children.length

  while i < l
    child = children[i++]
    #@ts-ignore
    child[cullCheckSym](worldBounds)

# Convert screen bounds to world bounds
###*
@param e {CameraEntity}
@param camera {Camera}
###
cameraToWorldBounds = (e, camera) ->
  {x, y} = camera.viewport
  {x: screenX, y: screenY, hw: shw, hh: shh} = e

  x: screenX - x
  y: screenY - y
  hw: shw
  hh: shh

#
###*
@typedef {import("../types/camera").CameraEntity} CameraEntity
@typedef {import("../types/camera").Camera} Camera
@typedef {import("../types/types").Player} Player
@typedef {import("../types/types").SimplePoint} Point
###
