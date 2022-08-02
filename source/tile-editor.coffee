{Container, NineSlicePlane, Point, Rectangle, Sprite, Texture, TilingSprite} = PIXI
{rand, stopKeyboardHandler} = TinyGame.util
{UIButton} = TinyGame.ui
{addBehaviors, addEntity} = game
{floor} = Math

#
###*
@param name {string}
@param size {number}
###
#@ts-ignore
window.tileMode = (name, size) ->
  game.hardReset()

  addEntity
    behaviors: ["display:hud:tile-editor"]
    size: size
    snap: size
    texture: name

# In Game Editors

#
###* @type {Sprite & {data: unknown} | null} TODO ###
activeSprite = null

addBehaviors
  "display:hud:tile-editor":
    ###* @param e {any} TODO ###
    create: (e) ->
      e.x ?= 0
      e.y ?= 0
      e.width ?= 640
      e.height ?= 360
      e.margin ?= 2
      e.size ?= 16
      e.snap ?= 16
      e.texture ?= "rotting-pixels-tileset"

    ###* @param e {any} TODO ###
    display: (e) ->
      editor = new Container

      {size, snap, margin} = e
      scale =
        x: 1
        y: 1

      center = new Point 0.5, 0.5

      #
      ###*
      @param s {Sprite & {data: unknown}}
      ###
      setTileProps = (s) ->
        return unless activeSprite
        s.texture = activeSprite.texture
        if randomFlip
          s.scale.x = (rand(2) - 0.5) * 2
          s.scale.y = (rand(2) - 0.5) * 2
        else
          s.scale.x = scale.x
          s.scale.y = scale.y
        s.data = activeSprite.data

      #@ts-ignore
      prevX = null
      #@ts-ignore
      prevY = null
      #
      ###* @param data {any} TODO ###
      paint = (data) ->
        return unless activeSprite
        {buttons, global} = data

        {x, y} = global
        # Snap to tile size
        x = floor(x / snap) * snap
        y = floor(y / snap) * snap

        #@ts-ignore
        return if prevX is x and prevY is y
        prevX = x
        prevY = y

        if buttons
          s = new Sprite activeSprite.texture
          #@ts-ignore
          setTileProps s
          #@ts-ignore
          s.anchor = center
          s.x = x + snap / 2
          s.y = y + snap / 2
          s.interactive = true
          #@ts-ignore
          s.pointerdown = ({currentTarget})->
            if activeSprite
              setTileProps(currentTarget)

          #@ts-ignore
          layers[activeLayer].addChild s
        return

      bgTexture = game.textures.editorBG
      assert bgTexture
      background = new TilingSprite bgTexture, e.width, e.height
      background.interactive = true
      background.on "pointerdown", ({data}) ->
        paint(data)

      editor.addChild background

      viewport = new Container
      #@ts-ignore
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
            #@ts-ignore
            layer.children.map ({x, y, data, scale}) ->
              {
                x, y,
                i: data.index,
                s: {x: scale.x, y: scale.y}
              }
      saveButton.x = 2
      saveButton.y = 360 - saveButton.height - 2
      editor.addChild saveButton

      #
      ###*
      @param name {string}
      @param fn {(args: any[]) => void}
      @return {Container & {active: boolean}}
      ###
      addButton = (name, fn) ->
        button = UIButton name, fn
        button.x = offset
        button.y = margin
        editor.addChild button
        offset += button.width + margin
        #@ts-ignore
        return button

      #
      ###* @param i {number} ###
      setActiveLayer = (i) ->
        layerButtons.forEach (b) ->
          b.active = false

        activeLayer = i
        #@ts-ignore
        layerButtons[i].active = true
        # Only children of the active layer are interactive
        layers.forEach (l, j) ->
          l.children.forEach (child) ->
            child.interactive = j is activeLayer

      activeLayer = floor layers.length / 2
      offset = margin
      layerButtons = layers.map (_layer, i) ->
        addButton "#{i+1}", setActiveLayer.bind(null, i)

      #@ts-ignore
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

      #@ts-ignore
      baseTexture = game.textures[e.texture].baseTexture

      w = size
      h = size
      tilesWide = baseTexture.width / w
      tilesTall = baseTexture.height / h
      numTiles = tilesWide * tilesTall

      translucentBGTexture = game.textures.translucentBG
      assert translucentBGTexture
      bg = new TilingSprite translucentBGTexture,
        tilesWide * (w + margin) + margin,
        360 - 2 * margin
      palette.addChild bg

      palette.x = 640 - bg.width - margin
      palette.y = margin

      highlight9sTexture = game.textures.highlight_9s
      assert highlight9sTexture
      highlight = new NineSlicePlane highlight9sTexture, 1, 1, 1, 1
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
        #@ts-ignore
        sprite.data =
          index: i
        sprite.x = margin + x * (w + margin)
        sprite.y = margin + y * (h + margin)
        sprite.interactive = true
        sprite.on "pointerdown", ({currentTarget}) ->
          activeSprite = currentTarget
          highlight.x = currentTarget.x - 1
          highlight.y = currentTarget.y - 1

        palette.addChild sprite

        i++

      editor.addChild palette

      #
      ###* @param e {KeyboardEvent} ###
      keyHandler = (e) ->
        return if e.defaultPrevented
        #@ts-ignore
        return if stopKeyboardHandler e, e.target, ""
        {key} = e

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

    ###*
    @param e {any} TODO
    @param editor {Container}
    ###
    render: (e, editor) ->
      [viewport] = editor.children
      assert viewport

      if e.target
        {x, y} = e.target

        viewport.x = floor -x + shw + e.x
        viewport.y = floor -y + shh + e.y
      return

    ###* @param e {any} TODO ###
    destroy: (e) ->
      e._cleanup?()

module.exports = {}

#
###*
@typedef {import("@danielx/tiny-game").PIXI.Container} Container
@typedef {import("@danielx/tiny-game").PIXI.Sprite} Sprite
###
