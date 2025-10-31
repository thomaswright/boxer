module IdleScheduler = {
  type handle
  @module("./IdleScheduler.js")
  external schedule: (unit => unit) => handle = "schedule"
  @module("./IdleScheduler.js")
  external cancel: handle => unit = "cancel"
}

@react.component
let make = (~board: Types.board, ~emptyColor: option<string>, ~isMouseDown: bool) => {
  let canvasRef = React.useRef((Js.Nullable.null: Js.Nullable.t<Dom.element>))
  let drawHandleRef = React.useRef(None)

  React.useEffect3(() => {
    switch canvasRef.current->Js.Nullable.toOption {
    | Some(canvasElement) =>
      switch drawHandleRef.current {
      | Some(handle) =>
        IdleScheduler.cancel(handle)
        drawHandleRef.current = None
      | None => ()
      }
      if !isMouseDown {
        let handle = IdleScheduler.schedule(() => {
          drawHandleRef.current = None
          PreviewCanvas.drawBoard(~canvasElement, ~board, ~emptyColor)
        })
        drawHandleRef.current = Some(handle)
      }
    | None => ()
    }
    Some(
      () => {
        switch drawHandleRef.current {
        | Some(handle) =>
          IdleScheduler.cancel(handle)
          drawHandleRef.current = None
        | None => ()
        }
      },
    )
  }, (Board.data(board), emptyColor, isMouseDown))

  <canvas
    ref={ReactDOM.Ref.domRef(canvasRef)}
    className="block object-contain w-full h-full"
    style={{imageRendering: "pixelated"}}
  />
}
