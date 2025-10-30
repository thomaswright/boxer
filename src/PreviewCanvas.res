open Webapi.Canvas

@set external setImageSmoothingEnabled: (Canvas2d.t, bool) => unit = "imageSmoothingEnabled"

let prepareContext = (canvasElement, width, height) => {
  CanvasElement.setWidth(canvasElement, width)
  CanvasElement.setHeight(canvasElement, height)
  let ctx = CanvasElement.getContext2d(canvasElement)
  setImageSmoothingEnabled(ctx, false)
  Canvas2d.clearRect(ctx, ~x=0., ~y=0., ~w=width->Int.toFloat, ~h=height->Int.toFloat)
  ctx
}

let drawBoolGrid = (~canvasElement, ~grid, ~trueColor, ~falseColor) => {
  let (height, width) = grid->Array2D.dims
  if height == 0 || width == 0 {
    ()
  } else {
    let ctx = prepareContext(canvasElement, width, height)
    let lastColor = ref("")
    grid->Array.forEachWithIndex((row, rowIndex) =>
      row->Array.forEachWithIndex((cell, colIndex) => {
        let color = if cell {
          trueColor
        } else {
          falseColor
        }
        switch color {
        | Some(colorString) =>
          if colorString != lastColor.contents {
            Canvas2d.setFillStyle(ctx, Canvas2d.String, colorString)
            lastColor.contents = colorString
          }
          Canvas2d.fillRect(ctx, ~x=colIndex->Int.toFloat, ~y=rowIndex->Int.toFloat, ~w=1., ~h=1.)
        | None => ()
        }
      })
    )
  }
}

let drawBoard = (~canvasElement, ~board: Types.board, ~emptyColor) => {
  let (height, width) = Board.dims(board)
  if height == 0 || width == 0 {
    ()
  } else {
    let ctx = prepareContext(canvasElement, width, height)
    let lastColor = ref("")
    Board.forEachValue(board, (rowIndex, colIndex, value) => {
      let color =
        if value == 0 {
          emptyColor
        } else {
          Board.valueToNullable(value)->Js.Nullable.toOption
        }
      switch color {
      | Some(colorString) =>
        if colorString != lastColor.contents {
          Canvas2d.setFillStyle(ctx, Canvas2d.String, colorString)
          lastColor.contents = colorString
        }
        Canvas2d.fillRect(
          ctx,
          ~x=colIndex->Int.toFloat,
          ~y=rowIndex->Int.toFloat,
          ~w=1.,
          ~h=1.,
        )
      | None => ()
      }
    })
  }
}
