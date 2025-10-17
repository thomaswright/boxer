open Types

@react.component
let make = (
  ~canvases,
  ~currentCanvasId,
  ~canDeleteCanvas,
  ~handleDeleteCanvas,
  ~handleAddCanvas,
  ~onSelectCanvas,
) => {
  <div className="flex flex-row items-start gap-3 overflow-x-scroll p-2 pl-0">
    {canvases
    ->Array.map(canvas => {
      let canvasBoard = canvas.board
      let (thumbDimI, thumbDimJ) = canvasBoard->Array2D.dims2D
      let isSelectedCanvas = canvas.id == currentCanvasId
      <div
        key={canvas.id}
        className={[
          "relative flex-shrink-0 border-2 w-fit h-fit",
          isSelectedCanvas ? "border-blue-500" : "border-gray-200",
        ]->Array.join(" ")}>
        <button
          onClick={_ => onSelectCanvas(canvas.id)}
          className={[" w-fit h-fit block"]->Array.join(" ")}>
          <div
            className="h-16 w-16 grid"
            style={{
              gridTemplateColumns: `repeat(${thumbDimJ->Int.toString}, minmax(0, 1fr))`,
              gridTemplateRows: `repeat(${thumbDimI->Int.toString}, minmax(0, 1fr))`,
            }}>
            {canvasBoard
            ->Array.mapWithIndex((line, i) => {
              line
              ->Array.mapWithIndex(
                (cell, j) => {
                  <div
                    key={i->Int.toString ++ j->Int.toString}
                    className="w-full h-full"
                    style={{
                      backgroundColor: cell->Nullable.getOr("transparent"),
                    }}>
                  </div>
                },
              )
              ->React.array
            })
            ->React.array}
          </div>
        </button>
        {isSelectedCanvas
          ? <button
              className={[
                " w-4 h-4 leading-none text-sm font-medium absolute right-0 bottom-0",
                canDeleteCanvas
                  ? "bg-red-500 text-white"
                  : "bg-gray-200 text-gray-500 cursor-not-allowed",
              ]->Array.join(" ")}
              disabled={!canDeleteCanvas}
              onClick={e => {
                e->JsxEvent.Mouse.stopPropagation
                handleDeleteCanvas()
              }}>
              {"x"->React.string}
            </button>
          : React.null}
      </div>
    })
    ->React.array}
    <button
      onClick={_ => handleAddCanvas()}
      className="flex-shrink-0 h-16 w-16 border-2 border-dashed border-gray-300 flex items-center justify-center text-3xl text-gray-400">
      {"+"->React.string}
    </button>
  </div>
}
