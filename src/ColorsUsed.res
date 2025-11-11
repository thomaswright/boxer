type usage = {
  counts: Js.Dict.t<int>,
  total: int,
}

type colorUsage = {
  color: string,
  count: int,
  percent: float,
}

module IdleScheduler = {
  type handle
  @module("./IdleScheduler.js")
  external schedule: (unit => unit) => handle = "schedule"
  @module("./IdleScheduler.js")
  external cancel: handle => unit = "cancel"
}

let computeUsage = board => {
  let counts = Js.Dict.empty()
  let totalColored = ref(0)
  let data = Board.data(board)
  let dataLength = data->Board.TypedArray.length

  for idx in 0 to dataLength - 1 {
    switch data->Board.TypedArray.get(idx) {
    | Some(value) =>
      if value != 0 {
        totalColored.contents = totalColored.contents + 1
        switch Board.uint32ToHex(value)->Js.Nullable.toOption {
        | Some(color) =>
          let nextCount = switch Js.Dict.get(counts, color) {
          | Some(count) => count + 1
          | None => 1
          }
          Js.Dict.set(counts, color, nextCount)
        | None => ()
        }
      }
    | None => ()
    }
  }

  {counts, total: totalColored.contents}
}

@react.component
let make = (
  ~board: Types.board,
  ~onSelectUsedColor: string => unit,
  ~onReplaceUsedColor: string => unit,
  ~myColor,
  ~isMouseDown,
) => {
  let (replaceMode, setReplaceMode) = React.useState(_ => false)
  let (usageState, setUsageState) = React.useState(() => computeUsage(board))
  let idleHandleRef = React.useRef(None)

  React.useEffect2(() => {
    switch idleHandleRef.current {
    | Some(handle) =>
      IdleScheduler.cancel(handle)
      idleHandleRef.current = None
    | None => ()
    }

    if !isMouseDown {
      let handle = IdleScheduler.schedule(() => {
        idleHandleRef.current = None
        setUsageState(_ => computeUsage(board))
      })
      idleHandleRef.current = Some(handle)
    }

    Some(
      () => {
        switch idleHandleRef.current {
        | Some(handle) =>
          IdleScheduler.cancel(handle)
          idleHandleRef.current = None
        | None => ()
        }
      },
    )
  }, (Board.data(board), isMouseDown))

  let colorCounts = usageState.counts
  let totalColoredCells = usageState.total

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
      <span className="font-medium flex-1"> {"Colors Used"->React.string} </span>

      <span className="text-xs text-[color:var(--plain-500)] px-2">
        {uniqueColorCount->Int.toString->React.string}
      </span>
      <button
        type_="button"
        className={[
          replaceMode
            ? "bg-[color:var(--accent)] text-[color:var(--plain-white)]"
            : "bg-[color:var(--plain-200)] text-[color:var(--plain-900)]",
          "px-1 py-0.5 font-medium text-xs rounded",
        ]->Array.join(" ")}
        onClick={_ => setReplaceMode(v => !v)}>
        {"Set"->React.string}
      </button>
    </div>
    {switch usages->Array.length {
    | 0 =>
      <div className="text-xs text-[color:var(--plain-500)]">
        {"Start drawing to see colors"->React.string}
      </div>
    | _ =>
      <div className="flex flex-col max-h-48 overflow-scroll">
        {usages
        ->Array.map(({color, count, percent}) => {
          let percentLabel = percent->Float.toFixed(~digits=0)
          let isSelected = myColor == color
          <button
            key={color}
            type_="button"
            className={[
              "flex flex-1 flex-row items-center gap-2 text-xs rounded px-1 py-0.5 hover:bg-[color:var(--plain-100)] text-left",
              isSelected ? "bg-[color:var(--plain-200)]" : "",
            ]->Array.join(" ")}
            title={color}
            onClick={_ => replaceMode ? onReplaceUsedColor(color) : onSelectUsedColor(color)}>
            <div
              className="w-4 h-4 rounded border border-[color:var(--plain-300)]"
              style={{backgroundColor: color}}
            />
            <div className="text-xs text-[color:var(--plain-500)] tabular-nums">
              {`${percentLabel == "0" ? "<1" : percentLabel}%`->React.string}
            </div>
            <div className="text-xs text-[color:var(--plain-400)] w-8 text-right tabular-nums">
              {count->Int.toString->React.string}
            </div>
          </button>
        })
        ->React.array}
      </div>
    }}
  </div>
}
