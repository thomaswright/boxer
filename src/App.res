@@warning("-44")
open Webapi.Dom

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

module HexColorPicker = {
  @module("react-colorful") @react.component
  external make: (
    ~color: string,
    ~onChange: string => unit,
    ~style: ReactDOMStyle.t=?,
    ~className: string=?,
  ) => React.element = "HexColorPicker"
}

module Switch = {
  @module("./Switch.jsx") @react.component
  external make: (~checked: bool, ~onChange: bool => unit) => React.element = "default"
}

module Array = {
  include Array

  let make2D = (rows, cols, f) =>
    Array.make(~length=rows, ())->Array.map(_ => Array.make(~length=cols, f()))
  let dims2D = a => {
    let boardDimI = a->Array.length
    let boardDimJ = a->Array.get(0)->Option.mapOr(0, line => line->Array.length)
    (boardDimI, boardDimJ)
  }
  let check2D = (a, i, j) => {
    a->Array.get(i)->Option.flatMap(row => row->Array.get(j))
  }

  @module("./other.js")
  external isEqual2D: (array<array<bool>>, array<array<bool>>) => bool = "isEqual2D"
}

module Initials = {
  let canvasBackgroundColor = "#ffffff"
  let viewportBackgroundColor = "#e5e7eb"
  let myColor = "blue"
  let zoom_factor = 1.1
  let silhouette = false
}

type board = array<array<Nullable.t<string>>>
type canvasState = {
  id: string,
  board: board,
  zoom: float,
  pan: (float, float),
}
type exportOptions = {
  includeBackground: bool,
  backgroundColor: string,
}

type brushMode = | @as("Color") Color | @as("Erase") Erase
type resizeMode = | @as("Scale") Scale | @as("Crop") Crop

type canvasRenderer

@module("./CanvasRenderer.js")
external createCanvasRenderer: Dom.element => Js.Nullable.t<canvasRenderer> = "createCanvasRenderer"

@module("./CanvasRenderer.js")
external disposeCanvasRenderer: canvasRenderer => unit = "disposeCanvasRenderer"

@module("./CanvasRenderer.js")
external setRendererSize: (canvasRenderer, int, int, int) => unit = "setRendererSize"

@module("./CanvasRenderer.js")
external updateRendererBoard: (canvasRenderer, board, string, bool) => unit = "updateBoard"

@module("./CanvasRenderer.js")
external updateRendererBrush: (canvasRenderer, array<array<bool>>, int, int) => unit = "updateBrush"

@module("./CanvasRenderer.js")
external updateRendererTileMask: (canvasRenderer, array<array<bool>>) => unit = "updateTileMask"

@module("./CanvasRenderer.js")
external setRendererOverlayOptions: (canvasRenderer, bool, bool) => unit = "setOverlayOptions"

@module("./CanvasRenderer.js")
external setRendererHover: (canvasRenderer, Js.Nullable.t<(int, int)>) => unit = "setHover"

@module("./CanvasRenderer.js")
external renderRenderer: canvasRenderer => unit = "render"

let makeBoard = (i, j) => Array.make2D(i, j, () => Nullable.null)
let makeBrush = (i, j) => Array.make2D(i, j, () => true)
let makeTileMask = (i, j) => Array.make2D(i, j, () => true)

let generateCanvasId = () => {
  let timestamp = Js.Date.now()->Float.toString
  let random = Js.Math.random()->Float.toString
  timestamp ++ "-" ++ random
}

let makeCanvas = (~board, ~zoom, ~pan) => {
  {id: generateCanvasId(), board, zoom, pan}
}

@module("./exportBoard.js")
external exportBoardAsPng: (board, float, exportOptions) => unit = "exportBoardAsPng"

let useIsMouseDown = () => {
  let (isMouseDown, setIsMouseDown) = React.useState(() => false)

  // Global listeners
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

let isLight = color => {
  let (_, _, l) = Texel.convert(color->Texel.hexToRgb, Texel.srgb, Texel.okhsl)
  l > 0.5
}

let defaultTileMasks = [
  [[true, true], [true, true]],
  [[true, false], [false, true]],
  [[false, true], [true, false]],
  [[false, true], [false, true]],
  [[true, false], [true, false]],
  [[false, false], [true, true]],
  [[true, true], [false, false]],
  [[true, false, false], [false, true, false], [false, false, true]],
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

module SavedBrushesPanel = {
  @react.component
  let make = (
    ~board,
    ~brush,
    ~setBrush,
    ~savedBrushes,
    ~setSavedBrushes,
    ~canDeleteSelectedBrush,
    ~handleDeleteSelectedBrush,
  ) => {
    <div className={"flex flex-col gap-1 h-full overflow-y-scroll"}>
      <div>
        <button
          className={[
            "w-4 h-4 leading-none",
            canDeleteSelectedBrush
              ? "bg-red-500 text-white"
              : "bg-gray-200 text-gray-500 cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canDeleteSelectedBrush}
          onClick={_ => handleDeleteSelectedBrush()}>
          {"x"->React.string}
        </button>
        <button
          className={"bg-gray-200 w-4 h-4 leading-none"}
          onClick={_ => {
            let newBrush =
              board->Array.map(row => row->Array.map(cell => !(cell->Nullable.isNullable)))
            setSavedBrushes(v => v->Array.concat([newBrush]))
            setBrush(_ => newBrush)
          }}>
          {"+"->React.string}
        </button>
      </div>

      {savedBrushes
      ->Array.mapWithIndex((savedBrush, savedBrushIndex) => {
        let (dimI, dimJ) = savedBrush->Array.dims2D
        let selected = Array.isEqual2D(brush, savedBrush)
        <button
          key={savedBrushIndex->Int.toString}
          onClick={_ => setBrush(_ => savedBrush)}
          className={["flex flex-row"]->Array.join(" ")}>
          <div
            className={[
              " text-3xs font-bold w-4 text-center bg-white",
              selected ? "text-orange-700" : "text-black",
            ]->Array.join(" ")}
            style={{writingMode: "sideways-lr"}}>
            {`${dimI->Int.toString}:${dimJ->Int.toString}`->React.string}
          </div>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: `repeat(${dimJ->Int.toString}, auto)`,
              gridTemplateRows: `repeat(${dimI->Int.toString}, auto)`,
            }}
            className={[
              selected ? "bg-orange-500" : "bg-gray-400",
              "flex flex-row h-8 w-8 rounded-xs overflow-hidden",
            ]->Array.join(" ")}>
            {savedBrush
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    className={[
                      "w-full h-full ",
                      selected
                        ? cell ? "bg-orange-500" : "bg-orange-200"
                        : cell
                        ? "bg-gray-400"
                        : "bg-gray-200",
                    ]->Array.join(" ")}
                    key={i->Int.toString ++ j->Int.toString}>
                  </div>
                },
              )
              ->React.array
            })
            ->React.array}
          </div>
        </button>
      })
      ->React.array}
    </div>
  }
}

module SavedTileMasksPanel = {
  @react.component
  let make = (
    ~board,
    ~setTileMask,
    ~savedTileMasks,
    ~setSavedTileMasks,
    ~selectedTileMaskIndex,
    ~setSelectedTileMaskIndex,
    ~canDeleteSelectedTileMask,
    ~handleDeleteSelectedTileMask,
  ) => {
    <div className={"flex flex-col gap-1 h-full overflow-y-scroll"}>
      <div>
        <button
          className={[
            "w-4 h-4 leading-none",
            canDeleteSelectedTileMask
              ? "bg-red-500 text-white"
              : "bg-gray-200 text-gray-500 cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canDeleteSelectedTileMask}
          onClick={_ => handleDeleteSelectedTileMask()}>
          {"x"->React.string}
        </button>
        <button
          className={"bg-gray-200 w-4 h-4 leading-none"}
          onClick={_ => {
            let newTileMask =
              board->Array.map(row => row->Array.map(cell => !(cell->Nullable.isNullable)))
            setSavedTileMasks(prev => {
              let next = prev->Array.concat([newTileMask])
              setSelectedTileMaskIndex(_ => next->Array.length - 1)
              next
            })
            setTileMask(_ => newTileMask)
          }}>
          {"+"->React.string}
        </button>
      </div>

      {savedTileMasks
      ->Array.mapWithIndex((savedTileMask, savedTileMaskIndex) => {
        let (dimI, dimJ) = savedTileMask->Array.dims2D
        let selected = savedTileMaskIndex == selectedTileMaskIndex
        <button
          key={savedTileMaskIndex->Int.toString}
          onClick={_ => {
            setSelectedTileMaskIndex(_ => savedTileMaskIndex)
            setTileMask(_ => savedTileMask)
          }}>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: `repeat(${dimJ->Int.toString}, auto)`,
              gridTemplateRows: `repeat(${dimI->Int.toString}, auto)`,
            }}
            className={[
              "h-8 w-8 rounded-xs overflow-hidden",
              selected ? "bg-orange-500 " : "bg-gray-400",
            ]->Array.join(" ")}>
            {savedTileMask
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    className={[
                      "w-full h-full ",
                      selected
                        ? cell ? "bg-orange-500" : "bg-orange-200"
                        : cell
                        ? "bg-gray-400"
                        : "bg-gray-200",
                    ]->Array.join(" ")}
                    key={i->Int.toString ++ j->Int.toString}
                    // style={{
                    //   backgroundColor: cell ? "inherit" : "#ddd",
                    // }}
                  >
                  </div>
                },
              )
              ->React.array
            })
            ->React.array}
          </div>
        </button>
      })
      ->React.array}
    </div>
  }
}

// module MyOverrides = {
//   module Elements = {
//     type props = {
//       ...JsxDOM.domProps,
//       \"data-active": bool,
//     }

//     @module("react")
//     external jsx: (string, props) => Jsx.element = "jsx"
//   }
// }

// @@jsxConfig({module_: "MyOverrides"})

module CanvasViewport = {
  let cellSize = 16
  let cellSizeFloat = 16.

  let hoverToNullable = cell =>
    switch cell {
    | Some((row, col)) => Js.Nullable.return((row, col))
    | None => Js.Nullable.null
    }

  @react.component
  let make = (
    ~canvasContainerRef: React.ref<Js.Nullable.t<Element.t>>,
    ~board,
    ~boardDimI,
    ~boardDimJ,
    ~transformValue,
    ~zoom,
    ~pan,
    ~cursorOverlayOff,
    ~setCursorOverlayOff,
    ~isMouseDown,
    ~applyBrush,
    ~showCursorOverlay,
    ~canvasBackgroundColor,
    ~viewportBackgroundColor,
    ~isSilhouette,
    ~clearHoverRef: React.ref<unit => unit>,
    ~brush,
    ~brushDimI,
    ~brushDimJ,
    ~brushCenterDimI,
    ~brushCenterDimJ,
    ~tileMask,
    ~tileMaskDimI,
    ~tileMaskDimJ,
  ) => {
    let canvasRef = React.useRef((Js.Nullable.null: Js.Nullable.t<Dom.element>))
    let rendererRef = React.useRef((None: option<canvasRenderer>))
    let hoveredCellRef = React.useRef((None: option<(int, int)>))
    let (panX, panY) = pan

    let withRenderer = callback =>
      switch rendererRef.current {
      | Some(renderer) => callback(renderer)
      | None => ()
      }

    React.useEffect0(() => {
      switch canvasRef.current->Js.Nullable.toOption {
      | Some(canvasElement) =>
        let maybeRenderer = createCanvasRenderer(canvasElement)
        switch maybeRenderer->Js.Nullable.toOption {
        | Some(renderer) =>
          rendererRef.current = Some(renderer)
          Some(
            () => {
              rendererRef.current = None
              disposeCanvasRenderer(renderer)
            },
          )
        | None =>
          Js.log("Unable to initialize WebGL2 renderer")
          None
        }
      | None => None
      }
    })

    React.useEffect5(() => {
      withRenderer(renderer => {
        setRendererSize(renderer, boardDimJ, boardDimI, cellSize)
        updateRendererBoard(renderer, board, canvasBackgroundColor, isSilhouette)
        renderRenderer(renderer)
        setRendererHover(renderer, hoverToNullable(hoveredCellRef.current))
      })
      None
    }, (board, boardDimI, boardDimJ, canvasBackgroundColor, isSilhouette))

    React.useEffect5(() => {
      withRenderer(renderer => {
        updateRendererBrush(renderer, brush, brushCenterDimI, brushCenterDimJ)
        setRendererHover(renderer, hoverToNullable(hoveredCellRef.current))
      })
      None
    }, (brush, brushDimI, brushDimJ, brushCenterDimI, brushCenterDimJ))

    React.useEffect3(() => {
      withRenderer(renderer => {
        updateRendererTileMask(renderer, tileMask)
        setRendererHover(renderer, hoverToNullable(hoveredCellRef.current))
      })
      None
    }, (tileMask, tileMaskDimI, tileMaskDimJ))

    React.useEffect3(() => {
      withRenderer(renderer => {
        let overlayEnabled = showCursorOverlay && !cursorOverlayOff
        setRendererOverlayOptions(renderer, overlayEnabled, isSilhouette)
        renderRenderer(renderer)
      })
      None
    }, (showCursorOverlay, cursorOverlayOff, isSilhouette))

    let updateHover = hover => {
      hoveredCellRef.current = hover
      withRenderer(renderer => setRendererHover(renderer, hoverToNullable(hover)))
    }

    React.useEffect0(() => {
      clearHoverRef.current = () => updateHover(None)
      Some(() => clearHoverRef.current = () => ())
    })

    let getCellFromEvent = event =>
      switch canvasContainerRef.current->Js.Nullable.toOption {
      | Some(containerElement) =>
        let rect = containerElement->Element.getBoundingClientRect
        let clientX = ReactEvent.Mouse.clientX(event)
        let clientY = ReactEvent.Mouse.clientY(event)
        let relativeX = clientX->Int.toFloat -. rect->DomRect.left
        let relativeY = clientY->Int.toFloat -. rect->DomRect.top
        let boardX = (relativeX -. panX) /. zoom
        let boardY = (relativeY -. panY) /. zoom
        if boardX < 0. || boardY < 0. {
          None
        } else {
          let col = (boardX /. cellSizeFloat)->Js.Math.floor_float->Float.toInt
          let row = (boardY /. cellSizeFloat)->Js.Math.floor_float->Float.toInt

          if col < 0 || col >= boardDimJ || row < 0 || row >= boardDimI {
            None
          } else {
            Some((row, col))
          }
        }
      | None => None
      }

    let handleMouseMove = event => {
      setCursorOverlayOff(_ => false)
      switch getCellFromEvent(event) {
      | Some((row, col)) =>
        updateHover(Some((row, col)))
        if isMouseDown {
          applyBrush(row, col)
        }
      | None => updateHover(None)
      }
    }

    let handleMouseDown = event =>
      switch getCellFromEvent(event) {
      | Some((row, col)) =>
        updateHover(Some((row, col)))
        applyBrush(row, col)
        setCursorOverlayOff(_ => true)
      | None => ()
      }

    let handleMouseLeave = _ => updateHover(None)

    let canvasWidth = boardDimJ * cellSize
    let canvasHeight = boardDimI * cellSize
    let widthString = canvasWidth->Int.toString ++ "px"
    let heightString = canvasHeight->Int.toString ++ "px"

    <div
      ref={ReactDOM.Ref.domRef(canvasContainerRef)}
      className="relative border border-gray-300 overflow-hidden w-full h-full"
      style={{
        backgroundColor: viewportBackgroundColor,
      }}>
      <div
        className={"absolute top-0 left-0"}
        style={{
          transform: transformValue,
          transformOrigin: "top left",
          backgroundColor: canvasBackgroundColor,
        }}>
        <canvas
          ref={ReactDOM.Ref.domRef(canvasRef)}
          className="absolute top-0 left-0 block"
          style={{
            width: widthString,
            height: heightString,
            imageRendering: "pixelated",
          }}
          onMouseMove={handleMouseMove}
          onMouseEnter={handleMouseMove}
          onMouseLeave={handleMouseLeave}
          onMouseDown={handleMouseDown}
        />
      </div>
    </div>
  }
}

module CanvasThumbnails = {
  @react.component
  let make = (
    ~canvases,
    ~currentCanvasId,
    ~canDeleteCanvas,
    ~handleDeleteCanvas,
    ~handleAddCanvas,
    ~onSelectCanvas,
  ) => {
    <div className="flex flex-row items-start gap-3 overflow-x-scroll p-2 pl-0">
      {canvases
      ->Array.map(canvas => {
        let canvasBoard = canvas.board
        let (thumbDimI, thumbDimJ) = canvasBoard->Array.dims2D
        let isSelectedCanvas = canvas.id == currentCanvasId
        <div
          key={canvas.id}
          className={[
            "relative flex-shrink-0 border-2 w-fit h-fit",
            isSelectedCanvas ? "border-blue-500" : "border-gray-200",
          ]->Array.join(" ")}>
          <button
            onClick={_ => onSelectCanvas(canvas.id)}
            className={[" w-fit h-fit block"]->Array.join(" ")}>
            <div
              className="h-16 w-16 grid"
              style={{
                gridTemplateColumns: `repeat(${thumbDimJ->Int.toString}, minmax(0, 1fr))`,
                gridTemplateRows: `repeat(${thumbDimI->Int.toString}, minmax(0, 1fr))`,
              }}>
              {canvasBoard
              ->Array.mapWithIndex((line, i) => {
                line
                ->Array.mapWithIndex(
                  (cell, j) => {
                    <div
                      key={i->Int.toString ++ j->Int.toString}
                      className="w-full h-full"
                      style={{
                        backgroundColor: cell->Nullable.getOr("transparent"),
                      }}>
                    </div>
                  },
                )
                ->React.array
              })
              ->React.array}
            </div>
          </button>
          {isSelectedCanvas
            ? <button
                className={[
                  " w-4 h-4 leading-none text-sm font-medium absolute right-0 bottom-0",
                  canDeleteCanvas
                    ? "bg-red-500 text-white"
                    : "bg-gray-200 text-gray-500 cursor-not-allowed",
                ]->Array.join(" ")}
                disabled={!canDeleteCanvas}
                onClick={e => {
                  e->JsxEvent.Mouse.stopPropagation
                  handleDeleteCanvas()
                }}>
                {"x"->React.string}
              </button>
            : React.null}
        </div>
      })
      ->React.array}
      <button
        onClick={_ => handleAddCanvas()}
        className="flex-shrink-0 h-16 w-16 border-2 border-dashed border-gray-300 flex items-center justify-center text-3xl text-gray-400">
        {"+"->React.string}
      </button>
    </div>
  }
}

module ColorControl = {
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
}

module CanvasColorsControl = {
  @react.component
  let make = (
    ~myColor,
    ~canvasBackgroundColor,
    ~setCanvasBackgroundColor,
    ~viewportBackgroundColor,
    ~setViewportBackgroundColor,
  ) => {
    <div className=" p-2 flex flex-col gap-2 w-full">
      <div className="flex flex-row">
        <span className="font-medium flex-1"> {"Canvas Colors"->React.string} </span>
        <button
          type_="button"
          className="flex flex-row items-center gap-1 text-xs font-medium ml-2"
          onClick={_ => {
            setCanvasBackgroundColor(_ => Initials.canvasBackgroundColor)
            setViewportBackgroundColor(_ => Initials.viewportBackgroundColor)
          }}>
          {"Default"->React.string}
        </button>
      </div>
      <div className="flex flex-col gap-1">
        <button
          type_="button"
          className="flex flex-row items-center gap-1 text-xs font-medium "
          onClick={_ => setCanvasBackgroundColor(_ => myColor)}>
          <div className="flex-1 text-left"> {"Background"->React.string} </div>
          <div
            className="w-6 h-6 border rounded"
            style={{
              backgroundColor: canvasBackgroundColor,
            }}
          />
        </button>
        <button
          type_="button"
          className="flex flex-row items-center gap-1 text-xs font-medium"
          onClick={_ => setViewportBackgroundColor(_ => myColor)}>
          <div className="flex-1 text-left"> {"Viewport"->React.string} </div>
          <div
            className="w-6 h-6 border rounded"
            style={{
              backgroundColor: viewportBackgroundColor,
            }}
          />
        </button>
      </div>
    </div>
  }
}

module BrushOverlayControl = {
  @react.component
  let make = (~showCursorOverlay, ~setShowCursorOverlay) => {
    <div className="flex flex-row justify-between p-2 w-full">
      <div className="flex flex-row font-medium"> {"Brush Overlay"->React.string} </div>
      <Switch checked={showCursorOverlay} onChange={v => setShowCursorOverlay(_ => v)} />
    </div>
  }
}

module CanvasSizeControl = {
  @react.component
  let make = (
    ~resizeRowsInput,
    ~setResizeRowsInput,
    ~resizeColsInput,
    ~setResizeColsInput,
    ~resizeMode,
    ~setResizeMode,
    ~canSubmitResize,
    ~onSubmitResize,
  ) => {
    let baseButtonClasses = "flex-1 rounded px-2 py-1 text-xs font-medium border"
    let scaleButtonClasses = [
      baseButtonClasses,
      switch resizeMode {
      | Scale => "bg-blue-500 text-white border-blue-500"
      | Crop => "bg-gray-100 text-gray-700 border-gray-300"
      },
    ]->Array.join(" ")
    let cropButtonClasses = [
      baseButtonClasses,
      switch resizeMode {
      | Crop => "bg-blue-500 text-white border-blue-500"
      | Scale => "bg-gray-100 text-gray-700 border-gray-300"
      },
    ]->Array.join(" ")

    <div className=" p-2 flex flex-col gap-2 w-full">
      <div
        className={["flex flex-row items-center justify-between font-medium", "w-full"]->Array.join(
          " ",
        )}>
        {"Canvas Size"->React.string}
      </div>
      <div className="flex flex-col gap-2">
        <div className="flex flex-row gap-2">
          <button
            type_="button"
            className={scaleButtonClasses}
            ariaPressed={resizeMode == Scale ? #"true" : #"false"}
            onClick={_ => setResizeMode(_ => Scale)}>
            {"Scale"->React.string}
          </button>
          <button
            type_="button"
            className={cropButtonClasses}
            ariaPressed={resizeMode == Crop ? #"true" : #"false"}
            onClick={_ => setResizeMode(_ => Crop)}>
            {"Crop"->React.string}
          </button>
        </div>
        <div className="flex flex-row w-full gap-2 justify-between">
          <input
            className="border rounded px-2 py-1 text-sm flex-none w-16 "
            value={resizeRowsInput}
            onChange={event => {
              let value = ReactEvent.Form.target(event)["value"]
              setResizeRowsInput(_ => value)
            }}
          />
          <span className={"flex-none px-1"}> {"x"->React.string} </span>
          <input
            className="border rounded px-2 py-1 text-sm flex-none w-16 "
            value={resizeColsInput}
            onChange={event => {
              let value = ReactEvent.Form.target(event)["value"]
              setResizeColsInput(_ => value)
            }}
          />
        </div>

        <button
          className={[
            "rounded px-2 py-1 text-sm font-medium",
            canSubmitResize
              ? "bg-blue-500 text-white"
              : "bg-gray-200 text-gray-500 cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canSubmitResize}
          onClick={_ => onSubmitResize()}>
          {"Save"->React.string}
        </button>
      </div>
    </div>
  }
}

module ZoomControl = {
  @react.component
  let make = (~onZoomOut, ~onZoomReset, ~onZoomIn, ~onCenterCanvas, ~zoom) => {
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
      <button
        className="rounded px-2 py-1 text-sm font-medium bg-gray-200"
        onClick={_ => onCenterCanvas()}>
        {"Center"->React.string}
      </button>
    </div>
  }
}

module SilhouetteControl = {
  @react.component
  let make = (~isSilhouette, ~setIsSilhouette) => {
    <div className="flex flex-row items-center justify-between p-2 w-full">
      <div className="font-medium"> {"Silhouette"->React.string} </div>
      <Switch checked={isSilhouette} onChange={value => setIsSilhouette(_ => value)} />
    </div>
  }
}

module ExportControl = {
  @react.component
  let make = (
    ~exportScaleInput,
    ~setExportScaleInput,
    ~includeBackground,
    ~setIncludeBackground,
    ~canExport,
    ~onExport,
  ) => {
    <div className=" p-2 flex flex-col gap-2 w-full">
      <span className="font-medium"> {"Export PNG"->React.string} </span>
      <div className="flex flex-row  gap-2 items-end">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-xs uppercase tracking-wide text-gray-500">
            {"Scale"->React.string}
          </span>
          <input
            className="border rounded px-2 py-1 text-sm w-16"
            type_="number"
            min={"1"}
            step={1.0}
            value={exportScaleInput}
            onChange={event => {
              let value = ReactEvent.Form.target(event)["value"]
              setExportScaleInput(_ => value)
            }}
          />
        </label>
        <button
          className={[
            "rounded px-2 py-1 text-sm font-medium flex-1 h-fit",
            canExport ? "bg-blue-500 text-white" : "bg-gray-200 text-gray-500 cursor-not-allowed",
          ]->Array.join(" ")}
          disabled={!canExport}
          onClick={_ => onExport()}>
          {"Export"->React.string}
        </button>
      </div>
      <label className="flex flex-row items-center gap-2 text-sm">
        <input
          type_="checkbox"
          checked={includeBackground}
          onChange={event => {
            let checked = ReactEvent.Form.target(event)["checked"]
            setIncludeBackground(_ => checked)
          }}
        />
        <span> {"Include Background"->React.string} </span>
      </label>
    </div>
  }
}

module ControlsPanel = {
  @react.component
  let make = (
    ~brushMode,
    ~setBrushMode,
    ~myColor,
    ~setMyColor,
    ~canvasBackgroundColor,
    ~setCanvasBackgroundColor,
    ~viewportBackgroundColor,
    ~setViewportBackgroundColor,
    ~isSilhouette,
    ~setIsSilhouette,
    ~showCursorOverlay,
    ~setShowCursorOverlay,
    ~resizeMode,
    ~setResizeMode,
    ~resizeRowsInput,
    ~setResizeRowsInput,
    ~resizeColsInput,
    ~setResizeColsInput,
    ~canSubmitResize,
    ~onSubmitResize,
    ~zoom,
    ~onZoomIn,
    ~onZoomOut,
    ~onZoomReset,
    ~onCenterCanvas,
    ~exportScaleInput,
    ~setExportScaleInput,
    ~includeExportBackground,
    ~setIncludeExportBackground,
    ~canExport,
    ~onExport,
  ) => {
    <div className=" h-full overflow-x-visible flex flex-col w-48 py-2">
      <ColorControl brushMode setBrushMode myColor setMyColor />
      <div className={"overflow-y-scroll flex-1 flex flex-col py-2 divide-y divide-gray-300"}>
        <CanvasColorsControl
          myColor
          canvasBackgroundColor
          setCanvasBackgroundColor
          viewportBackgroundColor
          setViewportBackgroundColor
        />
        <ZoomControl onZoomOut onZoomReset onZoomIn onCenterCanvas zoom />
        <SilhouetteControl isSilhouette setIsSilhouette />
        <ExportControl
          exportScaleInput
          setExportScaleInput
          includeBackground={includeExportBackground}
          setIncludeBackground={setIncludeExportBackground}
          canExport
          onExport
        />
        <CanvasSizeControl
          resizeRowsInput
          setResizeRowsInput
          resizeColsInput
          setResizeColsInput
          resizeMode
          setResizeMode
          canSubmitResize
          onSubmitResize
        />
        <BrushOverlayControl showCursorOverlay setShowCursorOverlay />
      </div>
    </div>
  }
}

@react.component
let make = () => {
  // Persistent tool state
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)
  let makeDefaultCanvas = () => makeCanvas(~board=makeBoard(12, 12), ~zoom=1., ~pan=(0., 0.))
  let (canvases, setCanvases, _) = useLocalStorage("canvases", [makeDefaultCanvas()])
  let (selectedCanvasId, setSelectedCanvasId, _) = useLocalStorage("selected-canvas-id", "")
  let (brush, setBrush, _) = useLocalStorage("brush", makeBrush(3, 3))
  let (savedBrushes, setSavedBrushes, _) = useLocalStorage("saved-brushes", defaultBrushes)
  let (savedTileMasks, setSavedTileMasks, _) = useLocalStorage("saved-tile-masks", defaultTileMasks)
  let (selectedTileMaskIndex, setSelectedTileMaskIndex, _) = useLocalStorage(
    "selected-tile-mask-index",
    0,
  )
  let (tileMask, setTileMask, _) = useLocalStorage("tile-mask", makeTileMask(4, 4))
  let (showCursorOverlay, setShowCursorOverlay, _) = useLocalStorage("show-cursor-overlay", true)
  let (myColor, setMyColor, _) = useLocalStorage("my-color", Initials.myColor)
  let (canvasBackgroundColor, setCanvasBackgroundColor, _) = useLocalStorage(
    "canvas-background-color",
    Initials.canvasBackgroundColor,
  )
  let (viewportBackgroundColor, setViewportBackgroundColor, _) = useLocalStorage(
    "viewport-background-color",
    Initials.viewportBackgroundColor,
  )
  let (isSilhouette, setIsSilhouette, _) = useLocalStorage("canvas-silhouette", Initials.silhouette)

  // Transient UI state
  let (cursorOverlayOff, setCursorOverlayOff) = React.useState(() => false)
  let (exportScaleInput, setExportScaleInput) = React.useState(() => "1")
  let (includeExportBackground, setIncludeExportBackground) = React.useState(() => true)
  let (resizeMode, setResizeMode) = React.useState(() => Scale)
  let clearHoverRef = React.useRef(() => ())
  // Camera positioning
  let zoomRef = React.useRef(1.)
  let panRef = React.useRef((0., 0.))

  // Layout helpers
  let canvasContainerRef = React.useRef(Js.Nullable.null)
  let (viewportCenter, setViewportCenter) = React.useState(() => (192., 192.))
  let viewportCenterRef = React.useRef(viewportCenter)
  viewportCenterRef.current = viewportCenter

  let updateViewportCenter = () =>
    switch canvasContainerRef.current->Js.Nullable.toOption {
    | Some(element) =>
      let rect = element->Element.getBoundingClientRect
      setViewportCenter(_ => (rect->DomRect.width /. 2., rect->DomRect.height /. 2.))
    | None => ()
    }

  React.useEffect0(() => {
    updateViewportCenter()
    let handleResize = _ => updateViewportCenter()
    window->Window.addEventListener("resize", handleResize)
    Some(() => window->Window.removeEventListener("resize", handleResize))
  })

  let clampZoom = value => {
    let cappedMax = if value > 4. {
      4.
    } else {
      value
    }
    if cappedMax < 0.25 {
      0.25
    } else {
      cappedMax
    }
  }

  let isMouseDown = useIsMouseDown()

  // Canvas selection & derived state
  let canvasCount = canvases->Array.length

  React.useEffect0(() => {
    if canvasCount == 0 {
      let defaultCanvas = makeDefaultCanvas()
      setCanvases(_ => [defaultCanvas])
      setSelectedCanvasId(_ => defaultCanvas.id)
    }
    None
  })

  let currentCanvas = switch canvases->Belt.Array.getBy(canvas => canvas.id == selectedCanvasId) {
  | Some(canvas) => canvas
  | None =>
    switch canvases->Array.get(0) {
    | Some(firstCanvas) => firstCanvas
    | None => makeDefaultCanvas()
    }
  }

  let currentCanvasId = currentCanvas.id
  let currentCanvasIdRef = React.useRef(currentCanvasId)
  currentCanvasIdRef.current = currentCanvasId

  React.useEffect2(() => {
    let hasValidSelection = canvases->Belt.Array.some(canvas => canvas.id == selectedCanvasId)
    if !hasValidSelection {
      switch canvases->Array.get(0) {
      | Some(firstCanvas) =>
        if firstCanvas.id != selectedCanvasId {
          setSelectedCanvasId(_ => firstCanvas.id)
        }
      | None => ()
      }
    }
    None
  }, (canvases, selectedCanvasId))

  React.useEffect1(() => {
    let requiresMigration =
      canvases->Belt.Array.some(canvas => Js.typeof(canvas.id) != "string" || canvas.id == "")
    if requiresMigration {
      setCanvases(prev =>
        prev->Array.mapWithIndex(
          (canvas, idx) =>
            if Js.typeof(canvas.id) == "string" && canvas.id != "" {
              canvas
            } else {
              let uniqueSuffix = "-" ++ idx->Int.toString
              {...canvas, id: generateCanvasId() ++ uniqueSuffix}
            },
        )
      )
    }
    None
  }, canvases)

  let board = currentCanvas.board
  let zoom = currentCanvas.zoom
  let pan = currentCanvas.pan

  zoomRef.current = zoom
  panRef.current = pan

  let updateCanvasById = (targetId, updater) =>
    setCanvases(prev =>
      if prev->Array.length == 0 {
        [updater(makeDefaultCanvas())]
      } else {
        prev->Array.map(canvas => canvas.id == targetId ? updater(canvas) : canvas)
      }
    )

  let setBoard = updater =>
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      ...canvas,
      board: updater(canvas.board),
    })

  let updatePan = updater => {
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      let nextPan = updater(canvas.pan)
      panRef.current = nextPan
      {...canvas, pan: nextPan}
    })
  }

  let adjustPan = (deltaX, deltaY) =>
    updatePan(((prevX, prevY)) => (prevX +. deltaX, prevY +. deltaY))

  let updateZoom = updater =>
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      let prevZoom = canvas.zoom
      let nextZoom = clampZoom(updater(prevZoom))
      if nextZoom != prevZoom {
        let (centerX, centerY) = viewportCenterRef.current
        let (prevPanX, prevPanY) = canvas.pan
        let boardCenterX = (centerX -. prevPanX) /. prevZoom
        let boardCenterY = (centerY -. prevPanY) /. prevZoom
        let nextPanX = centerX -. boardCenterX *. nextZoom
        let nextPanY = centerY -. boardCenterY *. nextZoom
        let nextPan = (nextPanX, nextPanY)
        zoomRef.current = nextZoom
        panRef.current = nextPan
        {...canvas, zoom: nextZoom, pan: nextPan}
      } else {
        zoomRef.current = nextZoom
        canvas
      }
    })

  let adjustZoomByFactor = factor => updateZoom(prev => prev *. factor)
  let resetZoom = () => updateZoom(_ => 1.)
  let zoomIn = () => adjustZoomByFactor(Initials.zoom_factor)
  let zoomOut = () => adjustZoomByFactor(1. /. Initials.zoom_factor)

  let (boardDimI, boardDimJ) = board->Array.dims2D
  let lastAutoCenteredDimsRef = React.useRef(None)
  let (brushDimI, brushDimJ) = brush->Array.dims2D
  let brushCenterDimI = brushDimI / 2
  let brushCenterDimJ = brushDimJ / 2
  let (tileMaskDimI, tileMaskDimJ) = tileMask->Array.dims2D
  let computeCenteredPan = (dimI, dimJ, zoomValue) => {
    let (centerX, centerY) = viewportCenter
    let cellSize = 16.
    let boardWidth = Float.fromInt(dimI) *. cellSize
    let boardHeight = Float.fromInt(dimJ) *. cellSize
    let nextPanX = centerX -. boardWidth *. zoomValue /. 2.
    let nextPanY = centerY -. boardHeight *. zoomValue /. 2.
    (nextPanX, nextPanY)
  }

  let centerCanvas = () => {
    let (nextPanX, nextPanY) = computeCenteredPan(boardDimI, boardDimJ, zoomRef.current)
    updatePan(((prevX, prevY)) =>
      if prevX == nextPanX && prevY == nextPanY {
        (prevX, prevY)
      } else {
        (nextPanX, nextPanY)
      }
    )
  }
  let centerCanvasForDimensions = (dimI, dimJ) => {
    let (nextPanX, nextPanY) = computeCenteredPan(dimI, dimJ, zoomRef.current)
    updatePan(((prevX, prevY)) =>
      if prevX == nextPanX && prevY == nextPanY {
        (prevX, prevY)
      } else {
        (nextPanX, nextPanY)
      }
    )
  }

  // Resize controls
  let (resizeRowsInput, setResizeRowsInput) = React.useState(() => boardDimI->Int.toString)
  let (resizeColsInput, setResizeColsInput) = React.useState(() => boardDimJ->Int.toString)

  React.useEffect2(() => {
    setResizeRowsInput(_ => boardDimI->Int.toString)
    setResizeColsInput(_ => boardDimJ->Int.toString)
    None
  }, (boardDimI, boardDimJ))

  React.useEffect3(() => {
    let shouldCenter = switch lastAutoCenteredDimsRef.current {
    | Some((prevI, prevJ)) => prevI != boardDimI || prevJ != boardDimJ
    | None => true
    }
    let (panX, panY) = panRef.current
    if shouldCenter || (panX == 0. && panY == 0.) {
      centerCanvasForDimensions(boardDimI, boardDimJ)
      lastAutoCenteredDimsRef.current = Some((boardDimI, boardDimJ))
    }
    None
  }, (boardDimI, boardDimJ, viewportCenter))

  React.useEffect2(() => {
    switch savedTileMasks->Array.get(selectedTileMaskIndex) {
    | Some(mask) =>
      if !Array.isEqual2D(mask, tileMask) {
        setTileMask(_ => mask)
      }
      None
    | None =>
      if savedTileMasks->Array.length > 0 {
        let fallbackIndex = if selectedTileMaskIndex >= savedTileMasks->Array.length {
          savedTileMasks->Array.length - 1
        } else {
          0
        }
        setSelectedTileMaskIndex(_ => fallbackIndex)
      }
      None
    }
  }, (savedTileMasks, selectedTileMaskIndex))

  let parsePositiveInt = value =>
    switch value->Int.fromString {
    | Some(parsed) if parsed > 0 => Some(parsed)
    | _ => None
    }
  let parsePositiveFloat = value =>
    switch value->Belt.Float.fromString {
    | Some(parsed) if parsed > 0. => Some(parsed)
    | _ => None
    }

  let mapIndex = (~srcSize, ~dstSize, index) =>
    if srcSize <= 1 || dstSize <= 1 {
      0
    } else {
      let numerator = index * (srcSize - 1) + (dstSize - 1) / 2
      let denominator = dstSize - 1
      let mapped = numerator / denominator
      let maxIndex = srcSize - 1
      if mapped < 0 {
        0
      } else if mapped > maxIndex {
        maxIndex
      } else {
        mapped
      }
    }

  let resizeBoardScale = (prev, nextRows, nextCols) => {
    let (prevRows, prevCols) = prev->Array.dims2D
    if prevRows == 0 || prevCols == 0 {
      makeBoard(nextRows, nextCols)
    } else {
      Array.make2D(nextRows, nextCols, () => Nullable.null)->Array.mapWithIndex((row, rowI) =>
        row->Array.mapWithIndex((_, colJ) => {
          let srcRow = mapIndex(~srcSize=prevRows, ~dstSize=nextRows, rowI)
          let srcCol = mapIndex(~srcSize=prevCols, ~dstSize=nextCols, colJ)
          prev->Array.check2D(srcRow, srcCol)->Option.getOr(Nullable.null)
        })
      )
    }
  }

  let resizeBoardCrop = (prev, nextRows, nextCols) =>
    Array.make2D(nextRows, nextCols, () => Nullable.null)->Array.mapWithIndex((row, rowI) =>
      row->Array.mapWithIndex((_, colJ) =>
        prev->Array.check2D(rowI, colJ)->Option.getOr(Nullable.null)
      )
    )

  let canSubmitResize = switch (
    parsePositiveInt(resizeRowsInput),
    parsePositiveInt(resizeColsInput),
  ) {
  | (Some(nextRows), Some(nextCols)) => nextRows != boardDimI || nextCols != boardDimJ
  | _ => false
  }
  let exportScaleValue = parsePositiveFloat(exportScaleInput)
  let canExport = exportScaleValue->Option.isSome

  let handleResizeSubmit = () =>
    switch (parsePositiveInt(resizeRowsInput), parsePositiveInt(resizeColsInput)) {
    | (Some(nextRows), Some(nextCols)) =>
      switch resizeMode {
      | Scale => setBoard(prev => resizeBoardScale(prev, nextRows, nextCols))
      | Crop => setBoard(prev => resizeBoardCrop(prev, nextRows, nextCols))
      }
      clearHoverRef.current()
      setCursorOverlayOff(_ => true)
    | _ => ()
    }

  let handleExportPng = () =>
    switch exportScaleValue {
    | Some(scale) =>
      exportBoardAsPng(
        board,
        scale,
        {includeBackground: includeExportBackground, backgroundColor: canvasBackgroundColor},
      )
    | None => ()
    }

  // Saved asset helpers
  let selectedSavedBrushIndex =
    savedBrushes->Belt.Array.getIndexBy(savedBrush => Array.isEqual2D(savedBrush, brush))

  let canDeleteSelectedBrush = selectedSavedBrushIndex->Option.isSome
  let canDeleteSelectedTileMask = savedTileMasks->Array.length > 1

  let handleDeleteSelectedBrush = () =>
    switch selectedSavedBrushIndex {
    | Some(selectedIndex) =>
      setSavedBrushes(prev => prev->Belt.Array.keepWithIndex((_, idx) => idx != selectedIndex))
    | None => ()
    }

  let handleDeleteSelectedTileMask = () => {
    if canDeleteSelectedTileMask {
      setSavedTileMasks(prev => {
        let next = prev->Belt.Array.keepWithIndex((_, idx) => idx != selectedTileMaskIndex)
        let nextLength = next->Array.length
        let nextIndex = if nextLength == 0 {
          0
        } else if selectedTileMaskIndex >= nextLength {
          nextLength - 1
        } else {
          selectedTileMaskIndex
        }
        setSelectedTileMaskIndex(_ => nextIndex)
        switch next->Array.get(nextIndex) {
        | Some(mask) => setTileMask(_ => mask)
        | None => ()
        }
        next
      })
    }
  }

  // Canvas collection actions
  let canDeleteCanvas = canvasCount > 1

  let handleAddCanvas = () => {
    let defaultZoom = 1.
    let newBoard = makeBoard(boardDimI, boardDimJ)
    let newPan = computeCenteredPan(boardDimI, boardDimJ, defaultZoom)
    let newCanvas = makeCanvas(~board=newBoard, ~zoom=defaultZoom, ~pan=newPan)
    setCanvases(prev => prev->Array.concat([newCanvas]))
    setSelectedCanvasId(_ => newCanvas.id)
    clearHoverRef.current()
    setCursorOverlayOff(_ => true)
    lastAutoCenteredDimsRef.current = Some((boardDimI, boardDimJ))
  }

  let handleDeleteCanvas = () => {
    if canDeleteCanvas {
      let nextSelectionId = switch canvases->Belt.Array.getIndexBy(canvas =>
        canvas.id == currentCanvasId
      ) {
      | Some(currentIndex) =>
        switch canvases->Array.get(currentIndex + 1) {
        | Some(nextCanvas) => Some(nextCanvas.id)
        | None =>
          if currentIndex > 0 {
            switch canvases->Array.get(currentIndex - 1) {
            | Some(prevCanvas) => Some(prevCanvas.id)
            | None => None
            }
          } else {
            None
          }
        }
      | None =>
        canvases
        ->Array.get(0)
        ->Option.flatMap(canvas => canvas.id == currentCanvasId ? None : Some(canvas.id))
      }

      setCanvases(prev => prev->Belt.Array.keep(canvas => canvas.id != currentCanvasId))

      switch nextSelectionId {
      | Some(nextId) => setSelectedCanvasId(_ => nextId)
      | None => ()
      }
      clearHoverRef.current()
      setCursorOverlayOff(_ => true)
    }
  }

  let handleSelectCanvas = canvasId => {
    if canvasId != selectedCanvasId {
      setSelectedCanvasId(_ => canvasId)
    }
    clearHoverRef.current()
    setCursorOverlayOff(_ => true)
  }

  // Painting helpers
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

  let getBrushColor = () => {
    switch brushMode {
    | Color => Nullable.Value(myColor)
    | Erase => Nullable.null
    }
  }

  let applyBrush = (clickI, clickJ) => {
    setBoard(b => {
      let brush = b->Array.mapWithIndex((row, boardI) =>
        row->Array.mapWithIndex(
          (cell, boardJ) => {
            canApply(boardI, boardJ, clickI, clickJ) ? getBrushColor() : cell
          },
        )
      )
      brush
    })
  }

  // Global listeners
  React.useEffect0(() => {
    window->Window.addMouseMoveEventListener(onMouseMove)

    Some(() => window->Window.removeMouseMoveEventListener(onMouseMove))
  })

  React.useEffect0(() => {
    let handleKeyDown = event => {
      if event->KeyboardEvent.metaKey {
        switch event->KeyboardEvent.key {
        | "]" =>
          event->KeyboardEvent.preventDefault
          zoomIn()
        | "[" =>
          event->KeyboardEvent.preventDefault
          zoomOut()
        | _ => ()
        }
      } else {
        let step = 16. /. zoomRef.current
        switch event->KeyboardEvent.key {
        | "ArrowDown" =>
          event->KeyboardEvent.preventDefault
          adjustPan(0., step)
        | "ArrowUp" =>
          event->KeyboardEvent.preventDefault
          adjustPan(0., -.step)
        | "ArrowRight" =>
          event->KeyboardEvent.preventDefault
          adjustPan(step, 0.)
        | "ArrowLeft" =>
          event->KeyboardEvent.preventDefault
          adjustPan(-.step, 0.)
        | _ => ()
        }
      }
    }

    window->Window.addKeyDownEventListener(handleKeyDown)

    Some(() => window->Window.removeKeyDownEventListener(handleKeyDown))
  })

  // Canvas transform
  let transformValue = {
    let (offsetX, offsetY) = pan
    let offsetXString = offsetX->Js.Float.toString
    let offsetYString = offsetY->Js.Float.toString
    let zoomString = zoom->Js.Float.toString
    "translate3d(" ++
    offsetXString ++
    "px, " ++
    offsetYString ++
    "px, 0) scale(" ++
    zoomString ++ ")"
  }

  <div className=" flex flex-row h-dvh overflow-x-hidden">
    <div className="flex flex-row gap-2 h-full flex-none p-2">
      <SavedBrushesPanel
        board={board}
        brush={brush}
        setBrush={setBrush}
        savedBrushes={savedBrushes}
        setSavedBrushes={setSavedBrushes}
        canDeleteSelectedBrush={canDeleteSelectedBrush}
        handleDeleteSelectedBrush={handleDeleteSelectedBrush}
      />
      <SavedTileMasksPanel
        board={board}
        setTileMask={setTileMask}
        savedTileMasks={savedTileMasks}
        setSavedTileMasks={setSavedTileMasks}
        selectedTileMaskIndex={selectedTileMaskIndex}
        setSelectedTileMaskIndex={setSelectedTileMaskIndex}
        canDeleteSelectedTileMask={canDeleteSelectedTileMask}
        handleDeleteSelectedTileMask={handleDeleteSelectedTileMask}
      />
    </div>
    <div className="flex flex-col flex-1 overflow-x-hidden">
      <div className={"flex-1 pt-2"}>
        <CanvasViewport
          canvasContainerRef
          board
          boardDimI
          boardDimJ
          transformValue
          zoom
          pan
          cursorOverlayOff
          setCursorOverlayOff
          isMouseDown
          applyBrush
          showCursorOverlay
          canvasBackgroundColor
          viewportBackgroundColor
          isSilhouette
          clearHoverRef
          brush
          brushDimI
          brushDimJ
          brushCenterDimI
          brushCenterDimJ
          tileMask
          tileMaskDimI
          tileMaskDimJ
        />
      </div>

      <CanvasThumbnails
        canvases
        currentCanvasId
        canDeleteCanvas
        handleDeleteCanvas
        handleAddCanvas
        onSelectCanvas={handleSelectCanvas}
      />
    </div>
    <ControlsPanel
      brushMode={brushMode}
      setBrushMode={setBrushMode}
      myColor={myColor}
      setMyColor={setMyColor}
      canvasBackgroundColor={canvasBackgroundColor}
      setCanvasBackgroundColor={setCanvasBackgroundColor}
      viewportBackgroundColor={viewportBackgroundColor}
      setViewportBackgroundColor={setViewportBackgroundColor}
      isSilhouette={isSilhouette}
      setIsSilhouette={setIsSilhouette}
      showCursorOverlay={showCursorOverlay}
      setShowCursorOverlay={setShowCursorOverlay}
      resizeMode={resizeMode}
      setResizeMode={setResizeMode}
      resizeRowsInput={resizeRowsInput}
      setResizeRowsInput={setResizeRowsInput}
      resizeColsInput={resizeColsInput}
      setResizeColsInput={setResizeColsInput}
      canSubmitResize={canSubmitResize}
      onSubmitResize={handleResizeSubmit}
      zoom
      onZoomIn={zoomIn}
      onZoomOut={zoomOut}
      onZoomReset={resetZoom}
      onCenterCanvas={centerCanvas}
      exportScaleInput={exportScaleInput}
      setExportScaleInput={setExportScaleInput}
      includeExportBackground={includeExportBackground}
      setIncludeExportBackground={setIncludeExportBackground}
      canExport={canExport}
      onExport={handleExportPng}
    />
  </div>
}
