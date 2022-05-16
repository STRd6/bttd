{Container, Point, Sprite} = PIXI
{wrap} = TinyGame.util

Data = require "./data"
{cullCheckSym, lookupTable, noise1d} = require "./util"
{tileWidth, tileHeight} = require "./const"

CENTER = new Point 0.5, 0.5

game.addBehaviors
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

# Gnarly method for creating a PIXI container for tile blocks
createTile = (e, index) ->
  {adjacent, hw, hh, vary, x, y, tileIdx} = e

  {
    accentTop
    accentRight
    accentBottom
    accentLeft
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
