import { Entity } from "@danielx/tiny-game";
import { BufferedController, Controller } from "@danielx/tiny-game"

export interface Player {
  ID: number
  attackCooldown: number
  controller: BufferedController
  facing: [number, number]
  maxHealth: number
  onFloor: boolean
  regenerationDuration: number
  reloading: boolean
  vx: number
  vy: number
  weapon: string
  x: number
  y: number

  bowDraw: number
  xHeld: boolean
}

export interface SimplePoint {
  x: number
  y: number
}

export interface ExtendedEntity extends Entity, SimplePoint {
  item: boolean
  type: unknown
  subtype: string
  interact: (p: Player) => void
}

export interface Weapon {
  atkIdx: number
  baseVelocity: number
  cooldown: number
  drawMax: number

  drawSound: string
  releaseSound: string
  projectileIdx: number
}

export { Player }
