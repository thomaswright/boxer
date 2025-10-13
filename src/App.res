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
type exportOptions = {
  includeBackground: bool,
  backgroundColor: string,
}

type brushMode = | @as("Color") Color | @as("Erase") Erase

let makeBoard = (i, j) => Array.make2D(i, j, () => Nullable.null)
let makeBrush = (i, j) => Array.make2D(i, j, () => true)
let makeTileMask = (i, j) => Array.make2D(i, j, () => true)

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
    <div className={"flex flex-col divide-y divide-gray-600 h-full overflow-y-scroll"}>
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
            className={[" text-3xs font-bold w-4 h- text-center bg-white"]->Array.join(" ")}
            style={{writingMode: "sideways-lr"}}>
            {`${dimI->Int.toString}:${dimJ->Int.toString}`->React.string}
          </div>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: `repeat(${dimI->Int.toString}, auto)`,
              gridTemplateRows: `repeat(${dimJ->Int.toString}, auto)`,
            }}
            className={[
              selected ? "bg-orange-500" : "bg-gray-400",
              "flex flex-row h-8 w-8",
            ]->Array.join(" ")}>
            {savedBrush
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    className={"w-full h-full "}
                    key={i->Int.toString ++ j->Int.toString}
                    style={{
                      backgroundColor: cell ? "inherit" : "white",
                    }}>
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
    ~tileMask,
    ~setTileMask,
    ~savedTileMasks,
    ~setSavedTileMasks,
    ~canDeleteSelectedTileMask,
    ~handleDeleteSelectedTileMask,
  ) => {
    <div className={"flex flex-col divide-y divide-gray-600 h-full overflow-y-scroll"}>
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
            setSavedTileMasks(v => v->Array.concat([newTileMask]))
            setTileMask(_ => newTileMask)
          }}>
          {"+"->React.string}
        </button>
      </div>

      {savedTileMasks
      ->Array.mapWithIndex((savedTileMask, savedTileMaskIndex) => {
        let (dimI, dimJ) = savedTileMask->Array.dims2D
        let selected = Array.isEqual2D(tileMask, savedTileMask)
        <button
          key={savedTileMaskIndex->Int.toString} onClick={_ => setTileMask(_ => savedTileMask)}>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: `repeat(${dimI->Int.toString}, auto)`,
              gridTemplateRows: `repeat(${dimJ->Int.toString}, auto)`,
            }}
            className={["h-8 w-8", selected ? "bg-orange-500 " : "bg-gray-300"]->Array.join(" ")}>
            {savedTileMask
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    className={"w-full h-full "}
                    key={i->Int.toString ++ j->Int.toString}
                    style={{
                      backgroundColor: cell ? "inherit" : "white",
                    }}>
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

module CanvasViewport = {
  @react.component
  let make = (
    ~canvasContainerRef,
    ~board,
    ~boardDimI,
    ~boardDimJ,
    ~transformValue,
    ~hoveredCell,
    ~setHoveredCell,
    ~cursorOverlayOff,
    ~setCursorOverlayOff,
    ~isMouseDown,
    ~applyBrush,
    ~canApply,
    ~showCursorOverlay,
    ~canvasBackgroundColor,
    ~viewportBackgroundColor,
    ~isSilhouette,
  ) => {
    <div
      ref={ReactDOM.Ref.domRef(canvasContainerRef)}
      className="relative border border-gray-300 overflow-hidden"
      style={{
        width: "384px",
        height: "384px",
        backgroundColor: viewportBackgroundColor,
      }}>
      <div
        className={"absolute top-0 left-0"}
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${boardDimI->Int.toString}, 1rem)`,
          gridTemplateRows: `repeat(${boardDimJ->Int.toString}, 1rem)`,
          transform: transformValue,
          transformOrigin: "top left",
          backgroundColor: canvasBackgroundColor,
        }}>
        {board
        ->Array.mapWithIndex((line, i) => {
          line
          ->Array.mapWithIndex((cell, j) => {
            let cellColor = if isSilhouette {
              cell->Nullable.mapOr("transparent", _ => "#000000")
            } else {
              cell->Nullable.getOr("transparent")
            }
            let overlayBackgroundColor = if isSilhouette {
              "white"
            } else {
              cell->Nullable.mapOr("black", value => value->isLight ? "black" : "white")
            }

            <div
              className={"w-full h-full group relative"}
              key={i->Int.toString ++ j->Int.toString}
              onMouseEnter={_ => {
                setHoveredCell(_ => Some((i, j)))
                if isMouseDown {
                  applyBrush(i, j)
                }
              }}
              onMouseLeave={_ => {
                setHoveredCell(_ => None)
              }}
              onMouseDown={_ => {
                applyBrush(i, j)
                setCursorOverlayOff(_ => true)
              }}>
              <div
                className={"w-full h-full absolute"}
                style={{
                  backgroundColor: cellColor,
                }}
              />
              {switch hoveredCell {
              | Some((hoverI, hoverJ)) =>
                cursorOverlayOff || !showCursorOverlay || !canApply(i, j, hoverI, hoverJ)
                  ? React.null
                  : <div
                      style={{
                        backgroundColor: overlayBackgroundColor,
                      }}
                      className="absolute w-full h-full inset-0 opacity-20">
                    </div>
              | None => React.null
              }}
            </div>
          })
          ->React.array
        })
        ->React.array}
      </div>
    </div>
  }
}

module CanvasThumbnails = {
  @react.component
  let make = (
    ~canvases,
    ~currentCanvasIndex,
    ~canDeleteCanvas,
    ~handleDeleteCanvas,
    ~handleAddCanvas,
    ~onSelectCanvas,
  ) => {
    <div className="flex flex-row items-start gap-3 overflow-x-auto">
      {canvases
      ->Array.mapWithIndex((canvasBoard, canvasIndex) => {
        let (thumbDimI, thumbDimJ) = canvasBoard->Array.dims2D
        let isSelectedCanvas = canvasIndex == currentCanvasIndex
        <div
          key={canvasIndex->Int.toString}
          className={[
            "relative flex-shrink-0 border w-16 h-16",
            isSelectedCanvas ? "border-blue-500" : "border-gray-200",
          ]->Array.join(" ")}>
          <button
            onClick={_ => onSelectCanvas(canvasIndex)}
            className={["absolute w-fit h-fit"]->Array.join(" ")}>
            <div
              className="h-16 w-16 grid"
              style={{
                gridTemplateColumns: `repeat(${thumbDimI->Int.toString}, minmax(0, 1fr))`,
                gridTemplateRows: `repeat(${thumbDimJ->Int.toString}, minmax(0, 1fr))`,
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

module CanvasColorsControl = {
  @react.component
  let make = (
    ~myColor,
    ~canvasBackgroundColor,
    ~setCanvasBackgroundColor,
    ~viewportBackgroundColor,
    ~setViewportBackgroundColor,
  ) => {
    <div className="border rounded p-2 flex flex-col gap-2 w-full">
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

module ColorControl = {
  @react.component
  let make = (~brushMode, ~setBrushMode, ~myColor, ~setMyColor) => {
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
    </div>
  }
}

module BrushOverlayControl = {
  @react.component
  let make = (~showCursorOverlay, ~setShowCursorOverlay) => {
    <div className="flex flex-row justify-between border rounded p-2 w-full">
      <div className="flex flex-row font-medium"> {"Brush Overlay"->React.string} </div>
      <Switch checked={showCursorOverlay} onChange={v => setShowCursorOverlay(_ => v)} />
    </div>
  }
}

module CanvasSizeControl = {
  @react.component
  let make = (
    ~isResizeOpen,
    ~setIsResizeOpen,
    ~resizeRowsInput,
    ~setResizeRowsInput,
    ~resizeColsInput,
    ~setResizeColsInput,
    ~canSubmitResize,
    ~onSubmitResize,
  ) => {
    <div className="border rounded p-2 flex flex-col gap-2 w-full">
      <button
        onClick={_ => setIsResizeOpen(v => !v)}
        className={["flex flex-row items-center justify-between font-medium", "w-full"]->Array.join(
          " ",
        )}>
        {"Canvas Size"->React.string}
        <span> {isResizeOpen ? "-"->React.string : "+"->React.string} </span>
      </button>

      {isResizeOpen
        ? <div className="flex flex-col gap-2">
            <div className="flex flex-row w-full gap-2">
              <input
                className="border rounded px-2 py-1 text-sm flex-1 min-w-0"
                value={resizeRowsInput}
                onChange={event => {
                  let value = ReactEvent.Form.target(event)["value"]
                  setResizeRowsInput(_ => value)
                }}
              />
              <span className={"flex-none px-1"}> {"x"->React.string} </span>
              <input
                className="border rounded px-2 py-1 text-sm flex-1  min-w-0"
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
        : React.null}
    </div>
  }
}

module ZoomControl = {
  @react.component
  let make = (~onZoomOut, ~onZoomReset, ~onZoomIn, ~onCenterCanvas, ~zoom) => {
    let zoomPercentString = (zoom *. 100.)->Float.toFixed(~digits=0)

    <div className="border rounded p-2 flex flex-col gap-2 w-full">
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
    <div className="flex flex-row items-center justify-between border rounded p-2 w-full">
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
    <div className="border rounded p-2 flex flex-col gap-2 w-full">
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
    ~isResizeOpen,
    ~setIsResizeOpen,
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
    <div className="flex flex-col gap-2 flex-none width-48 h-full overflow-y-scroll">
      <ColorControl brushMode setBrushMode myColor setMyColor />
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
        isResizeOpen
        setIsResizeOpen
        resizeRowsInput
        setResizeRowsInput
        resizeColsInput
        setResizeColsInput
        canSubmitResize
        onSubmitResize
      />
      <BrushOverlayControl showCursorOverlay setShowCursorOverlay />
    </div>
  }
}

@react.component
let make = () => {
  // Persistent tool state
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)
  let makeDefaultCanvas = () => makeBoard(12, 12)
  let (canvases, setCanvases, _) = useLocalStorage("canvases", [makeDefaultCanvas()])
  let (selectedCanvasIndex, setSelectedCanvasIndex, _) = useLocalStorage("selected-canvas-index", 0)
  let (brush, setBrush, _) = useLocalStorage("brush", makeBrush(3, 3))
  let (savedBrushes, setSavedBrushes, _) = useLocalStorage("saved-brushes", defaultBrushes)
  let (savedTileMasks, setSavedTileMasks, _) = useLocalStorage("saved-tile-masks", defaultTileMasks)
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
  let (hoveredCell, setHoveredCell) = React.useState(() => None)
  let (exportScaleInput, setExportScaleInput) = React.useState(() => "1")
  let (includeExportBackground, setIncludeExportBackground) = React.useState(() => true)

  // Camera positioning
  let (zoom, setZoom, _) = useLocalStorage("canvas-zoom", 1.)
  let zoomRef = React.useRef(zoom)
  zoomRef.current = zoom

  // Layout helpers
  let canvasContainerRef = React.useRef(Js.Nullable.null)
  let (viewportCenter, setViewportCenter) = React.useState(() => (192., 192.))

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

  let (pan, setPan, _) = useLocalStorage("canvas-pan", (0., 0.))
  let panRef = React.useRef(pan)
  panRef.current = pan

  let adjustPan = (deltaX, deltaY) => setPan(((prevX, prevY)) => (prevX +. deltaX, prevY +. deltaY))

  let updateZoom = updater =>
    setZoom(prev => {
      let next = clampZoom(updater(prev))
      if next != prev {
        let (centerX, centerY) = viewportCenter
        let (prevPanX, prevPanY) = panRef.current
        let boardCenterX = (centerX -. prevPanX) /. prev
        let boardCenterY = (centerY -. prevPanY) /. prev
        let nextPanX = centerX -. boardCenterX *. next
        let nextPanY = centerY -. boardCenterY *. next
        setPan(_ => (nextPanX, nextPanY))
      }
      next
    })

  let adjustZoomByFactor = factor => updateZoom(prev => prev *. factor)
  let resetZoom = () => updateZoom(_ => 1.)
  let zoomIn = () => adjustZoomByFactor(Initials.zoom_factor)
  let zoomOut = () => adjustZoomByFactor(1. /. Initials.zoom_factor)
  let isMouseDown = useIsMouseDown()

  // Canvas selection & derived state
  let canvasCount = canvases->Array.length

  React.useEffect0(() => {
    if canvasCount == 0 {
      setCanvases(_ => [makeDefaultCanvas()])
    }
    None
  })

  React.useEffect0(() => {
    if canvasCount > 0 && selectedCanvasIndex >= canvasCount {
      setSelectedCanvasIndex(_ => canvasCount - 1)
    }
    None
  })

  let currentCanvasIndex = if canvasCount == 0 {
    0
  } else if selectedCanvasIndex >= canvasCount {
    canvasCount - 1
  } else {
    selectedCanvasIndex
  }

  let board = switch canvases->Array.get(currentCanvasIndex) {
  | Some(canvas) => canvas
  | None => canvases->Array.get(0)->Option.getOr(makeDefaultCanvas())
  }

  let updateCanvasAtIndex = (index, updater) =>
    setCanvases(prev =>
      if prev->Array.length == 0 {
        [updater(makeDefaultCanvas())]
      } else {
        prev->Array.mapWithIndex((canvas, idx) => idx == index ? updater(canvas) : canvas)
      }
    )

  let setBoard = updater => updateCanvasAtIndex(currentCanvasIndex, updater)

  let (boardDimI, boardDimJ) = board->Array.dims2D
  let (brushDimI, brushDimJ) = brush->Array.dims2D
  let brushCenterDimI = brushDimI / 2
  let brushCenterDimJ = brushDimJ / 2
  let (tileMaskDimI, tileMaskDimJ) = tileMask->Array.dims2D
  let centerCanvas = () => {
    let (centerX, centerY) = viewportCenter
    let cellSize = 16.
    let boardWidth = Float.fromInt(boardDimI) *. cellSize
    let boardHeight = Float.fromInt(boardDimJ) *. cellSize
    let currentZoom = zoomRef.current
    let nextPanX = centerX -. boardWidth *. currentZoom /. 2.
    let nextPanY = centerY -. boardHeight *. currentZoom /. 2.
    setPan(_ => (nextPanX, nextPanY))
  }

  // Resize controls
  let (isResizeOpen, setIsResizeOpen) = React.useState(() => false)
  let (resizeRowsInput, setResizeRowsInput) = React.useState(() => boardDimI->Int.toString)
  let (resizeColsInput, setResizeColsInput) = React.useState(() => boardDimJ->Int.toString)

  React.useEffect2(() => {
    setResizeRowsInput(_ => boardDimI->Int.toString)
    setResizeColsInput(_ => boardDimJ->Int.toString)
    None
  }, (boardDimI, boardDimJ))

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
      setBoard(prev =>
        Array.make2D(nextRows, nextCols, () => Nullable.null)->Array.mapWithIndex((row, rowI) =>
          row->Array.mapWithIndex(
            (_, colJ) => prev->Array.check2D(rowI, colJ)->Option.getOr(Nullable.null),
          )
        )
      )
      setHoveredCell(_ => None)
      setCursorOverlayOff(_ => true)
      setIsResizeOpen(_ => false)
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

  let selectedSavedTileMaskIndex =
    savedTileMasks->Belt.Array.getIndexBy(savedTileMask => Array.isEqual2D(savedTileMask, tileMask))

  let canDeleteSelectedBrush = selectedSavedBrushIndex->Option.isSome
  let canDeleteSelectedTileMask = selectedSavedTileMaskIndex->Option.isSome

  let handleDeleteSelectedBrush = () =>
    switch selectedSavedBrushIndex {
    | Some(selectedIndex) =>
      setSavedBrushes(prev => prev->Belt.Array.keepWithIndex((_, idx) => idx != selectedIndex))
    | None => ()
    }

  let handleDeleteSelectedTileMask = () =>
    switch selectedSavedTileMaskIndex {
    | Some(selectedIndex) =>
      setSavedTileMasks(prev => prev->Belt.Array.keepWithIndex((_, idx) => idx != selectedIndex))
    | None => ()
    }

  // Canvas collection actions
  let canDeleteCanvas = canvasCount > 1

  let handleAddCanvas = () => {
    let newCanvas = makeBoard(boardDimI, boardDimJ)
    setCanvases(prev => prev->Array.concat([newCanvas]))
    setSelectedCanvasIndex(_ => canvasCount)
    setHoveredCell(_ => None)
    setCursorOverlayOff(_ => true)
  }

  let handleDeleteCanvas = () => {
    if canDeleteCanvas {
      let nextSelected = if selectedCanvasIndex >= canvasCount - 1 {
        selectedCanvasIndex == 0 ? 0 : selectedCanvasIndex - 1
      } else {
        selectedCanvasIndex
      }
      setCanvases(prev =>
        Belt.Array.keepWithIndex(prev, (_canvas, idx) => idx != selectedCanvasIndex)
      )
      setSelectedCanvasIndex(_ => nextSelected)
      setHoveredCell(_ => None)
      setCursorOverlayOff(_ => true)
    }
  }

  let handleSelectCanvas = canvasIndex => {
    setSelectedCanvasIndex(_ => canvasIndex)
    setHoveredCell(_ => None)
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

  <div className=" flex flex-row gap-5 p-3 h-dvh">
    <div className="flex flex-row gap-2 h-full p-2 border rounded flex-none">
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
        tileMask={tileMask}
        setTileMask={setTileMask}
        savedTileMasks={savedTileMasks}
        setSavedTileMasks={setSavedTileMasks}
        canDeleteSelectedTileMask={canDeleteSelectedTileMask}
        handleDeleteSelectedTileMask={handleDeleteSelectedTileMask}
      />
    </div>
    <div className="flex flex-col gap-2 flex-1">
      <CanvasViewport
        canvasContainerRef
        board
        boardDimI
        boardDimJ
        transformValue
        hoveredCell
        setHoveredCell
        cursorOverlayOff
        setCursorOverlayOff
        isMouseDown
        applyBrush
        canApply
        showCursorOverlay
        canvasBackgroundColor
        viewportBackgroundColor
        isSilhouette
      />
      <div className="flex flex-col gap-2 w-full">
        <CanvasThumbnails
          canvases
          currentCanvasIndex
          canDeleteCanvas
          handleDeleteCanvas
          handleAddCanvas
          onSelectCanvas={handleSelectCanvas}
        />
      </div>
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
      isResizeOpen={isResizeOpen}
      setIsResizeOpen={setIsResizeOpen}
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
