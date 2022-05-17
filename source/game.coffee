{PI, abs, cos, floor, max, min, sign, sin} = Math
{BitmapText, Container, DisplayObject, NineSlicePlane, ParticleContainer, Point, Sprite} = PIXI
{ext, ui, util} = TinyGame
{loadSpritesheet, parseLevel} = ext
{HealthBar} = ui
{DataType, approach, clamp, createEnum, rand, squirrel3} = util
{BIT, U8, U16, FIXED16, FIXED32, I32} = DataType
{addBehaviors, addClass, addEntity, config, sound} = game
{screenWidth} = config
{getController, nullController} = game.system.input

{tileWidth, tileHeight} = require("./const")
{
  cullCheckSym
  lookupTable
  noise1d
  to8WayDirection
} = require("./util")
Data = require "./data"

require "./camera"
require "./tile-editor"
require "./tilemap"

CENTER = new Point 0.5, 0.5

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

