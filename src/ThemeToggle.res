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
  let buttonClass = " flex-none rounded w-7 h-7 flex flex-row items-center justify-center text-lg transition-colors bg-[var(--plain-200)] text-[var(--plain-black)]"

  <div className="p-2 flex flex-row gap-2 w-full items-center">
    <div className="flex-1 text-sm font-bold"> {"Background"->React.string} </div>
    <button
      className="w-6 h-6 border rounded"
      style={{
        backgroundColor: canvasBackgroundColor,
      }}
      onClick={_ => setCanvasBackgroundColor(_ => myColor)}
    />
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
          setTheme(_ => Tan)
          setViewportBackgroundColor(_ => "#FBE0C1")
        }}>
        <Icons.Moon />
      </button>
    | Tan =>
      <button
        className={buttonClass}
        onClick={_ => {
          setTheme(_ => Pink)
          setViewportBackgroundColor(_ => "#F4E6F0")
        }}>
        {"🏝️"->React.string}
      </button>
    | Pink =>
      <button
        className={buttonClass}
        onClick={_ => {
          setTheme(_ => Light)
          setViewportBackgroundColor(_ => "#d8d8d8")
        }}>
        {"🌸"->React.string}
      </button>
    }}
  </div>
}
