import React from "react";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

const storeCache = new Map();

const noopStorage = {
  getItem: () => null,
  setItem: () => {},
  removeItem: () => {},
};

const getStorage = () =>
  typeof window === "undefined" ? noopStorage : window.localStorage;

export function setLocalStoragePersistencePaused(_paused) {
  // Deferred writes are no longer used; keep API for callers.
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
        clearValue: () => set({ value: initialValue }),
      }),
      {
        name: key,
        storage: createJSONStorage(getStorage),
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

const selectValue = initialValue => state => {
  const current = state.value;
  return current === undefined ? initialValue : current;
};

export default function useLocalStorage(key, initialValue) {
  const store = getStore(key, initialValue);
  const value = store(
    React.useCallback(selectValue(initialValue), [initialValue])
  );

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
