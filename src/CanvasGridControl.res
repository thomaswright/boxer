open Types

@react.component
let make = (~gridMode, ~setGridMode) => {
  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="font-bold text-sm "> {"Canvas Guides"->React.string} </div>
    <div className="grid grid-cols-2">
      {[
        (GridNone, "None"),
        (GridLinesOverlay, "Grid Over"),
        (GridLinesUnderlay, "Grid Under"),
        (CheckeredOverlay, "Check Over"),
        (CheckeredUnderlay, "Check Under"),
      ]
      ->Belt.Array.map(((mode, label)) =>
        <button
          type_="button"
          className={Styles.segmentButton(
            ~isActive=gridMode == mode,
          ) ++ " py-1 nth-[1]:rounded-t-xl nth-[1]:col-span-2 nth-[4]:rounded-bl-xl nth-[5]:rounded-br-xl"}
          onClick={_ => setGridMode(_ => mode)}
          key={label}>
          {label->React.string}
        </button>
      )
      ->React.array}
    </div>
  </div>
}
