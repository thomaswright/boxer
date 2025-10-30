@react.component
let make = (
  ~brush,
  ~setBrush,
  ~savedBrushes,
  ~handleAddBrush,
  ~canDeleteSelectedBrush,
  ~handleDeleteSelectedBrush,
) => {
  <div className={"flex flex-col gap-1 h-full overflow-y-scroll items-end"}>
    {savedBrushes
    ->Array.mapWithIndex((savedBrush, savedBrushIndex) => {
      let (dimI, dimJ) = savedBrush->Array2D.dims
      let selected = Array2D.isEqual(brush, savedBrush)
      let (filledColor, emptyColor) = if selected {
        ("#f97316", "#fed7aa")
      } else {
        ("#9ca3af", "#e5e7eb")
      }
      <button
        key={savedBrushIndex->Int.toString}
        onClick={_ => setBrush(_ => savedBrush)}
        className={["flex flex-row"]->Array.join(" ")}>
        <div
          className={[
            " text-3xs font-bold w-4 text-center bg-white",
            selected ? "text-orange-700" : "text-black",
          ]->Array.join(" ")}
          style={{writingMode: "sideways-lr"}}>
          {`${dimI->Int.toString}:${dimJ->Int.toString}`->React.string}
        </div>
        <div
          className={[
            selected ? "bg-orange-500" : "bg-gray-400",
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
      className={"rounded p-1 h-6 w-6 text-sm font-medium bg-blue-500 text-white "}
      onClick={_ => handleAddBrush()}>
      <Icons.Plus />
    </button>
    <button
      className={[
        "rounded p-1 h-6 w-6 text-sm font-medium",
        canDeleteSelectedBrush
          ? "bg-blue-500 text-white"
          : "bg-gray-200 text-gray-500 cursor-not-allowed",
      ]->Array.join(" ")}
      disabled={!canDeleteSelectedBrush}
      onClick={_ => handleDeleteSelectedBrush()}>
      <Icons.Trash />
    </button>
  </div>
}
