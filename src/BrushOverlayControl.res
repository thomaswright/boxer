open Types

let options = [(OverlayNone, "None"), (OverlayDefault, "Shadow"), (OverlayColor, "Color")]

let buttonClass = (~isActive) =>
  "flex-1 text-xs font-medium px-1 py-1  first:rounded-l last:rounded-r border transition-colors " ++ if (
    isActive
  ) {
    "bg-[color:var(--plain-900)] text-[color:var(--plain-white)] border-[color:var(--plain-900)]"
  } else {
    "bg-[color:var(--plain-white)] text-[color:var(--plain-800)] border-[color:var(--plain-200)] hover:border-[color:var(--plain-400)]"
  }

@react.component
let make = (~overlayMode, ~setOverlayMode) => {
  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="font-medium"> {"Brush Overlay"->React.string} </div>
    <div className="grid grid-cols-3">
      {options
      ->Belt.Array.map(((mode, label)) =>
        <button
          type_="button"
          className={buttonClass(~isActive=overlayMode == mode)}
          onClick={_ => setOverlayMode(_ => mode)}
          key={label}>
          {label->React.string}
        </button>
      )
      ->React.array}
    </div>
  </div>
}
