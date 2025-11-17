let segmentButton = (~isActive) =>
  "flex-1 text-xs font-medium px-1 py-1  border transition-colors " ++ if isActive {
    "bg-[var(--accent)] text-[var(--plain-white)] border-[var(--accent)]"
  } else {
    "bg-[var(--plain-white)] text-[var(--plain-800)] border-[var(--plain-200)] hover:border-[var(--plain-400)]"
  }
