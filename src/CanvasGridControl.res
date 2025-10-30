open Types

let options = [
  (GridNone, "None"),
  (GridLines, "Grid"),
  (CheckeredOverlay, "Checkered Overlay"),
  (CheckeredUnderlay, "Checkered Underlay"),
]

let buttonClass = (~isActive) =>
  "flex-1 text-xs font-medium px-2 py-1 nth-[1]:rounded-tl nth-[2]:rounded-tr nth-[3]:rounded-bl nth-[4]:rounded-br border transition-colors " ++ if (
    isActive
  ) {
    "bg-gray-900 text-white border-gray-900"
  } else {
    "bg-white text-gray-800 border-gray-200 hover:border-gray-400"
  }

@react.component
let make = (~gridMode, ~setGridMode) => {
  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="font-medium"> {"Canvas Guides"->React.string} </div>
    <div className="grid grid-cols-2">
      {options
      ->Belt.Array.map(((mode, label)) =>
        <button
          type_="button"
          className={buttonClass(~isActive=gridMode == mode)}
          onClick={_ => setGridMode(_ => mode)}
          key={label}>
          {label->React.string}
        </button>
      )
      ->React.array}
    </div>
  </div>
}
