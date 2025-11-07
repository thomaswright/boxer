import React from "react";
import { hexToUint32 } from "./BoardColor.js";
import { canvasBackgroundColor as defaultCanvasBackgroundColor } from "./Initials.res.mjs";

const CANVAS_METADATA_KEY = "canvas-metadata-v1";
const CANVAS_METADATA_VERSION = 1;
const CANVAS_BOARDS_KEY = "canvas-boards-v1";
const CANVAS_BOARDS_VERSION = 1;
const DEFERRED_KEYS = new Set([CANVAS_BOARDS_KEY]);
const FLUSH_DELAY_MS = 500;
const pendingWrites = new Map();
const SNAPSHOT_SOURCE_MEMORY = "memory";
const SNAPSHOT_SOURCE_STORAGE = "storage";
const snapshotCache = new Map();
let flushHandlersRegistered = false;
let persistencePaused = false;
let listenersAttached = false;

function createSnapshot(source, serializedValue, value) {
  return { source, serialized: serializedValue, value };
}

function cacheSnapshot(key, snapshot) {
  const previous = snapshotCache.get(key);
  if (
    previous &&
    previous.source === snapshot.source &&
    previous.serialized === snapshot.serialized &&
    previous.value === snapshot.value
  ) {
    return previous;
  }
  snapshotCache.set(key, snapshot);
  return snapshot;
}

function isTypedBoard(board) {
  return (
    board &&
    typeof board === "object" &&
    Number.isInteger(board.rows) &&
    Number.isInteger(board.cols) &&
    board.data instanceof Uint32Array
  );
}

function ensureTypedBoard(board) {
  if (isTypedBoard(board)) {
    return {
      rows: board.rows | 0,
      cols: board.cols | 0,
      data: board.data,
    };
  }

  if (!Array.isArray(board)) {
    return { rows: 0, cols: 0, data: new Uint32Array(0) };
  }

  const rows = board.length;
  const cols = rows > 0 && Array.isArray(board[0]) ? board[0].length : 0;
  const data = new Uint32Array(rows * cols);
  for (let row = 0; row < rows; row += 1) {
    const rowData = Array.isArray(board[row]) ? board[row] : [];
    for (let col = 0; col < cols; col += 1) {
      const cell = rowData[col];
      if (cell != null) {
        data[row * cols + col] = hexToUint32(cell);
      }
    }
  }

  return { rows, cols, data };
}

function dispatchStorageEvent(key, newValue) {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(new StorageEvent("storage", { key, newValue }));
}

function shouldDeferPersistence(key) {
  return DEFERRED_KEYS.has(key);
}

function getPendingEntry(key) {
  return pendingWrites.get(key);
}

function ensureFlushHandlersRegistered() {
  if (flushHandlersRegistered || typeof window === "undefined") {
    return;
  }
  const handleBeforeUnload = () => {
    flushAllDeferredWrites();
  };
  const handleVisibilityChange = () => {
    if (
      typeof document !== "undefined" &&
      document.visibilityState === "hidden"
    ) {
      flushAllDeferredWrites();
    }
  };
  window.addEventListener("beforeunload", handleBeforeUnload);
  window.addEventListener("visibilitychange", handleVisibilityChange);
  flushHandlersRegistered = true;
}

function flushDeferredWrite(key) {
  const entry = pendingWrites.get(key);
  if (!entry || typeof window === "undefined") {
    return;
  }
  if (entry.timerId != null) {
    window.clearTimeout(entry.timerId);
  }
  pendingWrites.delete(key);
  const serializedValue =
    entry.serializedValue != null ? entry.serializedValue : entry.serialize();
  try {
    window.localStorage.setItem(key, serializedValue);
  } catch (error) {
    if (isQuotaExceededError(error)) {
      console.warn(
        `Unable to persist deferred value for "${key}" in localStorage: quota exceeded`
      );
    } else {
      console.warn(error);
    }
    return;
  }
  dispatchStorageEvent(key, serializedValue);
}

function flushAllDeferredWrites() {
  Array.from(pendingWrites.keys()).forEach((key) => {
    flushDeferredWrite(key);
  });
}

function ensurePersistenceListeners() {
  if (listenersAttached || typeof window === "undefined") {
    return;
  }
  const captureOptions = { capture: true };
  const pause = () => setLocalStoragePersistencePaused(true);
  const resume = () => setLocalStoragePersistencePaused(false);
  window.addEventListener("pointerdown", pause, captureOptions);
  window.addEventListener("pointerup", resume, captureOptions);
  window.addEventListener("pointercancel", resume, captureOptions);
  window.addEventListener("mousedown", pause, captureOptions);
  window.addEventListener("mouseup", resume, captureOptions);
  window.addEventListener("blur", resume, captureOptions);
  listenersAttached = true;
}

function scheduleDeferredWrite(key, value, serialize) {
  if (typeof window === "undefined") {
    return;
  }
  ensurePersistenceListeners();
  ensureFlushHandlersRegistered();
  const existing = pendingWrites.get(key);
  if (existing) {
    if (existing.timerId != null) {
      window.clearTimeout(existing.timerId);
    }
  }
  if (persistencePaused) {
    pendingWrites.set(key, {
      value,
      serialize,
      serializedValue: null,
      timerId: null,
    });
    dispatchStorageEvent(key, null);
    return;
  }
  const serializedValue = serialize();
  const timerId = window.setTimeout(() => {
    flushDeferredWrite(key);
  }, FLUSH_DELAY_MS);
  pendingWrites.set(key, { value, serialize, serializedValue, timerId });
  dispatchStorageEvent(key, serializedValue);
}

function toBase36(value) {
  return value.toString(36);
}

function fromBase36(value) {
  return parseInt(value, 36);
}

function encodeBoard(board) {
  const typed = ensureTypedBoard(board);
  const rows = typed.rows | 0;
  const cols = typed.cols | 0;

  if (rows === 0 || cols === 0) {
    return { rows: 0, cols: 0, palette: [0], runs: "" };
  }

  const palette = [0];
  const colorToIndex = new Map();

  const runs = [];
  let previousIndex = -1;
  let count = 0;

  const totalCells = rows * cols;
  const data = typed.data;

  for (let idx = 0; idx < totalCells; idx += 1) {
    const value = data[idx] >>> 0;
    let paletteIndex = 0;
    if (value !== 0) {
      if (colorToIndex.has(value)) {
        paletteIndex = colorToIndex.get(value);
      } else {
        paletteIndex = palette.length;
        palette.push(value);
        colorToIndex.set(value, paletteIndex);
      }
    }

    if (paletteIndex === previousIndex) {
      count += 1;
    } else {
      if (count > 0) {
        runs.push([previousIndex, count]);
      }
      previousIndex = paletteIndex;
      count = 1;
    }
  }

  if (count > 0 && previousIndex !== -1) {
    runs.push([previousIndex, count]);
  }

  const runString = runs
    .map(([index, length]) => `${toBase36(index)}:${toBase36(length)}`)
    .join(",");

  return {
    rows,
    cols,
    palette,
    runs: runString,
  };
}

function decodeBoard(encoded) {
  if (!encoded) {
    return { rows: 0, cols: 0, data: new Uint32Array(0) };
  }

  if (isTypedBoard(encoded)) {
    const rows = Math.max(0, encoded.rows | 0);
    const cols = Math.max(0, encoded.cols | 0);
    const source = encoded.data;
    const data =
      source instanceof Uint32Array ? source : new Uint32Array(source ?? []);
    if (data.length === rows * cols) {
      return { rows, cols, data };
    }
    const copy = new Uint32Array(rows * cols);
    const minLength = Math.min(copy.length, data.length);
    copy.set(data.subarray(0, minLength));
    return { rows, cols, data: copy };
  }

  if (Array.isArray(encoded)) {
    return ensureTypedBoard(encoded);
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

function serializeCanvasMetadata(canvas) {
  if (!canvas) {
    return canvas;
  }
  const zoomValue = typeof canvas.zoom === "number" ? canvas.zoom : 1;
  const panValue =
    Array.isArray(canvas.pan) && canvas.pan.length === 2
      ? [Number(canvas.pan[0]) || 0, Number(canvas.pan[1]) || 0]
      : [0, 0];
  const isDotMaskValue =
    typeof canvas.isDotMask === "boolean" ? canvas.isDotMask : false;
  const canvasBackgroundColorValue =
    typeof canvas.canvasBackgroundColor === "string"
      ? canvas.canvasBackgroundColor
      : defaultCanvasBackgroundColor;
  return {
    id: canvas.id,
    zoom: zoomValue,
    pan: panValue,
    isDotMask: isDotMaskValue,
    canvasBackgroundColor: canvasBackgroundColorValue,
  };
}

function deserializeCanvasMetadata(entry) {
  if (!entry) {
    return null;
  }

  const { id, zoom, pan } = entry;
  const isDotMask =
    typeof entry.isDotMask === "boolean"
      ? entry.isDotMask
      : entry.isDotMask === 1
      ? true
      : false;
  const canvasBackgroundColor =
    typeof entry.canvasBackgroundColor === "string"
      ? entry.canvasBackgroundColor
      : defaultCanvasBackgroundColor;

  return {
    id,
    zoom: typeof zoom === "number" ? zoom : 1,
    pan: Array.isArray(pan) && pan.length === 2 ? pan : [0, 0],
    isDotMask,
    canvasBackgroundColor,
  };
}

function serializeCanvasMetadatas(canvases) {
  const payload = Array.isArray(canvases)
    ? canvases.map(serializeCanvasMetadata)
    : [];
  return JSON.stringify({
    version: CANVAS_METADATA_VERSION,
    canvases: payload,
  });
}

function normalizeCanvasMetadataPayload(rawValue, fallback) {
  if (Array.isArray(rawValue)) {
    return rawValue.map(deserializeCanvasMetadata).filter(Boolean);
  }
  if (
    rawValue &&
    typeof rawValue === "object" &&
    Array.isArray(rawValue.canvases)
  ) {
    return rawValue.canvases.map(deserializeCanvasMetadata).filter(Boolean);
  }
  return fallback;
}

function deserializeCanvasMetadatasSerialized(serializedValue, fallback) {
  if (typeof serializedValue !== "string") {
    return fallback;
  }
  try {
    const parsed = JSON.parse(serializedValue);
    return normalizeCanvasMetadataPayload(parsed, fallback);
  } catch (error) {
    console.warn(error);
    return fallback;
  }
}

function serializeCanvasBoardEntry(entry) {
  if (!entry || typeof entry.id !== "string") {
    return null;
  }
  return {
    id: entry.id,
    board: encodeBoard(entry.board),
  };
}

function deserializeCanvasBoardEntry(entry) {
  if (!entry || typeof entry.id !== "string") {
    return null;
  }
  return {
    id: entry.id,
    board: decodeBoard(entry.board),
  };
}

function serializeCanvasBoards(entries) {
  const payload = Array.isArray(entries)
    ? entries.map(serializeCanvasBoardEntry).filter(Boolean)
    : [];
  return JSON.stringify({
    version: CANVAS_BOARDS_VERSION,
    boards: payload,
  });
}

function normalizeCanvasBoardsPayload(rawValue, fallback) {
  if (Array.isArray(rawValue)) {
    return rawValue.map(deserializeCanvasBoardEntry).filter(Boolean);
  }
  if (rawValue && typeof rawValue === "object" && Array.isArray(rawValue.boards)) {
    return rawValue.boards.map(deserializeCanvasBoardEntry).filter(Boolean);
  }
  return fallback;
}

function deserializeCanvasBoardsSerialized(serializedValue, fallback) {
  if (typeof serializedValue !== "string") {
    return fallback;
  }
  try {
    const parsed = JSON.parse(serializedValue);
    return normalizeCanvasBoardsPayload(parsed, fallback);
  } catch (error) {
    console.warn(error);
    return fallback;
  }
}

function serializeForKey(key, value) {
  if (key === CANVAS_METADATA_KEY) {
    return serializeCanvasMetadatas(value);
  }
  if (key === CANVAS_BOARDS_KEY) {
    return serializeCanvasBoards(value);
  }
  return JSON.stringify(value);
}

function deserializeStoredValue(key, serializedValue, fallback) {
  if (serializedValue === null || serializedValue === undefined) {
    return fallback;
  }

  if (key === CANVAS_METADATA_KEY) {
    return deserializeCanvasMetadatasSerialized(serializedValue, fallback);
  }

  if (key === CANVAS_BOARDS_KEY) {
    return deserializeCanvasBoardsSerialized(serializedValue, fallback);
  }

  if (typeof serializedValue !== "string") {
    return fallback;
  }

  try {
    return JSON.parse(serializedValue);
  } catch (error) {
    console.warn(error);
    return fallback;
  }
}

function resolveSnapshotValue(key, snapshot, fallback) {
  if (!snapshot) {
    return fallback;
  }
  if (
    snapshot.source === SNAPSHOT_SOURCE_MEMORY &&
    snapshot.value !== undefined
  ) {
    return snapshot.value;
  }
  return deserializeStoredValue(key, snapshot.serialized, fallback);
}

function snapshotHasPersistedValue(snapshot) {
  if (!snapshot) {
    return false;
  }
  if (snapshot.source === SNAPSHOT_SOURCE_MEMORY) {
    return true;
  }
  return snapshot.serialized !== null && snapshot.serialized !== undefined;
}

function isQuotaExceededError(error) {
  if (!(error instanceof DOMException)) {
    return false;
  }
  return (
    error.code === 22 ||
    error.code === 1014 ||
    error.name === "QuotaExceededError" ||
    error.name === "NS_ERROR_DOM_QUOTA_REACHED"
  );
}

const setLocalStorageItem = (key, value) => {
  if (shouldDeferPersistence(key)) {
    scheduleDeferredWrite(key, value, () => serializeForKey(key, value));
    return;
  }
  const serializedValue = serializeForKey(key, value);
  if (typeof window !== "undefined") {
    window.localStorage.setItem(key, serializedValue);
    dispatchStorageEvent(key, serializedValue);
  }
};

const removeLocalStorageItem = (key) => {
  const pending = getPendingEntry(key);
  if (pending && typeof window !== "undefined") {
    if (pending.timerId != null) {
      window.clearTimeout(pending.timerId);
    }
    pendingWrites.delete(key);
  }
  if (typeof window !== "undefined") {
    window.localStorage.removeItem(key);
  }
  dispatchStorageEvent(key, null);
};

const getLocalStorageSnapshot = (key) => {
  const pending = getPendingEntry(key);
  if (pending) {
    if (pending.serializedValue == null) {
      pending.serializedValue = pending.serialize();
    }
    return cacheSnapshot(
      key,
      createSnapshot(SNAPSHOT_SOURCE_MEMORY, pending.serializedValue, pending.value)
    );
  }
  const serialized =
    typeof window === "undefined" ? null : window.localStorage.getItem(key);
  return cacheSnapshot(
    key,
    createSnapshot(SNAPSHOT_SOURCE_STORAGE, serialized, null)
  );
};

const useLocalStorageSubscribe = (callback) => {
  window.addEventListener("storage", callback);
  return () => window.removeEventListener("storage", callback);
};

const getLocalStorageServerSnapshot = () => {
  throw Error("useLocalStorage is a client-only hook");
};

if (typeof window !== "undefined") {
  ensurePersistenceListeners();
}

export function setLocalStoragePersistencePaused(paused) {
  if (persistencePaused === paused) {
    return;
  }
  persistencePaused = paused;
  if (paused) {
    if (typeof window !== "undefined") {
      pendingWrites.forEach((entry) => {
        if (entry && entry.timerId != null) {
          window.clearTimeout(entry.timerId);
          entry.timerId = null;
        }
      });
    }
  } else {
    flushAllDeferredWrites();
  }
}

export default function useLocalStorage(key, initialValue) {
  const getSnapshot = React.useCallback(() => getLocalStorageSnapshot(key), [key]);

  const getCurrentValue = React.useCallback(() => {
    const snapshot = getLocalStorageSnapshot(key);
    return resolveSnapshotValue(key, snapshot, initialValue);
  }, [key, initialValue]);

  const store = React.useSyncExternalStore(
    useLocalStorageSubscribe,
    getSnapshot,
    getLocalStorageServerSnapshot
  );

  const currentValue = React.useMemo(() => {
    if (store === null || store === undefined) {
      return initialValue;
    }
    return resolveSnapshotValue(key, store, initialValue);
  }, [store, key, initialValue]);

  const setState = React.useCallback(
    (updater) => {
      const previousSnapshot = getSnapshot();
      const previousValue = resolveSnapshotValue(key, previousSnapshot, initialValue);

      const nextState =
        typeof updater === "function" ? updater(previousValue) : updater;

      if (nextState === undefined || nextState === null) {
        removeLocalStorageItem(key);
        return;
      }

      try {
        setLocalStorageItem(key, nextState);
      } catch (error) {
        if (isQuotaExceededError(error)) {
          console.warn(
            `Unable to persist "${key}" in localStorage: quota exceeded`
          );
        } else {
          console.warn(error);
        }
      }
    },
    [key, getSnapshot, initialValue]
  );

  React.useEffect(() => {
    const snapshot = getLocalStorageSnapshot(key);
    if (!snapshotHasPersistedValue(snapshot) && typeof initialValue !== "undefined") {
      try {
        setLocalStorageItem(key, initialValue);
      } catch (error) {
        if (isQuotaExceededError(error)) {
          console.warn(
            `Unable to persist initial value for "${key}" in localStorage: quota exceeded`
          );
        } else {
          console.warn(error);
        }
      }
    }
  }, [key, initialValue]);

  return [currentValue, setState, getCurrentValue];
}

export function useLocalStorageListener(key, defaultValue) {
  const getSnapshot = React.useCallback(() => getLocalStorageSnapshot(key), [key]);

  const store = React.useSyncExternalStore(
    useLocalStorageSubscribe,
    getSnapshot,
    getLocalStorageServerSnapshot
  );

  const currentValue = React.useMemo(() => {
    if (store === null || store === undefined) {
      return defaultValue;
    }
    return resolveSnapshotValue(key, store, defaultValue);
  }, [store, key, defaultValue]);

  return currentValue;
}
