interface CameraEntity extends Entity {
  /** Unique id for an individual camera */
  id: number
  /** x position at camera center in screen coordinates */
  x: number
  /** y position at camera center in screen coordinates */
  y: number
  /** half-width in screen coordinates */
  hw: number
  /** half-height in screen coordinates */
  hh: number
}

import { Camera, Entity, PIXI } from "@danielx/tiny-game"

interface DefaultCamera extends Camera {
  border: PIXI.Sprite
  filterArea: PIXI.Rectangle
  filters: PIXI.Filter[]
  lighting: PIXI.Sprite & {
    ctx?: CanvasRenderingContext2D
  }
}

export {
  DefaultCamera as Camera,
  CameraEntity
}
