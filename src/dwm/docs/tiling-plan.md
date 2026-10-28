# Directional tiling changes

User requirements: 10px inner horizontal/vertical and all outer gaps; default 50/50 master/right stack; append new clients without replacing master, and focus new windows. H/J/K/L focus left/down/up/right, Shift variants move by swapping the spatial neighbor; minus/equal shrink/grow the focused window. Preserve 1–9 workspaces, Shift+1–9 move, and Tab back-and-forth.

Implementation: attach new windows to the end while retaining head insertion for explicit zoom; spatial nearest-neighbor selection with perpendicular overlap preferred; per-client height weights for stack resizing and master factor for single-window-column resizing. Fixed dialogs/notification behavior remains scoped to existing floating rules.

Verification: tests compile the actual production C geometry/list/navigation functions with only X drawing replaced by recording stubs. Cover 50/50/gaps, stable insertion, adjacent/nonadjacent swaps, hidden/floating exclusions, resize directions and uneven vertical weights. Build the actual binary and verify with owned test windows before activating the final configuration.
