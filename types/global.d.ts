import assertType from "assert"

import TinyGameType, { GameInstance, PIXI as PIXIType } from "@danielx/tiny-game"

declare global {
  var PIXI: typeof PIXIType
  const TinyGame: typeof TinyGameType
  var assert: typeof assertType
  const game: GameInstance
}
