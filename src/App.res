@@warning("-44")
open Webapi.Dom

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

module HexColorPicker = {
  @module("react-colorful") @react.component
  external make: (~color: string, ~onChange: string => unit) => React.element = "HexColorPicker"
}

module Switch = {
  @module("./Switch.jsx") @react.component
  external make: (~checked: bool, ~onChange: bool => unit) => React.element = "default"
}

module Array = {
  include Array
  let update2d = (a, i, j, f) =>
    a->Array.mapWithIndex((row, rowI) =>
      rowI == i ? row->Array.mapWithIndex((cell, cellJ) => cellJ == j ? f(cell) : cell) : row
    )
  let make2D = (a, b) => Array.make(~length=a, Array.make(~length=b, None))
}

let defaultBoard = Array.make2D(12, 12)

let useIsMouseDown = () => {
  let (isMouseDown, setIsMouseDown) = React.useState(() => false)

  React.useEffect0(() => {
    let downHandler = _ => setIsMouseDown(_ => true)
    let upHandler = _ => setIsMouseDown(_ => false)
    window->Window.addMouseDownEventListener(downHandler)
    window->Window.addMouseUpEventListener(upHandler)

    Some(
      () => {
        window->Window.removeMouseDownEventListener(downHandler)
        window->Window.removeMouseUpEventListener(upHandler)
      },
    )
  })

  isMouseDown
}

@react.component
let make = () => {
  let (board, setBoard, _) = useLocalStorage("board", defaultBoard)
  let (showMask, setShowMask, _) = useLocalStorage("show-mask", true)
  let (myColor, setMyColor, _) = useLocalStorage("myColor", "blue")
  let (maskOff, setMaskOff) = React.useState(() => false)

  let isMouseDown = useIsMouseDown()

  let width = board->Array.length
  let height = board->Array.get(0)->Option.mapOr(0, line => line->Array.length)

  let onMouseMove = _ => setMaskOff(_ => false)

  React.useEffect0(() => {
    window->Window.addMouseMoveEventListener(onMouseMove)

    None
  })

  <div className=" flex flex-row gap-5">
    <div
      className={"border w-fit h-fit"}
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${width->Int.toString}, 1rem)`,
        gridTemplateRows: `repeat(${height->Int.toString}, 1rem)`,
      }}>
      {board
      ->Array.mapWithIndex((line, i) => {
        line
        ->Array.mapWithIndex((cell, j) => {
          let backgroundColor = cell->Option.getOr("transparent")
          <div
            className={"w-full h-full group relative"}
            key={i->Int.toString ++ j->Int.toString}
            onMouseEnter={_ => {
              if isMouseDown {
                setBoard(b => b->Array.update2d(i, j, _ => Some(myColor)))
              }
            }}
            onClick={_ => {
              setBoard(b => b->Array.update2d(i, j, _ => Some(myColor)))
              setMaskOff(_ => true)
            }}>
            <div
              className={"w-full h-full absolute"}
              style={{
                backgroundColor: backgroundColor,
              }}
            />
            {maskOff || !showMask
              ? React.null
              : <div
                  className="absolute w-full h-full inset-0 bg-black opacity-0 group-hover:opacity-20">
                </div>}
          </div>
        })
        ->React.array
      })
      ->React.array}
    </div>
    <div className="flex flex-col gap-5">
      <HexColorPicker
        color={myColor}
        onChange={newColor => {
          setMyColor(_ => newColor)
        }}
      />
      <div>
        <div className="flex flex-row"> {"Show Overlay"->React.string} </div>
        <Switch checked={showMask} onChange={v => setShowMask(_ => v)} />
      </div>
    </div>
  </div>
}
