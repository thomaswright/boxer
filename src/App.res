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
    let boardDimI = a->Array.length
    let boardDimJ = a->Array.get(0)->Option.mapOr(0, line => line->Array.length)
    (boardDimI, boardDimJ)
  }
  let check2D = (a, i, j) => {
    a->Array.get(i)->Option.flatMap(row => row->Array.get(j))
  }
}

type brushMode = | @as("Color") Color | @as("Erase") Erase

let defaultBoard = Array.make2D(12, 12, () => Nullable.null)
let defaultBrush = Array.make2D(3, 3, () => false)
let defaultTileMask = Array.make2D(4, 4, () => true)

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

@set @scope("style") external setStyleDisplay: (Dom.element, string) => unit = "display"

let getOverlayId = (i, j) => "canvas-overlay" ++ i->Int.toString ++ j->Int.toString

let isLight = color => {
  let (_, _, l) = Texel.convert(color->Texel.hexToRgb, Texel.srgb, Texel.okhsl)
  l > 0.5
}

@react.component
let make = () => {
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)

  let (board, setBoard, _) = useLocalStorage("board", defaultBoard)
  let (brush, setBrush, _) = useLocalStorage("brush", defaultBrush)
  let (tileMask, setTileMask, _) = useLocalStorage("tile-mask", defaultTileMask)

  let (showCursorOverlay, setShowCursorOverlay, _) = useLocalStorage("show-cursor-overlay", true)
  let (myColor, setMyColor, _) = useLocalStorage("my-color", "blue")
  let (cursorOverlayOff, setCursorOverlayOff) = React.useState(() => false)

  let isMouseDown = useIsMouseDown()

  let (boardDimI, boardDimJ) = board->Array.dims2D
  let (brushDimI, brushDimJ) = brush->Array.dims2D
  let brushCenterDimI = brushDimI / 2
  let brushCenterDimJ = brushDimJ / 2
  let (tileMaskDimI, tileMaskDimJ) = tileMask->Array.dims2D

  let onMouseMove = _ => setCursorOverlayOff(_ => false)

  let canApply = (boardI, boardJ, clickI, clickJ) => {
    let brushPosI = boardI - clickI + brushCenterDimI
    let brushPosJ = boardJ - clickJ + brushCenterDimJ

    let brushAllows = Array.check2D(brush, brushPosI, brushPosJ)->Option.getOr(false)

    let maskAllows =
      Array.check2D(tileMask, mod(boardI, tileMaskDimI), mod(boardJ, tileMaskDimJ))->Option.getOr(
        false,
      )

    brushAllows && maskAllows
  }

  let applyOverlay = (clickI, clickJ, f) => {
    board->Array.forEachWithIndex((row, boardI) =>
      row->Array.forEachWithIndex((_, boardJ) => {
        if canApply(boardI, boardJ, clickI, clickJ) {
          let id = getOverlayId(boardI, boardJ)
          document
          ->Document.getElementById(id)
          ->Option.mapOr((), f)
        }
      })
    )
  }

  let getBrushColor = () => {
    switch brushMode {
    | Color => Nullable.Value(myColor)
    | Erase => Nullable.null
    }
  }

  let applyBrush = (clickI, clickJ) => {
    setBoard(b =>
      b->Array.mapWithIndex((row, boardI) =>
        row->Array.mapWithIndex(
          (cell, boardJ) => {
            canApply(boardI, boardJ, clickI, clickJ) ? getBrushColor() : cell
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
    <div>
      <div
        className={"border w-fit h-fit"}
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${tileMaskDimI->Int.toString}, 1rem)`,
          gridTemplateRows: `repeat(${tileMaskDimJ->Int.toString}, 1rem)`,
        }}>
        {tileMask
        ->Array.mapWithIndex((line, i) => {
          line
          ->Array.mapWithIndex((cell, j) => {
            <div
              className={"w-full h-full group relative "}
              key={i->Int.toString ++ j->Int.toString}
              onMouseEnter={_ => {
                if isMouseDown {
                  setTileMask(b => b->Array.update2D(i, j, v => !v))
                }
              }}
              onMouseDown={_ => {
                setTileMask(b => b->Array.update2D(i, j, v => !v))
                setCursorOverlayOff(_ => true)
              }}>
              <div
                className={"w-full h-full absolute"}
                style={{
                  backgroundColor: cell ? "#ffa700" : "transparent",
                }}
              />
              {cursorOverlayOff || !showCursorOverlay
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

      <div
        className={"border w-fit h-fit"}
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${brushDimI->Int.toString}, 1rem)`,
          gridTemplateRows: `repeat(${brushDimJ->Int.toString}, 1rem)`,
        }}>
        {brush
        ->Array.mapWithIndex((line, i) => {
          line
          ->Array.mapWithIndex((cell, j) => {
            let isCursorCenter = brushDimI / 2 == i && brushDimJ / 2 == j
            <div
              className={"w-full h-full group relative "}
              key={i->Int.toString ++ j->Int.toString}
              onMouseEnter={_ => {
                if isMouseDown {
                  setBrush(b => b->Array.update2D(i, j, v => !v))
                }
              }}
              onMouseDown={_ => {
                setBrush(b => b->Array.update2D(i, j, v => !v))
                setCursorOverlayOff(_ => true)
              }}>
              <div
                className={"w-full h-full absolute"}
                style={{
                  backgroundColor: cell ? "#00c3ff" : "transparent",
                }}
              />
              {cursorOverlayOff || !showCursorOverlay
                ? React.null
                : <div
                    className="absolute w-full h-full inset-0 bg-black opacity-0 group-hover:opacity-20">
                  </div>}
              {!isCursorCenter
                ? React.null
                : <div
                    className="absolute w-full h-full flex flex-row items-center justify-center ">
                    <div className=" w-1/2 h-1/2 bg-red-500 rounded-full"></div>
                  </div>}
            </div>
          })
          ->React.array
        })
        ->React.array}
      </div>
    </div>

    <div
      className={"border w-fit h-fit"}
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${boardDimI->Int.toString}, 1rem)`,
        gridTemplateRows: `repeat(${boardDimJ->Int.toString}, 1rem)`,
      }}>
      {board
      ->Array.mapWithIndex((line, i) => {
        line
        ->Array.mapWithIndex((cell, j) => {
          let backgroundColor = cell->Nullable.getOr("transparent")
          let overlayBackgroundColor =
            cell->Nullable.mapOr("black", v => v->isLight ? "black" : "white")

          <div
            className={"w-full h-full group relative"}
            key={i->Int.toString ++ j->Int.toString}
            onMouseEnter={_ => {
              applyOverlay(
                i,
                j,
                el => {
                  el->setStyleDisplay("block")
                },
              )

              if isMouseDown {
                applyBrush(i, j)
              }
            }}
            onMouseLeave={_ => {
              applyOverlay(
                i,
                j,
                el => {
                  el->setStyleDisplay("none")
                },
              )
            }}
            onMouseDown={_ => {
              applyBrush(i, j)
              setCursorOverlayOff(_ => true)
            }}>
            <div
              className={"w-full h-full absolute"}
              style={{
                backgroundColor: backgroundColor,
              }}
            />
            {cursorOverlayOff || !showCursorOverlay
              ? React.null
              : <div
                  style={{
                    display: "none",
                    backgroundColor: overlayBackgroundColor,
                  }}
                  id={getOverlayId(i, j)}
                  className="absolute w-full h-full inset-0 opacity-20">
                </div>}
          </div>
        })
        ->React.array
      })
      ->React.array}
    </div>
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-2">
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
      />
      <div>
        <div className="flex flex-row"> {"Show Brush Overlay"->React.string} </div>
        <Switch checked={showCursorOverlay} onChange={v => setShowCursorOverlay(_ => v)} />
      </div>
    </div>
  </div>
}
