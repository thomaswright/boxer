// these are passed to canvas elements and can't be vars

let gridLineDark = "rgba(0, 0, 0, 0.25)"
let gridLineLight = "rgba(255, 255, 255, 0.25)"
let checkeredPrimaryDark = "rgba(0, 0, 0, 0.15)"
let checkeredPrimaryLight = "rgba(255, 255, 255, 0.15)"
let checkeredSecondaryDark = "rgba(0, 0, 0, 0.00)"
let checkeredSecondaryLight = "rgba(255, 255, 255, 0.00)"

@module("./themeColors.js")
external resolveThemeColor: string => Js.Nullable.t<string> = "resolveThemeColor"

let resolveColor = color =>
  color
  ->resolveThemeColor
  ->Js.Nullable.toOption

module Thumbnail = {
  let selectedFilled = "var(--plain-500, #575757)"
  let selectedEmpty = "var(--plain-100, #E2E2E2)"
  let unselectedFilled = "var(--plain-300, #9ca3af)"
  let unselectedEmpty = "var(--plain-200, #e5e7eb)"
}
