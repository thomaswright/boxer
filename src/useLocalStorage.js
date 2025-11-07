import React from "react";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

const FLUSH_DELAY_MS = 500;
const pendingWrites = new Map();
let persistencePaused = false;
let listenersAttached = false;
let flushHandlersRegistered = false;
const storeCache = new Map();

function dispatchStorageEvent(key, newValue) {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(new StorageEvent("storage", { key, newValue }));
}

function cancelDeferredWrite(key) {
  const entry = pendingWrites.get(key);
  if (!entry) {
    return;
  }
  if (entry.timerId != null && typeof window !== "undefined") {
    window.clearTimeout(entry.timerId);
  }
  pendingWrites.delete(key);
}

function flushDeferredWrite(key) {
  const entry = pendingWrites.get(key);
  if (!entry || typeof window === "undefined") {
    return;
  }
  try {
    window.localStorage.setItem(key, entry.value);
    dispatchStorageEvent(key, entry.value);
  } catch (error) {
    console.warn(error);
  }
  pendingWrites.delete(key);
}

function flushAllDeferredWrites() {
  if (typeof window === "undefined") {
    return;
  }
  Array.from(pendingWrites.keys()).forEach(key => {
    flushDeferredWrite(key);
  });
}

function scheduleDeferredWrite(key, value) {
  if (typeof window === "undefined") {
    return value;
  }
  const existing = pendingWrites.get(key);
  if (existing && existing.timerId != null) {
    window.clearTimeout(existing.timerId);
  }
  const entry = { value, timerId: null };
  if (persistencePaused) {
    pendingWrites.set(key, entry);
    return value;
  }
  entry.timerId = window.setTimeout(() => flushDeferredWrite(key), FLUSH_DELAY_MS);
  pendingWrites.set(key, entry);
  return value;
}

const deferredStorage = {
  getItem: name => {
    const pending = pendingWrites.get(name);
    if (pending) {
      return pending.value;
    }
    if (typeof window === "undefined") {
      return null;
    }
    return window.localStorage.getItem(name);
  },
  setItem: (name, value) => scheduleDeferredWrite(name, value),
  removeItem: name => {
    cancelDeferredWrite(name);
    if (typeof window !== "undefined") {
      window.localStorage.removeItem(name);
      dispatchStorageEvent(name, null);
    }
  },
};

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
  if (typeof document !== "undefined") {
    document.addEventListener("visibilitychange", handleVisibilityChange);
  }
  flushHandlersRegistered = true;
}

if (typeof window !== "undefined") {
  ensurePersistenceListeners();
  ensureFlushHandlersRegistered();
}

export function setLocalStoragePersistencePaused(paused) {
  if (persistencePaused === paused) {
    return;
  }
  persistencePaused = paused;
  if (paused) {
    if (typeof window !== "undefined") {
      pendingWrites.forEach(entry => {
        if (entry.timerId != null) {
          window.clearTimeout(entry.timerId);
          entry.timerId = null;
        }
      });
    }
  } else {
    flushAllDeferredWrites();
  }
}

function createStoreForKey(key, initialValue) {
  return create(
    persist(
      (set, get) => ({
        value: initialValue,
        setValue: updater =>
          set(state => {
            const previous =
              state.value === undefined ? initialValue : state.value;
            const nextValue =
              typeof updater === "function" ? updater(previous) : updater;
            return { value: nextValue };
          }),
        getValue: () => {
          const current = get().value;
          return current === undefined ? initialValue : current;
        },
        clearValue: () => {
          deferredStorage.removeItem(key);
          set({ value: initialValue });
        },
      }),
      {
        name: key,
        storage: createJSONStorage(() => deferredStorage),
      }
    )
  );
}

function getStore(key, initialValue) {
  if (storeCache.has(key)) {
    return storeCache.get(key);
  }
  const store = createStoreForKey(key, initialValue);
  storeCache.set(key, store);
  return store;
}

const selectValue = (initialValue) => state => {
  const current = state.value;
  return current === undefined ? initialValue : current;
};

export default function useLocalStorage(key, initialValue) {
  const store = getStore(key, initialValue);
  const value = store(React.useCallback(selectValue(initialValue), [initialValue]));

  const setState = React.useCallback(
    updater => {
      if (updater === undefined || updater === null) {
        store.getState().clearValue();
        return;
      }
      store.getState().setValue(updater);
    },
    [store]
  );

  const getCurrentValue = React.useCallback(
    () => store.getState().getValue(),
    [store]
  );

  return [value, setState, getCurrentValue];
}

export function useLocalStorageListener(key, defaultValue) {
  const store = getStore(key, defaultValue);
  return store(React.useCallback(selectValue(defaultValue), [defaultValue]));
}
