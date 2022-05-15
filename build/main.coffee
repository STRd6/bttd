esbuild = require 'esbuild'

watch = process.argv.includes '--watch'
minify = !watch || process.argv.includes '--minify'
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
  plugins: [  ]
}).catch -> process.exit 1
