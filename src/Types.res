type board = Board.t
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
type gridMode =
  | @as("none") GridNone
  | @as("gridOverlay") GridLinesOverlay
  | @as("gridUnderlay") GridLinesUnderlay
  | @as("checkeredOverlay") CheckeredOverlay
  | @as("checkeredUnderlay") CheckeredUnderlay
type overlayMode =
  | @as("none") OverlayNone | @as("overlay") OverlayDefault | @as("color") OverlayColor

type canvasRenderer
