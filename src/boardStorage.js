import { get, set, del, keys } from "idb-keyval";
import { hexToUint32 } from "./BoardColor.js";

const BOARD_PREFIX = "boxer-board:";

const boardKey = (id) => `${BOARD_PREFIX}${id}`;

export async function saveBoard(id, board) {
  if (!id) {
    return;
  }
  await set(boardKey(id), board);
}

export async function loadBoard(id) {
  if (!id) {
    return null;
  }
  return (await get(boardKey(id))) ?? null;
}

export async function deleteBoard(id) {
  if (!id) {
    return;
  }
  await del(boardKey(id));
}

export async function loadAllBoards() {
  const entries = [];
  const allKeys = await keys();
  for (const key of allKeys) {
    if (typeof key === "string" && key.startsWith(BOARD_PREFIX)) {
      const id = key.slice(BOARD_PREFIX.length);
      const board = await get(key);
      if (board !== undefined && board !== null) {
        entries.push({ id, board });
      }
    }
  }
  return entries;
}

function fromBase36(value) {
  return parseInt(value, 36);
}

function decodeLegacyBoard(encoded) {
  if (!encoded) {
    return { rows: 0, cols: 0, data: new Uint32Array(0) };
  }

  if (
    typeof encoded.rows === "number" &&
    typeof encoded.cols === "number" &&
    encoded.data instanceof Uint32Array
  ) {
    const rows = encoded.rows | 0;
    const cols = encoded.cols | 0;
    const data = encoded.data;
    if (data.length === rows * cols) {
      return { rows, cols, data };
    }
  }

  const rows = typeof encoded.rows === "number" ? encoded.rows | 0 : 0;
  const cols = typeof encoded.cols === "number" ? encoded.cols | 0 : 0;
  const totalCells = rows * cols;
  const data = new Uint32Array(totalCells);
  const paletteSource = Array.isArray(encoded.palette) ? encoded.palette : [0];
  const palette = paletteSource.map((entry) =>
    entry === undefined || entry === null
      ? 0
      : typeof entry === "number"
      ? entry >>> 0
      : hexToUint32(entry)
  );

  let pointer = 0;
  const fillWithValue = (value, length) => {
    const boundedLength = Math.min(length, totalCells - pointer);
    for (let idx = 0; idx < boundedLength; idx += 1) {
      data[pointer + idx] = value;
    }
    pointer += boundedLength;
  };

  if (typeof encoded.runs === "string" && encoded.runs.length > 0) {
    const entries = encoded.runs.split(",");
    for (let i = 0; i < entries.length; i += 1) {
      const entry = entries[i];
      if (!entry) {
        continue;
      }
      const [indexPart, countPart] = entry.split(":");
      if (!indexPart || !countPart) {
        continue;
      }
      const paletteIndex = fromBase36(indexPart);
      const runLength = fromBase36(countPart);
      if (Number.isNaN(paletteIndex) || Number.isNaN(runLength)) {
        continue;
      }
      const value = palette[paletteIndex] ?? 0;
      fillWithValue(value, runLength);
      if (pointer >= totalCells) {
        break;
      }
    }
  }

  return { rows, cols, data };
}

export function loadLegacyBoardsFromLocalStorage() {
  if (typeof window === "undefined") {
    return [];
  }
  const rawValue = window.localStorage.getItem("canvas-boards-v1");
  if (!rawValue) {
    return [];
  }
  try {
    const parsed = JSON.parse(rawValue);
    const candidates = Array.isArray(parsed)
      ? parsed
      : Array.isArray(parsed.boards)
      ? parsed.boards
      : [];
    const entries = candidates
      .map((entry) => {
        if (!entry || typeof entry.id !== "string") {
          return null;
        }
        return {
          id: entry.id,
          board: decodeLegacyBoard(entry.board),
        };
      })
      .filter(Boolean);
    window.localStorage.removeItem("canvas-boards-v1");
    return entries;
  } catch (error) {
    console.warn(error);
    return [];
  }
}
