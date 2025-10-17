open Types

@react.component
let make = (~brushMode, ~setBrushMode, ~myColor, ~setMyColor) => {
  <div className="relative flex flex-col gap-2 w-full overflow-x-visible items-center flex-none">
    <div className="flex flex-row gap-2 justify-center">
      <button
        className={[
          brushMode == Color ? " bg-blue-500 text-white" : "bg-gray-200",
          "px-2 font-medium rounded",
        ]->Array.join(" ")}
        onClick={_ => setBrushMode(_ => Color)}>
        {"Color"->React.string}
      </button>
      <button
        className={[
          brushMode == Erase ? " bg-blue-500 text-white" : "bg-gray-200",
          "px-2 font-medium rounded",
        ]->Array.join(" ")}
        onClick={_ => setBrushMode(_ => Erase)}>
        {"Erase"->React.string}
      </button>
    </div>
    <HexColorPicker
      color={myColor}
      onChange={newColor => {
        setMyColor(_ => newColor)
      }}
      style={{
        width: "96%",
      }}
    />
  </div>
}
