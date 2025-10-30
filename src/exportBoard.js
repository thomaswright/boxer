import { uint32ToHex } from "./BoardColor.js";

const CELL_BASE_SIZE = 16;

function isTypedBoard(board) {
  return (
    board &&
    typeof board === "object" &&
    Number.isInteger(board.rows) &&
    Number.isInteger(board.cols) &&
    board.data instanceof Uint32Array
  );
}

function getBoardDimensions(board) {
  if (isTypedBoard(board)) {
    return [Math.max(0, board.rows | 0), Math.max(0, board.cols | 0)];
  }
  if (Array.isArray(board)) {
    const rows = board.length;
    const cols = rows > 0 && Array.isArray(board[0]) ? board[0].length : 0;
    return [rows, cols];
  }
  return [0, 0];
}

function ensurePositiveScale(scale) {
  if (!Number.isFinite(scale) || scale <= 0) {
    return 1;
  }
  return scale;
}

function drawBoardToCanvas(ctx, board, cellSize, backgroundColor) {
  if (isTypedBoard(board)) {
    const rows = Math.max(0, board.rows | 0);
    const cols = Math.max(0, board.cols | 0);
    const data = board.data;
    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < cols; col += 1) {
        const value = data[row * cols + col] >>> 0;
        const fill = value ? uint32ToHex(value) : backgroundColor;
        if (fill) {
          ctx.fillStyle = fill;
          ctx.fillRect(col * cellSize, row * cellSize, cellSize, cellSize);
        }
      }
    }
    return;
  }

  if (!Array.isArray(board)) {
    return;
  }

  for (let row = 0; row < board.length; row += 1) {
    const rowData = board[row];
    if (!Array.isArray(rowData)) continue;
    for (let col = 0; col < rowData.length; col += 1) {
      const color = rowData[col];
      const fill = color ?? backgroundColor;
      if (fill) {
        ctx.fillStyle = fill;
        ctx.fillRect(col * cellSize, row * cellSize, cellSize, cellSize);
      }
    }
  }
}

export function exportBoardAsPng(board, scale, options = {}) {
  const [rows, cols] = getBoardDimensions(board);
  if (rows === 0 || cols === 0) {
    return;
  }

  const safeScale = ensurePositiveScale(scale);
  const cellSize = CELL_BASE_SIZE * safeScale;
  const height = Math.ceil(rows * cellSize);
  const width = Math.ceil(cols * cellSize);

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    return;
  }

  ctx.clearRect(0, 0, width, height);

  if (options.includeBackground && options.backgroundColor) {
    ctx.fillStyle = options.backgroundColor;
    ctx.fillRect(0, 0, width, height);
  }

  drawBoardToCanvas(
    ctx,
    board,
    cellSize,
    options.includeBackground ? options.backgroundColor ?? null : null
  );

  const link = document.createElement("a");
  link.href = canvas.toDataURL("image/png");
  link.download = "canvas.png";
  // For Firefox compatibility, we must append before click
  document.body.appendChild(link);
  link.click();
  link.remove();
}
