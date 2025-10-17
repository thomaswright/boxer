@react.component
let make = (
  ~board,
  ~setBrush,
  ~setSavedBrushes,
  ~canDeleteSelectedBrush,
  ~handleDeleteSelectedBrush,
  ~setTileMask,
  ~setSavedTileMasks,
  ~setSelectedTileMaskIndex,
  ~canDeleteSelectedTileMask,
  ~handleDeleteSelectedTileMask,
) => {
  <div className={"p-2 flex flex-col gap-2"}>
    <div className={"flex flex-row items-center justify-between font-medium w-full"}>
      {"Brush and Tile Masks"->React.string}
    </div>
    <button
      className={"rounded px-2 py-1 text-sm font-medium bg-blue-500 text-white "}
      onClick={_ => {
        let newBrush = board->Array.map(row => row->Array.map(cell => !(cell->Nullable.isNullable)))
        setSavedBrushes(v => v->Array.concat([newBrush]))
        setBrush(_ => newBrush)
      }}>
      {"Add as Brush"->React.string}
    </button>
    <button
      className={[
        "rounded px-2 py-1 text-sm font-medium",
        canDeleteSelectedBrush
          ? "bg-blue-500 text-white"
          : "bg-gray-200 text-gray-500 cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedBrush}
      onClick={_ => handleDeleteSelectedBrush()}>
      {"Remove Brush"->React.string}
    </button>
    <button
      className={"rounded px-2 py-1 text-sm font-medium bg-blue-500 text-white"}
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
      {"Add as Tile Mask"->React.string}
    </button>

    <button
      className={[
        "rounded px-2 py-1 text-sm font-medium",
        canDeleteSelectedTileMask
          ? "bg-blue-500 text-white"
          : "bg-gray-200 text-gray-500 cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedTileMask}
      onClick={_ => handleDeleteSelectedTileMask()}>
      {"Remove Tile Mask"->React.string}
    </button>
  </div>
}
