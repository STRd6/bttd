
{ squirrel3 } = TinyGame.util
{ sign } = Math

#
###*
```text
 5  6  7
  \ | /
4 -   - 0
  / | \
 3  2  1
```

@param x {number}
@param y {number}
###
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

module.exports = {
  # Extend DisplayObject with cullCheck
  cullCheckSym: Symbol.for "TG.cullCheck"
  lookupTable
  noise1d: squirrel3
  to8WayDirection
}
