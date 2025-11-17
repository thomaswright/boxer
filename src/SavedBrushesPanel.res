module Palette = Palette

@react.component
let make = (
  ~savedBrushes: array<Types.brushEntry>,
  ~selectedBrushId: option<string>,
  ~setSelectedBrushId,
  ~handleAddBrush,
  ~canDeleteSelectedBrush,
  ~handleDeleteSelectedBrush,
  ~canSaveBrush,
) => {
  <div className={"flex flex-col gap-1 h-full overflow-y-scroll items-end"}>
    <div className={"text-2xs font-bold"}> {"Brush"->React.string} </div>
    {savedBrushes
    ->Array.map(savedBrushEntry => {
      let savedBrush = savedBrushEntry.brush
      let (dimI, dimJ) = savedBrush->Array2D.dims
      let selected = switch selectedBrushId {
      | Some(id) => savedBrushEntry.id == id
      | None => false
      }
      let (filledColor, emptyColor) = if selected {
        (Palette.Thumbnail.selectedFilled, Palette.Thumbnail.selectedEmpty)
      } else {
        (Palette.Thumbnail.unselectedFilled, Palette.Thumbnail.unselectedEmpty)
      }
      <button
        key={savedBrushEntry.id}
        onClick={_ => setSelectedBrushId(_ => Some(savedBrushEntry.id))}
        className={["flex flex-row"]->Array.join(" ")}>
        <div
          className={[
            " text-3xs font-bold w-4 text-center bg-[var(--plain-white)]",
            selected ? "text-[var(--secondary)]" : "text-[var(--plain-black)]",
          ]->Array.join(" ")}
          style={{writingMode: "sideways-lr"}}>
          {`${dimI->Int.toString}:${dimJ->Int.toString}`->React.string}
        </div>
        <div
          className={[
            selected ? "bg-[var(--secondary)]" : "bg-[var(--plain-400)]",
            "h-8 w-8 rounded-xs overflow-hidden",
          ]->Array.join(" ")}>
          <BoolGridPreview
            grid={savedBrush} filledColor={Some(filledColor)} emptyColor={Some(emptyColor)}
          />
        </div>
      </button>
    })
    ->React.array}
    <button
      className={[
        "rounded-lg h-8 w-8 text-lg font-medium flex items-center justify-center",
        canSaveBrush
          ? "bg-[var(--accent)] text-[var(--plain-white)]"
          : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canSaveBrush}
      onClick={_ => {
        handleAddBrush()
      }}>
      <Icons.Plus />
    </button>
    <button
      className={[
        "rounded-lg h-8 w-8 text-lg font-medium flex items-center justify-center",
        canDeleteSelectedBrush
          ? "bg-[var(--accent)] text-[var(--plain-white)]"
          : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedBrush}
      onClick={_ => handleDeleteSelectedBrush()}>
      <Icons.Trash />
    </button>
  </div>
}
