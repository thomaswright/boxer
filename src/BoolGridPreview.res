@react.component
let make = (
  ~grid: array<array<bool>>,
  ~filledColor: option<string>,
  ~emptyColor: option<string>,
) => {
  let canvasRef = React.useRef((Js.Nullable.null: Js.Nullable.t<Dom.element>))

  React.useEffect3(() => {
    switch canvasRef.current->Js.Nullable.toOption {
    | Some(canvasElement) =>
      PreviewCanvas.drawBoolGrid(
        ~canvasElement,
        ~grid,
        ~trueColor=filledColor,
        ~falseColor=emptyColor,
      )
    | None => ()
    }
    None
  }, (grid, filledColor, emptyColor))

  <canvas
    ref={ReactDOM.Ref.domRef(canvasRef)}
    className="w-full h-full block object-contain "
    style={{imageRendering: "pixelated"}}
  />
}
