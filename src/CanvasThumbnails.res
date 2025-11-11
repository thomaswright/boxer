open Types

@react.component
let make = (
  ~canvases: array<Types.canvasState>,
  ~canvasBoards: array<Types.canvasBoardState>,
  ~currentCanvasId,
  ~canDeleteCanvas,
  ~handleDeleteCanvas,
  ~handleAddCanvas,
  ~handleSelectCanvas,
  ~isMouseDown,
) => {
  let findCanvasMetadata = id =>
    canvases->Belt.Array.getBy(canvas => canvas.id == id)->Option.getOr({
      id,
      zoom: 1.,
      pan: (0., 0.),
      isDotMask: false,
      canvasBackgroundColor: Initials.canvasBackgroundColor,
    })

  <div className="flex flex-row items-start gap-3 overflow-x-scroll p-2 pl-0">
    {canvasBoards
    ->Array.map(({id, board}) => {
      let _canvas = findCanvasMetadata(id)
      let isSelectedCanvas = id == currentCanvasId
      <div
        key={id}
        className={[
          "relative flex-shrink-0 border-2 w-fit h-fit",
          isSelectedCanvas
            ? "border-[color:var(--accent)]"
            : "border-[color:var(--plain-200)]",
        ]->Array.join(" ")}>
        <button
          onClick={_ => handleSelectCanvas(id)}
          className={[" w-fit h-fit block"]->Array.join(" ")}>
          <div className="h-16 w-16 rounded-xs overflow-hidden">
            <BoardPreview board={board} emptyColor={None} isMouseDown />
          </div>
        </button>
        {isSelectedCanvas
          ? <button
              className={[
                " w-4 h-4 leading-none text-sm font-medium absolute right-0 bottom-0 flex items-center justify-center",
                canDeleteCanvas
                  ? "bg-[color:var(--plain-700)] text-[color:var(--plain-white)]"
                  : "bg-[color:var(--plain-200)] text-[color:var(--plain-500)] cursor-not-allowed",
              ]->Array.join(" ")}
              disabled={!canDeleteCanvas}
              onClick={e => {
                e->JsxEvent.Mouse.stopPropagation
                handleDeleteCanvas()
              }}>
              <Icons.Trash />
            </button>
          : React.null}
      </div>
    })
    ->React.array}
    <button
      onClick={_ => handleAddCanvas()}
      className="flex-shrink-0 h-16 w-16 border-2 border-dashed border-[color:var(--plain-300)] flex items-center justify-center text-3xl text-[color:var(--plain-400)]">
      <Icons.Plus />
    </button>
  </div>
}
