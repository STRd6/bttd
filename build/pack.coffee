# Copied from danielx.net/tiny-game/system/fs/fdfs.coffee

{Blob} = require("node:buffer")

{readdir, readFile, writeFile} = require "fs/promises"
{resolve, sep} = require("path")

anyMatch = new RegExp("")

#
###*
Traverse a directory recursively yielding each path that matches the given
RegExp.

@param dir {string}
@param [regExp] {RegExp}
@return {AsyncGenerator<string>}
###
getFiles = (dir, regExp) ->
  entities = await readdir dir,
    withFileTypes: true

  regExp ?= anyMatch

  for entity from entities
    res = resolve dir, entity.name
    if entity.isDirectory()
      yield from getFiles(res, regExp)
    else if res.match regExp
      yield res

{floor, random, pow} = Math
randomHex = ->
  try
    return Array.from(crypto.getRandomValues(new Uint8Array(8))).map (n) ->
      n.toString(16).padStart(2, "0")
    .join('')

  return floor(random() * pow(2, 53)).toString(16).padStart(14, '0')

crlf = "\r\n"

#
###*
@param entries {[string, Buffer][]}
@param [boundary] {string}
###
pack = (entries, boundary) ->
  boundary ?= "whimsyspacefdfs" + randomHex()

  pieces = []
  entries.forEach ([name, value]) ->
    pieces.push "--", boundary, crlf
    disposition = "Content-Disposition: form-data; name=#{JSON.stringify(name)}"

    disposition += "; filename=#{JSON.stringify(name)}"
    pieces.push disposition, crlf
    if name.match /\.js$|\.coffee$|\.json$/
      # Text types
      type = "text/plain; charset=utf-8"
    else # TODO: actual content type
      type = "application/octet-stream"

    pieces.push "Content-Type: #{type}", crlf, crlf
    pieces.push value, crlf

  pieces.push "--", boundary, "--"

  Buffer.from await (new Blob(pieces)).arrayBuffer()

if require.main is module
  rootDir = "assets/"
  outPath = "dist/data.txt"

  base = resolve(rootDir) + sep
  #
  ###* @type {[string, Buffer][]} ###
  entries = []

  #@ts-ignore top level await
  for await path from getFiles(base)
    relative = path.replace(base, "").replace(/\\/g, "/")
    console.log relative
    ###* @type {[string, Buffer]} ###
    #@ts-ignore top level await
    entry = [relative, await readFile(path)]
    entries.push entry

  #@ts-ignore top level await
  buf = await pack entries
  console.log buf

  #@ts-ignore top level await
  await writeFile(outPath, buf)

  process.exit()
