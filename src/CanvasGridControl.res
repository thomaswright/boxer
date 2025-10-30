@react.component
let make = (~showGrid, ~setShowGrid) => {
  <div className="flex flex-row items-center justify-between p-2 w-full">
    <div className="font-medium"> {"Canvas Grid"->React.string} </div>
    <Switch checked={showGrid} onChange={value => setShowGrid(_ => value)} />
  </div>
}
