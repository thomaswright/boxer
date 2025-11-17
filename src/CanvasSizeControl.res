open Types

@react.component
let make = (
  ~resizeRowsInput,
  ~setResizeRowsInput,
  ~resizeColsInput,
  ~setResizeColsInput,
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
      <div className={"flex flex-row gap-2 w-full"}>
        <button
          className={[
            "rounded px-1 py-1 text-xs font-medium flex-1",
            canSubmitResize
              ? "bg-[var(--accent)] text-[var(--plain-white)]"
              : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canSubmitResize}
          onClick={_ => handleResizeSubmit(Crop)}>
          {"Save (Scale)"->React.string}
        </button>
        <button
          className={[
            "rounded px-1 py-1 text-xs font-medium flex-1",
            canSubmitResize
              ? "bg-[var(--accent)] text-[var(--plain-white)]"
              : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canSubmitResize}
          onClick={_ => handleResizeSubmit(Scale)}>
          {"Save (Crop)"->React.string}
        </button>
      </div>
    </div>
  </div>
}
