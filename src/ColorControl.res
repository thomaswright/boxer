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
      <button
        className={[
          brushMode == Color
            ? "bg-[color:var(--accent)] text-[color:var(--plain-white)]"
            : "bg-[color:var(--plain-200)] text-[color:var(--plain-900)]",
          "px-2 font-medium rounded-l",
        ]->Array.join(" ")}
        onClick={_ => setBrushMode(_ => Color)}>
        {"Color"->React.string}
      </button>
      <button
        className={[
          brushMode == Erase
            ? "bg-[color:var(--accent)] text-[color:var(--plain-white)]"
            : "bg-[color:var(--plain-200)] text-[color:var(--plain-900)]",
          "px-2 font-medium rounded-r",
        ]->Array.join(" ")}
        onClick={_ => setBrushMode(_ => Erase)}>
        {"Erase"->React.string}
      </button>
      <button
        className={[
          isPickingColor
            ? "bg-[color:var(--accent)] text-[color:var(--plain-white)]"
            : "bg-[color:var(--plain-200)] text-[color:var(--plain-900)]",
          "px-2 font-medium rounded ml-2",
        ]->Array.join(" ")}
        onClick={_ => onStartColorPick()}>
        {"Pick"->React.string}
      </button>
    </div>
    {isPickingColor
      ? <div
          className="w-full h-[200px] border border-[color:var(--plain-300)]"
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
