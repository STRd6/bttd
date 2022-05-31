
{ squirrel3 } = TinyGame.util
{ sign } = Math

#
###* @type {import("../types/util").poisson_0_5} ###
poisson_0_5 = (bits) ->
  b = bits & 0xf
  if b < 10
    0
  else if b < 15
    1
  else
    2

#
###* @type {import("../types/util").poisson_1} ###
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

#
###* @type {import("../types/util").to8WayDirection} ###
to8WayDirection = (x, y) ->
  x = sign x
  if y > 0
    #@ts-ignore number -> U3
    2 - x
  else if y < 0
    #@ts-ignore number -> U3
    6 + x
  else
    if x < 0
      4
    else
      0

#
###* @type {import("../types/util").lookupTable} ###
lookupTable = (key, table, properties) ->
  #
  ###* @type {Exclude<typeof properties, string>} ###
  #@ts-ignore
  props = null

  if typeof properties is "string"
    #@ts-ignore
    props = properties.split(/\s+/)
  else
    props = properties

  #
  ###* @type {{[K in keyof typeof table[number]]: {get(this: {[S in typeof key]: number}): typeof table[number][K]}}} ###
  #@ts-ignore
  result = {}

  props.reduce (o, prop) ->
    o[prop] = get: ->
      ###* @type {number} ###
      id = @[key]
      assert id?
      lookup = table[id]
      assert lookup
      lookup[prop]
    o
  , result

#
###* @type {import("../types/util").noise1d} ###
noise1d = squirrel3

#
###* @type {import("../types/util")} ###
module.exports = {
  # Extend DisplayObject with cullCheck
  cullCheckSym: Symbol.for "TG.cullCheck"
  lookupTable
  ###*
  Ahoy!
  ###
  noise1d
  poisson_0_5
  poisson_1
  squirrel3
  to8WayDirection
}
