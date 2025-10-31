export function schedule(callback) {
  if (typeof window === "undefined") {
    const id = setTimeout(() => callback(), 50);
    return {mode: "timeout", id};
  }

  if (typeof window.requestIdleCallback === "function") {
    const id = window.requestIdleCallback(() => callback());
    return {mode: "idle", id};
  }

  const id = window.setTimeout(() => callback(), 50);
  return {mode: "timeout", id};
}

export function cancel(handle) {
  if (!handle) {
    return;
  }

  if (handle.mode === "idle" && typeof window !== "undefined") {
    if (typeof window.cancelIdleCallback === "function") {
      window.cancelIdleCallback(handle.id);
      return;
    }
  }

  clearTimeout(handle.id);
}
