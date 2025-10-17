@react.component
let make = (
  ~board,
  ~setTileMask,
  ~savedTileMasks,
  ~setSavedTileMasks,
  ~selectedTileMaskIndex,
  ~setSelectedTileMaskIndex,
  ~canDeleteSelectedTileMask,
  ~handleDeleteSelectedTileMask,
) => {
  <div className={"flex flex-col gap-1 h-full overflow-y-scroll"}>
    <div>
      <button
        className={[
          "w-4 h-4 leading-none",
          canDeleteSelectedTileMask
            ? "bg-red-500 text-white"
            : "bg-gray-200 text-gray-500 cursor-not-allowed",
        ]->Array.join(" ")}
        disabled={!canDeleteSelectedTileMask}
        onClick={_ => handleDeleteSelectedTileMask()}>
        {"x"->React.string}
      </button>
      <button
        className={"bg-gray-200 w-4 h-4 leading-none"}
        onClick={_ => {
          let newTileMask =
            board->Array.map(row => row->Array.map(cell => !(cell->Nullable.isNullable)))
          setSavedTileMasks(prev => {
            let next = prev->Array.concat([newTileMask])
            setSelectedTileMaskIndex(_ => next->Array.length - 1)
            next
          })
          setTileMask(_ => newTileMask)
        }}>
        {"+"->React.string}
      </button>
    </div>

    {savedTileMasks
    ->Array.mapWithIndex((savedTileMask, savedTileMaskIndex) => {
      let selected = savedTileMaskIndex == selectedTileMaskIndex
      let (filledColor, emptyColor) = if selected {
        ("#f97316", "#fed7aa")
      } else {
        ("#9ca3af", "#e5e7eb")
      }
      <button
        key={savedTileMaskIndex->Int.toString}
        onClick={_ => {
          setSelectedTileMaskIndex(_ => savedTileMaskIndex)
          setTileMask(_ => savedTileMask)
        }}>
        <div
          className={[
            "h-8 w-8 rounded-xs overflow-hidden",
            selected ? "bg-orange-500 " : "bg-gray-400",
          ]->Array.join(" ")}>
          <BoolGridPreview
            grid={savedTileMask} filledColor={Some(filledColor)} emptyColor={Some(emptyColor)}
          />
        </div>
      </button>
    })
    ->React.array}
  </div>
}
