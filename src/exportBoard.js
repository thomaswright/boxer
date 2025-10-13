const CELL_BASE_SIZE = 16;

function ensurePositiveScale(scale) {
  if (!Number.isFinite(scale) || scale <= 0) {
    return 1;
  }
  return scale;
}

function drawBoardToCanvas(ctx, board, cellSize) {
  for (let x = 0; x < board.length; x += 1) {
    const column = board[x];
    if (!Array.isArray(column)) continue;
    for (let y = 0; y < column.length; y += 1) {
      const color = column[y];
      if (color) {
        ctx.fillStyle = color;
        ctx.fillRect(x * cellSize, y * cellSize, cellSize, cellSize);
      }
    }
  }
}

export function exportBoardAsPng(board, scale) {
  if (!Array.isArray(board) || board.length === 0) {
    return;
  }
  const columnLength = board[0]?.length ?? 0;
  if (columnLength === 0) {
    return;
  }

  const safeScale = ensurePositiveScale(scale);
  const cellSize = CELL_BASE_SIZE * safeScale;
  const width = Math.ceil(board.length * cellSize);
  const height = Math.ceil(columnLength * cellSize);

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    return;
  }

  ctx.clearRect(0, 0, width, height);
  drawBoardToCanvas(ctx, board, cellSize);

  const link = document.createElement("a");
  link.href = canvas.toDataURL("image/png");
  link.download = "canvas.png";
  // For Firefox compatibility, we must append before click
  document.body.appendChild(link);
  link.click();
  link.remove();
}

