import React from "react";

const CANVASES_KEY = "canvases";
const CANVAS_STORAGE_VERSION = 1;
const DEFERRED_KEYS = new Set([CANVASES_KEY]);
const FLUSH_DELAY_MS = 500;
const pendingWrites = new Map();
let flushHandlersRegistered = false;

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
    if (typeof document !== "undefined" && document.visibilityState === "hidden") {
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
  window.clearTimeout(entry.timerId);
  pendingWrites.delete(key);
  try {
    window.localStorage.setItem(key, entry.serializedValue);
  } catch (error) {
    if (isQuotaExceededError(error)) {
      console.warn(`Unable to persist deferred value for "${key}" in localStorage: quota exceeded`);
    } else {
      console.warn(error);
    }
    return;
  }
  dispatchStorageEvent(key, entry.serializedValue);
}

function flushAllDeferredWrites() {
  Array.from(pendingWrites.keys()).forEach((key) => {
    flushDeferredWrite(key);
  });
}

function scheduleDeferredWrite(key, serializedValue) {
  if (typeof window === "undefined") {
    return;
  }
  ensureFlushHandlersRegistered();
  const existing = pendingWrites.get(key);
  if (existing) {
    window.clearTimeout(existing.timerId);
  }
  const timerId = window.setTimeout(() => {
    flushDeferredWrite(key);
  }, FLUSH_DELAY_MS);
  pendingWrites.set(key, { serializedValue, timerId });
  dispatchStorageEvent(key, serializedValue);
}

function toBase36(value) {
  return value.toString(36);
}

function fromBase36(value) {
  return parseInt(value, 36);
}

function encodeBoard(board) {
  if (!Array.isArray(board) || board.length === 0) {
    return { rows: 0, cols: 0, palette: [null], runs: "" };
  }

  const rows = board.length;
  const cols = Array.isArray(board[0]) ? board[0].length : 0;

  const palette = [null];
  const colorToIndex = new Map([[null, 0]]);

  const getIndex = (value) => {
    if (value === undefined || value === null) {
      return 0;
    }
    if (colorToIndex.has(value)) {
      return colorToIndex.get(value);
    }
    const nextIndex = palette.length;
    palette.push(value);
    colorToIndex.set(value, nextIndex);
    return nextIndex;
  };

  const runs = [];
  let previousIndex = -1;
  let count = 0;

  for (let row = 0; row < rows; row += 1) {
    const rowData = Array.isArray(board[row]) ? board[row] : [];
    for (let col = 0; col < cols; col += 1) {
      const cell = rowData[col];
      const index = getIndex(cell);
      if (index === previousIndex) {
        count += 1;
      } else {
        if (count > 0) {
          runs.push([previousIndex, count]);
        }
        previousIndex = index;
        count = 1;
      }
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
    return [];
  }

  if (Array.isArray(encoded)) {
    return encoded;
  }

  const rows = typeof encoded.rows === "number" ? encoded.rows : 0;
  const cols = typeof encoded.cols === "number" ? encoded.cols : 0;
  const paletteSource = Array.isArray(encoded.palette) ? encoded.palette : [null];
  const palette = paletteSource.map((entry) =>
    entry === undefined || entry === null ? null : entry
  );

  const cellCount = rows * cols;
  const flattened = new Array(cellCount);
  let pointer = 0;

  const fillWithValue = (value, length) => {
    for (let idx = 0; idx < length && pointer < cellCount; idx += 1) {
      flattened[pointer] = value;
      pointer += 1;
    }
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
      const value = palette[paletteIndex] ?? null;
      fillWithValue(value, runLength);
    }
  }

  while (pointer < cellCount) {
    flattened[pointer] = null;
    pointer += 1;
  }

  const board = [];
  for (let row = 0; row < rows; row += 1) {
    const start = row * cols;
    board.push(flattened.slice(start, start + cols));
  }

  return board;
}

function serializeCanvas(canvas) {
  if (!canvas) {
    return canvas;
  }
  const zoomValue = typeof canvas.zoom === "number" ? canvas.zoom : 1;
  const panValue =
    Array.isArray(canvas.pan) && canvas.pan.length === 2
      ? [Number(canvas.pan[0]) || 0, Number(canvas.pan[1]) || 0]
      : [0, 0];
  const boardValue = encodeBoard(canvas.board);
  return {
    id: canvas.id,
    zoom: zoomValue,
    pan: panValue,
    board: boardValue,
  };
}

function deserializeCanvas(entry) {
  if (!entry) {
    return null;
  }

  const { id, zoom, pan } = entry;
  const board = decodeBoard(entry.board);

  return {
    id,
    zoom: typeof zoom === "number" ? zoom : 1,
    pan: Array.isArray(pan) && pan.length === 2 ? pan : [0, 0],
    board,
  };
}

function serializeCanvases(canvases) {
  const payload = Array.isArray(canvases)
    ? canvases.map(serializeCanvas)
    : [];
  return JSON.stringify({
    version: CANVAS_STORAGE_VERSION,
    canvases: payload,
  });
}

function deserializeCanvases(rawValue, fallback) {
  try {
    const parsed = JSON.parse(rawValue);

    if (Array.isArray(parsed)) {
      return parsed;
    }

    if (
      parsed &&
      Array.isArray(parsed.canvases)
    ) {
      return parsed.canvases
        .map(deserializeCanvas)
        .filter(Boolean);
    }

    return fallback;
  } catch (error) {
    console.warn(error);
    return fallback;
  }
}

function serializeForKey(key, value) {
  if (key === CANVASES_KEY) {
    return serializeCanvases(value);
  }
  return JSON.stringify(value);
}

function deserializeForKey(key, rawValue, fallback) {
  if (rawValue === null || rawValue === undefined) {
    return fallback;
  }

  if (key === CANVASES_KEY) {
    return deserializeCanvases(rawValue, fallback);
  }

  try {
    return JSON.parse(rawValue);
  } catch (error) {
    console.warn(error);
    return fallback;
  }
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
  const serializedValue = serializeForKey(key, value);
  if (shouldDeferPersistence(key)) {
    scheduleDeferredWrite(key, serializedValue);
  } else if (typeof window !== "undefined") {
    window.localStorage.setItem(key, serializedValue);
    dispatchStorageEvent(key, serializedValue);
  }
};

const removeLocalStorageItem = (key) => {
  const pending = getPendingEntry(key);
  if (pending && typeof window !== "undefined") {
    window.clearTimeout(pending.timerId);
    pendingWrites.delete(key);
  }
  if (typeof window !== "undefined") {
    window.localStorage.removeItem(key);
  }
  dispatchStorageEvent(key, null);
};

const getLocalStorageItem = (key) => {
  const pending = getPendingEntry(key);
  if (pending) {
    return pending.serializedValue;
  }
  if (typeof window === "undefined") {
    return null;
  }
  return window.localStorage.getItem(key);
};

const useLocalStorageSubscribe = (callback) => {
  window.addEventListener("storage", callback);
  return () => window.removeEventListener("storage", callback);
};

const getLocalStorageServerSnapshot = () => {
  throw Error("useLocalStorage is a client-only hook");
};

export default function useLocalStorage(key, initialValue) {
  const getSnapshot = React.useCallback(() => getLocalStorageItem(key), [key]);

  const getCurrentValue = React.useCallback(() => {
    const raw = getLocalStorageItem(key);
    if (raw === null || raw === undefined) {
      return initialValue;
    }
    return deserializeForKey(key, raw, initialValue);
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
    return deserializeForKey(key, store, initialValue);
  }, [store, key, initialValue]);

  const setState = React.useCallback(
    (updater) => {
      const rawPrevious = getSnapshot();
      const previousValue =
        rawPrevious === null || rawPrevious === undefined
          ? initialValue
          : deserializeForKey(key, rawPrevious, initialValue);

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
    if (
      getLocalStorageItem(key) === null &&
      typeof initialValue !== "undefined"
    ) {
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
  const getSnapshot = React.useCallback(() => getLocalStorageItem(key), [key]);

  const store = React.useSyncExternalStore(
    useLocalStorageSubscribe,
    getSnapshot,
    getLocalStorageServerSnapshot
  );

  const currentValue = React.useMemo(() => {
    if (store === null || store === undefined) {
      return defaultValue;
    }
    return deserializeForKey(key, store, defaultValue);
  }, [store, key, defaultValue]);

  return currentValue;
}
