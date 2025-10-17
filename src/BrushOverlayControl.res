@react.component
let make = (~showCursorOverlay, ~setShowCursorOverlay) => {
  <div className="flex flex-row justify-between p-2 w-full">
    <div className="flex flex-row font-medium"> {"Brush Overlay"->React.string} </div>
    <Switch checked={showCursorOverlay} onChange={v => setShowCursorOverlay(_ => v)} />
  </div>
}
