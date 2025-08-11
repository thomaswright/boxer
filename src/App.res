@@warning("-44")
open Webapi.Dom

@module("./useLocalStorage.js")
external useLocalStorage: (string, 'a) => ('a, ('a => 'a) => unit, unit => 'a) = "default"

let defaultBoard = [
  [None, None, None, None],
  [None, None, None, None],
  [None, None, None, None],
  [None, None, None, None],
]

module Array = {
  include Array
  let update2d = (a, i, j, f) =>
    a->Array.mapWithIndex((row, rowI) =>
      rowI == i ? row->Array.mapWithIndex((cell, cellJ) => cellJ == j ? f(cell) : cell) : row
    )
}

@react.component
let make = () => {
  let (board, setBoard, _) = useLocalStorage("board", defaultBoard)
  let width = board->Array.length
  let height = board->Array.get(0)->Option.mapOr(0, line => line->Array.length)
  Console.log2(width, height)
  let (maskOff, setMaskOff) = React.useState(() => false)
  let onMouseMove = _ => setMaskOff(_ => false)

  React.useEffect0(() => {
    window->Window.addMouseMoveEventListener(onMouseMove)

    None
  })

  <div className="m-5 border ">
    <div
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${width->Int.toString}, 3rem)`,
        gridTemplateRows: `repeat(${height->Int.toString}, 3rem)`,
      }}>
      {board
      ->Array.mapWithIndex((line, i) => {
        line
        ->Array.mapWithIndex((cell, j) => {
          let backgroundColor = cell->Option.getOr("#f00")
          <div
            className={"w-full h-full group relative"}
            key={i->Int.toString ++ j->Int.toString}
            onClick={_ => {
              setBoard(b => b->Array.update2d(i, j, _ => Some("#0f0")))
              setMaskOff(_ => true)
            }}>
            <div
              className={"w-full h-full absolute"}
              style={{
                backgroundColor: backgroundColor,
              }}
            />
            {maskOff
              ? React.null
              : <div
                  className="absolute w-full h-full inset-0 bg-gray-400 opacity-0 group-hover:opacity-50 ">
                </div>}
          </div>
        })
        ->React.array
      })
      ->React.array}
    </div>
  </div>
}
