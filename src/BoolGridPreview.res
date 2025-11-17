module Palette = Palette
module Theme = Theme

@react.component
let make = (
  ~grid: array<array<bool>>,
  ~filledColor: option<string>,
  ~emptyColor: option<string>,
) => {
  let canvasRef = React.useRef((Js.Nullable.null: Js.Nullable.t<Dom.element>))
  let (theme, _setTheme) = Theme.useTheme()

  let resolveCanvasColor = color =>
    color->Option.flatMap(value => Palette.resolveColor(value))

  React.useEffect4(() => {
    let resolvedFilledColor = resolveCanvasColor(filledColor)
    let resolvedEmptyColor = resolveCanvasColor(emptyColor)
    switch canvasRef.current->Js.Nullable.toOption {
    | Some(canvasElement) =>
      PreviewCanvas.drawBoolGrid(
        ~canvasElement,
        ~grid,
        ~trueColor=resolvedFilledColor,
        ~falseColor=resolvedEmptyColor,
      )
    | None => ()
    }
    None
  }, (grid, filledColor, emptyColor, theme))

  <canvas
    ref={ReactDOM.Ref.domRef(canvasRef)}
    className="w-full h-full block object-contain "
    style={{imageRendering: "pixelated"}}
  />
}
