import { hexToUint32 } from "./BoardColor.js";

function ensureContext(canvas, width, height) {
  if (!canvas) {
    return null;
  }
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    return null;
  }
  if (typeof ctx.imageSmoothingEnabled === "boolean") {
    ctx.imageSmoothingEnabled = false;
  }
  return ctx;
}

function argbToCanvasPixel(argb) {
  const alpha = (argb >>> 24) & 0xff;
  if (alpha === 0) {
    return 0;
  }
  const red = (argb >>> 16) & 0xff;
  const green = (argb >>> 8) & 0xff;
  const blue = argb & 0xff;
  return ((alpha << 24) | (blue << 16) | (green << 8) | red) >>> 0;
}

function colorStringToPixel(color) {
  if (color == null) {
    return null;
  }
  const value = hexToUint32(color);
  if (!value) {
    return null;
  }
  return argbToCanvasPixel(value);
}

function fillImageData(buffer32, rows, cols, resolver) {
  let index = 0;
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      buffer32[index] = resolver(row, col);
      index += 1;
    }
  }
}

export function drawBoolGrid(canvasElement, grid, trueColor, falseColor) {
  if (!Array.isArray(grid) || grid.length === 0) {
    return;
  }
  const rows = grid.length;
  const cols = Array.isArray(grid[0]) ? grid[0].length : 0;
  if (rows === 0 || cols === 0) {
    return;
  }
  const ctx = ensureContext(canvasElement, cols, rows);
  if (!ctx) {
    return;
  }
  const imageData = ctx.createImageData(cols, rows);
  const buffer32 = new Uint32Array(imageData.data.buffer);
  const truePixel = colorStringToPixel(trueColor);
  const falsePixel = colorStringToPixel(falseColor);

  fillImageData(buffer32, rows, cols, (row, col) => {
    const rowData = grid[row];
    const cell = Array.isArray(rowData) ? rowData[col] : undefined;
    if (cell) {
      return truePixel ?? 0;
    }
    return falsePixel ?? 0;
  });

  ctx.putImageData(imageData, 0, 0);
}

export function drawBoard(canvasElement, board, emptyColor) {
  if (!board || typeof board !== "object") {
    return;
  }
  const rows = board.rows | 0;
  const cols = board.cols | 0;
  const data = board.data;
  if (!data || rows <= 0 || cols <= 0) {
    return;
  }
  const ctx = ensureContext(canvasElement, cols, rows);
  if (!ctx) {
    return;
  }
  const imageData = ctx.createImageData(cols, rows);
  const buffer32 = new Uint32Array(imageData.data.buffer);
  const emptyPixel = colorStringToPixel(emptyColor);
  const source = data;
  const total = rows * cols;

  for (let i = 0; i < total; i += 1) {
    const value = source[i];
    if (value) {
      buffer32[i] = argbToCanvasPixel(value);
    } else {
      buffer32[i] = emptyPixel ?? 0;
    }
  }

  ctx.putImageData(imageData, 0, 0);
}
