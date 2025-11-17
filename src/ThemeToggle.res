open Theme

@react.component
let make = (
  ~theme: Theme.theme,
  ~setTheme,
  ~setViewportBackgroundColor,
  ~canvasBackgroundColor,
  ~setCanvasBackgroundColor,
  ~myColor,
) => {
  let buttonClass = "w-fit flex-none rounded p-1 text-lg transition-colors bg-[var(--plain-200)] text-[var(--plain-black)]"

  <div className="p-2 flex flex-row gap-2 w-full items-center">
    {switch theme {
    | Light =>
      <button
        className={buttonClass}
        onClick={_ => {
          setTheme(_ => Dark)
          setViewportBackgroundColor(_ => "#181818")
        }}>
        <Icons.Sun />
      </button>
    | Dark =>
      <button
        className={buttonClass}
        onClick={_ => {
          setTheme(_ => Light)
          setViewportBackgroundColor(_ => "#d8d8d8")
        }}>
        <Icons.Moon />
      </button>
    }}

    <div className="flex-1 text-right"> {"Background"->React.string} </div>
    <button
      className="w-6 h-6 border rounded"
      style={{
        backgroundColor: canvasBackgroundColor,
      }}
      onClick={_ => setCanvasBackgroundColor(_ => myColor)}
    />
  </div>
}
