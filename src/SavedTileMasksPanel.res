module Palette = Palette

@react.component
let make = (
  ~savedTileMasks: array<Types.tileMaskEntry>,
  ~selectedTileMaskId: option<string>,
  ~setSelectedTileMaskId,
  ~handleAddTileMask,
  ~canDeleteSelectedTileMask,
  ~handleDeleteSelectedTileMask,
  ~canSaveTileMask,
) => {
  <div className={"flex flex-col gap-1 h-full overflow-y-scroll items-end"}>
    <div className={"text-2xs font-bold"}> {"Dither"->React.string} </div>

    {savedTileMasks
    ->Array.map(savedTileMask => {
      let selected = switch selectedTileMaskId {
      | Some(id) => savedTileMask.id == id
      | None => false
      }
      let (filledColor, emptyColor) = if selected {
        (Palette.Thumbnail.selectedFilled, Palette.Thumbnail.selectedEmpty)
      } else {
        (Palette.Thumbnail.unselectedFilled, Palette.Thumbnail.unselectedEmpty)
      }
      <button
        key={savedTileMask.id}
        onClick={_ => {
          setSelectedTileMaskId(_ => Some(savedTileMask.id))
        }}>
        <div
          className={[
            "h-8 w-8 rounded-xs overflow-hidden",
            selected ? "bg-[var(--accent)]" : "bg-[var(--plain-100)]",
          ]->Array.join(" ")}>
          <BoolGridPreview
            grid={savedTileMask.mask} filledColor={Some(filledColor)} emptyColor={Some(emptyColor)}
          />
        </div>
      </button>
    })
    ->React.array}
    <button
      className={[
        "rounded-lg h-8 w-8 text-lg font-medium flex items-center justify-center",
        canSaveTileMask
          ? "bg-[var(--accent)] text-[var(--plain-white)]"
          : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canSaveTileMask}
      onClick={_ => handleAddTileMask()}>
      <Icons.Plus />
    </button>

    <button
      className={[
        "rounded-lg h-8 w-8 text-lg font-medium flex items-center justify-center",
        canDeleteSelectedTileMask
          ? "bg-[var(--accent)] text-[var(--plain-white)]"
          : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedTileMask}
      onClick={_ => handleDeleteSelectedTileMask()}>
      <Icons.Trash />
    </button>
  </div>
}
