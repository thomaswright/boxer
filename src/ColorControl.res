open Types

@react.component
let make = (
  ~brushMode,
  ~setBrushMode,
  ~myColor,
  ~setMyColor,
  ~hoveredPickColor,
  ~isPickingColor,
  ~onStartColorPick,
  ~canvasBackgroundColor,
) => {
  let previewColor = switch hoveredPickColor {
  | Some(color) => color
  | None => canvasBackgroundColor
  }

  <div className="relative flex flex-col gap-2 w-full overflow-x-visible items-center flex-none">
    <div className="flex flex-row justify-center">
      <div className={"flex flex-row"}>
        {[(Color, "Color"), (Erase, "Erase")]
        ->Belt.Array.map(((mode, label)) =>
          <button
            type_="button"
            className={Styles.segmentButton(
              ~isActive=brushMode == mode,
            ) ++ " py-1 px-3 first:rounded-l-xl last:rounded-r-xl"}
            onClick={_ => setBrushMode(_ => mode)}
            key={label}>
            {label->React.string}
          </button>
        )
        ->React.array}
      </div>

      <button
        className={[
          isPickingColor
            ? "bg-[var(--accent)] text-[var(--plain-white)]"
            : "bg-[var(--plain-200)] text-[var(--plain-900)]",
          "px-3 font-medium rounded-xl ml-2 text-xs",
        ]->Array.join(" ")}
        onClick={_ => onStartColorPick()}>
        {"Pick"->React.string}
      </button>
    </div>
    {isPickingColor
      ? <div
          className="w-full h-[200px] border border-[var(--plain-300)]"
          style={{
            backgroundColor: previewColor,
          }}
        />
      : <HexColorPicker
          color={myColor}
          onChange={newColor => {
            setMyColor(_ => newColor)
          }}
          style={{
            width: "96%",
          }}
        />}
  </div>
}
