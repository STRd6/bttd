import { BIT, Entity } from "@danielx/tiny-game";
import { BufferedController, Controller } from "@danielx/tiny-game"

export interface Bounds {
  x: number
  y: number
  hw: number
  hh: number
}

export interface Player extends Entity, Bounds, Physics {
  ID: number
  attackCooldown: number
  bowDraw: number
  controller: BufferedController
  dropping: boolean
  facing: [number, number]
  facingPrevX: number
  items: Array<unknown>
  jumpHeld: BIT
  maxHealth: number
  onFloor: boolean
  regenerationAmount: number
  regenerationDuration: number
  reloading: boolean
  weapon: string
  xHeld: boolean
}

export interface SimplePoint {
  x: number
  y: number
}

export interface Physics {
  x: number
  y: number
  vx: number
  vy: number
  ax: number
  ay: number
  vyMax: number
}

export interface Light {
  light: boolean
  r1: number
  r2: number
}

export interface ExtendedEntity extends Player, Light {
  age: number
  bounce: boolean
  bubbleVisible: boolean
  damage: number
  item: boolean
  floorVelocity: number
  friction: number
  hazardDelta: Bounds
  health: number
  knockback: number
  maxAge: number
  onFloorPrev: boolean
  subtype: string
  sourceId: number
  type: unknown
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
