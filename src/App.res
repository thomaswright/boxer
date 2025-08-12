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
  let update2D = (a, i, j, f) =>
    a->Array.mapWithIndex((row, rowI) =>
      rowI == i ? row->Array.mapWithIndex((cell, cellJ) => cellJ == j ? f(cell) : cell) : row
    )
  let make2D = (a, b, f) => Array.make(~length=a, Array.make(~length=b, f()))
  let dims2D = a => {
    let boardWidth = a->Array.length
    let boardHeight = a->Array.get(0)->Option.mapOr(0, line => line->Array.length)
    (boardWidth, boardHeight)
  }
  let check2D = (a, i, j) => {
    a->Array.get(i)->Option.flatMap(row => row->Array.get(j))
  }
}

let defaultBoard = Array.make2D(12, 12, () => None)

let defaultBrush = Array.make2D(3, 3, () => false)

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
  let (brush, setBrush, _) = useLocalStorage("brush", defaultBrush)
  let (showMask, setShowMask, _) = useLocalStorage("show-mask", true)
  let (myColor, setMyColor, _) = useLocalStorage("myColor", "blue")
  let (maskOff, setMaskOff) = React.useState(() => false)

  let isMouseDown = useIsMouseDown()

  let (boardWidth, boardHeight) = board->Array.dims2D
  let (brushWidth, brushHeight) = brush->Array.dims2D

  let onMouseMove = _ => setMaskOff(_ => false)
  let applyBrush = (clickI, clickJ) => {
    let brushCenterWidth = brushWidth / 2
    let brushCenterHeight = brushHeight / 2

    setBoard(b =>
      b->Array.mapWithIndex((row, boardI) =>
        row->Array.mapWithIndex(
          (cell, boardJ) => {
            let brushPosI = boardI - clickI + brushCenterWidth
            let brushPosJ = boardJ - clickJ + brushCenterHeight

            Array.check2D(brush, brushPosI, brushPosJ)->Option.getOr(false) ? Some(myColor) : cell
          },
        )
      )
    )
  }

  React.useEffect0(() => {
    window->Window.addMouseMoveEventListener(onMouseMove)

    None
  })

  <div className=" flex flex-row gap-5">
    <div
      className={"border w-fit h-fit"}
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${brushWidth->Int.toString}, 1rem)`,
        gridTemplateRows: `repeat(${brushHeight->Int.toString}, 1rem)`,
      }}>
      {brush
      ->Array.mapWithIndex((line, i) => {
        line
        ->Array.mapWithIndex((cell, j) => {
          let isCursorCenter = brushWidth / 2 == i && brushHeight / 2 == j
          <div
            className={"w-full h-full group relative "}
            key={i->Int.toString ++ j->Int.toString}
            onMouseEnter={_ => {
              if isMouseDown {
                setBrush(b => b->Array.update2D(i, j, v => !v))
              }
            }}
            onClick={_ => {
              setBrush(b => b->Array.update2D(i, j, v => !v))
              setMaskOff(_ => true)
            }}>
            <div
              className={"w-full h-full absolute"}
              style={{
                backgroundColor: cell ? "#00c3ff" : "transparent",
              }}
            />
            {maskOff || !showMask
              ? React.null
              : <div
                  className="absolute w-full h-full inset-0 bg-black opacity-0 group-hover:opacity-20">
                </div>}
            {!isCursorCenter
              ? React.null
              : <div className="absolute w-full h-full flex flex-row items-center justify-center ">
                  <div className=" w-1/2 h-1/2 bg-red-500 rounded-full"></div>
                </div>}
          </div>
        })
        ->React.array
      })
      ->React.array}
    </div>

    <div
      className={"border w-fit h-fit"}
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${boardWidth->Int.toString}, 1rem)`,
        gridTemplateRows: `repeat(${boardHeight->Int.toString}, 1rem)`,
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
                applyBrush(i, j)
              }
            }}
            onClick={_ => {
              applyBrush(i, j)
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
