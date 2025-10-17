@react.component
let make = (~board: Types.board, ~emptyColor: option<string>) => {
  let canvasRef = React.useRef((Js.Nullable.null: Js.Nullable.t<Dom.element>))

  React.useEffect2(() => {
    switch canvasRef.current->Js.Nullable.toOption {
    | Some(canvasElement) => PreviewCanvas.drawBoard(~canvasElement, ~board, ~emptyColor)
    | None => ()
    }
    None
  }, (board, emptyColor))

  <canvas
    ref={ReactDOM.Ref.domRef(canvasRef)}
    className="w-full h-full block"
    style={{imageRendering: "pixelated"}}
  />
}
