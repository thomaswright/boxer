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

const HEX_DIGITS = "0123456789ABCDEF";
const HEX_TABLE = Array.from({ length: 256 }, (_, value) => {
  const hi = HEX_DIGITS[(value >>> 4) & 0xf];
  const lo = HEX_DIGITS[value & 0xf];
  return hi + lo;
});

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
  const r = (rgb >>> 16) & 0xff;
  const g = (rgb >>> 8) & 0xff;
  const b = rgb & 0xff;
  return `#${HEX_TABLE[r]}${HEX_TABLE[g]}${HEX_TABLE[b]}`;
}
