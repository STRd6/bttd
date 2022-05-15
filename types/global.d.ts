import * as PIXIType from "pixi.js"

import TinyG, { GameInstance } from "@danielx/tiny-game"

declare global {
  var PIXI: typeof PIXIType
  const TinyGame: TinyG
  const game: GameInstance
}
