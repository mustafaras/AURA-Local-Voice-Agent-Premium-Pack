#!/usr/bin/env python3
"""Generate a polished, aesthetic network visualization for the AURA knowledge graph.

Reads graphify-out/graph.json and emits a self-contained HTML file using
vis-network with a curated dark theme, soft physics, hover effects, and a
clean control panel. Node size scales with degree; edges are styled by
confidence (EXTRACTED solid / INFERRED dashed / AMBIGUOUS dotted).
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "graphify-out" / "graph.json"
OUT = ROOT / "graphify-out" / "network.html"

data = json.loads(GRAPH.read_text(encoding="utf-8"))
nodes = data.get("nodes", [])
links = data.get("links", [])

# ---- curated palette (dark, high-contrast, colorblind-friendly) ------------
PALETTE = [
    "#7aa2f7", "#7dcfff", "#9ece6a", "#e0af68", "#bb9af7",
    "#f7768e", "#73daca", "#ff9e64", "#2ac3de", "#c0caf5",
    "#a9b1d6", "#e1c184", "#89ddff", "#f28fad", "#b4f9f8",
]

# ---- node degree for sizing -------------------------------------------------
degree = {}
for l in links:
    degree[l["source"]] = degree.get(l["source"], 0) + 1
    degree[l["target"]] = degree.get(l["target"], 0) + 1

# ---- filter to the architectural core (top-N by degree) ---------------------
# A hairball of thousands of nodes hides every edge. To actually SEE the
# connections, keep only the highest-degree nodes — the architectural core —
# so clusters separate and edges are legible. The tail is dropped, not lost:
# it is still in graph.json.
CORE_N = 400
by_degree = sorted(nodes, key=lambda n: degree.get(n["id"], 0), reverse=True)
keep = {n["id"] for n in by_degree[:CORE_N]}
nodes = [n for n in nodes if n["id"] in keep]
links = [l for l in links if l["source"] in keep and l["target"] in keep]
print(f"Core: {len(nodes):,} nodes (top {CORE_N} by degree), {len(links):,} edges")

# ---- build vis.js datasets --------------------------------------------------
vis_nodes = []
for n in nodes:
    cid = n.get("community", 0)
    color = PALETTE[cid % len(PALETTE)]
    deg = degree.get(n["id"], 0)
    # size: 6..26 by degree (log-ish), god nodes larger
    size = 6 + min(20, int(deg ** 0.5) * 2)
    label = n.get("label", n["id"])
    if len(label) > 40:
        label = label[:38] + "…"
    vis_nodes.append({
        "id": n["id"],
        "label": label,
        "color": {"background": color, "border": "#ffffff", "highlight": {"background": "#ffffff", "border": color}},
        "borderWidth": 1,
        "size": size,
        "font": {"color": "#c8d3f5", "size": 11, "face": "Inter, system-ui, sans-serif"},
        "title": f"<b>{n.get('label', n['id'])}</b><br/><span style='color:#9aa5ce'>{n.get('community_name', '')}</span><br/><span style='color:#565f89'>{n.get('file_type', '')}</span>",
        "group": cid,
    })

vis_edges = []
for l in links:
    conf = l.get("confidence", "EXTRACTED")
    if conf == "EXTRACTED":
        dashes = False
        color = "rgba(122,162,247,0.55)"
    elif conf == "INFERRED":
        dashes = [6, 4]
        color = "rgba(158,206,106,0.5)"
    else:  # AMBIGUOUS
        dashes = [2, 4]
        color = "rgba(224,175,104,0.5)"
    vis_edges.append({
        "from": l["source"],
        "to": l["target"],
        "color": {"color": color, "highlight": "#ffffff", "opacity": 0.7},
        "dashes": dashes,
        "width": 0.8 + min(2.5, l.get("weight", 1.0)),
        "title": f"{l.get('relation', '')} · {conf}",
        "smooth": {"enabled": True, "type": "continuous", "roundness": 0.4},
    })

# ---- community legend -------------------------------------------------------
community_names = {}
for n in nodes:
    cid = n.get("community", 0)
    name = n.get("community_name", f"Community {cid}")
    community_names.setdefault(cid, name)
legend = "".join(
    f"<div class='lg'><span class='dot' style='background:{PALETTE[cid % len(PALETTE)]}'></span>"
    f"<span class='lg-name'>{name}</span><span class='lg-count'>{sum(1 for n in nodes if n.get('community',0)==cid)}</span></div>"
    for cid, name in sorted(community_names.items(), key=lambda kv: -sum(1 for n in nodes if n.get('community',0)==kv[0]))[:40]
)

# group definitions for vis.js (computed before the f-string that embeds them)
groups = ",\n      ".join(
    f"{cid}: {{ color: {{ background: '{PALETTE[cid % len(PALETTE)]}', border: '#ffffff' }}, font: {{ color: '#c8d3f5' }} }}"
    for cid in community_names
)

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>AURA Knowledge Network</title>
<script type="text/javascript" src="https://unpkg.com/vis-network@9.1.9/standalone/umd/vis-network.min.js"></script>
<style>
  :root {{
    --bg: #0f1117;
    --panel: #161a24;
    --panel-border: #232a3a;
    --text: #c8d3f5;
    --muted: #9aa5ce;
    --accent: #7aa2f7;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{ height: 100%; overflow: hidden; font-family: Inter, system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); }}
  #network {{ position: absolute; inset: 0; }}
  #panel {{
    position: absolute; top: 16px; left: 16px; z-index: 10;
    width: 300px; max-height: calc(100vh - 32px); overflow-y: auto;
    background: rgba(22,26,36,0.92); border: 1px solid var(--panel-border);
    border-radius: 14px; padding: 16px; backdrop-filter: blur(12px);
    box-shadow: 0 8px 32px rgba(0,0,0,0.5);
  }}
  #panel h1 {{ font-size: 15px; font-weight: 700; letter-spacing: 0.02em; margin-bottom: 2px; }}
  #panel .sub {{ font-size: 11px; color: var(--muted); margin-bottom: 12px; }}
  #search {{
    width: 100%; padding: 8px 10px; border-radius: 8px; border: 1px solid var(--panel-border);
    background: #0f1117; color: var(--text); font-size: 12px; margin-bottom: 10px; outline: none;
  }}
  #search:focus {{ border-color: var(--accent); }}
  .legend-title {{ font-size: 11px; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; margin: 8px 0 6px; }}
  .lg {{ display: flex; align-items: center; gap: 8px; padding: 3px 0; font-size: 11px; }}
  .lg .dot {{ width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }}
  .lg-name {{ flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .lg-count {{ color: var(--muted); font-size: 10px; }}
  .stats {{ display: flex; gap: 12px; margin-top: 10px; padding-top: 10px; border-top: 1px solid var(--panel-border); font-size: 11px; color: var(--muted); }}
  .stats b {{ color: var(--text); font-weight: 600; }}
  .legend-toggle {{ position: absolute; top: 16px; right: 16px; z-index: 10; background: rgba(22,26,36,0.92); border: 1px solid var(--panel-border); color: var(--text); border-radius: 8px; padding: 6px 10px; font-size: 11px; cursor: pointer; backdrop-filter: blur(12px); }}
  ::-webkit-scrollbar {{ width: 6px; }} ::-webkit-scrollbar-thumb {{ background: #2a3245; border-radius: 3px; }}
</style>
</head>
<body>
<div id="network"></div>
<button class="legend-toggle" id="toggle">Topluluklar</button>
<div id="panel">
  <h1>AURA Knowledge Network</h1>
  <div class="sub">{len(nodes):,} çekirdek düğüm · {len(links):,} bağlantı · {len(community_names)} topluluk</div>
  <input id="search" type="text" placeholder="Sembol ara… (örn. AuraKernel, PolicyEngine)"/>
  <div class="legend-title">En büyük topluluklar</div>
  <div id="legend">{legend}</div>
  <div class="stats">
    <span><b>{len(nodes):,}</b> düğüm</span>
    <span><b>{len(links):,}</b> bağlantı</span>
    <span><b>{len(community_names)}</b> topluluk</span>
  </div>
</div>
<script>
  const nodes = new vis.DataSet({{nodes_json}});
  const edges = new vis.DataSet({{edges_json}});
  const container = document.getElementById('network');
  const options = {{
    physics: {{
      enabled: true,
      barnesHut: {{
        gravitationalConstant: -6000,
        centralGravity: 0.15,
        springLength: 120,
        springConstant: 0.06,
        damping: 0.5,
        avoidOverlap: 0.4
      }},
      stabilization: {{ iterations: 300, updateInterval: 15 }}
    }},
    interaction: {{
      hover: true, tooltipDelay: 120, navigationButtons: true,
      keyboard: true, hideEdgesOnDrag: true
    }},
    nodes: {{
      shape: 'dot', scaling: {{ min: 6, max: 26 }},
      shadow: {{ enabled: true, color: 'rgba(0,0,0,0.4)', size: 6 }}
    }},
    edges: {{ smooth: {{ enabled: true, type: 'continuous', roundness: 0.4 }} }},
    groups: {{
      {groups}
    }}
  }};
  const network = new vis.Network(container, {{ nodes, edges }}, options);

  // search
  const search = document.getElementById('search');
  search.addEventListener('input', () => {{
    const q = search.value.trim().toLowerCase();
    if (!q) {{ network.selectNodes([]); return; }}
    const matches = nodes.get().filter(n => n.label.toLowerCase().includes(q)).slice(0, 20).map(n => n.id);
    network.selectNodes(matches);
    if (matches.length) network.focus(matches[0], {{ scale: 1.2 }});
  }});

  // legend toggle
  const panel = document.getElementById('panel');
  const toggle = document.getElementById('toggle');
  toggle.addEventListener('click', () => {{
    const hidden = panel.style.display === 'none';
    panel.style.display = hidden ? 'block' : 'none';
    toggle.textContent = hidden ? 'Kapat' : 'Topluluklar';
  }});
</script>
</body>
</html>
"""

# Inject the datasets independently; a shared placeholder would silently put
# the node records into the edge dataset as well.
html = html.replace("{nodes_json}", json.dumps(vis_nodes, ensure_ascii=False))
html = html.replace("{edges_json}", json.dumps(vis_edges, ensure_ascii=False))
html = html.replace("{groups}", groups)

OUT.write_text(html, encoding="utf-8")
print(f"Wrote {OUT} ({len(html):,} bytes, {len(vis_nodes):,} nodes, {len(vis_edges):,} edges)")
