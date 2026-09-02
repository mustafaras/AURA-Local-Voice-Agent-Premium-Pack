#!/usr/bin/env python3
"""Render the AURA knowledge graph as a high-density force-directed network.

Computes a ForceAtlas2-style layout over the full graph in numpy (Barnes-Hut
replaced by a grid centre-of-mass approximation, so no scipy dependency), then
emits a self-contained HTML file that draws it on a canvas with additive
blending. The density is the point: ~35k translucent edges compose into a
fabric, and high-degree hubs bloom where many edges converge.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "graphify-out" / "graph.json"
OUT = ROOT / "graphify-out" / "network.html"

ITERATIONS = 320
GRID = 48
SEED = 7

# Warm-dominant palette; hubs bloom toward gold under additive blending. The
# cool entries are deliberately in the minority -- they read as accents against
# the warm fabric rather than splitting it into two competing colour fields.
PALETTE = [
    "#ff9e64", "#ffa07a", "#f7768e", "#e0af68", "#ffc777",
    "#ff7a93", "#ffb86c", "#ffd7a0", "#e8956b", "#ff8f70",
    "#7aa2f7", "#7dcfff", "#73daca", "#bb9af7", "#c0caf5",
]


def load_graph() -> tuple[list[dict], list[dict]]:
    data = json.loads(GRAPH.read_text(encoding="utf-8"))
    return data.get("nodes", []), data.get("links", [])


def forceatlas2(
    n: int, src: np.ndarray, dst: np.ndarray, mass: np.ndarray
) -> np.ndarray:
    """Grid-approximated ForceAtlas2. Repulsion is computed against per-cell
    centres of mass rather than pairwise, which is what makes 13.5k nodes
    tractable without scipy."""
    rng = np.random.default_rng(SEED)
    pos = rng.normal(0.0, 1.0, (n, 2)) * 40.0

    # Standard ForceAtlas2 balance: unit-coefficient attraction, mass-product
    # repulsion, weak gravity. Gravity only has to stop drift, not compete
    # with attraction -- turn it up and every cluster dissolves into one disk.
    k_attract = 1.0
    k_repel = 1.0
    k_gravity = 0.12

    for it in range(ITERATIONS):
        cool = 1.0 - (it / ITERATIONS) * 0.85
        disp = np.zeros((n, 2), dtype=np.float64)

        # Attraction along edges, scaled down on heavy nodes so hubs stay put
        # and their neighbours orbit them instead of collapsing inward.
        delta = pos[dst] - pos[src]
        pull = delta * k_attract
        np.add.at(disp, src, pull / mass[src, None])
        np.add.at(disp, dst, -pull / mass[dst, None])

        # Central gravity. Without it, isolates and disconnected components
        # feel only repulsion and drift to infinity, which flattens the core
        # to a dot once the result is normalised.
        radial = np.linalg.norm(pos, axis=1, keepdims=True)
        disp -= (pos / np.maximum(radial, 1e-9)) * (k_gravity * mass[:, None])

        # Repulsion against grid cell centres of mass.
        lo = pos.min(axis=0)
        span = np.maximum(pos.max(axis=0) - lo, 1e-6)
        cell = ((pos - lo) / span * (GRID - 1)).astype(np.int32)
        flat = cell[:, 0] * GRID + cell[:, 1]

        cell_mass = np.bincount(flat, weights=mass, minlength=GRID * GRID)
        cell_x = np.bincount(flat, weights=pos[:, 0] * mass, minlength=GRID * GRID)
        cell_y = np.bincount(flat, weights=pos[:, 1] * mass, minlength=GRID * GRID)
        live = np.nonzero(cell_mass > 0)[0]
        com = np.stack(
            [cell_x[live] / cell_mass[live], cell_y[live] / cell_mass[live]], axis=1
        )
        com_mass = cell_mass[live]

        # Chunked so the node x cell matrix never materialises all at once.
        step = 512
        for start in range(0, n, step):
            end = min(start + step, n)
            diff = pos[start:end, None, :] - com[None, :, :]
            dist2 = np.einsum("ijk,ijk->ij", diff, diff) + 0.01
            scale = (k_repel * mass[start:end, None] * com_mass[None, :]) / dist2
            disp[start:end] += np.einsum("ij,ijk->ik", scale, diff)

        # Clamp per-node step so a single hub cannot slingshot across the plane.
        length = np.linalg.norm(disp, axis=1, keepdims=True)
        limit = 12.0 * cool
        disp = np.where(length > limit, disp / np.maximum(length, 1e-9) * limit, disp)
        pos += disp

        if it % 40 == 0:
            print(f"  layout iteration {it}/{ITERATIONS}")

    return pos


def main() -> None:
    nodes, links = load_graph()
    index = {node["id"]: i for i, node in enumerate(nodes)}
    n = len(nodes)

    pairs = [
        (index[l["source"]], index[l["target"]])
        for l in links
        if l["source"] in index and l["target"] in index
    ]
    src = np.array([p[0] for p in pairs], dtype=np.int64)
    dst = np.array([p[1] for p in pairs], dtype=np.int64)

    degree = np.bincount(np.concatenate([src, dst]), minlength=n).astype(np.float64)
    mass = degree + 1.0

    print(f"Laying out {n:,} nodes and {len(pairs):,} edges...")
    pos = forceatlas2(n, src, dst, mass)

    # Normalise into a 0..1000 square. Percentile bounds rather than min/max so
    # a handful of far-flung isolates cannot squash the core into a dot; the
    # few nodes outside the range simply overhang the frame.
    lo = np.percentile(pos, 0.5, axis=0)
    hi = np.percentile(pos, 99.5, axis=0)
    span = float(np.maximum(hi - lo, 1e-6).max())
    pos = (pos - lo) / span * 1000.0

    communities: dict[int, str] = {}
    for node in nodes:
        communities.setdefault(
            node.get("community", 0),
            node.get("community_name", f"Community {node.get('community', 0)}"),
        )

    payload_nodes = [
        [
            round(float(pos[i, 0]), 1),
            round(float(pos[i, 1]), 1),
            int(degree[i]),
            int(node.get("community", 0)),
            node.get("label", node["id"]),
        ]
        for i, node in enumerate(nodes)
    ]
    payload_edges = [[int(a), int(b)] for a, b in pairs]

    sizes: dict[int, int] = {}
    for node in nodes:
        cid = node.get("community", 0)
        sizes[cid] = sizes.get(cid, 0) + 1
    legend_rows = sorted(communities.items(), key=lambda kv: -sizes[kv[0]])[:24]
    legend = "".join(
        f"<div class='row' data-cid='{cid}'>"
        f"<span class='swatch' style='background:{PALETTE[cid % len(PALETTE)]}'></span>"
        f"<span class='name'>{name}</span><span class='count'>{sizes[cid]}</span></div>"
        for cid, name in legend_rows
    )

    html = TEMPLATE.format(
        nodes_json=json.dumps(payload_nodes, ensure_ascii=False, separators=(",", ":")),
        edges_json=json.dumps(payload_edges, separators=(",", ":")),
        palette_json=json.dumps(PALETTE),
        legend=legend,
        node_count=f"{n:,}",
        edge_count=f"{len(pairs):,}",
        community_count=f"{len(communities):,}",
    )
    OUT.write_text(html, encoding="utf-8")
    print(f"Wrote {OUT} ({len(html):,} bytes)")


TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>AURA — Knowledge Network</title>
<style>
  :root {{
    --bg: #0a0c14;
    --panel: rgba(14,17,26,0.82);
    --border: rgba(122,162,247,0.14);
    --text: #dfe4f5;
    --muted: #7e88a8;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{ height: 100%; overflow: hidden; background: var(--bg);
    font-family: "SF Pro Text", Inter, system-ui, -apple-system, sans-serif;
    color: var(--text); -webkit-font-smoothing: antialiased; }}
  canvas {{ position: absolute; inset: 0; cursor: grab; }}
  canvas.dragging {{ cursor: grabbing; }}

  .panel {{ position: absolute; z-index: 10; background: var(--panel);
    border: 1px solid var(--border); border-radius: 12px;
    backdrop-filter: blur(20px) saturate(1.3);
    box-shadow: 0 16px 48px rgba(0,0,0,0.6); }}

  #hud {{ top: 20px; left: 20px; width: 292px; padding: 18px 18px 14px; }}
  #hud h1 {{ font-size: 13px; font-weight: 600; letter-spacing: 0.14em;
    text-transform: uppercase; color: #fff; }}
  #hud .tagline {{ font-size: 11px; color: var(--muted); margin-top: 4px;
    line-height: 1.5; }}
  .metrics {{ display: flex; gap: 18px; margin: 14px 0 4px;
    padding-top: 13px; border-top: 1px solid var(--border); }}
  .metric .v {{ font-size: 17px; font-weight: 600; letter-spacing: -0.02em;
    font-variant-numeric: tabular-nums; }}
  .metric .k {{ font-size: 9px; color: var(--muted); text-transform: uppercase;
    letter-spacing: 0.1em; margin-top: 2px; }}

  #search {{ width: 100%; margin-top: 14px; padding: 8px 11px; font-size: 12px;
    color: var(--text); background: rgba(0,0,0,0.35);
    border: 1px solid var(--border); border-radius: 7px; outline: none; }}
  #search:focus {{ border-color: rgba(122,162,247,0.5); }}
  #search::placeholder {{ color: #5a6382; }}

  #legend {{ top: 20px; right: 20px; width: 246px; padding: 14px;
    max-height: calc(100vh - 40px); overflow-y: auto; }}
  #legend .title {{ font-size: 9px; text-transform: uppercase;
    letter-spacing: 0.12em; color: var(--muted); margin-bottom: 9px; }}
  .row {{ display: flex; align-items: center; gap: 9px; padding: 4px 6px;
    border-radius: 5px; font-size: 11px; cursor: pointer; }}
  .row:hover {{ background: rgba(122,162,247,0.09); }}
  .row.dim {{ opacity: 0.3; }}
  .swatch {{ width: 8px; height: 8px; border-radius: 2px; flex: 0 0 auto; }}
  .name {{ flex: 1; overflow: hidden; text-overflow: ellipsis;
    white-space: nowrap; }}
  .count {{ color: var(--muted); font-size: 10px;
    font-variant-numeric: tabular-nums; }}

  #tip {{ position: absolute; z-index: 20; display: none; padding: 7px 10px;
    background: rgba(10,12,20,0.94); border: 1px solid var(--border);
    border-radius: 7px; font-size: 11px; pointer-events: none;
    max-width: 300px; box-shadow: 0 8px 24px rgba(0,0,0,0.6); }}
  #tip .t {{ font-weight: 600; }}
  #tip .s {{ color: var(--muted); margin-top: 3px; font-size: 10px; }}

  #hint {{ bottom: 20px; left: 20px; padding: 8px 13px; font-size: 10px;
    color: var(--muted); letter-spacing: 0.04em; }}
  ::-webkit-scrollbar {{ width: 5px; }}
  ::-webkit-scrollbar-thumb {{ background: rgba(122,162,247,0.2);
    border-radius: 3px; }}
</style>
</head>
<body>
<canvas id="c"></canvas>

<div class="panel" id="hud">
  <h1>AURA Knowledge Network</h1>
  <div class="tagline">Force-directed projection of the full extraction graph.</div>
  <div class="metrics">
    <div class="metric"><div class="v">{node_count}</div><div class="k">Nodes</div></div>
    <div class="metric"><div class="v">{edge_count}</div><div class="k">Edges</div></div>
    <div class="metric"><div class="v">{community_count}</div><div class="k">Clusters</div></div>
  </div>
  <input id="search" type="text" placeholder="Search symbols — AuraKernel, PolicyEngine…"/>
</div>

<div class="panel" id="legend">
  <div class="title">Largest clusters</div>
  {legend}
</div>

<div class="panel" id="hint">Drag to pan · Scroll to zoom · Hover a node to inspect</div>
<div id="tip"></div>

<script>
const NODES = {nodes_json};
const EDGES = {edges_json};
const PALETTE = {palette_json};

const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d', {{ alpha: false }});
const tip = document.getElementById('tip');

let W = 0, H = 0, DPR = Math.min(window.devicePixelRatio || 1, 2);
let scale = 1, offX = 0, offY = 0, fitted = false;
let dragging = false, dragged = false, lastX = 0, lastY = 0;
let highlight = null;      // matched node indices from search
let activeCluster = null;  // cluster filter from the legend

const rgb = PALETTE.map(hex => {{
  const v = parseInt(hex.slice(1), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}});

// Degree drives both node radius and how brightly a hub blooms.
let maxDeg = 1;
for (const n of NODES) if (n[2] > maxDeg) maxDeg = n[2];

function resize() {{
  W = window.innerWidth; H = window.innerHeight;
  canvas.width = W * DPR; canvas.height = H * DPR;
  canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  // fit() depends on W/H, so it can only run once they are known.
  if (!fitted) {{ fit(); fitted = true; }}
  draw();
}}

function fit() {{
  // The layout is normalised to a 1000-unit square.
  const pad = 90;
  scale = Math.min((W - pad * 2) / 1000, (H - pad * 2) / 1000);
  offX = (W - 1000 * scale) / 2;
  offY = (H - 1000 * scale) / 2;
}}

const sx = x => x * scale + offX;
const sy = y => y * scale + offY;

function visible(i) {{
  if (activeCluster !== null && NODES[i][3] !== activeCluster) return false;
  return true;
}}

function draw(simplified) {{
  ctx.fillStyle = '#0a0c14';
  ctx.fillRect(0, 0, W, H);

  // Additive blending is what turns overlapping translucent edges into a
  // fabric and makes dense regions bloom instead of muddying to grey.
  ctx.globalCompositeOperation = 'lighter';

  // --- edges -------------------------------------------------------------
  if (!simplified) {{
    // Alpha has to stay very low: with 35k edges the additive accumulation
    // clips to white long before any individual stroke looks visible.
    const alpha = Math.min(0.10, 0.032 + scale * 0.022);
    ctx.lineWidth = Math.max(0.3, 0.4 * scale);
    let currentCluster = -1;
    ctx.beginPath();
    for (let e = 0; e < EDGES.length; e++) {{
      const a = EDGES[e][0], b = EDGES[e][1];
      if (!visible(a) && !visible(b)) continue;
      const na = NODES[a], nb = NODES[b];
      const cluster = na[3];
      if (cluster !== currentCluster) {{
        ctx.stroke();
        const c = rgb[cluster % rgb.length];
        let a2 = alpha;
        if (highlight && !highlight.has(a) && !highlight.has(b)) a2 = alpha * 0.15;
        ctx.strokeStyle = `rgba(${{c[0]}},${{c[1]}},${{c[2]}},${{a2}})`;
        ctx.beginPath();
        currentCluster = cluster;
      }}
      ctx.moveTo(sx(na[0]), sy(na[1]));
      ctx.lineTo(sx(nb[0]), sy(nb[1]));
    }}
    ctx.stroke();
  }}

  // --- nodes -------------------------------------------------------------
  for (let i = 0; i < NODES.length; i++) {{
    if (!visible(i)) continue;
    const n = NODES[i];
    const x = sx(n[0]), y = sy(n[1]);
    if (x < -40 || x > W + 40 || y < -40 || y > H + 40) continue;

    const norm = Math.sqrt(n[2] / maxDeg);
    const r = Math.max(0.6, (0.7 + norm * 4.0) * Math.sqrt(scale));
    const c = rgb[n[3] % rgb.length];
    let a = 0.26 + norm * 0.74;
    if (highlight && !highlight.has(i)) a *= 0.1;

    // Hubs get a soft halo; ordinary nodes stay a flat dot so the field of
    // small nodes reads as texture rather than noise.
    if (norm > 0.45 && !simplified) {{
      const g = ctx.createRadialGradient(x, y, 0, x, y, r * 5);
      g.addColorStop(0, `rgba(${{c[0]}},${{c[1]}},${{c[2]}},${{a * 0.28}})`);
      g.addColorStop(1, `rgba(${{c[0]}},${{c[1]}},${{c[2]}},0)`);
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, r * 5, 0, 6.283); ctx.fill();
    }}
    ctx.fillStyle = `rgba(${{c[0]}},${{c[1]}},${{c[2]}},${{a}})`;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 6.283); ctx.fill();
  }}

  // --- labels for the largest hubs ---------------------------------------
  ctx.globalCompositeOperation = 'source-over';
  if (scale > 0.55 && !simplified) {{
    ctx.font = '600 10px "SF Pro Text", Inter, sans-serif';
    ctx.textAlign = 'center';
    for (let i = 0; i < NODES.length; i++) {{
      if (!visible(i)) continue;
      const n = NODES[i];
      if (n[2] < maxDeg * 0.22) continue;
      const x = sx(n[0]), y = sy(n[1]);
      if (x < 0 || x > W || y < 0 || y > H) continue;
      let a = 0.85;
      if (highlight && !highlight.has(i)) a = 0.12;
      ctx.fillStyle = `rgba(255,255,255,${{a}})`;
      ctx.fillText(n[4], x, y - 9);
    }}
  }}
}}

function pick(mx, my) {{
  let best = null, bestD = 14 * 14;
  for (let i = 0; i < NODES.length; i++) {{
    if (!visible(i)) continue;
    const dx = sx(NODES[i][0]) - mx, dy = sy(NODES[i][1]) - my;
    const d = dx * dx + dy * dy;
    if (d < bestD) {{ bestD = d; best = i; }}
  }}
  return best;
}}

canvas.addEventListener('mousedown', e => {{
  dragging = true; dragged = false;
  lastX = e.clientX; lastY = e.clientY;
  canvas.classList.add('dragging');
}});
window.addEventListener('mouseup', () => {{
  dragging = false; canvas.classList.remove('dragging');
  if (dragged) draw();
}});
window.addEventListener('mousemove', e => {{
  if (dragging) {{
    dragged = true;
    offX += e.clientX - lastX; offY += e.clientY - lastY;
    lastX = e.clientX; lastY = e.clientY;
    draw(true);              // simplified while dragging keeps it responsive
    tip.style.display = 'none';
    return;
  }}
  const i = pick(e.clientX, e.clientY);
  if (i === null) {{ tip.style.display = 'none'; return; }}
  const n = NODES[i];
  const clusterName = document.querySelector(`.row[data-cid="${{n[3]}}"] .name`);
  tip.innerHTML = `<div class="t">${{n[4]}}</div><div class="s">` +
    `${{clusterName ? clusterName.textContent : 'Cluster ' + n[3]}} · ${{n[2]}} connections</div>`;
  tip.style.display = 'block';
  tip.style.left = Math.min(e.clientX + 14, W - 310) + 'px';
  tip.style.top = (e.clientY + 14) + 'px';
}});

canvas.addEventListener('wheel', e => {{
  e.preventDefault();
  const k = e.deltaY < 0 ? 1.12 : 1 / 1.12;
  // Zoom about the cursor so the point under the pointer stays put.
  offX = e.clientX - (e.clientX - offX) * k;
  offY = e.clientY - (e.clientY - offY) * k;
  scale *= k;
  draw();
}}, {{ passive: false }});

document.getElementById('search').addEventListener('input', e => {{
  const q = e.target.value.trim().toLowerCase();
  if (!q) {{ highlight = null; draw(); return; }}
  highlight = new Set();
  for (let i = 0; i < NODES.length; i++) {{
    if (NODES[i][4].toLowerCase().includes(q)) highlight.add(i);
  }}
  draw();
}});

document.querySelectorAll('.row').forEach(row => {{
  row.addEventListener('click', () => {{
    const cid = parseInt(row.dataset.cid, 10);
    activeCluster = activeCluster === cid ? null : cid;
    document.querySelectorAll('.row').forEach(r => {{
      r.classList.toggle('dim',
        activeCluster !== null && parseInt(r.dataset.cid, 10) !== activeCluster);
    }});
    draw();
  }});
}});

window.addEventListener('resize', resize);
resize();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
