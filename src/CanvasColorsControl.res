@react.component
let make = (
  ~myColor,
  ~canvasBackgroundColor,
  ~setCanvasBackgroundColor,
  ~viewportBackgroundColor,
  ~setViewportBackgroundColor,
) => {
  <div className=" p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row">
      <span className="font-medium flex-1"> {"Canvas Colors"->React.string} </span>
      <button
        type_="button"
        className="flex flex-row items-center gap-1 text-xs font-medium ml-2"
        onClick={_ => {
          setCanvasBackgroundColor(_ => Initials.canvasBackgroundColor)
          setViewportBackgroundColor(_ => Initials.viewportBackgroundColor)
        }}>
        {"Default"->React.string}
      </button>
    </div>
    <div className="flex flex-col gap-1">
      <button
        type_="button"
        className="flex flex-row items-center gap-1 text-xs font-medium "
        onClick={_ => setCanvasBackgroundColor(_ => myColor)}>
        <div className="flex-1 text-left"> {"Background"->React.string} </div>
        <div
          className="w-6 h-6 border rounded"
          style={{
            backgroundColor: canvasBackgroundColor,
          }}
        />
      </button>
      <button
        type_="button"
        className="flex flex-row items-center gap-1 text-xs font-medium"
        onClick={_ => setViewportBackgroundColor(_ => myColor)}>
        <div className="flex-1 text-left"> {"Viewport"->React.string} </div>
        <div
          className="w-6 h-6 border rounded"
          style={{
            backgroundColor: viewportBackgroundColor,
          }}
        />
      </button>
    </div>
  </div>
}
