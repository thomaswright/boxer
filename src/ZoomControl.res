@react.component
let make = (~onZoomOut, ~onZoomReset, ~onZoomIn, ~onCenterCanvas, ~onFitCanvas, ~zoom) => {
  let zoomPercentString = (zoom *. 100.)->Float.toFixed(~digits=0)

  <div className="p-2 flex flex-col gap-2 w-full">
    <div className="flex flex-row items-center justify-between">
      <span className="font-medium"> {"Zoom"->React.string} </span>
      <span className="text-sm font-mono"> {`${zoomPercentString}%`->React.string} </span>
    </div>
    <div className="flex flex-row gap-2">
      <button
        className="flex-1 rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onZoomOut()}>
        {"-"->React.string}
      </button>
      <button
        className="flex-1 rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onZoomReset()}>
        {"100%"->React.string}
      </button>
      <button
        className="flex-1 rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onZoomIn()}>
        {"+"->React.string}
      </button>
    </div>
    <div className="flex flex-row gap-2">
      <button
        className="flex-1 rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onCenterCanvas()}>
        {"Center"->React.string}
      </button>
      <button
        className="flex-1 rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onFitCanvas()}>
        {"Fit"->React.string}
      </button>
    </div>
  </div>
}
