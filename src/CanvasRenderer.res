open Types

@module("./CanvasRenderer.js")
external create: Dom.element => Js.Nullable.t<canvasRenderer> = "create"

@module("./CanvasRenderer.js")
external dispose: canvasRenderer => unit = "dispose"

@module("./CanvasRenderer.js")
external setSize: (canvasRenderer, int, int, int) => unit = "setSize"

@module("./CanvasRenderer.js")
external updateBoard: (canvasRenderer, board, string, bool) => unit = "updateBoard"

@module("./CanvasRenderer.js")
external updateBrush: (canvasRenderer, array<array<bool>>, int, int) => unit = "updateBrush"

@module("./CanvasRenderer.js")
external updateTileMask: (canvasRenderer, array<array<bool>>) => unit = "updateTileMask"

@module("./CanvasRenderer.js")
external setOverlayOptions: (canvasRenderer, bool, bool) => unit = "setOverlayOptions"

@module("./CanvasRenderer.js")
external setHover: (canvasRenderer, Js.Nullable.t<(int, int)>) => unit = "setHover"

@module("./CanvasRenderer.js")
external render: canvasRenderer => unit = "render"
