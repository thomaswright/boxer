open Theme

@react.component
let make = (~theme: Theme.theme, ~setTheme) => {
  let buttonClass = targetTheme =>
    "flex-1 rounded px-2 py-1 text-xs font-medium border transition-colors " ++ if (
      theme == targetTheme
    ) {
      "bg-[var(--accent)] text-[var(--plain-white)] border-[var(--accent)]"
    } else {
      "bg-[var(--plain-200)] text-[var(--plain-900)] border-[var(--plain-300)]"
    }

  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row items-center justify-between">
      <span className="font-medium"> {"Theme"->React.string} </span>
    </div>
    <div className="flex flex-row gap-2">
      <button className={buttonClass(Light)} onClick={_ => setTheme(_ => Light)}>
        {"Light"->React.string}
      </button>
      <button className={buttonClass(Dark)} onClick={_ => setTheme(_ => Dark)}>
        {"Dark"->React.string}
      </button>
    </div>
  </div>
}
