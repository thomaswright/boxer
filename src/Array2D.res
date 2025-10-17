let make2D = (rows, cols, f) =>
  Array.make(~length=rows, ())->Array.map(_ => Array.make(~length=cols, f()))
let dims2D = a => {
  let boardDimI = a->Array.length
  let boardDimJ = a->Array.get(0)->Option.mapOr(0, line => line->Array.length)
  (boardDimI, boardDimJ)
}
let check2D = (a, i, j) => {
  a->Array.get(i)->Option.flatMap(row => row->Array.get(j))
}

@module("./other.js")
external isEqual2D: (array<array<bool>>, array<array<bool>>) => bool = "isEqual2D"
