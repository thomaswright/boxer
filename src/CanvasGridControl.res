open Types

let options = [
  (GridNone, "None"),
  (GridLinesOverlay, "Grid Over"),
  (GridLinesUnderlay, "Grid Under"),
  (CheckeredOverlay, "Check Over"),
  (CheckeredUnderlay, "Check Under"),
]

let buttonClass = (~isActive) =>
  "flex-1 text-xs font-medium px-1 py-1 nth-[1]:rounded-t nth-[1]:col-span-2 nth-[4]:rounded-bl nth-[5]:rounded-br border transition-colors " ++ if (
    isActive
  ) {
    "bg-[var(--plain-900)] text-[var(--plain-white)] border-[var(--plain-900)]"
  } else {
    "bg-[var(--plain-white)] text-[var(--plain-800)] border-[var(--plain-200)] hover:border-[var(--plain-400)]"
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
