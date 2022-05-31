import { squirrel3 } from "@danielx/tiny-game/types/util"

/**
Very rough approximation of 4bit poisson distribution mean=0.5

@param bits 4-bit unsigned integer.
*/
export function poisson_0_5(bits: number): 0 | 1 | 2

/**
Convert a 4 bit number into a ~poisson distribution mean=1 with counts 0-3

```text
0: 37.5%
1: 37.5%
2: 18.75%
3: 06.25%
```

@param bits 4-bit unsigned integer.
*/
export function poisson_1(bits: number): 0 | 1 | 2 | 3

/**
```text
 5  6  7
  \ | /
4 -   - 0
  / | \
 3  2  1
```

@param x {number}
@param y {number}
*/
export function to8WayDirection(x: number, y: number): 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7

/**
Map a list of properties to a lookup table keyed by `key`. The value of `key` is
used to index into a data table of properties.

[TS Example](https://www.typescriptlang.org/play?#code/PQKhCgFkEMAcAJrwDYEsDOAXeB7AZvLAE46wCmRmqZ68mOiKOOA1gK4KbQBGyZ8LMgE8yAE3jch8AAaCh0gHTwAKgAt+AN2jI2-fDLnT4GcG3Ri6DVADtRZAB7Hr9RqOhc6PPrgLFSFKhoFcBBgcDw2awBjKhxrJlYOZS8yAB4AaWF4B0wyW1osIhsAcwAaFQA+AAo5AC54TKFyrl4yeuUAbQBdcr9ySmp0eprhfWUASm7x+ABvcHgF+Ci4rHgiGjZkbABeWYBfRFoZjvSnAVGCZS76meKyTCrMVQwbjoBlM8br+Gs2AFtuBQ9uN2icuns9uB5ot1pg2ER4n0AoMFOtRGwomQqlUcL0SLBptsKrNoYtFjgOn0uvBdnMyfTFndMPUItFYtYqtM6QyeQtltZVqhxLsnhgOnIugBuUm8+n81bIZjsBAilIdIVSmWymH3eHxRWJWCU-FdLXa+CQ3mWnmwvW4GV7crrdCbTDjaWQ8Dy7DuFi0XYdbkLazQP5teAAIjcxTuRAjpRloj+xXqACYE2SiNBrHd6gBGBOOklkkNh+oR9AAdxwRFE8cTyfqABYMzDs7n4KnwEWgz9Q+GI9wcJX62Skyn4ABmVsLLM58MAdkLpvAmCE5HgABEyHgbKh2QA1bS6VLKYm7ZTZey5fKzJmc+o2PAUeAHg4Aflf8HqkRY1mH1hQt6hD4siNA0gkyrJK0VQRr6ACSdblL66DlB0EalmQ8aRuO2ERnOdwRl04xQmuG7bru1hiMo678LSCGiPUvwAkC8AAGSzOs0CiHEyBSCcZxyPoZFkPoSIDDQ3wUXuh7Hmkjy0WJoESegkzpF0FSesBDD1NJVGiDRG4QQA8twABWZAxAodiUWQAAKymBOgVS9gx9QAAzdocW47jY1G0Xi-gqSROAKAxEF5lCoWYeAoXjuAQA)
*/
export function lookupTable<Key extends string, T>(key: Key, table: T[], properties: string | (keyof T)[]): unknown

export {
  squirrel3
}

/**
Returns an unsigned integer containing 31 reasonably-well-scrambled
bits, based on a given (signed) integer input parameter `n` and optional
`seed`.  Kind of like looking up a value in a non-existent table of 2^31
previously generated random numbers.
*/
export const noise1d: typeof squirrel3

/**
Unique symbol for extending PIXI.js containers with a cull checking function.
*/
export const cullCheckSym: symbol

declare const util: {
  noise1d: typeof noise1d
  poisson_0_5: typeof poisson_0_5
  poisson_1: typeof poisson_1
  squirrel3: typeof squirrel3
  to8WayDirection: typeof to8WayDirection
}

export default util
