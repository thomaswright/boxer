open Types

@react.component
let make = (
  ~resizeRowsInput,
  ~setResizeRowsInput,
  ~resizeColsInput,
  ~setResizeColsInput,
  ~resizeMode,
  ~setResizeMode,
  ~canSubmitResize,
  ~handleResizeSubmit,
) => {
  <div className=" p-2 flex flex-col gap-2 w-full">
    <div
      className={["flex flex-row items-center justify-between font-medium w-full"]->Array.join(
        " ",
      )}>
      {"Canvas Size"->React.string}
    </div>
    <div className="flex flex-col gap-2">
      <div className="flex flex-row">
        {[(Scale, "Scale"), (Crop, "Crop")]
        ->Belt.Array.map(((mode, label)) =>
          <button
            type_="button"
            className={Styles.segmentButton(
              ~isActive=resizeMode == mode,
            ) ++ " first:rounded-l last:rounded-r"}
            onClick={_ => setResizeMode(_ => mode)}
            key={label}>
            {label->React.string}
          </button>
        )
        ->React.array}
      </div>
      <div className="flex flex-row w-full gap-2 justify-between items-center">
        <input
          className="border border-[var(--plain-300)] rounded px-2 py-1 text-sm flex-none w-16 "
          value={resizeRowsInput}
          onChange={event => {
            let value = ReactEvent.Form.target(event)["value"]
            setResizeRowsInput(_ => value)
          }}
        />
        <Icons.X />
        <input
          className="border border-[var(--plain-300)] rounded px-2 py-1 text-sm flex-none w-16 "
          value={resizeColsInput}
          onChange={event => {
            let value = ReactEvent.Form.target(event)["value"]
            setResizeColsInput(_ => value)
          }}
        />
      </div>

      <button
        className={[
          "rounded px-2 py-1 text-sm font-medium",
          canSubmitResize
            ? "bg-[var(--accent)] text-[var(--plain-white)]"
            : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
        ]->Array.join(" ")}
        disabled={!canSubmitResize}
        onClick={_ => handleResizeSubmit()}>
        {"Save"->React.string}
      </button>
    </div>
  </div>
}
