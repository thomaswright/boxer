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
    {savedTileMasks
    ->Array.map(savedTileMask => {
      let selected =
        switch selectedTileMaskId {
        | Some(id) => savedTileMask.id == id
        | None => false
        }
      let (filledColor, emptyColor) = if selected {
        ("#f97316", "#fed7aa")
      } else {
        ("#9ca3af", "#e5e7eb")
      }
      <button
        key={savedTileMask.id}
        onClick={_ => {
          setSelectedTileMaskId(_ => Some(savedTileMask.id))
        }}>
        <div
          className={[
            "h-8 w-8 rounded-xs overflow-hidden",
            selected ? "bg-orange-100 " : "bg-gray-100",
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
        "rounded p-1 h-6 w-6 text-sm font-medium",
        canSaveTileMask ? "bg-blue-500 text-white" : "bg-gray-200 text-gray-500 cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={canSaveTileMask}
      onClick={_ => handleAddTileMask()}>
      <Icons.Plus />
    </button>

    <button
      className={[
        "rounded p-1 h-6 w-6 text-sm font-medium",
        canDeleteSelectedTileMask
          ? "bg-blue-500 text-white"
          : "bg-gray-200 text-gray-500 cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedTileMask}
      onClick={_ => handleDeleteSelectedTileMask()}>
      <Icons.Trash />
    </button>
  </div>
}
