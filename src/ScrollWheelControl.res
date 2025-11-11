open Types

@react.component
let make = (~scrollWheelMode, ~setScrollWheelMode) => {
  let optionClass = mode =>
    "flex-1 px-2 py-1 text-xs font-medium rounded border " ++
    (
      if mode == scrollWheelMode {
        "bg-gray-900 text-white border-gray-900"
      } else {
        "bg-gray-100 text-gray-700 border-gray-200"
      }
    )

  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row items-center justify-between">
      <span className="font-medium"> {"Scroll Wheel"->React.string} </span>
    </div>
    <div className="flex flex-row gap-2">
      <button
        className={optionClass(ScrollZoom)}
        onClick={_ => setScrollWheelMode(_ => ScrollZoom)}>
        {"Zoom"->React.string}
      </button>
      <button
        className={optionClass(ScrollPan)}
        onClick={_ => setScrollWheelMode(_ => ScrollPan)}>
        {"Pan"->React.string}
      </button>
    </div>
  </div>
}
