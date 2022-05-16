###*
@typedef {import("esbuild").Plugin} ESBuildPlugin
###

fsPromises = require "fs/promises"
{access} = fsPromises
path = require "path"
esbuild = require 'esbuild'
#@ts-ignore
coffeeScriptPlugin = require 'esbuild-coffeescript'

exists = (###* @type {string} ### p) ->
  access(p)
  .then ->
    true
  .catch ->
    false

#
###* @type {(extensions: string[]) => ESBuildPlugin} ###
extensionResolverPlugin = (extensions) ->
  name: "extension-resolve"
  setup: (build) ->
    # For relatiev requires that don't contain a '.'
    build.onResolve { filter: /\/[^.]*$/ }, (r) ->
      for extension in extensions
        {path: resolvePath, resolveDir} = r
        p = path.join(resolveDir, resolvePath + ".#{extension}")

        # see if a .coffee file exists
        found = await exists(p)
        if found
          return path: p

      return undefined

watch = process.argv.includes '--watch'
# minify = !watch || process.argv.includes '--minify'
sourcemap = true

esbuild.build({
  entryPoints: ['dist/game.js']
  tsconfig: "./tsconfig.json"
  bundle: true
  sourcemap
  minify: false
  watch
  platform: 'browser'
  outfile: 'dist/index.js'
  plugins: [
    extensionResolverPlugin ["coffee", "jadelet"]
    coffeeScriptPlugin
      bare: true
      inlineMap: sourcemap
  ]
}).catch -> process.exit 1
