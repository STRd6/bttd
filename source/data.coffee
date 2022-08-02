# Data Tables
module.exports =
  projectile: [{
    # 0 arrow
    ay: 0.25
    damage: 1
    textureKey: "arrow"
  }, {
    # 1 fire arrow
    ay: 0.25
    damage: 3
    light: true
    r1: 32
    r2: 48
    textureKey: "arrow"
    # TODO: Particles
  }, {
    # 2 bolt
    ay: 0.05
    damage: 5
    textureKey: "bolt"
  }]

  #
  ###* @type {{
    accentTop?: number[]
    accentBottom?: number[]
    accentLeft?: number[]
    accentRight?: number[]
    ladder?: boolean
    solid?: boolean
    tile?: number
    vary?: boolean
  }[]} ###
  tile: [
    {}, # 0
    { # 1
      accentTop: [11, 12, 13]
      accentBottom: [4, 5]
      accentLeft: [23,24]
      accentRight: [21, 22]
      solid: true
      tile: 25
      vary: true
    }, { # 2
      ladder: true
      solid: true
      tile: 10
    }
  ]

  attack: [{ # dagger
    damage: 1
    knockback: 1
    maxAge: 2
  }, { # sword
    damage: 2
    knockback: 4
    maxAge: 3
  }]
