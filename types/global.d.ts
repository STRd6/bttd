import assertType from "assert"

import TinyGameType, { GameInstance, PIXI as PIXIType } from "@danielx/tiny-game"

interface Extensions {
  loadSpritesheet: unknown
  parseLevel: unknown
}

declare global {
  var PIXI: typeof PIXIType
  const TinyGame: (typeof TinyGameType) & { ext: Extensions }
  var assert: typeof assertType
  const game: GameInstance
}
