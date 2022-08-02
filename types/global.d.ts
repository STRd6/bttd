import assertType from "assert"

import TinyGameType, { GameInstance, PIXI as PIXIType } from "@danielx/tiny-game"
import { ExtendedEntity } from "./types"

interface Extensions {
  loadSpritesheet: unknown
  parseLevel: (path: string) => Promise<LevelData>
}

interface LevelData {
  data: Uint8Array
  width: number
  height: number
}

interface Config {
  screenHeight: number
  screenWidth: number
}

interface ExtendedGameInstance extends GameInstance {
  config: Config
  debug: boolean
  entities: ExtendedEntity[]
  entityMap: Map<number, ExtendedEntity>
  levelData: LevelData
  tileset: PIXIType.Texture[]

  hardReset(): void
}

declare global {
  var PIXI: typeof PIXIType
  const TinyGame: (typeof TinyGameType) & { ext: Extensions }
  var assert: typeof assertType
  const game: ExtendedGameInstance
}
