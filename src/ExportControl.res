@react.component
let make = (
  ~exportScaleInput,
  ~setExportScaleInput,
  ~includeExportBackground,
  ~setIncludeExportBackground,
  ~includeExportDotMask,
  ~setIncludeExportDotMask,
  ~canExport,
  ~onExport,
) => {
  <div className=" p-2 flex flex-col gap-2 w-full">
    <span className="font-medium"> {"Export PNG"->React.string} </span>
    <div className="flex flex-row  gap-2 items-end">
      <label className="flex flex-col gap-1 text-sm">
        <span className="text-xs uppercase tracking-wide text-[var(--plain-500)]">
          {"Scale"->React.string}
        </span>
        <input
          className="border border-[var(--plain-300)]  rounded px-2 py-1 text-sm w-16"
          type_="number"
          min={"1"}
          step={1.0}
          value={exportScaleInput}
          onChange={event => {
            let value = ReactEvent.Form.target(event)["value"]
            setExportScaleInput(_ => value)
          }}
        />
      </label>
      <button
        className={[
          "rounded-xl px-2 py-1 text-sm font-medium flex-1 h-fit",
          canExport
            ? "bg-[var(--accent)] text-[var(--plain-white)]"
            : "bg-[var(--plain-200)] text-[var(--plain-500)] cursor-not-allowed",
        ]->Array.join(" ")}
        disabled={!canExport}
        onClick={_ => onExport()}>
        {"Export"->React.string}
      </button>
    </div>
    <label className="flex flex-row items-center gap-2 text-sm">
      <input
        type_="checkbox"
        checked={includeExportBackground}
        onChange={event => {
          let checked = ReactEvent.Form.target(event)["checked"]
          setIncludeExportBackground(_ => checked)
        }}
      />
      <span> {"Include Background"->React.string} </span>
    </label>
    <label className="flex flex-row items-center gap-2 text-sm">
      <input
        type_="checkbox"
        checked={includeExportDotMask}
        onChange={event => {
          let checked = ReactEvent.Form.target(event)["checked"]
          setIncludeExportDotMask(_ => checked)
        }}
      />
      <span> {"Apply Dot Mask"->React.string} </span>
    </label>
  </div>
}
