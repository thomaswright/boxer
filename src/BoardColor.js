function normalizeHex(hex) {
  if (typeof hex !== "string") {
    return null;
  }
  let value = hex.trim();
  if (value.startsWith("#")) {
    value = value.slice(1);
  }
  if (value.length === 3) {
    value = value
      .split("")
      .map((char) => char + char)
      .join("");
  }
  if (value.length !== 6) {
    return null;
  }
  const parsed = parseInt(value, 16);
  if (Number.isNaN(parsed)) {
    return null;
  }
  return parsed & 0xffffff;
}

export function hexToUint32(color) {
  const normalized = normalizeHex(color);
  if (normalized === null) {
    return 0;
  }
  const alpha = 0xff << 24;
  return (alpha | normalized) >>> 0;
}

export function uint32ToHex(value) {
  if (!value) {
    return null;
  }
  const rgb = value & 0xffffff;
  return `#${rgb.toString(16).padStart(6, "0").toUpperCase()}`;
}
