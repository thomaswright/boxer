@react.component
let make = (~isSilhouette, ~setIsSilhouette) => {
  <div className="flex flex-row items-center justify-between p-2 w-full">
    <div className="font-bold text-sm"> {"Silhouette"->React.string} </div>
    <Switch checked={isSilhouette} onChange={value => setIsSilhouette(_ => value)} />
  </div>
}
