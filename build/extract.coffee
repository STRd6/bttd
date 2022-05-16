{Blob} = require("node:buffer")

# Copied from danielx.net/tiny-game/system/fs/fdfs.coffee

# FormData as a file system
crlf = "\r\n"

# This implementation isn't completely robust, but since I'm controlling the
# published blob it is fine for now.
###*
@param text {string}
@param f {{set(name: string, blob: Blob): void }}
###
parseFormDataText = (text, f) ->
  # boundary is first line
  pos = text.indexOf(crlf)
  if pos is -1
    throw new Error "Malformed form data"

  boundary = text.slice(0, pos)
  pos += 2

  while pos != -1
    end = text.indexOf(boundary, pos)

    chunk = text.slice(pos, end - 2)

    # match headers
    headerEnd = chunk.indexOf(crlf + crlf)
    break if headerEnd is -1
    ###* @type {{[key: string]: string}}###
    #@ts-ignore
    headers = {}
    chunk.slice(0, headerEnd).split(crlf).forEach (headerText) ->
      if headerText.length
        match = headerText.match(/^([^:]+): *(.*)$/)
        if match
          header = match[1]
          value = match[2]
          if header and value
            #@ts-ignore
            headers[header] = value
      return

    content = chunk.slice(headerEnd+4, end)

    type = headers["Content-Type"]

    length = content.length
    buffer = new Uint8Array(length)
    i = 0
    while i < length
      buffer[i] = content.charCodeAt(i)
      i++

    match = headers["Content-Disposition"].match(/name="([^"]+)"; filename="([^"]+)"/)
    if match
      [_, name] = match
      if name
        f.set name, new Blob([buffer], type: type)

    pos = end + 2

  return

# Added CLI stuff
if require.main is module
  {readFile, writeFile, mkdir} = require "fs/promises"
  {dirname} = require "path"

  readFile "data.txt"
  .then (buffer) ->
    buffer.toString("binary")
  .then (str) ->
    parseFormDataText str,
      set: (name, blob) ->
        return if name.match /@/

        path = "out/#{name}"
        dir = dirname(path)
        await mkdir dir, recursive: true

        buffer = await blob.arrayBuffer()
        writeFile path, Buffer.from(buffer)
