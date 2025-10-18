@@warning("-44")
open Webapi.Dom

open Types

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

let makeBoard = (i, j) => Array2D.make(i, j, () => Nullable.null)
let makeBrush = (i, j) => Array2D.make(i, j, () => true)
let makeTileMask = (i, j) => Array2D.make(i, j, () => true)

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
  let (isPickingColor, setIsPickingColor) = React.useState(() => false)
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

  let isMouseDown = useIsMouseDown()

  let toggleColorPick = () =>
    setIsPickingColor(prev => {
      let next = !prev
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

  let handlePickColor = (row, col) => {
    let pickedColor = switch board->Array.get(row) {
    | Some(rowData) =>
      switch rowData->Array.get(col) {
      | Some(cell) => cell->Nullable.toOption
      | None => None
      }
    | None => None
    }
    switch pickedColor {
    | Some(color) =>
      setMyColor(_ => color)
      setBrushMode(_ => Color)
    | None => ()
    }
    setIsPickingColor(_ => false)
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

  let (boardDimI, boardDimJ) = board->Array2D.dims
  let lastAutoCenteredDimsRef = React.useRef(None)
  let (brushDimI, brushDimJ) = brush->Array2D.dims
  let brushCenterDimI = brushDimI / 2
  let brushCenterDimJ = brushDimJ / 2
  let (tileMaskDimI, tileMaskDimJ) = tileMask->Array2D.dims
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
  let fitCanvasToViewport = () => {
    switch canvasContainerRef.current->Js.Nullable.toOption {
    | Some(containerElement) =>
      let rect = containerElement->Element.getBoundingClientRect
      let viewportWidth = rect->DomRect.width
      let viewportHeight = rect->DomRect.height
      let cellSize = 16.
      let boardWidth = Float.fromInt(boardDimJ) *. cellSize
      let boardHeight = Float.fromInt(boardDimI) *. cellSize
      if viewportWidth <= 0. || viewportHeight <= 0. || boardWidth <= 0. || boardHeight <= 0. {
        centerCanvas()
      } else {
        let zoomByWidth = viewportWidth /. boardWidth
        let zoomByHeight = viewportHeight /. boardHeight
        let zoomToFit = if zoomByWidth < zoomByHeight {
          zoomByWidth
        } else {
          zoomByHeight
        }
        let nextZoom = clampZoom(zoomToFit)
        updateCanvasById(currentCanvasIdRef.current, canvas => {
          let (nextPanX, nextPanY) = computeCenteredPan(boardDimI, boardDimJ, nextZoom)
          zoomRef.current = nextZoom
          panRef.current = (nextPanX, nextPanY)
          {...canvas, zoom: nextZoom, pan: (nextPanX, nextPanY)}
        })
      }
    | None => centerCanvas()
    }
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
    let (prevRows, prevCols) = prev->Array2D.dims
    if prevRows == 0 || prevCols == 0 {
      makeBoard(nextRows, nextCols)
    } else {
      Array2D.make(nextRows, nextCols, () => Nullable.null)->Array.mapWithIndex((row, rowI) =>
        row->Array.mapWithIndex((_, colJ) => {
          let srcRow = mapIndex(~srcSize=prevRows, ~dstSize=nextRows, rowI)
          let srcCol = mapIndex(~srcSize=prevCols, ~dstSize=nextCols, colJ)
          prev->Array2D.check(srcRow, srcCol)->Option.getOr(Nullable.null)
        })
      )
    }
  }

  let resizeBoardCrop = (prev, nextRows, nextCols) =>
    Array2D.make(nextRows, nextCols, () => Nullable.null)->Array.mapWithIndex((row, rowI) =>
      row->Array.mapWithIndex((_, colJ) =>
        prev->Array2D.check(rowI, colJ)->Option.getOr(Nullable.null)
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
    savedBrushes->Belt.Array.getIndexBy(savedBrush => Array2D.isEqual(savedBrush, brush))

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

    let brushAllows = Array2D.check(brush, brushPosI, brushPosJ)->Option.getOr(false)

    let maskAllows =
      Array2D.check(tileMask, mod(boardI, tileMaskDimI), mod(boardJ, tileMaskDimJ))->Option.getOr(
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

  <div className=" flex flex-row h-dvh overflow-x-hidden">
    <div className="flex flex-row gap-2 h-full flex-none p-2">
      <SavedBrushesPanel brush={brush} setBrush={setBrush} savedBrushes={savedBrushes} />
      <SavedTileMasksPanel
        setTileMask={setTileMask}
        savedTileMasks={savedTileMasks}
        selectedTileMaskIndex={selectedTileMaskIndex}
        setSelectedTileMaskIndex={setSelectedTileMaskIndex}
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
          handlePickColor={handlePickColor}
          isPickingColor
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
    <div className=" h-full overflow-x-visible flex flex-col w-48 py-2">
      <ColorControl
        brushMode setBrushMode myColor setMyColor isPickingColor onStartColorPick={toggleColorPick}
      />
      <div className={"overflow-y-scroll flex-1 flex flex-col py-2 divide-y divide-gray-300"}>
        <ZoomControl
          onZoomOut={zoomOut}
          onZoomReset={resetZoom}
          onZoomIn={zoomIn}
          onCenterCanvas={centerCanvas}
          onFitCanvas={fitCanvasToViewport}
          zoom
        />

        <SilhouetteControl isSilhouette setIsSilhouette />
        <ExportControl
          exportScaleInput
          setExportScaleInput
          includeBackground={includeExportBackground}
          setIncludeBackground={setIncludeExportBackground}
          canExport
          onExport={handleExportPng}
        />

        <BrushAndTileMaskSaveControl
          board
          setBrush
          setSavedBrushes
          canDeleteSelectedBrush
          handleDeleteSelectedBrush
          setTileMask
          setSavedTileMasks
          setSelectedTileMaskIndex
          canDeleteSelectedTileMask
          handleDeleteSelectedTileMask
        />
        <BrushOverlayControl showCursorOverlay setShowCursorOverlay />

        <CanvasColorsControl
          myColor
          canvasBackgroundColor
          setCanvasBackgroundColor
          viewportBackgroundColor
          setViewportBackgroundColor
        />
        <CanvasSizeControl
          resizeRowsInput
          setResizeRowsInput
          resizeColsInput
          setResizeColsInput
          resizeMode
          setResizeMode
          canSubmitResize
          onSubmitResize={handleResizeSubmit}
        />
      </div>
    </div>
  </div>
}
