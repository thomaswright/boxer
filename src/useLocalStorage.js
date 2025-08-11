import React from "react";

function dispatchStorageEvent(key, newValue) {
  window.dispatchEvent(new StorageEvent("storage", { key, newValue }));
}

const setLocalStorageItem = (key, value) => {
  const stringifiedValue = JSON.stringify(value);
  window.localStorage.setItem(key, stringifiedValue);
  dispatchStorageEvent(key, stringifiedValue);
};

const removeLocalStorageItem = (key) => {
  window.localStorage.removeItem(key);
  dispatchStorageEvent(key, null);
};

const getLocalStorageItem = (key) => {
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
    let val = getLocalStorageItem(key);

    if (Boolean(val)) {
      return JSON.parse(val);
    } else {
      return initialValue;
    }
  }, [key]);

  const store = React.useSyncExternalStore(
    useLocalStorageSubscribe,
    getSnapshot,
    getLocalStorageServerSnapshot
  );

  const currentValue = React.useMemo(() => {
    return store ? JSON.parse(store) : initialValue;
  }, [store, initialValue]);

  const setState = React.useCallback(
    (v) => {
      try {
        const nextState =
          typeof v === "function" ? v(JSON.parse(getSnapshot())) : v;

        if (nextState === undefined || nextState === null) {
          removeLocalStorageItem(key);
        } else {
          setLocalStorageItem(key, nextState);
        }
      } catch (e) {
        console.warn(e);
      }
    },
    [key, getSnapshot]
  );

  React.useEffect(() => {
    if (
      getLocalStorageItem(key) === null &&
      typeof initialValue !== "undefined"
    ) {
      setLocalStorageItem(key, initialValue);
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
    return store ? JSON.parse(store) : defaultValue;
  }, [store, defaultValue]);

  return currentValue;
}
