@@warning("-44")
open Webapi.Dom

open Types

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

@module("./useLocalStorage.js")
external setLocalStoragePersistencePaused: bool => unit = "setLocalStoragePersistencePaused"

let makeBoard = (i, j) => Board.make(i, j)
let makeBrush = (i, j) => Array2D.make(i, j, () => true)
let makeTileMask = (i, j) => Array2D.make(i, j, () => true)

let generateCanvasId = () => {
  let timestamp = Js.Date.now()->Float.toString
  let random = Js.Math.random()->Float.toString
  timestamp ++ "-" ++ random
}

let makeCanvas = (
  ~board,
  ~zoom,
  ~pan,
  ~isDotMask=false,
  ~canvasBackgroundColor=Initials.canvasBackgroundColor,
) => {
  {
    id: generateCanvasId(),
    board,
    zoom,
    pan,
    isDotMask,
    canvasBackgroundColor,
  }
}

@module("./exportBoard.js")
external exportBoardAsPng: (board, float, exportOptions) => unit = "exportBoardAsPng"

let useIsMouseDown = () => {
  let (isMouseDown, setIsMouseDown) = React.useState(() => false)

  // Global listeners
  React.useEffect0(() => {
    let downHandler = _ => {
      setIsMouseDown(_ => true)
      setLocalStoragePersistencePaused(true)
    }
    let upHandler = _ => {
      setIsMouseDown(_ => false)
      setLocalStoragePersistencePaused(false)
    }
    window->Window.addMouseDownEventListener(downHandler)
    window->Window.addMouseUpEventListener(upHandler)

    Some(
      () => {
        window->Window.removeMouseDownEventListener(downHandler)
        window->Window.removeMouseUpEventListener(upHandler)
        setLocalStoragePersistencePaused(false)
      },
    )
  })

  isMouseDown
}

let _isLight = color => {
  let (_, _, l) = Texel.convert(color->Texel.hexToRgb, Texel.srgb, Texel.okhsl)
  l > 0.5
}

let defaultTileMasks = [
  [[true]],
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

@react.component
let make = () => {
  // Layout helpers
  let canvasContainerRef = React.useRef(Js.Nullable.null)
  let (viewportCenter, setViewportCenter) = React.useState(() => (192., 192.))
  let viewportCenterRef = React.useRef(viewportCenter)
  viewportCenterRef.current = viewportCenter

  let updateViewportCenter = () =>
    switch canvasContainerRef.current->Js.Nullable.toOption {
    | Some(element) =>
      let rect = element->Element.getBoundingClientRect
      let nextCenter = (rect->DomRect.width /. 2., rect->DomRect.height /. 2.)
      viewportCenterRef.current = nextCenter
      setViewportCenter(_ => nextCenter)
    | None => ()
    }

  React.useEffect0(() => {
    updateViewportCenter()
    let handleResize = _ => updateViewportCenter()
    window->Window.addEventListener("resize", handleResize)
    Some(() => window->Window.removeEventListener("resize", handleResize))
  })

  let clampZoom = value => {
    let cappedMax = if value > Initials.maxZoomIn {
      Initials.maxZoomIn
    } else {
      value
    }
    if cappedMax < Initials.maxZoomOut {
      Initials.maxZoomOut
    } else {
      cappedMax
    }
  }

  let computeCenteredPan = (dimI, dimJ, zoomValue) => {
    let (centerX, centerY) = viewportCenterRef.current
    let cellSize = 1.
    let boardWidth = Float.fromInt(dimJ) *. cellSize
    let boardHeight = Float.fromInt(dimI) *. cellSize
    let nextPanX = centerX -. boardWidth *. zoomValue /. 2.
    let nextPanY = centerY -. boardHeight *. zoomValue /. 2.
    (nextPanX, nextPanY)
  }

  let computeZoomToFitForDimensions = (dimI, dimJ) =>
    switch canvasContainerRef.current->Js.Nullable.toOption {
    | Some(containerElement) =>
      let rect = containerElement->Element.getBoundingClientRect
      let viewportWidth = rect->DomRect.width
      let viewportHeight = rect->DomRect.height
      let cellSize = 1.
      let boardWidth = Float.fromInt(dimJ) *. cellSize
      let boardHeight = Float.fromInt(dimI) *. cellSize
      if viewportWidth <= 0. || viewportHeight <= 0. || boardWidth <= 0. || boardHeight <= 0. {
        None
      } else {
        let zoomByWidth = viewportWidth /. boardWidth
        let zoomByHeight = viewportHeight /. boardHeight
        let zoomToFit = if zoomByWidth < zoomByHeight {
          zoomByWidth
        } else {
          zoomByHeight
        }
        Some(clampZoom(zoomToFit))
      }
    | None => None
    }

  let computeFitViewForDimensions = (dimI, dimJ) => {
    let fallbackZoom = 1.
    let fallbackPan = computeCenteredPan(dimI, dimJ, fallbackZoom)
    switch computeZoomToFitForDimensions(dimI, dimJ) {
    | Some(nextZoom) =>
      let nextPan = computeCenteredPan(dimI, dimJ, nextZoom)
      (nextZoom, nextPan)
    | None => (fallbackZoom, fallbackPan)
    }
  }

  let makeDefaultCanvas = () => {
    let defaultDimI = 12
    let defaultDimJ = 12
    let defaultBoard = makeBoard(defaultDimI, defaultDimJ)
    let (defaultZoom, defaultPan) = computeFitViewForDimensions(defaultDimI, defaultDimJ)
    makeCanvas(~board=defaultBoard, ~zoom=defaultZoom, ~pan=defaultPan, ~isDotMask=false)
  }

  // Persistent tool state
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)
  let (canvases, setCanvases, _) = useLocalStorage("canvases-v4", [])
  let (selectedCanvasId, setSelectedCanvasId, _) = useLocalStorage("selected-canvas-id", "")
  let (brush, setBrush, _) = useLocalStorage("brush", makeBrush(3, 3))
  let (savedBrushes, setSavedBrushes, _) = useLocalStorage("saved-brushes", defaultBrushes)
  let (savedTileMasks, setSavedTileMasks, _) = useLocalStorage("saved-tile-masks", defaultTileMasks)
  let (selectedTileMaskIndex, setSelectedTileMaskIndex, _) = useLocalStorage(
    "selected-tile-mask-index",
    0,
  )
  let (tileMask, setTileMask, _) = useLocalStorage("tile-mask", makeTileMask(4, 4))
  let (overlayMode, setOverlayMode, _) = useLocalStorage("brush-overlay-mode", OverlayDefault)
  let showCursorOverlay = switch overlayMode {
  | OverlayNone => false
  | _ => true
  }
  let (gridMode, setGridMode, _) = useLocalStorage("grid-mode", GridNone)
  let (myColor, setMyColor, _) = useLocalStorage("my-color", Initials.myColor)
  let (isSilhouette, setIsSilhouette, _) = useLocalStorage("canvas-silhouette", Initials.silhouette)
  let (viewportBackgroundColor, setViewportBackgroundColor, _) = useLocalStorage(
    "viewport-background-color",
    Initials.viewportBackgroundColor,
  )
  // Transient UI state
  let (cursorOverlayOff, setCursorOverlayOff) = React.useState(() => false)
  let (exportScaleInput, setExportScaleInput) = React.useState(() => "16")
  let (includeExportBackground, setIncludeExportBackground) = React.useState(() => true)
  let (resizeMode, setResizeMode) = React.useState(() => Scale)
  let (isPickingColor, setIsPickingColor) = React.useState(() => false)
  let (hoveredPickColor, setHoveredPickColor) = React.useState(() => None)
  let clearHoverRef = React.useRef(() => ())
  // Camera positioning
  let zoomRef = React.useRef(1.)
  let panRef = React.useRef((0., 0.))

  let isMouseDown = useIsMouseDown()

  let onStartColorPick = () =>
    setIsPickingColor(prev => {
      let next = !prev
      setHoveredPickColor(_ => None)
      if next {
        clearHoverRef.current()
        setCursorOverlayOff(_ => false)
      }
      next
    })

  // Canvas selection & derived state
  let canvasCount = canvases->Array.length

  React.useEffect0(() => {
    if canvasCount == 0 {
      updateViewportCenter()
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
  let (includeExportDotMask, setIncludeExportDotMask) = React.useState(() =>
    currentCanvas.isDotMask
  )

  React.useEffect1(() => {
    setIncludeExportDotMask(prev =>
      if prev == currentCanvas.isDotMask {
        prev
      } else {
        currentCanvas.isDotMask
      }
    )
    None
  }, [currentCanvasId])
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
  let board = currentCanvas.board
  let zoom = currentCanvas.zoom
  let pan = currentCanvas.pan
  let isDotMask = currentCanvas.isDotMask
  let canvasBackgroundColor = currentCanvas.canvasBackgroundColor
  let isCanvasBackgroundLight = _isLight(canvasBackgroundColor)
  let gridLineColor = if isCanvasBackgroundLight {
    "rgba(0, 0, 0, 0.25)"
  } else {
    "rgba(255, 255, 255, 0.25)"
  }
  let checkeredPrimaryColor = if isCanvasBackgroundLight {
    "rgba(0, 0, 0, 0.15)"
  } else {
    "rgba(255, 255, 255, 0.15)"
  }
  let checkeredSecondaryColor = if isCanvasBackgroundLight {
    "rgba(0, 0, 0, 0.00)"
  } else {
    "rgba(255, 255, 255, 0.00)"
  }

  zoomRef.current = zoom
  panRef.current = pan

  let handlePickColor = (row, col) => {
    let pickedColor = Board.get(board, row, col)->Js.Nullable.toOption
    switch pickedColor {
    | Some(color) =>
      setMyColor(_ => color)
      setBrushMode(_ => Color)
    | None => ()
    }
    setIsPickingColor(_ => false)
    setHoveredPickColor(_ => None)
  }

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

  let setCanvasDotMask = updater =>
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      {...canvas, isDotMask: updater(canvas.isDotMask)}
    })

  let setCanvasBackgroundColor = updater =>
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      {...canvas, canvasBackgroundColor: updater(canvas.canvasBackgroundColor)}
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
  let zoomIn = () => adjustZoomByFactor(Initials.zoom_factor)
  let zoomOut = () => adjustZoomByFactor(1. /. Initials.zoom_factor)

  let (boardDimI, boardDimJ) = Board.dims(board)
  let zoomPercent = switch computeZoomToFitForDimensions(boardDimI, boardDimJ) {
  | Some(fitZoom) =>
    if fitZoom <= 0. {
      zoom *. 100.
    } else {
      zoom /. fitZoom *. 100.
    }
  | None => zoom *. 100.
  }
  let lastAutoCenteredDimsRef = React.useRef(None)
  let (brushDimI, brushDimJ) = brush->Array2D.dims
  let brushCenterDimI = brushDimI / 2
  let brushCenterDimJ = brushDimJ / 2
  let (tileMaskDimI, tileMaskDimJ) = tileMask->Array2D.dims

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

  let centerCanvas = () => centerCanvasForDimensions(boardDimI, boardDimJ)
  let fitCanvasToViewportForDimensions = (dimI, dimJ) =>
    switch computeZoomToFitForDimensions(dimI, dimJ) {
    | Some(nextZoom) =>
      updateCanvasById(currentCanvasIdRef.current, canvas => {
        let (nextPanX, nextPanY) = computeCenteredPan(dimI, dimJ, nextZoom)
        zoomRef.current = nextZoom
        panRef.current = (nextPanX, nextPanY)
        {...canvas, zoom: nextZoom, pan: (nextPanX, nextPanY)}
      })
    | None => centerCanvasForDimensions(dimI, dimJ)
    }

  let fitCanvasToViewport = () => fitCanvasToViewportForDimensions(boardDimI, boardDimJ)

  // Resize controls
  let (resizeRowsInput, setResizeRowsInput) = React.useState(() => boardDimI->Int.toString)
  let (resizeColsInput, setResizeColsInput) = React.useState(() => boardDimJ->Int.toString)

  React.useEffect2(() => {
    setResizeRowsInput(_ => boardDimI->Int.toString)
    setResizeColsInput(_ => boardDimJ->Int.toString)
    None
  }, (boardDimI, boardDimJ))

  React.useEffect3(() => {
    let (panX, panY) = panRef.current
    let hasCustomPan = panX != 0. || panY != 0.
    switch lastAutoCenteredDimsRef.current {
    | Some((prevI, prevJ)) =>
      if prevI != boardDimI || prevJ != boardDimJ {
        centerCanvasForDimensions(boardDimI, boardDimJ)
        lastAutoCenteredDimsRef.current = Some((boardDimI, boardDimJ))
      }
    | None =>
      if !hasCustomPan {
        centerCanvasForDimensions(boardDimI, boardDimJ)
      }
      lastAutoCenteredDimsRef.current = Some((boardDimI, boardDimJ))
    }
    None
  }, (boardDimI, boardDimJ, viewportCenter))

  React.useEffect2(() => {
    switch savedTileMasks->Array.get(selectedTileMaskIndex) {
    | Some(mask) =>
      if !Array2D.isEqual(mask, tileMask) {
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
    let (prevRows, prevCols) = Board.dims(prev)
    let nextBoard = Board.make(nextRows, nextCols)
    if prevRows == 0 || prevCols == 0 {
      nextBoard
    } else {
      for rowI in 0 to nextRows - 1 {
        let srcRow = mapIndex(~srcSize=prevRows, ~dstSize=nextRows, rowI)
        for colJ in 0 to nextCols - 1 {
          let srcCol = mapIndex(~srcSize=prevCols, ~dstSize=nextCols, colJ)
          Board.setInPlace(nextBoard, rowI, colJ, Board.get(prev, srcRow, srcCol))
        }
      }
      nextBoard
    }
  }

  let resizeBoardCrop = (prev, nextRows, nextCols) => {
    let nextBoard = Board.make(nextRows, nextCols)
    for rowI in 0 to nextRows - 1 {
      for colJ in 0 to nextCols - 1 {
        Board.setInPlace(nextBoard, rowI, colJ, Board.get(prev, rowI, colJ))
      }
    }
    nextBoard
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
      switch resizeMode {
      | Scale => setBoard(prev => resizeBoardScale(prev, nextRows, nextCols))
      | Crop => setBoard(prev => resizeBoardCrop(prev, nextRows, nextCols))
      }
      fitCanvasToViewportForDimensions(nextRows, nextCols)
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
        {
          includeBackground: includeExportBackground,
          backgroundColor: canvasBackgroundColor,
          includeDotMask: includeExportDotMask,
          dotMaskColor: canvasBackgroundColor,
        },
      )
    | None => ()
    }

  // Saved asset helpers
  let selectedSavedBrushIndex =
    savedBrushes->Belt.Array.getIndexBy(savedBrush => Array2D.isEqual(savedBrush, brush))

  let canDeleteSelectedBrush = selectedSavedBrushIndex->Option.isSome
  let canDeleteSelectedTileMask = savedTileMasks->Array.length > 1

  let handleAddBrush = () => {
    let newBrush = Board.toBoolGrid(board)
    setSavedBrushes(v => v->Array.concat([newBrush]))
    setBrush(_ => newBrush)
  }

  let handleDeleteSelectedBrush = () =>
    switch selectedSavedBrushIndex {
    | Some(selectedIndex) =>
      setSavedBrushes(prev => prev->Belt.Array.keepWithIndex((_, idx) => idx != selectedIndex))
    | None => ()
    }

  let handleAddTileMask = () => {
    let newTileMask = Board.toBoolGrid(board)
    setSavedTileMasks(prev => {
      let next = prev->Array.concat([newTileMask])
      setSelectedTileMaskIndex(_ => next->Array.length - 1)
      next
    })
    setTileMask(_ => newTileMask)
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
    let newBoard = makeBoard(boardDimI, boardDimJ)
    let (fittedZoom, newPan) = computeFitViewForDimensions(boardDimI, boardDimJ)
    let newCanvas = makeCanvas(
      ~board=newBoard,
      ~zoom=fittedZoom,
      ~pan=newPan,
      ~isDotMask=false,
      ~canvasBackgroundColor,
    )
    setCanvases(prev => prev->Array.concat([newCanvas]))
    setSelectedCanvasId(_ => newCanvas.id)
    zoomRef.current = fittedZoom
    panRef.current = newPan
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

  let getBrushColor = () => {
    switch brushMode {
    | Color => Nullable.Value(myColor)
    | Erase => Nullable.null
    }
  }

  let applyBrush = (clickI, clickJ) => {
    setLocalStoragePersistencePaused(true)
    let brushColor = getBrushColor()
    setBoard(prev => {
      let (rows, cols) = Board.dims(prev)
      if rows == 0 || cols == 0 {
        prev
      } else {
        let updates: array<(int, int, Js.Nullable.t<string>)> = []
        for brushI in 0 to brushDimI - 1 {
          let boardI = clickI - brushCenterDimI + brushI
          if boardI >= 0 && boardI < rows {
            for brushJ in 0 to brushDimJ - 1 {
              let boardJ = clickJ - brushCenterDimJ + brushJ
              if boardJ >= 0 && boardJ < cols {
                let brushAllows = Array2D.check(brush, brushI, brushJ)->Option.getOr(false)
                if brushAllows {
                  let maskAllows = if tileMaskDimI > 0 && tileMaskDimJ > 0 {
                    Array2D.check(
                      tileMask,
                      mod(boardI, tileMaskDimI),
                      mod(boardJ, tileMaskDimJ),
                    )->Option.getOr(false)
                  } else {
                    true
                  }
                  if maskAllows {
                    ignore(Js.Array2.push(updates, (boardI, boardJ, brushColor)))
                  }
                }
              }
            }
          }
        }
        if Js.Array2.length(updates) == 0 {
          prev
        } else {
          Board.setMany(prev, updates)
        }
      }
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
        let step = 20.
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

  let onSelectUsedColor = color => {
    setMyColor(_ => color)
    setBrushMode(_ => Color)
  }

  let onReplaceUsedColor = color =>
    setBoard(prev => {
      let (rows, cols) = Board.dims(prev)
      let replacement = Nullable.Value(myColor)
      let updates: array<(int, int, Js.Nullable.t<string>)> = []
      for row in 0 to rows - 1 {
        for col in 0 to cols - 1 {
          switch Board.get(prev, row, col)->Js.Nullable.toOption {
          | Some(existing) =>
            if existing == color {
              ignore(Js.Array2.push(updates, (row, col, replacement)))
            }
          | None => ()
          }
        }
      }
      if Js.Array2.length(updates) == 0 {
        prev
      } else {
        Board.setMany(prev, updates)
      }
    })

  <div className=" flex flex-row h-dvh overflow-x-hidden">
    <div className="flex flex-col flex-none overflow-x-hidden divide-y divide-gray-300">
      <ZoomControl zoomOut zoomIn centerCanvas fitCanvasToViewport zoomPercent />

      <div className="flex flex-row gap-2 h-full flex-none p-2">
        <SavedBrushesPanel
          brush
          setBrush
          savedBrushes
          handleAddBrush
          handleDeleteSelectedBrush
          canDeleteSelectedBrush
          canSaveBrush={boardDimI <= 32 && boardDimJ <= 32}
        />
        <SavedTileMasksPanel
          setTileMask
          savedTileMasks
          selectedTileMaskIndex
          setSelectedTileMaskIndex
          handleAddTileMask
          handleDeleteSelectedTileMask
          canDeleteSelectedTileMask
          canSaveTileMask={boardDimI <= 32 && boardDimJ <= 32}
        />
      </div>
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
          handlePickColor
          setHoveredPickColor
          isPickingColor
          showCursorOverlay
          overlayMode
          gridMode
          canvasBackgroundColor
          gridLineColor
          overlayColor=myColor
          checkeredPrimaryColor
          checkeredSecondaryColor
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
          isDotMask
        />
      </div>

      <CanvasThumbnails
        canvases
        currentCanvasId
        canDeleteCanvas
        handleDeleteCanvas
        handleAddCanvas
        handleSelectCanvas
        isMouseDown
      />
    </div>
    <div className=" h-full overflow-x-visible flex flex-col w-48 py-2">
      <ColorControl
        brushMode
        setBrushMode
        myColor
        setMyColor
        hoveredPickColor
        isPickingColor
        onStartColorPick
        canvasBackgroundColor
      />
      <div className={"overflow-y-scroll flex-1 flex flex-col py-2 divide-y divide-gray-300"}>
        <ColorsUsed myColor board onSelectUsedColor onReplaceUsedColor isMouseDown />

        <BrushOverlayControl overlayMode setOverlayMode />
        <CanvasGridControl gridMode setGridMode />

        <CanvasColorsControl
          myColor
          canvasBackgroundColor
          setCanvasBackgroundColor
          viewportBackgroundColor
          setViewportBackgroundColor
        />
        <SilhouetteControl isSilhouette setIsSilhouette />
        <DotModeControl isDotMask setCanvasDotMask />

        <CanvasSizeControl
          resizeRowsInput
          setResizeRowsInput
          resizeColsInput
          setResizeColsInput
          resizeMode
          setResizeMode
          canSubmitResize
          handleResizeSubmit
        />

        <ExportControl
          exportScaleInput
          setExportScaleInput
          includeExportBackground
          setIncludeExportBackground
          includeExportDotMask
          setIncludeExportDotMask
          canExport
          onExport={handleExportPng}
        />
      </div>
    </div>
  </div>
}
