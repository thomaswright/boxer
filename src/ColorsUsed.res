type colorUsage = {
  color: string,
  count: int,
  percent: float,
}

@react.component
let make = (
  ~board: Types.board,
  ~onSelectUsedColor: string => unit,
  ~onReplaceUsedColor: string => unit,
  ~myColor,
) => {
  let colorCounts = Js.Dict.empty()
  let totalColored = ref(0)

  board->Array.forEach(row =>
    row->Array.forEach(cell =>
      switch cell->Nullable.toOption {
      | None => ()
      | Some(color) =>
        totalColored.contents = totalColored.contents + 1
        let nextCount = switch colorCounts->Js.Dict.get(color) {
        | Some(count) => count + 1
        | None => 1
        }
        colorCounts->Js.Dict.set(color, nextCount)
      }
    )
  )

  let totalColoredCells = totalColored.contents

  let usages: array<colorUsage> =
    colorCounts
    ->Js.Dict.entries
    ->Array.map(((color, count)) => {
      let percent = if totalColoredCells == 0 {
        0.
      } else {
        count->Int.toFloat /. totalColoredCells->Int.toFloat *. 100.
      }
      {
        color,
        count,
        percent,
      }
    })
    ->Array.toSorted((a, b) =>
      switch Int.compare(b.count, a.count) {
      | 0. => String.compare(a.color, b.color)
      | other => other
      }
    )

  let uniqueColorCount = usages->Array.length

  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row items-center justify-between">
      <span className="font-medium"> {"Colors Used"->React.string} </span>
      <span className="text-xs text-gray-500">
        {uniqueColorCount->Int.toString->React.string}
      </span>
    </div>
    {switch usages->Array.length {
    | 0 =>
      <div className="text-xs text-gray-500"> {"Start drawing to see colors"->React.string} </div>
    | _ =>
      <div className="flex flex-col max-h-48 overflow-scroll">
        {usages
        ->Array.map(({color, count, percent}) => {
          let percentLabel = percent->Float.toFixed(~digits=0)
          let isSelected = myColor == color
          <div key={color} className={["flex flex-row items-center gap-2"]->Array.join(" ")}>
            <button
              type_="button"
              className={[
                "flex flex-1 flex-row items-center gap-2 text-xs rounded px-1 py-0.5 hover:bg-gray-100 text-left",
                isSelected ? "bg-gray-200" : "",
              ]->Array.join(" ")}
              title={color}
              onClick={_ => onSelectUsedColor(color)}>
              <div
                className="w-4 h-4 rounded border border-gray-300" style={{backgroundColor: color}}
              />
              <div className="text-xs text-gray-500 tabular-nums">
                {`${percentLabel == "0" ? "<1" : percentLabel}%`->React.string}
              </div>
              <div className="text-xs text-gray-400 w-8 text-right tabular-nums">
                {count->Int.toString->React.string}
              </div>
            </button>
            <button
              type_="button"
              className="text-xs font-medium px-1 py-0.5 rounded bg-gray-200 hover:bg-gray-300"
              onClick={_ => onReplaceUsedColor(color)}>
              <Icons.ColorPicker />
            </button>
          </div>
        })
        ->React.array}
      </div>
    }}
  </div>
}
