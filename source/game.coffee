{PI, abs, cos, floor, max, min, sign, sin} = Math
{BitmapText, Container, DisplayObject, Filter, NineSlicePlane, ParticleContainer, Point, Sprite, TilingSprite} = PIXI
{ext, ui, util} = TinyGame
{loadSpritesheet, parseLevel} = ext
{HealthBar, UIButton} = ui
{DataType, approach, clamp, createEnum, rand, squirrel3, stopKeyboardHandler, wrap} = util
{BIT, U8, U16, FIXED16, FIXED32, I32} = DataType
{addBehaviors, addClass, addEntity, config, sound} = game
{screenWidth, screenHeight} = config
{getController, nullController} = game.system.input

CENTER = new Point 0.5, 0.5

# Extend DisplayObject with cullCheck
cullCheckSym = Symbol.for "TG.cullCheck"

Object.defineProperty DisplayObject.prototype, cullCheckSym,
  configurable: true # For hot reloading
  value: (worldBounds) ->
    {entity} = @
    return unless entity
    {x, y, hw, hh} = entity

    childBounds =
      x: x
      y: y
      hw: hw
      hh: hh

    @visible = collides(childBounds, worldBounds)

noise1d = (index, seed) ->
  squirrel3(index, seed)

#  5  6  7
#   \ | /
# 4 -   - 0
#   / | \
#  3  2  1

to8WayDirection = (x, y) ->
  x = sign x
  if y > 0
    2 - x
  else if y < 0
    6 + x
  else
    if x < 0
      4
    else
      0

lookupTable = (key, table, properties) ->
  if typeof properties is "string"
    properties = properties.split(/\s+/)

  properties.reduce (o, prop) ->
    o[prop] = get: ->
      table[@[key]][prop]
    o
  , {}

ItemType = createEnum """
  Food
  Weapon
"""

WeaponSubtype = createEnum """
  dagger
  sword
  bow
  fireBow
"""

# Convert screen bounds to world bounds
cameraToWorldBounds = (e, camera) ->
  {x, y} = camera.viewport
  {x: screenX, y: screenY, hw: shw, hh: shh} = e

  x: screenX - x
  y: screenY - y
  hw: shw
  hh: shh

# TODO: need to add cull to tilemap
cullViewport = (e, camera) ->
  {viewport} = camera

  worldBounds = cameraToWorldBounds e, camera

  i = 0
  children = viewport.children

  while child = children[i++]
    child[cullCheckSym](worldBounds)

interact = (p, e) ->
  if e.item
    addInventory p, e
  else
    e.interact(p)

addInventory = (p, i) ->
  i.destroy = true

  sound.play "get"

  p.attackCooldown += 20
  if i.type is ItemType.Weapon
    sound.play "flipping"

    subtype = p.weapon

    tossItem p, {x: 0, y: -5},
      type: ItemType.Weapon
      subtype: p.weapon

    p.weapon = i.subtype
  else # food
    p.maxHealth += 1
    p.regenerationDuration += 600 # gain 3 hp over 10s

genWeapon = (n) ->
  if n < 7
    "sword"
  else if n < 13
    "bow"
  else
    "fireBow"

tossItem = (e, v, data) ->
  Item Object.assign data,
    x: e.x
    y: e.y - 4
    vx: v.x
    vy: v.y

# very rough approximation of 4bit poisson distribution mean=0.5
poisson_0_5 = (bits) ->
  b = bits & 0xf
  if b < 10
    0
  else if b < 15
    1
  else
    2

# Convert a 4 bit number into a ~poisson distribution mean=1 with counts 0-3
# 0: 37.5%
# 1: 37.5%
# 2: 18.75%
# 3: 06.25%
poisson_1 = (bits) ->
  b = bits & 0xf

  if b < 6
    0
  else if b < 12
    1
  else if b < 15
    2
  else
    3

rateTables = [poisson_0_5, poisson_1]

# Generate loot based on noise function, seeded from entity ID
# same position p gives same results.
spawnTreasure = (e, p=0, guaranteedDrops=0, rateTable=0) ->
  bits = noise1d(p, e.ID)
  r = bits & 0xf

  n = max rateTables[rateTable](r), guaranteedDrops

  return if n < 1

  # rand unit based on least significant bit of random value
  s = ((r & 1) or -1) / 2

  vs = [{
    x: 0
    y: -5
  }, {
    x: s
    y: -4
  }, {
    x: -s
    y: -3
  }, {
    x: s/2
    y: -5
  }, {
    x: -s/2
    y: -4
  }]

  sound.play "flipping"

  for i in [0...n]
    v = vs[i]

    if i is 1
      w = genWeapon((bits & 0xf0) >> 4)
      data =
        type: ItemType.Weapon
        subtype: w
    else
      data =
        type: "food"

    tossItem(e, v, data)

defaultBehaviors = ["display:object:sprite", "display:component:debug"]

bladeAttack = (player, weapon) ->
  {attackCooldown, controller} = player
  return if attackCooldown > 0
  return unless controller

  {x} = controller
  return unless x

  {cooldown, atkIdx} = weapon

  player.attackCooldown = cooldown

  [x, y] = player.facing

  # Bounce if attacking into floor
  # TODO: use collision check rather than onFloor status
  if y > 0 and player.onFloor
    player.vy = -4
    player.vx = -x
    player.onFloor = false

  sound.play "slash"

  Attack
    x: player.x + x * 16
    y: player.y + y * 16
    direction: to8WayDirection(x, y)
    atkIdx: atkIdx
    sourceId: player.ID

boltAttack = (player, weapon) ->
  {attackCooldown, controller, reloading} = player
  if player.reloading and attackCooldown is 1
    sound.play "blip"
    player.reloading = false
  return if attackCooldown > 0
  return unless controller

  {axes, pressed} = controller

  if pressed.x
    {cooldown, projectileIdx, releaseSound} = weapon
    player.attackCooldown = cooldown
    player.reloading = true

    theta = atan2 axes[1], axes[0]
    v = 9

    sound.play releaseSound

    Projectile
      projectileIdx: projectileIdx
      x: player.x
      y: player.y
      vx: v * cos theta
      vy: v * sin theta
      sourceId: player.ID

bowAttack = (player, weapon) ->
  {attackCooldown, controller} = player
  return if attackCooldown > 0
  return unless controller

  {x, axes} = controller
  player.bowDraw ?= 0

  player.xHeld = player.xHeld and x

  {
    baseVelocity
    cooldown
    projectileIdx
    drawMax
    drawSound
    releaseSound
  } = weapon

  if !player.xHeld
    # draw back
    if x
      sound.play drawSound
      player.xHeld = true
    else # release
      draw = player.bowDraw
      if draw >= 1
        player.attackCooldown = cooldown
        v = baseVelocity + draw / 6

        if draw is drawMax
          v += 2

        theta = atan2 axes[1], axes[0]

        sound.play releaseSound

        Projectile
          projectileIdx: projectileIdx
          x: player.x
          y: player.y
          vx: v * cos theta
          vy: v * sin theta

      player.bowDraw = 0

  if player.xHeld
    if player.bowDraw is drawMax - 1
      sound.play "draw-max"
    player.bowDraw = min player.bowDraw + 1, drawMax

weapons =
  dagger:
    attack: bladeAttack
    atkIdx: 0
    cooldown: 15
    sound: "slash"
  sword:
    attack: bladeAttack
    atkIdx: 1
    cooldown: 20
    sound: "slash"
  bow:
    attack: bowAttack
    projectileIdx: 0
    baseVelocity: 4
    cooldown: 15
    drawMax: 30
    drawSound: "draw-bow"
    projectileBehaviors: []
    releaseSound: "pew"
  fireBow:
    attack: bowAttack
    projectileIdx: 1
    baseVelocity: 2
    cooldown: 45
    drawMax: 30
    drawSound: "draw-fire-bow"
    projectileBehaviors: ["flaming"]
    releaseSound: "release-fire-bow"
  crossbow:
    attack: boltAttack
    cooldown: 120
    projectileIdx: 2
    releaseSound: "pew"

playerAttack = (player) ->
  w = weapons[player.weapon]
  w.attack(player, w)

overlap = (a, b) ->
  [
    min (a.hw + b.hw) - abs(b.x - a.x), 2 * a.hw, 2 * b.hw
    min (a.hh + b.hh) - abs(b.y - a.y), 2 * a.hh, 2 * b.hh
  ]

collides = (a, b) ->
  abs(b.x - a.x) < a.hw + b.hw and
  abs(b.y - a.y) < a.hh + b.hh

# Data Tables

Data =
  projectile: [{
    # 0 arrow
    ay: 0.25
    damage: 1
    textureKey: "arrow"
  }, {
    # 1 fire arrow
    ay: 0.25
    damage: 3
    light: true
    r1: 32
    r2: 48
    textureKey: "arrow"
    # TODO: Particles
  }, {
    # 2 bolt
    ay: 0.05
    damage: 5
    textureKey: "bolt"
  }]

  tile: [
    {}, # 0
    { # 1
      accentTop: [11, 12, 13]
      accentBottom: [4, 5]
      accentLeft: [23,24]
      accentRight: [21, 22]
      solid: true
      tile: 25
      vary: true
    }, { # 2
      ladder: true
      solid: true
      tile: 10
    }
  ]

  attack: [{ # dagger
    damage: 1
    knockback: 1
    maxAge: 2
  }, { # sword
    damage: 2
    knockback: 4
    maxAge: 3
  }]

addBehaviors
  age:
    properties:
      age: U16

    update: (e) ->
      e.age++

  expires:
    update: (e) ->
      if e.maxAge > 0 and e.age >= e.maxAge
        e.destroy = true

  attack:
    properties:
      sourceId: I32
    create: (e) ->
      e.damage ?= 1

    update: (e) ->
      targets = game.entities.filter (t) ->
        # damageable and don't damage self
        t.damageable and t.ID != e.sourceId

      hit = false
      targets.forEach (t) ->
        if !hit and collides(e, t)
          hit = e.destroy = true
          t.health -= e.damage
          sound.play "hit"

          if e.knockback
            t.vx += e.knockback * sign(t.x - e.x)
            t.vy -= 2
            t.onFloor = false

          addEntity
            behaviors: ["age", "expires", "display:object:particles"]
            maxAge: 60
            x: e.x
            y: e.y

  chest:
    properties:
      empty: BIT
      x: U16
      y: U16
      hw: get: -> 8
      hh: get: -> 8
      interact: get: ->
        (p) ->
          if !@empty
            sound.play "chest-open"
            spawnTreasure(@, game.tick, 1, 1)
            @empty = true

      interactive: get: ->
        !@empty

      textureKey: get: ->
        if @empty
          "chest-empty"
        else
          "chest"

  collisions:
    properties:
      onFloor:
        value: false
        writable: true

    update: (e) ->
      # reset floor status
      e.onFloor = false

      # Collisions
      # Tilemap obstacles + entity obstacles
      tilemap = game.entities.find (t) ->
        t.tilemap
      # TODO: room for optimization when getting tilemap obstacles
      obstacles = (tilemap?.blocks or []).concat(game.entities).filter (t) ->
        t.solid

      obstacles.forEach (o) ->
        # Don't collide with self :P
        return if o is e

        if collides e, o
          if o.ladder
            return if e.dropping

            if e.vy >= 0
              e.y -= min e.vy, (e.y + e.hh) - (o.y - o.hh)
              e.vy = 0

              # This prevents grabbing the ladder but not being on the floor
              # (sliding and unable to jump, but still not falling)
              e.onFloor = true
          else
            # solid object resolution
            [ox, oy] = overlap e, o

            # vertical resolution
            if ox >= oy
              e.vy = 0
              # from above
              if e.y < o.y
                e.y = o.y - o.hh - e.hh
              else # from below
                e.y = o.y + o.hh + e.hh
            else
              if e.bounce
                e.vx = -e.bounce * e.vx
              else
                e.vx = 0
              # from left
              if e.x < o.x
                e.x = o.x - o.hw - e.hw
              else # from right
                e.x = o.x + o.hw + e.hw

      # Check if on floor
      if e.vy >= 0
        bottom =
          x: e.x
          y: e.y + e.hh + 1
          hw: e.hw
          hh: 0.5

        objectsOn = obstacles.filter (o) ->
          return false if e.dropping and o.ladder
          collides(bottom, o)

        platform = objectsOn.find (o) ->
          o.movingPlatform

        if platform
          e.floorVelocity = platform.vx
        else
          e.floorVelocity = 0

        e.onFloor = e.onFloor or !!objectsOn.length

  damageable:
    properties:
      damageable:
        value: true
      health: U8

    update: (e) ->
      if e.health <= 0
        e.die = true
        e.destroy = true

    die: ->
      sound.play "die"

  debugger:
    update: (e) ->
      game.system.input.controllers.forEach (controller) ->
        if controller.pressed.lb
          game.debug = !game.debug

        if controller.pressed.home
          console.log "Debug !"

  "display:camera:default":
    create: (e) ->
      e.id ?= 0
      # Screen coordinates
      e.x ?= screenWidth / 2
      e.y ?= screenHeight / 2
      e.hw ?= screenWidth / 2
      e.hh ?= screenHeight / 2

    display: (e) ->
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
      lighting = new Sprite lightingTexture
      camera.addChild lighting
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

    render: (e, camera) ->
      {viewport, border} = camera

      players = game.entities.filter (p) ->
        # Locally controlled players
        p.player and p.local

      if players.length is 2
        [{x: x1, y:y1}, {x: x2, y:y2}] = players
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

      camera.filterArea.x = e.x - e.hw
      camera.filterArea.y = e.y - e.hh
      camera.filterArea.width = (shw = e.hw) * 2
      camera.filterArea.height = (shh = e.hh) * 2

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
      {width:cw, height:ch} = ctx.canvas
      ctx.globalCompositeOperation = "source-over"
      ctx.fillStyle = "#000"
      ctx.globalAlpha = 1
      ctx.clearRect 0, 0, cw, ch
      ctx.globalAlpha = 0.875
      ctx.fillRect 0, 0, cw, ch
      ctx.globalCompositeOperation = "destination-out"
      game.entities.filter (e) ->
        e.light
      .forEach ({r1, r2, x, y}) ->
        dx = floor -x + shw + e.x - viewport.x
        dy = floor -y + shh + e.y - viewport.y

        r1 = max 0, r1 + 2 * cos(game.tick / 17)
        r2 = max 0, r2 + 8 * sin(game.tick / 20)

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

  "display:component:bubble":
    display: (e) ->
      # Preview bubble
      bubble = new Sprite game.textures.bubble
      bubble.visible = false
      bubble.name = "bubble"
      bubble.anchor = new Point 0.5, 0.5

      # item icon
      icon = new Sprite
      icon.name = "icon"
      icon.anchor = new Point 0.5, 0.5
      icon.y = 2
      bubble.addChild icon

      text = new BitmapText "RB",
        fontName: "m5x7"
        tint: 0x222034
      text.y = -5
      text.anchor = new Point 0.5, 0.5
      bubble.addChild text

      return bubble

    render: (e, bubble) ->
      bubble.visible = false
      tID = e.bubbleVisible
      target = game.entityMap.get(tID)

      if target
        bubble.visible = true
        bubble.y = floor -18 + 2 * sin 2 * PI * game.tick / 60

        bubble.getChildByName("icon").texture = target.texture

  "display:component:debug":
    display: (e) ->
      bgAlpha = 0.25
      bgColor = 0xFF00FF
      borderColor = 0x00FF00

      width = 2 * e.hw
      height = 2 * e.hh

      border = new NineSlicePlane game.textures.highlight_9s, 1, 1, 1, 1
      border.tint = borderColor
      border.width = width
      border.height = height
      border.x = -e.hw
      border.y = -e.hh

      bg = new Sprite Texture.WHITE
      bg.x = bg.y = 1
      bg.width = width - 2
      bg.height = height - 2
      bg.alpha = bgAlpha
      bg.tint = bgColor

      border.addChild bg

      border.interactive = true
      border.on "pointerdown", ->
        console.log e, border.parent

      return border

    render: (e, debugBox) ->
      debugBox.visible = game.debug

      debugBox.x = -e.hw
      debugBox.y = -e.hh

  "display:hud:player":
    display: (e) ->
      c = new Container
      c.x = e.id * (screenWidth / 4)

      health = HealthBar(12)
      health.name = "health"
      health.x = 1
      health.y = 1
      c.addChild health

      text = new BitmapText "PRESS START",
        fontName: "m5x7"
      text.name = "text"
      text.x = 10
      text.y = 1
      c.addChild text

      texture = game.textures[["guy", "fox"][e.id]]
      icon = new Sprite texture
      icon.x = 102
      icon.y = 1
      icon.scale = new Point 0.5, 0.5
      c.addChild icon

      return c

    render: (e, displayObject) ->
      players = game.entities.filter (p) ->
        p.player and p.local

      target = players[e.id]

      healthBar = displayObject.getChildByName "health"
      text = displayObject.getChildByName "text"

      if target
        text.visible = false

        {health:hp, maxHealth, regenerationAmount, regenerationDuration} = target
        healthBar.visible = true
        healthBar.maxHealth = maxHealth
        healthBar.health = clamp hp, 0, maxHealth
        healthBar.regen = regenerationAmount * regenerationDuration
      else
        text.visible = true
        healthBar.visible = false

  "display:object:particles":
    create: (e) ->
      e.hw ?= 64
      e.hh ?= 64

    display: (e) ->
      n = e.n ? 15

      c = new ParticleContainer
      texture = game.textures.particle
      for i in [0...n]
        s = new Sprite texture
        s.vx = (rand(11) - 5) / 5
        s.vy = (rand(11) - 5) / 5 - 2.5
        c.addChild s

      return c

    render: (e, displayObject) ->
      c = displayObject
      c.x = e.x
      c.y = e.y
      if e.tint?
        c.tint = e.tint

      toRemove = []
      c.children.forEach (s) ->
        s.vy += 0.125

        s.x += s.vx
        s.y += s.vy

        s.scale.x = s.scale.y = 1 / (max(0, s.y) + 1 )
        if s.y > 32
          toRemove.push s

      toRemove.forEach (s) ->
        c.removeChild s

  "display:object:sprite":
    properties:
      texture: get: ->
        # TODO: Simplify and cleanup texture lookups
        {textureKey:key, item, tile, type} = @
        if key
          game.textures[key]
        else if item and type
          game[String(type)][tile]
        else
          game.textures.missing

    display: (e) ->
      {texture} = e

      # Default hw and hh to texture size if not already present
      e.hw ?= texture.frame.width / 2
      e.hh ?= texture.frame.height / 2
      sprite = new Sprite texture

      # sx and sy used for flipping sprites
      if e.sx?
        sprite.scale.x = e.sx
      if e.sy?
        sprite.scale.y = e.sy

      sprite.anchor = CENTER
      return sprite

    render: (e, sprite) ->
      {rotation, texture, x, y} = e

      sprite.texture = texture

      sprite.x = floor x
      sprite.y = floor y

      if rotation?
        sprite.rotation = rotation

  "display:object:tilemap":
    properties:
      tilemap:
        value: true

    create: (e) ->
      {data, width, height} = game.levelData

      # proto for tile blocks
      tileBase = Object.defineProperties {},
        lookupTable("tileIdx", Data.tile, """
          accentTop
          accentBottom
          accentLeft
          accentRight
          ladder
          solid
          tile
          vary
        """)

      e.blocks = blocks = []
      e.x = e.hw = width * tileWidth / 2
      e.y = e.hh = height * tileHeight / 2

      # Aggregate horizontal and vertical runs
      # Scan ahead while adjacent, flag to skip matching data,
      # add a single aggregated object

      skip = new Uint8Array(data.length)

      # Map from palette index to tile index, will become obsolete with better
      # tilemap editing tools
      tileIdxMap = new Map [
        [1, 1]
        [3, 2]
      ]

      data.forEach (n, i) ->
        if n and !skip[i]
          x = i % width
          y = floor i / width

          # These are the values of tile data, the rest are entities and skipped
          # TODO: split entities from tiles completely
          if tileIdxMap.has(n)
            adjacent = calculateAdjacent(x, y, n, data, width)

            # scan right
            xStart = x
            # Only aggregate same top/bottom adjacency status
            t = adjacent & 8
            b = adjacent & 2
            l = adjacent & 1
            mask = 0b1010

            nextAdjacent = calculateAdjacent(x+1, y, n, data, width)
            while ((x + 1 < width) and (adjacent & 4) and (nextAdjacent & mask) is (adjacent & mask))
              x++
              if x < width
                skip[x + y * width] = 1
              adjacent = nextAdjacent
              nextAdjacent = calculateAdjacent(x+1, y, n, data, width)

            # At the end of the loop if x > xStart then
            # x is pointing to a non-matching cell
            # adjacent is the adjent info for the rightmost matching cell

            span = x - xStart

            if span > 0
              x = (x + xStart) / 2

              display =
                adjacent: t + (adjacent & 4) + b + l
                height: tileHeight
                width: (span + 1) * tileWidth
            else
              # scan down
              yStart = y
              # Only aggregate same left/right adjacency status
              t = adjacent & 8
              r = adjacent & 4
              l = adjacent & 1
              mask = 0b0101

              nextAdjacent = calculateAdjacent(x, y+1, n, data, width)
              while ((y + 1 < height) and (adjacent & 2) and (nextAdjacent & mask) is (adjacent & mask))
                if y < height
                  y++
                skip[x + y * width] = 1
                adjacent = nextAdjacent
                nextAdjacent = calculateAdjacent(x, y+1, n, data, width)

              # At the end of the loop if x > xStart then
              # x is pointing to a non-matching cell
              # adjacent is the adjent info for the rightmost matching cell

              span = y - yStart
              if span > 0
                y = (y + yStart) / 2

                display =
                  adjacent: t + r + (adjacent & 2) + l
                  height: (span + 1) * tileHeight
                  width: tileWidth

              else
                display =
                  adjacent:adjacent
                  height: tileHeight
                  width: tileWidth

            block = Object.create(tileBase)

            blocks.push Object.assign block,
              x: (x+0.5) * tileWidth
              y: (y+0.5) * tileHeight
              hw: display.width / 2
              hh: display.height / 2
              adjacent: display.adjacent
              tileIdx: tileIdxMap.get(n)

    display: (e) ->
      # Is there a good way to delegate display and render calls to every item
      # in the collection? How easy is it to reuse the WallTile "class" here?
      # How about the debug component?
      # skip for now but think about it!

      container = new Container

      Object.defineProperty container, cullCheckSym,
        value: (worldBounds) ->
          # TODO: add x, y offset for world bounds

          {children} = @
          i = 0
          while child = children[i++]
            child[cullCheckSym](worldBounds)

      # TODO: Add each tile based on tile data, this will subsume
      # display:object:tile
      e.blocks.forEach (data, i) ->
        tile = createTile data, i

        # Manually adding debug component behavior, probably a little brittle
        tile.debugDisplay = game.behaviors["display:component:debug"].display(data)
        tile.addChild tile.debugDisplay

        container.addChild tile

      return container

    # No need to update since tiles are static for now
    # may need to handle animations later
    render: (e, container) ->
      container.children.forEach (c) ->
        c.debugDisplay.visible = game.debug

  enemyJump:
    properties:
      friction:
        value: 0.125
        configurable: true
      hw:
        value: 7
      hh:
        value: 7
      textureKey:
        value: "jumper"

    create: (e) ->
      e.floorVelocity ?= 0

    update: (e) ->
      jumpBondary =
        x: e.x
        y: e.y
        hw: e.hw + 16
        hh: e.hh

      # TODO: tilemap collisions

      obstacles = game.entities.filter (t) ->
        t.player or (t.solid and !t.ladder)

      nearObstacle = obstacles.some (o) ->
        !o.ladder and collides jumpBondary, o

      if e.onFloor
        r = e.noise1d(game.tick)

        r1 = r & 0xff
        r2 = ((r & 0xffff00) >> 8) / 0x10000

        if nearObstacle or r1 is 0
          theta = PI * r2

          e.vy = -5 * sin(theta)
          e.vx = cos(theta)
          e.onFloor = false

    die: (e) ->
      spawnTreasure(e, game.tick)

  facing:
    create: (e) ->
      e.facingPrevX ?= 1
      e.facing ?= [1, 0]

    update: (e) ->
      {controller} = e
      [dx, dy] = controller.axes
      prevX = e.facingPrevX

      T = 0.25

      if dy > T
        y = 1
      else if dy < -T
        y = -1
      else
        y = 0

      if dx > T
        e.facingPrevX = x = 1
      else if dx < -T
        e.facingPrevX = x = -1
      else
        if y is 0
          x = prevX
        else
          x = 0

      e.facing = [x, y]

  flaming:
    create: (e) ->
      e.light ?= true
      e.r1 ?= 32
      e.r2 ?= 48

    update: (e) ->
      if game.tick % 4 is 0
        addEntity
          behaviors: ["age", "expires", "display:object:particles"]
          maxAge: 15
          tint: 0xF00000
          n: 3
          x: e.x
          y: e.y

  hazard:
    properties:
      hazardDelta:
        value:
          hw: 0
          hh: 0
        writable: true
        configurable: true
        enumerable: true
      hazardDamage:
        value: 1
        writable: true
        configurable: true
        enumerable: true

    update: (e) ->
      players = game.entities.filter (e) ->
        e.player

      collisionBox =
        x: e.x
        y: e.y
        hw: e.hw + e.hazardDelta.hw
        hh: e.hh + e.hazardDelta.hh

      players.forEach (p) ->
        if collides collisionBox, p
          [dx, dy] = overlap e, p
          sx = sign(p.x - e.x) or 1
          p.vx += 3 * sx
          p.vy = -3

          e.vx = -2 * sx
          e.vy = -4

          p.health--
          p.onFloor = false
          sound.play "hurt"
          # gamepads[p.id].vibrate
          #   startDelay: 0
          #   duration: 150
          #   weakMagnitude: 0.5
          #   strongMagnitude: 0.5

          addEntity
            behaviors: ["age", "expires", "display:object:particles"]
            maxAge: 60
            tint: 0x800000
            n: 10
            x: p.x
            y: p.y

  "input:controller":
    properties:
      inputId: U8
      clientId: U8
      controller: get: ->
        getController(@inputId, @clientId) or nullController
      local: get: ->
        @clientId is game.system.network.clientId

  item:
    properties:
      friction:
        value: 1

      interactive: get: ->
        @onFloor

      item:
        value: true

      rotation: get: ->
        if @onFloor
          0
        else
          # TODO: PRNG seed
          (game.tick + abs(@ID)) * 2 * PI / 20

      tile: get: ->
        noise1d(-11, abs(@ID)) % 64

      _subtype: U8
      subtype: WeaponSubtype.propertyFor "_subtype"

      _type: U8
      type: ItemType.propertyFor "_type"

      textureKey: get: ->
        if @type is ItemType.Weapon
          String(@subtype) + "-item"

    create: (e) ->
      e.onFloorPrev = true

    update: (e) ->
      if e.onFloor and !e.onFloorPrev
        sound.play "thud"

      e.onFloorPrev = e.onFloor

  light:
    create: (e) ->
      e.light ?= true
      e.r1 ?= 60
      e.r2 ?= 120

    update: (e) ->

  physics:
    properties:
      # Default values that can be overriden
      vyMax:
        value: 6
        configurable: true

      # These are computed based on behaviors
      ax:
        value: ax ? 0
        writable: true
        configurable: true
      ay:
        value: ay ? 0
        writable: true
        configurable: true

      # This data is part of the entity's state
      x: FIXED32()
      y: FIXED32()
      vx: FIXED16()
      vy: FIXED16()

    create: (e) ->
      e.friction ?= 0

      e.floorVelocity ?= 0

    update: (e) ->
      e.vx += e.ax
      if e.friction and e.onFloor
        e.vx = approach e.vx, e.floorVelocity, e.friction

      e.vy += e.ay unless e.onFloor
      e.vy = clamp e.vy, -e.vyMax, e.vyMax

      e.x += e.vx
      e.y += e.vy

  # Player item pickup behavior
  picker:
    create: (p) ->
      p.bubbleVisible ?= false

    update: (p) ->
      p.bubbleVisible = false
      if p.onFloor
        [nearest] = game.entities.filter (i) ->
          i.interactive and !i.destroy and collides(p, i)
        .sort (a, b) ->
          dxa = abs a.x - p.x
          dxb = abs b.x - p.x

          dxa - dxb

        if nearest
          p.bubbleVisible = nearest.ID

          if p.controller?.rb and p.attackCooldown <= 0
            interact p, nearest

  player:
    properties:
      attackCooldown: U8
      dropping: BIT
      hw: get: -> 6
      hh: get: -> 6
      health: FIXED16()
      maxHealth: U8
      modelIdx: U8
      player: get: -> true
      regenerationAmount: get: -> 1/256
      regenerationDuration: U16
      textureKey: get: ->
        # TODO: Model table, animations, etc.
        if @modelIdx is 0
          "guy"
        else
          "fox"

    create: (p) ->
      p.floorVelocity ?= 0
      p.friction ?= 0.075
      p.jumpHeld ?= false
      p.items ?= []
      p.light ?= true
      p.r1 ?= 100
      p.r2 ?= 200
      p.weapon ?= "dagger"

    update: (p) ->
      if p.regenerationDuration > 0
        p.health += p.regenerationAmount
        p.regenerationDuration = max 0, p.regenerationDuration-1

      if p.health <= 0
        p.destroy = true
        p.die = true
        return
      else if p.health >= p.maxHealth
        p.health = p.maxHealth

      maxSpeed = 1.5
      if p.attackCooldown > 0
        p.attackCooldown--

      {controller} = p
      {axes, a, b, x, y, lb, up, right, pressed} = controller
      [dx, dy] = axes

      if pressed.up
        spawnTreasure(p, game.tick, 1)

      # Controller deadzone
      if abs(dx) > 0.25
        p.vx = clamp p.vx + dx * 0.125, -maxSpeed, maxSpeed

      if abs(dy) > 0.25
        ;

      # jump is held for as long as we're holding a since starting the jump
      p.jumpHeld = p.jumpHeld and a

      if p.onFloor
        # Jump action
        if pressed.a
          # Holding down
          if p.facing[1] is 1
            p.dropping = true
            p.onFloor = false
          else
            p.onFloor = false
            p.jumpHeld = true
            p.vy += -5

      if p.onFloor
        p.ay = 0
      else if p.jumpHeld and p.vy < 0
        p.ay = 0.2
      else
        p.ay = 0.75

      playerAttack(p)
      # Continue dropping as long as we hold down
      p.dropping = p.dropping and p.facing[1] is 1

    die: ->
      check = game.entities.reduce ({age, x, y}, {age:eAge, x:eX, y: eY}) ->
        age: age + (eAge|0)
        x: x + (eY|0)
        y: y + (eY|0)
      , {age: 0, x: 0, y: 0}

      console.log check

  playerSpawn:
    properties:
      x: U16
      y: U16
      playerSpawn:
        value: true

  prng:
    properties:
      noise1d: get: ->
        (n) ->
          squirrel3(n, @seed)
      seed: get: ->
        squirrel3 abs(@ID), game.seed

  # Projectiles rotate to face their direction of travel
  projectile:
    properties:
      Object.assign lookupTable("projectileIdx", Data.projectile, """
        ay
        damage
        light
        r1
        r2
        textureKey
      """),
        projectileIdx: U8
        sourceId: I32
        # Dropping keeps projectile from being stopped by ladders
        dropping:
          value: true
          writable: false
          configurable: true

        rotation:
          get: ->
            atan2(@vy, @vx)
          configurable: true

        vyMax:
          value: 10
          configurable: true

    update: (e) ->
      e.destroy ||= e.onFloor

  spawnManager:
    update: (e) ->
      playerIds = new Set

      players = game.entities.forEach (p) ->
        if p.player
          playerIds.add p.controller.key

      game.system.input.controllers.forEach (c) ->
        if c.pressed.start and !playerIds.has(c.key)

          spawnPoint = game.entities.filter (e) ->
            e.playerSpawn

          # TODO: prng + seed?
          {x, y} = rand spawnPoint

          Player
            modelIdx: rand 2
            inputId: c.id
            clientId: c.clientId
            x: x
            y: y

Attack = addClass
  behaviors: defaultBehaviors.concat ["age", "expires", "attack"]
  properties:
    Object.assign
      attack: get: -> true
      x: FIXED32()
      y: FIXED32()
      direction: U8 # 8 way direction, actually just 3 bits
      sx: get: ->
          if 3 <= @direction <= 5
            -1
          else
            1
      sy: get: ->
          if 5 <= @direction <= 7
            -1
          else
            1
      horizontal: get: ->
        (@direction & 0b11) is 0
      vertical: get: ->
        (@direction & 0b11) is 2
      textureKey: get: ->
        if @horizontal
          "slash_x"
        else if @vertical
          "slash_y"
        else
          "slash_xy"
      hw: get: ->
        if @vertical
          2
        else
          6
      hh: get: ->
        if @horizontal
          2
        else
          6
      atkIdx: U8
    , lookupTable("atkIdx", Data.attack, """
        damage
        knockback
        maxAge
      """)

BreakableWall = addClass
  behaviors: defaultBehaviors.concat ["damageable"]
  defaults:
    health: 2
    solid: true
    textureKey: "floor"


FrogSquid = addClass
  behaviors: defaultBehaviors.concat [
    "prng"
    "enemyJump"
    "damageable"
    "physics"
    "collisions"
    "hazard"
  ]
  defaults:
    ay: 0.25
    health: 3

Item = addClass
  behaviors: defaultBehaviors.concat ["prng", "item", "physics", "collisions"]
  defaults:
    ay: 0.25

LavaTile = addClass
  behaviors: defaultBehaviors.concat ["hazard", "light"]
  defaults:
    textureKey: "lava"
    r1: 1
    r2: 16
    hazardDelta:
      hw: 1
      hh: 1

MushroomPlatform = addClass
  behaviors: defaultBehaviors.concat ["damageable", "physics", "collisions",]
  defaults:
    textureKey: "mush"
    bounce: 1
    health: 8
    movingPlatform: true
    solid: true
    vx: 1
    ay: 0.25
    hh: 15

Player = addClass
  behaviors: defaultBehaviors.concat([
    "input:controller"
    "display:component:bubble"
    "facing"
    "player"
    "physics"
    "collisions"
    "damageable"
    "picker"
  ])
  ,
  defaults:
    health: 6
    maxHealth: 6

Projectile = addClass
  behaviors: defaultBehaviors.concat [
    "physics"
    "collisions"
    "attack"
    "projectile"
  ]

Torch = addClass
  behaviors: defaultBehaviors.concat ["light"]
  properties:
    x: FIXED32()
    y: FIXED32()
    hw: FIXED16(2)
    hh: FIXED16(2)

  defaults:
    textureKey: "torch"

TreasureChest = addClass
  behaviors: defaultBehaviors.concat ["chest"]

makers =
  5: ({x, y}) ->
    Torch
      x: x
      y: y

  11: ({x, y}) ->
    FrogSquid
      x: x
      y: y

  20: ({x, y}) ->
    addEntity
      behaviors: ["playerSpawn"]
      x: x
      y: y

  23: ({x, y}) ->
    BreakableWall
      x: x
      y: y

  27: ({x, y}) ->
    LavaTile
      x: x
      y: y

  28: ({x, y}) ->
    MushroomPlatform
      x: x
      y: y

  30: ({x, y}) ->
    TreasureChest
      x: x
      y: y

# 0b1111 top,right,bottom,left
calculateAdjacent = (x, y, n, data, width) ->
  v = data[(y - 1) * width + x]
  t = !v? or v is n

  if x < width - 1
    v = data[y * width + x + 1]
    r = !v? or v is n
  else
    r = 1

  v = data[(y + 1) * width + x]
  b = !v? or v is n

  if x >= 1
    v = data[y * width + x - 1]
    l = !v? or v is n
  else
    l = 1

  t * 8 + r * 4 + b * 2 + l

tileHeight = 16
tileWidth = 16

loadLevel = (path, offset={x:0, y:0}) ->
  parseLevel(path)
  .then (levelData) ->
    game.levelData = levelData
    return

game.start = ->
  addEntity
    behaviors: ["debugger", "spawnManager"]

  addEntity
    behaviors: ["display:camera:default"]
    id: 0

  addEntity
    behaviors: ["display:camera:default"]
    id: 1

  addEntity
    behaviors: ["display:hud:player"]
    id: 0
  addEntity
    behaviors: ["display:hud:player"]
    id: 1

  # TODO: Preloader / Live Edit
  Promise.all([
   loadSpritesheet "/game/images/tileset.png"
   loadSpritesheet "/game/images/food.png"
  ]).then ([tileset, food]) ->
    game.tileset = tileset
    game.Food = food
  .then ->
    loadLevel("/game/levels/0.png")
    # loadLevel("/game/rooms/tower.png")
    # loadLevel("/game/rooms/test.png")
    # loadLevel("/game/rooms/treasure-secret-right.png", {x: 9*16, y: 0})
  .then ->
    # Add Tilemap
    addEntity
      behaviors: ["display:object:tilemap"]

    # Add Entities
    {data, width, height} = game.levelData

    data.forEach (n, i) ->
      x = i % width
      y = floor i / width

      if f = makers[n]
        f
          x: (x+0.5) * tileWidth
          y: (y+0.5) * tileHeight
  .catch console.error


# Gnarly method for creating a PIXI container for tile blocks
createTile = (e, index) ->
  {adjacent, hw, hh, vary, x, y, tileIdx} = e

  {
    accentTop
    accentRight
    accentBottom
    accentLeft
    ladder
    solid
    tile
    vary
  } = Data.tile[tileIdx]

  {seed, tileset} = game

  texture = tileset[tile]

  # Generate bits and use result as next seed
  nextRand = ->
    seed = noise1d(index, seed)

  width = hw * 2
  height = hh * 2

  container = new Container
  container.x = x
  container.y = y
  container.entity = e

  thw = tileWidth / 2
  thh = tileHeight / 2

  x = 0
  y = 0
  while y < height
    x = 0
    while x < width
      bits = nextRand()
      mask = 1
      randomUnits = [0...6].map (i) ->
        unit = ((bits & mask) >> i) || -1
        mask <<= 1
        return unit

      randomIndex0 = (0xf00 & bits) >> 8
      randomIndex1 = (0xf000 & bits) >> 12
      randomIndex2 = (0xf0000 & bits) >> 16
      randomIndex3 = (0xf00000 & bits) >> 20

      sprite = new Sprite texture
      sprite.x = x - hw + thw
      sprite.y = y - hh + thh
      sprite.anchor = CENTER
      if vary
        sprite.scale.x = randomUnits[0]
        sprite.scale.y = randomUnits[1]

      container.addChild sprite

      # Add accents on edges based on non-adjacency to tiles of same type
      aTexture = accentLeft and tileset[wrap(accentLeft, randomIndex0)]
      if x is 0 and adjacent? and !(adjacent & 1) and aTexture
        accent = new Sprite aTexture
        accent.x = x - hw + thw
        accent.y = y - hh + thh
        accent.anchor = CENTER
        if vary
          accent.scale.y = randomUnits[2]

        container.addChild accent

      aTexture = accentRight and tileset[wrap(accentRight, randomIndex1)]
      if x is width - tileWidth and adjacent? and !(adjacent & 4) and aTexture
        accent = new Sprite aTexture
        accent.x = x - hw + thw
        accent.y = y - hh + thh
        accent.anchor = CENTER
        if vary
          accent.scale.y = randomUnits[3]

        container.addChild accent

      aTexture = accentTop and tileset[wrap(accentTop, randomIndex2)]
      if y is 0 and adjacent? and !(adjacent & 8) and aTexture
        accent = new Sprite aTexture
        accent.x = x - hw + thw
        accent.y = y - hh + thh
        accent.anchor = CENTER
        if vary
          accent.scale.x = randomUnits[4]

        container.addChild accent

      aTexture = accentBottom and tileset[wrap(accentBottom, randomIndex3)]
      if y is height - tileHeight and adjacent? and !(adjacent & 2) and aTexture
        accent = new Sprite aTexture
        accent.x = x - hw + thw
        accent.y = y - hh + thh
        accent.anchor = CENTER
        if vary
          accent.scale.x = randomUnits[5]

        container.addChild accent

      x += tileWidth
    y += tileHeight

  return container

window.tileMode = (name, size) ->
  game.destroy()

  addEntity
    behaviors: ["display:hud:tile-editor"]
    size: size
    snap: size
    texture: name

# In Game Editors

addBehaviors
  "display:hud:tile-editor":
    create: (e) ->
      e.x ?= 0
      e.y ?= 0
      e.width ?= 640
      e.height ?= 360
      e.margin ?= 2
      e.size ?= 16
      e.snap ?= 16
      e.texture ?= "rotting-pixels-tileset"

    display: (e) ->
      editor = new Container

      {size, snap, margin} = e
      scale =
        x: 1
        y: 1

      center = new Point 0.5, 0.5

      setTileProps = (s) ->
        s.texture = window.activeSprite.texture
        if randomFlip
          s.scale.x = (rand(2) - 0.5) * 2
          s.scale.y = (rand(2) - 0.5) * 2
        else
          s.scale.x = scale.x
          s.scale.y = scale.y
        s.data = window.activeSprite.data

      prevX = null
      prevY = null
      paint = (data) ->
        return unless window.activeSprite
        {buttons, global} = data

        {x, y} = global
        # Snap to tile size
        x = floor(x / snap) * snap
        y = floor(y / snap) * snap

        return if prevX is x and prevY is y
        prevX = x
        prevY = y

        if buttons
          s = new Sprite window.activeSprite.texture
          setTileProps s
          s.anchor = center
          s.x = x + snap / 2
          s.y = y + snap / 2
          s.interactive = true
          s.pointerdown = ({currentTarget})->
            if window.activeSprite
              setTileProps(currentTarget)

          layers[activeLayer].addChild s

      background = new TilingSprite game.textures.editorBG, e.width, e.height
      background.interactive = true
      background.on "pointerdown", ({data}) ->
        paint(data)

      editor.addChild background

      viewport = new Container
      editor.viewport = viewport
      editor.addChild viewport

      layers = [
        new Container
        new Container
        new Container
        new Container
        new Container
        new Container
        new Container
      ]
      layers.forEach (layer) -> viewport.addChild layer

      saveButton = UIButton "Save", ->
        console.log
          layers: layers.map (layer) ->
            layer.children.map ({x, y, data, scale}) ->
              {
                x, y,
                i: data.index,
                s: {x: scale.x, y: scale.y}
              }
      saveButton.x = 2
      saveButton.y = 360 - saveButton.height - 2
      editor.addChild saveButton

      addButton = (name, fn) ->
        button = UIButton name, fn
        button.x = offset
        button.y = margin
        editor.addChild button
        offset += button.width + margin
        return button

      setActiveLayer = (i) ->
        layerButtons.forEach (b) ->
          b.active = false

        activeLayer = i
        layerButtons[i].active = true
        # Only children of the active layer are interactive
        layers.forEach (l, j) ->
          l.children.forEach (child) ->
            child.interactive = j is activeLayer

      activeLayer = floor layers.length / 2
      offset = margin
      layerButtons = layers.map (layer, i) ->
        layerButton = addButton "#{i+1}", setActiveLayer.bind(null, i)

      layerButtons[activeLayer].active = true
      offset += 2 * margin

      randomFlip = false
      toggleHorizontalFlip = ->
        scale.x = -1 * scale.x
        hsButton.active = scale.x is -1
        randButton.active = randomFlip = false
      hsButton = addButton "H", toggleHorizontalFlip

      toggleVerticalFlip = ->
        scale.y = -1 * scale.y
        vsButton.active = scale.y is -1
        randButton.active = randomFlip = false
      vsButton = addButton "V", toggleVerticalFlip

      toggleRandomFlip = ->
        randomFlip = !randomFlip
        randButton.active = randomFlip
        scale.x = 1
        scale.y = 1
        hsButton.active = vsButton.active = false
      randButton = addButton "Rand", toggleRandomFlip

      ## Palette
      palette = new Container
      palette.interactive = true

      baseTexture = game.textures[e.texture].baseTexture

      w = size
      h = size
      tilesWide = baseTexture.width / w
      tilesTall = baseTexture.height / h
      numTiles = tilesWide * tilesTall

      bg = new TilingSprite game.textures.translucentBG,
        tilesWide * (w + margin) + margin,
        360 - 2 * margin
      palette.addChild bg

      palette.x = 640 - bg.width - margin
      palette.y = margin

      highlight = new NineSlicePlane game.textures.highlight_9s, 1, 1, 1, 1
      highlight.alpha = 0.75
      highlight.x = highlight.y = margin - 1
      highlight.width = w + 2
      highlight.height = h + 2
      palette.addChild highlight

      i = 0
      while i < numTiles
        x = i % tilesWide
        y = floor i / tilesWide
        tex = new Texture baseTexture,
          new Rectangle x * w, y * w, w, h

        sprite = new Sprite tex
        sprite.data =
          index: i
        sprite.x = margin + x * (w + margin)
        sprite.y = margin + y * (h + margin)
        sprite.interactive = true
        sprite.on "pointerdown", ({currentTarget}) ->
          window.activeSprite = currentTarget
          highlight.x = currentTarget.x - 1
          highlight.y = currentTarget.y - 1

        palette.addChild sprite

        i++

      editor.addChild palette

      keyHandler = (e) ->
        return if e.defaultPrevented
        return if stopKeyboardHandler e, e.target, ""
        {key, code} = e

        n = parseInt(key, 10)
        if !isNaN(n) and n > 0
          setActiveLayer n - 1
          return e.preventDefault()

        handled = false

        switch key
          when "h"
            handled = true
            toggleHorizontalFlip()
          when "v"
            handled = true
            toggleVerticalFlip()
          when "r"
            handled = true
            toggleRandomFlip()

        if handled
          e.preventDefault()

      document.addEventListener "keydown", keyHandler
      e._cleanup = ->
        document.removeEventListener "keydown", keyHandler

      return editor

    render: (e, editor) ->
      [viewport] = editor.children

      if e.target
        {x, y} = e.target

        viewport.x = floor -x + shw + e.x
        viewport.y = floor -y + shh + e.y

    destroy: (e) ->
      e._cleanup?()
