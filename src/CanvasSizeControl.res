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
  let baseButtonClasses = "flex-1 px-2 py-1 text-xs font-medium border first:rounded-l last:rounded-r"
  let scaleButtonClasses = [
    baseButtonClasses,
    switch resizeMode {
    | Scale =>
      "bg-[color:var(--accent)] text-[color:var(--plain-white)] border-[color:var(--accent)]"
    | Crop =>
      "bg-[color:var(--plain-100)] text-[color:var(--plain-700)] border-[color:var(--plain-300)]"
    },
  ]->Array.join(" ")
  let cropButtonClasses = [
    baseButtonClasses,
    switch resizeMode {
    | Crop =>
      "bg-[color:var(--accent)] text-[color:var(--plain-white)] border-[color:var(--accent)]"
    | Scale =>
      "bg-[color:var(--plain-100)] text-[color:var(--plain-700)] border-[color:var(--plain-300)]"
    },
  ]->Array.join(" ")

  <div className=" p-2 flex flex-col gap-2 w-full">
    <div
      className={["flex flex-row items-center justify-between font-medium", "w-full"]->Array.join(
        " ",
      )}>
      {"Canvas Size"->React.string}
    </div>
    <div className="flex flex-col gap-2">
      <div className="flex flex-row">
        <button
          type_="button"
          className={scaleButtonClasses}
          ariaPressed={resizeMode == Scale ? #"true" : #"false"}
          onClick={_ => setResizeMode(_ => Scale)}>
          {"Scale"->React.string}
        </button>
        <button
          type_="button"
          className={cropButtonClasses}
          ariaPressed={resizeMode == Crop ? #"true" : #"false"}
          onClick={_ => setResizeMode(_ => Crop)}>
          {"Crop"->React.string}
        </button>
      </div>
      <div className="flex flex-row w-full gap-2 justify-between items-center">
        <input
          className="border rounded px-2 py-1 text-sm flex-none w-16 "
          value={resizeRowsInput}
          onChange={event => {
            let value = ReactEvent.Form.target(event)["value"]
            setResizeRowsInput(_ => value)
          }}
        />
        <Icons.X />
        <input
          className="border rounded px-2 py-1 text-sm flex-none w-16 "
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
            ? "bg-[color:var(--accent)] text-[color:var(--plain-white)]"
            : "bg-[color:var(--plain-200)] text-[color:var(--plain-500)] cursor-not-allowed",
        ]->Array.join(" ")}
        disabled={!canSubmitResize}
        onClick={_ => handleResizeSubmit()}>
        {"Save"->React.string}
      </button>
    </div>
  </div>
}
