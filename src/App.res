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
type brush = array<array<bool>>
type brushMode = | @as("Color") Color | @as("Erase") Erase

// type toolTray = | @as("Hidden") Hidden | @as("Brush") Brush | @as("TileMask") TileMask

let makeBoard = (i, j) => Array.make2D(i, j, () => Nullable.null)
let makeBrush = (i, j) => Array.make2D(i, j, () => true)
let makeTileMask = (i, j) => Array.make2D(i, j, () => true)

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

type tileMask = {
  name: string,
  value: array<array<bool>>,
}

let defaultTileMasks = [
  [[true, false], [false, true]],
  [[false, true], [true, false]],
  [[false, true], [false, true]],
  [[true, false], [true, false]],
  [[false, false], [true, true]],
  [[true, true], [false, false]],
  [[true, false], [false, false]],
  [[false, true], [false, false]],
  [[false, false], [true, false]],
  [[false, false], [false, true]],
]

let defaultBrushes = [
  makeBrush(1, 1),
  makeBrush(2, 2),
  makeBrush(3, 3),
  makeBrush(4, 4),
  makeBrush(8, 8),
  makeBrush(12, 12),
  makeBrush(16, 16),
]

//  <div>
//           {[1, 2, 3, 4, 5, 8, 12, 16, 24]
//           ->Array.map(dim => {
//             let dimString = dim->Int.toString
//             <button
//               onClick={_ => setBrush(_ => makeBrush(dim, dim))}
//               className={"px-1 bg-gray-300 rounded text-xs"}>
//               {`${dimString}`->React.string}
//             </button>
//           })
//           ->React.array}
//         </div>

@react.component
let make = () => {
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)
  // let (toolTrayMode, setToolTrayMode, _) = useLocalStorage("tool-tray-mode", Brush)

  let (board, setBoard, _) = useLocalStorage("board", makeBoard(12, 12))
  let (brush, setBrush, _) = useLocalStorage("brush", makeBrush(3, 3))
  let (savedBrushes, setSavedBrushes, _) = useLocalStorage("saved-brushes", defaultBrushes)
  let (savedTileMasks, setSavedTileMasks, _) = useLocalStorage("saved-tile-masks", defaultTileMasks)

  let (tileMask, setTileMask, _) = useLocalStorage("tile-mask", makeTileMask(4, 4))

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
  <div className=" flex flex-col gap-5 p-5">
    <div className="flex flex-row gap-2">
      <div
        className={"border w-20 h-20"}
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${brushDimI->Int.toString}, auto)`,
          gridTemplateRows: `repeat(${brushDimJ->Int.toString}, auto)`,
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
      <div className={"flex flex-row flex-wrap gap-1 w-32"}>
        {savedBrushes
        ->Array.map(savedBrush => {
          let (dimI, dimJ) = savedBrush->Array.dims2D
          <div>
            <div className={" text-3xs font-bold border border-b-0 w-8 text-center"}>
              {`${dimI->Int.toString}:${dimJ->Int.toString}`->React.string}
            </div>

            <button
              onClick={_ => setBrush(_ => savedBrush)}
              style={{
                display: "grid",
                gridTemplateColumns: `repeat(${dimI->Int.toString}, auto)`,
                gridTemplateRows: `repeat(${dimJ->Int.toString}, auto)`,
              }}
              className={"h-8 w-8 border"}>
              {savedBrush
              ->Array.mapWithIndex((line, i) => {
                line
                ->Array.mapWithIndex(
                  (cell, j) => {
                    <div
                      className={"w-full h-full "}
                      key={i->Int.toString ++ j->Int.toString}
                      style={{
                        backgroundColor: cell ? "#00c3ff" : "transparent",
                      }}>
                    </div>
                  },
                )
                ->React.array
              })
              ->React.array}
            </button>
          </div>
        })
        ->React.array}
      </div>
      <div
        className={"border w-20 h-20"}
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${tileMaskDimI->Int.toString}, auto)`,
          gridTemplateRows: `repeat(${tileMaskDimJ->Int.toString}, auto)`,
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

      <div className={"flex flex-row flex-wrap gap-1 w-20"}>
        {savedTileMasks
        ->Array.map(savedTileMask => {
          let (dimI, dimJ) = savedTileMask->Array.dims2D
          <button
            onClick={_ => setTileMask(_ => savedTileMask)}
            style={{
              display: "grid",
              gridTemplateColumns: `repeat(${dimI->Int.toString}, auto)`,
              gridTemplateRows: `repeat(${dimJ->Int.toString}, auto)`,
            }}
            className={"h-5 w-5 border"}>
            {savedTileMask
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    className={"w-full h-full "}
                    key={i->Int.toString ++ j->Int.toString}
                    style={{
                      backgroundColor: cell ? "#ffa700" : "transparent",
                    }}>
                  </div>
                },
              )
              ->React.array
            })
            ->React.array}
          </button>
        })
        ->React.array}
      </div>
    </div>

    // <div>
    //   {switch toolTrayMode {
    //   | Hidden => React.null
    //   | Brush => "Brush"->React.string
    //   | TileMask => "TileMask"->React.string
    //   }}
    // </div>

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
