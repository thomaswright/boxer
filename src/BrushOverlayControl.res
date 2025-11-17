open Types

@react.component
let make = (~overlayMode, ~setOverlayMode) => {
  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="font-medium"> {"Brush Overlay"->React.string} </div>
    <div className="grid grid-cols-3">
      {[(OverlayNone, "None"), (OverlayDefault, "Shadow"), (OverlayColor, "Color")]
      ->Belt.Array.map(((mode, label)) =>
        <button
          type_="button"
          className={Styles.segmentButton(
            ~isActive=overlayMode == mode,
          ) ++ " first:rounded-l last:rounded-r"}
          onClick={_ => setOverlayMode(_ => mode)}
          key={label}>
          {label->React.string}
        </button>
      )
      ->React.array}
    </div>
  </div>
}
