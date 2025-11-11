@@warning("-44")
open Webapi.Dom

open Types

let cellSize = 1
let cellSizeFloat = 1.
let baseGridCellSize = 16.
let gridLineThickness = cellSizeFloat /. baseGridCellSize

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
  ~handlePickColor,
  ~setHoveredPickColor,
  ~isPickingColor,
  ~showCursorOverlay,
  ~overlayMode: Types.overlayMode,
  ~overlayColor,
  ~gridMode,
  ~canvasBackgroundColor,
  ~gridLineColor,
  ~checkeredPrimaryColor,
  ~checkeredSecondaryColor,
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
  ~isDotMask,
  ~onWheel,
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
      let maybeRenderer = CanvasRenderer.create(canvasElement)
      switch maybeRenderer->Js.Nullable.toOption {
      | Some(renderer) =>
        rendererRef.current = Some(renderer)
        Some(
          () => {
            rendererRef.current = None
            CanvasRenderer.dispose(renderer)
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
      CanvasRenderer.setSize(renderer, boardDimJ, boardDimI, cellSize)
      CanvasRenderer.updateBoard(renderer, board, canvasBackgroundColor, isSilhouette)
      CanvasRenderer.render(renderer)
      CanvasRenderer.setHover(renderer, hoverToNullable(hoveredCellRef.current))
    })
    None
  }, (board, boardDimI, boardDimJ, canvasBackgroundColor, isSilhouette))

  React.useEffect5(() => {
    withRenderer(renderer => {
      CanvasRenderer.updateBrush(renderer, brush, brushCenterDimI, brushCenterDimJ)
      CanvasRenderer.setHover(renderer, hoverToNullable(hoveredCellRef.current))
    })
    None
  }, (brush, brushDimI, brushDimJ, brushCenterDimI, brushCenterDimJ))

  React.useEffect3(() => {
    withRenderer(renderer => {
      CanvasRenderer.updateTileMask(renderer, tileMask)
      CanvasRenderer.setHover(renderer, hoverToNullable(hoveredCellRef.current))
    })
    None
  }, (tileMask, tileMaskDimI, tileMaskDimJ))

  React.useEffect5(() => {
    withRenderer(renderer => {
      let overlayEnabled = showCursorOverlay && !cursorOverlayOff
      CanvasRenderer.setOverlayOptions(
        renderer,
        overlayEnabled,
        isSilhouette,
        overlayMode,
        overlayColor,
      )
      CanvasRenderer.render(renderer)
    })
    None
  }, (showCursorOverlay, cursorOverlayOff, isSilhouette, overlayMode, overlayColor))

  let updateHover = hover => {
    hoveredCellRef.current = hover
    withRenderer(renderer => CanvasRenderer.setHover(renderer, hoverToNullable(hover)))
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
      let col = (boardX /. cellSizeFloat)->Js.Math.floor_float->Float.toInt
      let row = (boardY /. cellSizeFloat)->Js.Math.floor_float->Float.toInt
      Some((row, col))
    | None => None
    }
  let isWithinBoard = (row, col) => row >= 0 && row < boardDimI && col >= 0 && col < boardDimJ

  let handleMouseMove = event => {
    setCursorOverlayOff(_ => false)
    switch getCellFromEvent(event) {
    | Some((row, col)) =>
      updateHover(Some((row, col)))
      if isPickingColor {
        if isWithinBoard(row, col) {
          let hoveredColor = Board.get(board, row, col)->Js.Nullable.toOption
          setHoveredPickColor(_ => hoveredColor)
        } else {
          setHoveredPickColor(_ => None)
        }
      }
      if isMouseDown && !isPickingColor {
        applyBrush(row, col)
      }
    | None =>
      updateHover(None)
      if isPickingColor {
        setHoveredPickColor(_ => None)
      }
    }
  }

  let handleMouseDown = event =>
    switch getCellFromEvent(event) {
    | Some((row, col)) =>
      updateHover(Some((row, col)))
      if isPickingColor {
        if isWithinBoard(row, col) {
          handlePickColor(row, col)
        }
      } else {
        applyBrush(row, col)
        setCursorOverlayOff(_ => true)
      }
    | None => ()
    }

  let handleMouseLeave = _ => {
    updateHover(None)
    if isPickingColor {
      setHoveredPickColor(_ => None)
    }
  }

  let canvasWidth = boardDimJ * cellSize
  let canvasHeight = boardDimI * cellSize
  let widthString = canvasWidth->Int.toString ++ "px"
  let heightString = canvasHeight->Int.toString ++ "px"
  let cellSizeString = cellSize->Int.toString ++ "px"
  let lineBreadthFull = gridLineThickness /. cellSizeFloat
  let lineBreadth = (lineBreadthFull /. 2.)->Js.Float.toString
  let lineLength1 = (1. -. lineBreadthFull /. 2.)->Js.Float.toString
  let lineLength2 = (1. -. lineBreadthFull)->Js.Float.toString

  let gridSvg =
    "<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1' viewBox='0 0 1 1' shape-rendering='crispEdges'>" ++
    // left
    `<rect x='0' y='0' width='${lineBreadth}' height='1' fill='${gridLineColor}'/>` ++
    // top
    `<rect x='${lineBreadth}' y='0' width='${lineLength1}' height='${lineBreadth}' fill='${gridLineColor}'/>` ++
    // bottom
    `<rect x='${lineBreadth}' y='${lineLength1}' width='${lineLength1}' height='${lineBreadth}' fill='${gridLineColor}'/>` ++
    // right
    `<rect x='${lineLength1}' y='${lineBreadth}' width='${lineBreadth}' height='${lineLength2}' fill='${gridLineColor}'/>` ++ "</svg>"
  let gridBackgroundImage =
    "url(\"data:image/svg+xml," ++ Js.Global.encodeURIComponent(gridSvg) ++ "\")"
  let gridBackgroundSize = cellSizeString ++ " " ++ cellSizeString
  let doubleCellSizeString = (cellSize * 2)->Int.toString ++ "px"
  let checkeredSvg =
    "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2' shape-rendering='crispEdges'>" ++
    "<rect width='1' height='1' fill='" ++
    checkeredPrimaryColor ++
    "'/>" ++
    "<rect x='1' y='1' width='1' height='1' fill='" ++
    checkeredPrimaryColor ++
    "'/>" ++
    "<rect x='1' width='1' height='1' fill='" ++
    checkeredSecondaryColor ++
    "'/>" ++
    "<rect y='1' width='1' height='1' fill='" ++
    checkeredSecondaryColor ++
    "'/>" ++ "</svg>"
  let checkeredBackgroundImage =
    "url(\"data:image/svg+xml," ++ Js.Global.encodeURIComponent(checkeredSvg) ++ "\")"
  let checkeredBackgroundSize = doubleCellSizeString ++ " " ++ doubleCellSizeString

  let dotMaskSvg = `<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1' shape-rendering='crispEdges'>
    <defs>
      <mask id='hole'>
        <rect width='1' height='1' fill='white'/>
        <circle cx='0.5' cy='0.5' r='0.5' fill='black'/>
      </mask>
    </defs>
    <rect width='1' height='1' fill='white' mask='url(#hole)'/>
  </svg>`
  let dotMaskImage =
    "url(\"data:image/svg+xml," ++ Js.Global.encodeURIComponent(dotMaskSvg) ++ "\")"

  let isGridLinesOverlay = gridMode == GridLinesOverlay
  let isGridLinesUnderlay = gridMode == GridLinesUnderlay
  let isCheckeredOverlay = gridMode == CheckeredOverlay
  let isCheckeredUnderlay = gridMode == CheckeredUnderlay

  <div
    ref={ReactDOM.Ref.domRef(canvasContainerRef)}
    className="relative border border-gray-300 overflow-hidden w-full h-full"
    style={{
      backgroundColor: viewportBackgroundColor,
    }}
    onWheel={event => {
      event->ReactEvent.Wheel.preventDefault
      onWheel(event)
    }}
    onMouseMove={handleMouseMove}
    onMouseEnter={handleMouseMove}
    onMouseLeave={handleMouseLeave}
    onMouseDown={handleMouseDown}>
    <div
      className={"absolute top-0 left-0"}
      style={{
        transform: transformValue,
        transformOrigin: "top left",
      }}>
      <div
        className="absolute top-0 left-0 pointer-events-none"
        style={{
          width: widthString,
          height: heightString,
          backgroundColor: canvasBackgroundColor,
        }}
      />

      {isCheckeredUnderlay
        ? <div
            className="absolute top-0 left-0 pointer-events-none"
            style={{
              width: widthString,
              height: heightString,
              backgroundImage: checkeredBackgroundImage,
              backgroundColor: checkeredSecondaryColor,
              backgroundSize: checkeredBackgroundSize,
              imageRendering: "pixelated",
            }}
          />
        : React.null}
      {isGridLinesUnderlay
        ? <div
            className="absolute top-0 left-0 pointer-events-none"
            style={{
              width: widthString,
              height: heightString,
              backgroundImage: gridBackgroundImage,
              backgroundSize: gridBackgroundSize,
            }}
          />
        : React.null}
      <canvas
        ref={ReactDOM.Ref.domRef(canvasRef)}
        className="absolute top-0 left-0 block"
        style={{
          width: widthString,
          height: heightString,
          imageRendering: "pixelated",
        }}
      />
      {isDotMask
        ? <div
            className="absolute top-0 left-0 pointer-events-none"
            style={{
              width: widthString,
              height: heightString,
              backgroundColor: canvasBackgroundColor,
              backgroundSize: gridBackgroundSize,
              maskImage: dotMaskImage,
              maskSize: gridBackgroundSize,
            }}
          />
        : React.null}

      {isGridLinesOverlay
        ? <div
            className="absolute top-0 left-0 pointer-events-none"
            style={{
              width: widthString,
              height: heightString,
              backgroundImage: gridBackgroundImage,
              backgroundSize: gridBackgroundSize,
            }}
          />
        : React.null}
      {isCheckeredOverlay
        ? <div
            className="absolute top-0 left-0 pointer-events-none"
            style={{
              width: widthString,
              height: heightString,
              backgroundImage: checkeredBackgroundImage,
              backgroundColor: checkeredSecondaryColor,
              backgroundSize: checkeredBackgroundSize,
              imageRendering: "pixelated",
            }}
          />
        : React.null}
    </div>
  </div>
}
