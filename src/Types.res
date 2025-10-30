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
type gridMode =
  | @as("none") GridNone
  | @as("grid") GridLines
  | @as("checkeredOverlay") CheckeredOverlay
  | @as("checkeredUnderlay") CheckeredUnderlay

type canvasRenderer
