module Uint32Array = Stdlib_Uint32Array
module TypedArray = Stdlib_TypedArray

type t = {
  rows: int,
  cols: int,
  data: Uint32Array.t,
}

@module("./BoardColor.js")
external colorToUint32: string => int = "hexToUint32"

@module("./BoardColor.js")
external uint32ToHex: int => Js.Nullable.t<string> = "uint32ToHex"

let make = (rows, cols) => {
  let clampedRows = if rows < 0 {
    0
  } else {
    rows
  }
  let clampedCols = if cols < 0 {
    0
  } else {
    cols
  }
  {
    rows: clampedRows,
    cols: clampedCols,
    data: Uint32Array.fromLength(clampedRows * clampedCols),
  }
}

let dims = board => (board.rows, board.cols)

let index = (board, row, col) => row * board.cols + col

let inBounds = (board, row, col) => row >= 0 && row < board.rows && col >= 0 && col < board.cols

let getValue = (board, row, col) =>
  if !inBounds(board, row, col) {
    0
  } else {
    board.data->TypedArray.get(index(board, row, col))->Option.getOr(0)
  }

let valueToNullable = value =>
  if value == 0 {
    Js.Nullable.null
  } else {
    uint32ToHex(value)
  }

let get = (board, row, col) => valueToNullable(getValue(board, row, col))

let nullableToValue = color =>
  switch color->Js.Nullable.toOption {
  | Some(hex) => colorToUint32(hex)
  | None => 0
  }

let copyData = board => board.data->TypedArray.copy

let set = (board, row, col, color) =>
  if !inBounds(board, row, col) {
    board
  } else {
    let idx = index(board, row, col)
    let nextValue = nullableToValue(color)
    let currentValue = board.data->TypedArray.get(idx)->Option.getOr(0)
    if currentValue == nextValue {
      board
    } else {
      let nextData = copyData(board)
      nextData->TypedArray.set(idx, nextValue)
      {rows: board.rows, cols: board.cols, data: nextData}
    }
  }

let clone = board => {rows: board.rows, cols: board.cols, data: copyData(board)}

let unsafeSetInPlace = (board, row, col, value) =>
  if inBounds(board, row, col) {
    board.data->TypedArray.set(index(board, row, col), value)
  } else {
    ()
  }

let setInPlace = (board, row, col, color) =>
  unsafeSetInPlace(board, row, col, nullableToValue(color))

let setValueInPlace = (board, row, col, value) => unsafeSetInPlace(board, row, col, value)

let setMany = (board, updates) => {
  let copyRef = ref(None)
  let ensureCopy = () =>
    switch copyRef.contents {
    | Some(data) => data
    | None =>
      let copied = copyData(board)
      copyRef := Some(copied)
      copied
    }
  updates->Array.forEach(((row, col, color)) =>
    if inBounds(board, row, col) {
      let idx = index(board, row, col)
      let nextValue = nullableToValue(color)
      let currentValue = board.data->TypedArray.get(idx)->Option.getOr(0)
      if currentValue != nextValue {
        let data = ensureCopy()
        data->TypedArray.set(idx, nextValue)
      }
    }
  )
  switch copyRef.contents {
  | Some(data) => {rows: board.rows, cols: board.cols, data}
  | None => board
  }
}

let toBoolGrid = board => {
  let (rows, cols) = dims(board)
  let result = []
  for row in 0 to rows - 1 {
    let rowArray = []
    for col in 0 to cols - 1 {
      let hasColor = getValue(board, row, col) != 0
      ignore(Js.Array2.push(rowArray, hasColor))
    }
    ignore(Js.Array2.push(result, rowArray))
  }
  result
}

let forEachValue = (board, f) => {
  let (rows, cols) = dims(board)
  for row in 0 to rows - 1 {
    for col in 0 to cols - 1 {
      let value = getValue(board, row, col)
      f(row, col, value)
    }
  }
}

let fromArray2D = array2d => {
  let rows = array2d->Array.length
  let cols = array2d->Array.get(0)->Option.mapOr(0, firstRow => firstRow->Array.length)
  let board = make(rows, cols)
  for row in 0 to rows - 1 {
    switch array2d->Array.get(row) {
    | Some(rowArray) =>
      for col in 0 to cols - 1 {
        switch rowArray->Array.get(col) {
        | Some(color) => unsafeSetInPlace(board, row, col, nullableToValue(color))
        | None => ()
        }
      }
    | None => ()
    }
  }
  board
}

let toArray2D = board => {
  let (rows, cols) = dims(board)
  let result = []
  for row in 0 to rows - 1 {
    let rowArray = []
    for col in 0 to cols - 1 {
      ignore(Js.Array2.push(rowArray, get(board, row, col)))
    }
    ignore(Js.Array2.push(result, rowArray))
  }
  result
}

let fill = (rows, cols, color) => {
  let board = make(rows, cols)
  let value = nullableToValue(color)
  if value != 0 {
    ignore(board.data->TypedArray.fillAll(value))
  }
  board
}

let mapValues = (board, mapper) => {
  let (rows, cols) = dims(board)
  let next = make(rows, cols)
  for row in 0 to rows - 1 {
    for col in 0 to cols - 1 {
      let value = mapper(row, col, get(board, row, col))
      unsafeSetInPlace(next, row, col, nullableToValue(value))
    }
  }
  next
}

let data = board => board.data
