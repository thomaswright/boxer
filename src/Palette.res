// these are passed to canvas elements and can't be vars

let gridLineDark = "rgba(0, 0, 0, 0.25)"
let gridLineLight = "rgba(255, 255, 255, 0.25)"
let checkeredPrimaryDark = "rgba(0, 0, 0, 0.15)"
let checkeredPrimaryLight = "rgba(255, 255, 255, 0.15)"
let checkeredSecondaryDark = "rgba(0, 0, 0, 0.00)"
let checkeredSecondaryLight = "rgba(255, 255, 255, 0.00)"

let getColor = () => {
  Webapi.Dom.document
  ->Webapi.Dom.Document.querySelector(".tan")
  ->Option.flatMap(element => {
    let style = Webapi.Dom.Window.getComputedStyle(Webapi.Dom.window, element)

    style->Webapi.Dom.CssStyleDeclaration.getPropertyValue("--plain-500")
  })
  ->Option.getOr("#dddddd")
}

Js.log(getColor())

module Thumbnail = {
  let selectedFilled = "#E7000B"
  let selectedEmpty = "#FFCAC2"
  let unselectedFilled = "#9ca3af"
  let unselectedEmpty = "#e5e7eb"
}
