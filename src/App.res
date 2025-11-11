@@warning("-44")
open Webapi.Dom

open Types

module CanvasHistoryMap = Belt.Map.String

let maxHistoryEntries = 200

type strokeSnapshot = {
  canvasId: string,
  startBoard: board,
}

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

@module("./useLocalStorage.js")
external setLocalStoragePersistencePaused: bool => unit = "setLocalStoragePersistencePaused"

@module("./boardStorage.js")
external loadAllBoards: unit => Js.Promise.t<array<canvasBoardState>> = "loadAllBoards"

@module("./boardStorage.js")
external saveBoardEntry: (string, board) => Js.Promise.t<unit> = "saveBoard"

@module("./boardStorage.js")
external deleteBoardEntry: string => Js.Promise.t<unit> = "deleteBoard"

let makeBoard = (i, j) => Board.make(i, j)
let makeBrush = (i, j) => Array2D.make(i, j, () => true)
let makeTileMask = (i, j) => Array2D.make(i, j, () => true)

let generateCanvasId = () => {
  let timestamp = Js.Date.now()->Float.toString
  let random = Js.Math.random()->Float.toString
  timestamp ++ "-" ++ random
}

let makeCanvas = (
  ~zoom,
  ~pan,
  ~isDotMask=false,
  ~canvasBackgroundColor=Initials.canvasBackgroundColor,
) => {
  {
    id: generateCanvasId(),
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

let runBoardStoragePromise = promise => ignore(promise)

let _isLight = color => {
  let (_, _, l) = Texel.convert(color->Texel.hexToRgb, Texel.srgb, Texel.okhsl)
  l > 0.5
}

let defaultTileMaskPatterns = [
  [[true]],
  [[true, false], [false, true]],
  [[false, true], [true, false]],
  [[false, true], [false, true]],
  [[true, false], [true, false]],
  [[false, false], [true, true]],
  [[true, true], [false, false]],
  [[true, false, false], [false, true, false], [false, false, true]],
]

let generateTileMaskId = () => "tile-mask-" ++ generateCanvasId()

let makeTileMaskEntry = mask => {id: generateTileMaskId(), mask}

let defaultTileMaskEntries = defaultTileMaskPatterns->Array.mapWithIndex((mask, index) => {
  id: "default-tile-mask-" ++ index->Int.toString,
  mask,
})

let defaultBrushPatterns = [
  makeBrush(1, 1),
  makeBrush(2, 2),
  makeBrush(3, 3),
  makeBrush(4, 4),
  makeBrush(8, 8),
  makeBrush(12, 12),
  makeBrush(16, 16),
]

let generateBrushId = () => "brush-" ++ generateCanvasId()

let makeBrushEntry = (brush): brushEntry => {id: generateBrushId(), brush}

let defaultBrushEntries = defaultBrushPatterns->Array.mapWithIndex((brush, index) => {
  id: "default-brush-" ++ index->Int.toString,
  brush,
})

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

  let defaultBoardDimI = 12
  let defaultBoardDimJ = 12

  let makeDefaultCanvas = () => {
    let defaultBoard = makeBoard(defaultBoardDimI, defaultBoardDimJ)
    let (defaultZoom, defaultPan) = computeFitViewForDimensions(defaultBoardDimI, defaultBoardDimJ)
    (makeCanvas(~zoom=defaultZoom, ~pan=defaultPan, ~isDotMask=false), defaultBoard)
  }

  // Persistent Data
  let (canvases, setCanvases, _) = useLocalStorage("canvas-metadata-v1", [])
  let (canvasBoards, setCanvasBoards) = React.useState((): array<Types.canvasBoardState> => [])
  let (boardHistoryByCanvas, setBoardHistoryByCanvas) = React.useState(() => CanvasHistoryMap.empty)
  let canvasBoardsRef = React.useRef(canvasBoards)
  canvasBoardsRef.current = canvasBoards
  let boardHistoryByCanvasRef = React.useRef(boardHistoryByCanvas)
  boardHistoryByCanvasRef.current = boardHistoryByCanvas
  let updateBoardHistoryMap = updater =>
    setBoardHistoryByCanvas(prev => {
      let next = updater(prev)
      boardHistoryByCanvasRef.current = next
      next
    })
  let (savedBrushes, setSavedBrushes, _) = useLocalStorage("saved-brushes", defaultBrushEntries)
  let (savedTileMasks, setSavedTileMasks, _) = useLocalStorage(
    "saved-tile-masks",
    defaultTileMaskEntries,
  )
  let (viewportBackgroundColor, setViewportBackgroundColor, _) = useLocalStorage(
    "viewport-background-color",
    Initials.viewportBackgroundColor,
  )

  // Lifecycle Helper
  let (areBoardsLoaded, setBoardsLoaded) = React.useState(() => false)

  // Persistent Tool Selection
  let (selectedBrushId, setSelectedBrushId, _) = useLocalStorage("selected-brush-id", None)
  let (selectedTileMaskId, setSelectedTileMaskId, _) = useLocalStorage(
    "selected-tile-mask-id",
    None,
  )
  let (selectedCanvasId, setSelectedCanvasId, _) = useLocalStorage("selected-canvas-id", None)
  let (myColor, setMyColor, _) = useLocalStorage("my-color", Initials.myColor)

  // Persistent UI Selection
  let (brushMode, setBrushMode, _) = useLocalStorage("brush-mode", Color)
  let (overlayMode, setOverlayMode, _) = useLocalStorage("brush-overlay-mode", OverlayDefault)
  let showCursorOverlay = switch overlayMode {
  | OverlayNone => false
  | _ => true
  }
  let (gridMode, setGridMode, _) = useLocalStorage("grid-mode", GridNone)

  // Transient UI
  let (isSilhouette, setIsSilhouette, _) = useLocalStorage("canvas-silhouette", Initials.silhouette)
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
  let pushFront = (items, value) => [value]->Array.concat(items)
  let dropFirst = items => {
    let length = items->Array.length
    if length <= 1 {
      []
    } else {
      let trimmed = []
      for index in 1 to length - 1 {
        switch items->Array.get(index) {
        | Some(value) => ignore(Js.Array2.push(trimmed, value))
        | None => ()
        }
      }
      trimmed
    }
  }
  let clampArray = items =>
    if maxHistoryEntries <= 0 || items->Array.length <= maxHistoryEntries {
      items
    } else {
      let trimmed = []
      for index in 0 to maxHistoryEntries - 1 {
        switch items->Array.get(index) {
        | Some(value) => ignore(Js.Array2.push(trimmed, value))
        | None => ()
        }
      }
      trimmed
    }
  let makeHistoryEntry = board => {past: [], present: Some(board), future: []}
  let ensureHistoryPresent = (canvasId, board) =>
    updateBoardHistoryMap(prev => {
      if prev->CanvasHistoryMap.has(canvasId) {
        prev
      } else {
        prev->CanvasHistoryMap.set(canvasId, makeHistoryEntry(board))
      }
    })
  let clearHistoryForCanvas = canvasId =>
    updateBoardHistoryMap(prev => prev->CanvasHistoryMap.remove(canvasId))
  let recordBoardHistoryEntry = (canvasId, prevBoard, nextBoard) =>
    if prevBoard == nextBoard {
      ()
    } else {
      updateBoardHistoryMap(prevMap => {
        let history = switch prevMap->CanvasHistoryMap.get(canvasId) {
        | Some(existing) => existing
        | None => makeHistoryEntry(prevBoard)
        }
        let cappedPast = history.past->pushFront(prevBoard)->clampArray
        prevMap->CanvasHistoryMap.set(
          canvasId,
          {past: cappedPast, present: Some(nextBoard), future: []},
        )
      })
    }
  let strokeSnapshotRef = React.useRef((None: option<strokeSnapshot>))
  let getBoardByCanvasId = canvasId =>
    canvasBoardsRef.current
    ->Belt.Array.getBy(entry => entry.id == canvasId)
    ->Option.map(entry => entry.board)

  let persistBoardValue = (id, boardValue) => runBoardStoragePromise(saveBoardEntry(id, boardValue))

  let removePersistedBoard = id => runBoardStoragePromise(deleteBoardEntry(id))

  let storeBoardValue = (id, boardValue) => {
    setCanvasBoards(prev => {
      let replaced = ref(false)
      let next = prev->Array.map(entry =>
        if entry.id == id {
          replaced := true
          {id: entry.id, board: boardValue}
        } else {
          entry
        }
      )
      if replaced.contents {
        next
      } else {
        next->Array.concat([{id, board: boardValue}])
      }
    })
    persistBoardValue(id, boardValue)
    ensureHistoryPresent(id, boardValue)
  }

  let modifyBoardEntry = (~trackHistory=true, id, updater) => {
    let updatedBoardRef = ref(None)
    let previousBoardRef = ref(None)
    setCanvasBoards(prev => {
      let next = prev->Array.map(entry =>
        if entry.id == id {
          previousBoardRef := Some(entry.board)
          let nextBoard = updater(entry.board)
          updatedBoardRef := Some(nextBoard)
          {id: entry.id, board: nextBoard}
        } else {
          entry
        }
      )
      switch updatedBoardRef.contents {
      | Some(_) => next
      | None =>
        let fallbackPrev = makeBoard(defaultBoardDimI, defaultBoardDimJ)
        previousBoardRef := Some(fallbackPrev)
        let fallback = updater(fallbackPrev)
        updatedBoardRef := Some(fallback)
        next->Array.concat([{id, board: fallback}])
      }
    })
    switch updatedBoardRef.contents {
    | Some(boardValue) =>
      if trackHistory {
        switch previousBoardRef.contents {
        | Some(prevBoard) => recordBoardHistoryEntry(id, prevBoard, boardValue)
        | None => ()
        }
      }
      persistBoardValue(id, boardValue)
    | None => ()
    }
  }

  React.useEffect0(() => {
    ignore(Js.Promise.then_(entries => {
        setCanvasBoards(_ => entries)
        setBoardsLoaded(_ => true)
        Js.Promise.resolve()
      }, loadAllBoards()))
    None
  })

  React.useEffect2(() => {
    if areBoardsLoaded && canvasCount == 0 {
      updateViewportCenter()
      let (defaultCanvas, defaultBoard) = makeDefaultCanvas()
      setCanvases(_ => [defaultCanvas])
      storeBoardValue(defaultCanvas.id, defaultBoard)
      setSelectedCanvasId(_ => Some(defaultCanvas.id))
    }
    None
  }, (areBoardsLoaded, canvasCount))

  React.useEffect3(() => {
    if areBoardsLoaded {
      canvases->Array.forEach(canvas => {
        let hasBoard = canvasBoards->Belt.Array.some(entry => entry.id == canvas.id)
        if !hasBoard {
          let fallbackBoard = makeBoard(defaultBoardDimI, defaultBoardDimJ)
          storeBoardValue(canvas.id, fallbackBoard)
        }
      })
    }
    None
  }, (areBoardsLoaded, canvases, canvasBoards))

  React.useEffect2(() => {
    if areBoardsLoaded {
      updateBoardHistoryMap(prev => {
        let next = canvasBoards->Array.reduce(
          prev,
          (map, entry) =>
            if map->CanvasHistoryMap.has(entry.id) {
              map
            } else {
              map->CanvasHistoryMap.set(entry.id, makeHistoryEntry(entry.board))
            },
        )
        next
      })
    }
    None
  }, (areBoardsLoaded, canvasBoards))

  let selectedCanvas = switch selectedCanvasId {
  | Some(id) => canvases->Belt.Array.getBy(canvas => canvas.id == id)
  | None => None
  }

  let currentCanvas = switch selectedCanvas {
  | Some(canvas) => canvas
  | None =>
    switch canvases->Array.get(0) {
    | Some(firstCanvas) => firstCanvas
    | None =>
      let (defaultCanvas, _) = makeDefaultCanvas()
      defaultCanvas
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
    if canvases->Array.length == 0 {
      if selectedCanvasId != None {
        setSelectedCanvasId(_ => None)
      }
    } else {
      let hasValidSelection = switch selectedCanvasId {
      | Some(id) => canvases->Belt.Array.some(canvas => canvas.id == id)
      | None => false
      }
      if !hasValidSelection {
        switch canvases->Array.get(0) {
        | Some(firstCanvas) => setSelectedCanvasId(_ => Some(firstCanvas.id))
        | None => ()
        }
      }
    }
    None
  }, (canvases, selectedCanvasId))

  let board = switch canvasBoards->Belt.Array.getBy(entry => entry.id == currentCanvasId) {
  | Some(entry) => entry.board
  | None => makeBoard(defaultBoardDimI, defaultBoardDimJ)
  }
  let currentBoardRef = React.useRef(board)
  currentBoardRef.current = board
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

  let ensureStrokeSnapshot = () =>
    switch strokeSnapshotRef.current {
    | Some(snapshot) if snapshot.canvasId == currentCanvasIdRef.current => ()
    | _ =>
      strokeSnapshotRef.current = Some({
        canvasId: currentCanvasIdRef.current,
        startBoard: currentBoardRef.current,
      })
    }
  let finalizeStrokeSnapshot = () =>
    switch strokeSnapshotRef.current {
    | Some(snapshot) =>
      strokeSnapshotRef.current = None
      switch getBoardByCanvasId(snapshot.canvasId) {
      | Some(latestBoard) =>
        recordBoardHistoryEntry(snapshot.canvasId, snapshot.startBoard, latestBoard)
      | None => ()
      }
    | None => ()
    }

  let updateCanvasBoardById = (~trackHistory=true, targetId, updater) =>
    modifyBoardEntry(~trackHistory, targetId, updater)

  let replaceBoardWithoutHistory = (canvasId, boardValue) =>
    updateCanvasBoardById(~trackHistory=false, canvasId, _prev => boardValue)
  let undo = () => {
    finalizeStrokeSnapshot()
    let canvasId = currentCanvasIdRef.current
    let historyMap = boardHistoryByCanvasRef.current
    switch historyMap->CanvasHistoryMap.get(canvasId) {
    | Some(history) =>
      switch history.past->Array.get(0) {
      | Some(previousBoard) =>
        let remainingPast = history.past->dropFirst
        let nextFuture = switch history.present {
        | Some(presentBoard) => history.future->pushFront(presentBoard)->clampArray
        | None => history.future
        }
        let nextHistory = {past: remainingPast, present: Some(previousBoard), future: nextFuture}
        updateBoardHistoryMap(prev => prev->CanvasHistoryMap.set(canvasId, nextHistory))
        replaceBoardWithoutHistory(canvasId, previousBoard)
        strokeSnapshotRef.current = None
      | None => ()
      }
    | None => ()
    }
  }
  let redo = () => {
    finalizeStrokeSnapshot()
    let canvasId = currentCanvasIdRef.current
    let historyMap = boardHistoryByCanvasRef.current
    switch historyMap->CanvasHistoryMap.get(canvasId) {
    | Some(history) =>
      switch history.future->Array.get(0) {
      | Some(nextBoard) =>
        let nextPast = switch history.present {
        | Some(presentBoard) => history.past->pushFront(presentBoard)->clampArray
        | None => history.past
        }
        let remainingFuture = history.future->dropFirst
        let nextHistory = {past: nextPast, present: Some(nextBoard), future: remainingFuture}
        updateBoardHistoryMap(prev => prev->CanvasHistoryMap.set(canvasId, nextHistory))
        replaceBoardWithoutHistory(canvasId, nextBoard)
        strokeSnapshotRef.current = None
      | None => ()
      }
    | None => ()
    }
  }
  let historyForCurrentCanvas = boardHistoryByCanvas->CanvasHistoryMap.get(currentCanvasId)
  let canUndo = switch historyForCurrentCanvas {
  | Some(history) => history.past->Array.length > 0
  | None => false
  }
  let canRedo = switch historyForCurrentCanvas {
  | Some(history) => history.future->Array.length > 0
  | None => false
  }

  React.useEffect1(() => {
    if !isMouseDown {
      finalizeStrokeSnapshot()
    }
    None
  }, [isMouseDown])
  React.useEffect1(() => {
    finalizeStrokeSnapshot()
    None
  }, [currentCanvasId])

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
    setCanvases(prev => prev->Array.map(canvas => canvas.id == targetId ? updater(canvas) : canvas))

  let setBoard = (~trackHistory=true, updater) =>
    updateCanvasBoardById(~trackHistory, currentCanvasIdRef.current, updater)

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

  let updateZoom = (~focalPoint=?, updater) =>
    updateCanvasById(currentCanvasIdRef.current, canvas => {
      let prevZoom = canvas.zoom
      let nextZoom = clampZoom(updater(prevZoom))
      if nextZoom != prevZoom {
        let (anchorX, anchorY) = switch focalPoint {
        | Some(point) => point
        | None => viewportCenterRef.current
        }
        let (prevPanX, prevPanY) = canvas.pan
        let boardCenterX = (anchorX -. prevPanX) /. prevZoom
        let boardCenterY = (anchorY -. prevPanY) /. prevZoom
        let nextPanX = anchorX -. boardCenterX *. nextZoom
        let nextPanY = anchorY -. boardCenterY *. nextZoom
        let nextPan = (nextPanX, nextPanY)
        zoomRef.current = nextZoom
        panRef.current = nextPan
        {...canvas, zoom: nextZoom, pan: nextPan}
      } else {
        zoomRef.current = nextZoom
        canvas
      }
    })

  let adjustZoomByFactor = (~focalPoint=?, factor) =>
    updateZoom(~focalPoint?, prev => prev *. factor)
  let zoomIn = () => adjustZoomByFactor(Initials.zoom_factor)
  let zoomOut = () => adjustZoomByFactor(1. /. Initials.zoom_factor)
  let handleWheelZoom = event => {
    let deltaY = event->ReactEvent.Wheel.deltaY

    if deltaY == 0. {
      ()
    } else {
      let anchor = switch canvasContainerRef.current->Js.Nullable.toOption {
      | Some(containerElement) =>
        let rect = containerElement->Element.getBoundingClientRect
        let mouseEvent: ReactEvent.Mouse.t = event->Obj.magic
        let clientX = mouseEvent->ReactEvent.Mouse.clientX->Int.toFloat
        let clientY = mouseEvent->ReactEvent.Mouse.clientY->Int.toFloat
        (clientX -. rect->DomRect.left, clientY -. rect->DomRect.top)
      | None => (0., 0.)
      }
      let factor = if deltaY < 0. {
        Initials.zoom_factor
      } else {
        1. /. Initials.zoom_factor
      }
      adjustZoomByFactor(~focalPoint=anchor, factor)
    }
  }

  let fallbackBrush = React.useMemo0(() => makeBrush(3, 3))
  let fallbackTileMask = React.useMemo0(() => makeTileMask(4, 4))

  let brush = switch selectedBrushId {
  | Some(id) =>
    switch savedBrushes->Belt.Array.getBy(entry => entry.id == id) {
    | Some(entry) => entry.brush
    | None => fallbackBrush
    }
  | None =>
    switch savedBrushes->Array.get(0) {
    | Some(entry) => entry.brush
    | None => fallbackBrush
    }
  }

  let tileMask = switch selectedTileMaskId {
  | Some(id) =>
    switch savedTileMasks->Belt.Array.getBy(entry => entry.id == id) {
    | Some(entry) => entry.mask
    | None => fallbackTileMask
    }
  | None =>
    switch savedTileMasks->Array.get(0) {
    | Some(entry) => entry.mask
    | None => fallbackTileMask
    }
  }

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
  let canDeleteSelectedBrush = savedBrushes->Array.length > 1
  let canDeleteSelectedTileMask = savedTileMasks->Array.length > 1

  let handleAddBrush = () => {
    let newBrush = Board.toBoolGrid(board)
    let newEntry = makeBrushEntry(newBrush)
    setSavedBrushes(v => v->Array.concat([newEntry]))
    setSelectedBrushId(_ => Some(newEntry.id))
  }

  let handleDeleteSelectedBrush = () => {
    if canDeleteSelectedBrush {
      setSavedBrushes(prev => {
        let currentIndex =
          selectedBrushId
          ->Option.flatMap(id => prev->Belt.Array.getIndexBy(entry => entry.id == id))
          ->Belt.Option.getWithDefault(0)
        let next =
          selectedBrushId->Option.mapOr(prev, id => prev->Belt.Array.keep(entry => entry.id != id))
        let nextSelectionId = switch next->Array.get(currentIndex) {
        | Some(entry) => Some(entry.id)
        | None =>
          if currentIndex > 0 {
            switch next->Array.get(currentIndex - 1) {
            | Some(entry) => Some(entry.id)
            | None => next->Array.get(0)->Option.map(entry => entry.id)
            }
          } else {
            next->Array.get(0)->Option.map(entry => entry.id)
          }
        }
        setSelectedBrushId(_ => nextSelectionId)
        next
      })
    }
  }

  let handleAddTileMask = () => {
    let newTileMask = Board.toBoolGrid(board)
    let newEntry = makeTileMaskEntry(newTileMask)
    setSavedTileMasks(prev => prev->Array.concat([newEntry]))
    setSelectedTileMaskId(_ => Some(newEntry.id))
  }

  let handleDeleteSelectedTileMask = () => {
    if canDeleteSelectedTileMask {
      setSavedTileMasks(prev => {
        let currentIndex =
          selectedTileMaskId
          ->Option.flatMap(id => prev->Belt.Array.getIndexBy(entry => entry.id == id))
          ->Belt.Option.getWithDefault(0)
        let next =
          selectedTileMaskId->Option.mapOr(prev, id =>
            prev->Belt.Array.keep(entry => entry.id != id)
          )
        let nextSelectionId = switch next->Array.get(currentIndex) {
        | Some(entry) => Some(entry.id)
        | None =>
          if currentIndex > 0 {
            switch next->Array.get(currentIndex - 1) {
            | Some(entry) => Some(entry.id)
            | None => next->Array.get(0)->Option.map(entry => entry.id)
            }
          } else {
            next->Array.get(0)->Option.map(entry => entry.id)
          }
        }
        setSelectedTileMaskId(_ => nextSelectionId)
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
      ~zoom=fittedZoom,
      ~pan=newPan,
      ~isDotMask=false,
      ~canvasBackgroundColor,
    )
    setCanvases(prev => prev->Array.concat([newCanvas]))
    storeBoardValue(newCanvas.id, newBoard)
    setSelectedCanvasId(_ => Some(newCanvas.id))
    zoomRef.current = fittedZoom
    panRef.current = newPan
    clearHoverRef.current()
    setCursorOverlayOff(_ => true)
    lastAutoCenteredDimsRef.current = Some((boardDimI, boardDimJ))
  }

  let handleDeleteCanvas = () => {
    if canDeleteCanvas {
      finalizeStrokeSnapshot()
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
      setCanvasBoards(prev => prev->Belt.Array.keep(entry => entry.id != currentCanvasId))
      removePersistedBoard(currentCanvasId)
      clearHistoryForCanvas(currentCanvasId)

      setSelectedCanvasId(_ => nextSelectionId)
      clearHoverRef.current()
      setCursorOverlayOff(_ => true)
    }
  }

  let handleSelectCanvas = canvasId => {
    let isAlreadySelected = switch selectedCanvasId {
    | Some(id) => id == canvasId
    | None => false
    }
    if !isAlreadySelected {
      finalizeStrokeSnapshot()
      setSelectedCanvasId(_ => Some(canvasId))
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
    ensureStrokeSnapshot()
    let brushColor = getBrushColor()
    setBoard(~trackHistory=false, prev => {
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
      let hasPrimaryModifier = event->KeyboardEvent.metaKey || event->KeyboardEvent.ctrlKey
      if hasPrimaryModifier {
        switch event->KeyboardEvent.key {
        | "]" =>
          event->KeyboardEvent.preventDefault
          zoomIn()
        | "[" =>
          event->KeyboardEvent.preventDefault
          zoomOut()
        | "z" | "Z" =>
          event->KeyboardEvent.preventDefault
          if event->KeyboardEvent.shiftKey {
            redo()
          } else {
            undo()
          }
        | "y" | "Y" =>
          event->KeyboardEvent.preventDefault
          redo()
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

  if !areBoardsLoaded {
    <div className="flex h-dvh items-center justify-center text-sm text-gray-500">
      {React.string("Loading canvases…")}
    </div>
  } else {
    <div className=" flex flex-row h-dvh overflow-x-hidden">
      <div className="flex flex-col flex-none overflow-x-hidden divide-y divide-gray-300">
        <ZoomControl zoomOut zoomIn centerCanvas fitCanvasToViewport zoomPercent />

        <div className="flex flex-row gap-2 h-full flex-none p-2">
          <SavedBrushesPanel
            savedBrushes
            selectedBrushId
            setSelectedBrushId
            handleAddBrush
            handleDeleteSelectedBrush
            canDeleteSelectedBrush
            canSaveBrush={boardDimI <= 32 && boardDimJ <= 32}
          />
          <SavedTileMasksPanel
            savedTileMasks
            selectedTileMaskId
            setSelectedTileMaskId
            handleAddTileMask
            handleDeleteSelectedTileMask
            canDeleteSelectedTileMask
            canSaveTileMask={boardDimI <= 32 && boardDimJ <= 32}
          />
        </div>
      </div>

      <div className="flex flex-col flex-1 overflow-x-hidden">
        <div className={"flex-1 pt-2"}>
          {if selectedCanvas == None {
            <div> {React.string("No canvas selected")} </div>
          } else {
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
              onWheel={handleWheelZoom}
            />
          }}
        </div>

        <CanvasThumbnails
          canvases
          canvasBoards
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
}
