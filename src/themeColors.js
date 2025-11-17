import { convert, OKLCH, sRGB, RGBToHex } from "@texel/color";

const OKLCH_REGEX = /oklch\(\s*([\d.]+)%\s+([\d.]+)\s+([\d.]+)\s*\)/i;
const VAR_REGEX = /^var\(\s*([^,\s)]+)\s*(?:,\s*([^)]+))?\)$/i;

function getRootComputedStyle() {
  if (typeof document === "undefined") {
    return null;
  }
  const root = document.documentElement;
  if (!root) {
    return null;
  }
  return getComputedStyle(root);
}

function readCssVar(varName) {
  if (!varName) {
    return null;
  }
  const style = getRootComputedStyle();
  if (!style) {
    return null;
  }
  return style.getPropertyValue(varName);
}

function oklchTokenToHex(token) {
  if (!token) {
    return null;
  }
  const match = token.match(OKLCH_REGEX);
  if (!match) {
    return null;
  }
  const l = parseFloat(match[1]);
  const c = parseFloat(match[2]);
  const h = parseFloat(match[3]);
  if (Number.isNaN(l) || Number.isNaN(c) || Number.isNaN(h)) {
    return null;
  }
  const rgb = convert([l / 100, c, h], OKLCH, sRGB);
  return RGBToHex(rgb);
}

function cssColorTokenToHex(token) {
  if (typeof token !== "string") {
    return null;
  }
  const trimmed = token.trim();
  if (!trimmed) {
    return null;
  }
  if (trimmed.startsWith("#")) {
    return trimmed;
  }
  return oklchTokenToHex(trimmed);
}

export function resolveThemeColor(input) {
  if (typeof input !== "string") {
    return null;
  }
  const trimmed = input.trim();
  if (!trimmed) {
    return null;
  }
  if (trimmed.startsWith("#")) {
    return trimmed;
  }
  const varMatch = trimmed.match(VAR_REGEX);
  if (varMatch) {
    const varName = varMatch[1].trim();
    const fallback = varMatch[2]?.trim();
    return (
      cssColorTokenToHex(readCssVar(varName)) ??
      (fallback ? cssColorTokenToHex(fallback) : null)
    );
  }
  if (trimmed.startsWith("--")) {
    return cssColorTokenToHex(readCssVar(trimmed));
  }
  return cssColorTokenToHex(trimmed);
}
