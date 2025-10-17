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
      let (dimI, dimJ) = savedTileMask->Array2D.dims
      let selected = savedTileMaskIndex == selectedTileMaskIndex
      <button
        key={savedTileMaskIndex->Int.toString}
        onClick={_ => {
          setSelectedTileMaskIndex(_ => savedTileMaskIndex)
          setTileMask(_ => savedTileMask)
        }}>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: `repeat(${dimJ->Int.toString}, auto)`,
            gridTemplateRows: `repeat(${dimI->Int.toString}, auto)`,
          }}
          className={[
            "h-8 w-8 rounded-xs overflow-hidden",
            selected ? "bg-orange-500 " : "bg-gray-400",
          ]->Array.join(" ")}>
          {savedTileMask
          ->Array.mapWithIndex((line, i) => {
            line
            ->Array.mapWithIndex(
              (cell, j) => {
                <div
                  className={[
                    "w-full h-full ",
                    selected
                      ? cell ? "bg-orange-500" : "bg-orange-200"
                      : cell
                      ? "bg-gray-400"
                      : "bg-gray-200",
                  ]->Array.join(" ")}
                  key={i->Int.toString ++ j->Int.toString}
                  // style={{
                  //   backgroundColor: cell ? "inherit" : "#ddd",
                  // }}
                >
                </div>
              },
            )
            ->React.array
          })
          ->React.array}
        </div>
      </button>
    })
    ->React.array}
  </div>
}
