@react.component
let make = (~isDotMask, ~setCanvasDotMask) => {
  <div className="flex flex-row items-center justify-between p-2 w-full">
    <div className="font-medium"> {"Dot Mode"->React.string} </div>
    <Switch checked={isDotMask} onChange={value => setCanvasDotMask(_ => value)} />
  </div>
}
