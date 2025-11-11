@react.component
let make = (~canUndo, ~canRedo, ~onUndo, ~onRedo) => {
  let buttonClass = enabled =>
    "flex-1 rounded px-2 py-1 text-xs font-medium flex items-center justify-center " ++ if enabled {
      "bg-[var(--plain-200)] text-[var(--plain-900)]"
    } else {
      "bg-[var(--plain-100)] text-[var(--plain-400)] cursor-not-allowed"
    }

  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row items-center justify-between">
      <span className="font-medium"> {"History"->React.string} </span>
      <span className="text-xs text-[var(--plain-500)] font-mono">
        {"Cmd+Z / Cmd+Shift+Z"->React.string}
      </span>
    </div>
    <div className="flex flex-row gap-2">
      <button
        className={buttonClass(canUndo)}
        disabled={!canUndo}
        onClick={_ =>
          if canUndo {
            onUndo()
          } else {
            ()
          }}>
        {"Undo"->React.string}
      </button>
      <button
        className={buttonClass(canRedo)}
        disabled={!canRedo}
        onClick={_ =>
          if canRedo {
            onRedo()
          } else {
            ()
          }}>
        {"Redo"->React.string}
      </button>
    </div>
  </div>
}
