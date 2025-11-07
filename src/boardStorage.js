import { get, set, del, keys } from "idb-keyval";

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
