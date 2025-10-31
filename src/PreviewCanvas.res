@module("./PreviewCanvasRenderer.js")
external drawBoolGrid: (
  ~canvasElement: Dom.element,
  ~grid: array<array<bool>>,
  ~trueColor: option<string>,
  ~falseColor: option<string>,
) => unit = "drawBoolGrid"

@module("./PreviewCanvasRenderer.js")
external drawBoard: (
  ~canvasElement: Dom.element,
  ~board: Types.board,
  ~emptyColor: option<string>,
) => unit = "drawBoard"
