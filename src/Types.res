type board = Board.t
type canvasState = {
  id: string,
  zoom: float,
  pan: (float, float),
  isDotMask: bool,
  canvasBackgroundColor: string,
}
type canvasBoardState = {
  id: string,
  board: board,
}
type history<'a> = {
  past: array<'a>,
  present: option<'a>,
  future: array<'a>,
}
type boardHistory = history<board>
type boolean2D = array<array<bool>>
type tileMaskEntry = {
  id: string,
  mask: boolean2D,
}
type brushEntry = {
  id: string,
  brush: boolean2D,
}
type exportOptions = {
  includeBackground: bool,
  backgroundColor: string,
  includeDotMask: bool,
  dotMaskColor: string,
}

type brushMode = | @as("Color") Color | @as("Erase") Erase
type resizeMode = | @as("Scale") Scale | @as("Crop") Crop
type gridMode =
  | @as("none") GridNone
  | @as("gridOverlay") GridLinesOverlay
  | @as("gridUnderlay") GridLinesUnderlay
  | @as("checkeredOverlay") CheckeredOverlay
  | @as("checkeredUnderlay") CheckeredUnderlay
type overlayMode =
  | @as("none") OverlayNone | @as("overlay") OverlayDefault | @as("color") OverlayColor

type canvasRenderer
