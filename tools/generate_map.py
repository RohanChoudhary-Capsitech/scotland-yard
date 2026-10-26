#!/usr/bin/env python3
"""
tools/generate_map.py
Generates the map graph for the Scotland Yard board game.
Follows all constraints:
- 199 stations (IDs 1..199) in 2400x1800 area.
- Jittered grid with stations 90-130px apart and no overlaps.
- Taxi: connects each station to 2-4 nearest neighbours without crossing edges.
- Taxi graph is asserted to be 100% connected.
- Bus: ~60 stops forming routes with hops 2-4 taxi-steps apart.
- Underground: ~14 stations forming 3 long transit lines.
- Ferry: 4-5 stations along a river band, linked by ferry.
- 18 start stations spread across the map.
- Fixed random seed for deterministic reproduction.
"""

import math
import random
import json
import os
import sys
from collections import deque

RANDOM_SEED = 1888
WIDTH = 2400
HEIGHT = 1800
TARGET_STATIONS = 199


def ccw(A, B, C):
    return (C[1] - A[1]) * (B[0] - A[0]) > (B[1] - A[1]) * (C[0] - A[0])


def segments_cross(p1, p2, p3, p4):
    """Returns True if open segments (p1, p2) and (p3, p4) strictly intersect."""
    if p1 == p2 or p3 == p4:
        return False
    if p1 == p3 or p1 == p4 or p2 == p3 or p2 == p4:
        return False
    return (ccw(p1, p3, p4) != ccw(p2, p3, p4)) and (ccw(p1, p2, p3) != ccw(p1, p2, p4))


def generate_map():
    random.seed(RANDOM_SEED)

    # ── 1. Station Placement (Jittered Grid) ──────────────────────────────────
    cols, rows = 19, 14
    cell_w, cell_h = 110.0, 105.0
    center_c, center_r = (cols - 1) / 2.0, (rows - 1) / 2.0

    cells = []
    for r in range(rows):
        for c in range(cols):
            dc = (c - center_c) / center_c
            dr = (r - center_r) / center_r
            cells.append((dc * dc + dr * dr, c, r))

    # Pick the 199 cells closest to the center for a cohesive oval city layout
    cells.sort(key=lambda item: item[0])
    chosen = cells[:TARGET_STATIONS]

    start_x = (WIDTH - (cols - 1) * cell_w) / 2
    start_y = (HEIGHT - (rows - 1) * cell_h) / 2

    jitter = 6.0
    stations = {}
    for i, (_, c, r) in enumerate(chosen, 1):
        stagger = (cell_w * 0.25) if (r % 2 == 1) else (-cell_w * 0.25)
        x = int(round(start_x + c * cell_w + stagger + random.uniform(-jitter, jitter)))
        y = int(round(start_y + r * cell_h + random.uniform(-jitter, jitter)))
        stations[i] = (x, y)

    # Distance validations
    pairwise_dists = [
        math.hypot(stations[i][0] - stations[j][0], stations[i][1] - stations[j][1])
        for i in range(1, TARGET_STATIONS + 1)
        for j in range(i + 1, TARGET_STATIONS + 1)
    ]
    min_dist = min(pairwise_dists)
    nn_dists = [
        min(
            math.hypot(stations[i][0] - stations[j][0], stations[i][1] - stations[j][1])
            for j in range(1, TARGET_STATIONS + 1)
            if i != j
        )
        for i in range(1, TARGET_STATIONS + 1)
    ]
    max_nn_dist = max(nn_dists)

    assert min_dist >= 90.0, f"Station overlap / min distance violated: {min_dist:.2f}px < 90px"
    assert max_nn_dist <= 130.0, f"Max nearest-neighbor distance violated: {max_nn_dist:.2f}px > 130px"

    # ── 2. Taxi Network (2-4 nearest neighbours, non-crossing, connected) ─────
    candidates = []
    for i in range(1, TARGET_STATIONS + 1):
        for j in range(i + 1, TARGET_STATIONS + 1):
            d = math.hypot(stations[i][0] - stations[j][0], stations[i][1] - stations[j][1])
            if d <= 180.0:
                candidates.append((d, i, j))
    candidates.sort(key=lambda x: x[0])

    taxi_edges = set()
    taxi_degree = {i: 0 for i in range(1, TARGET_STATIONS + 1)}

    def edge_crosses(u, v, cur_edges):
        p1, p2 = stations[u], stations[v]
        for ea, eb in cur_edges:
            if segments_cross(p1, p2, stations[ea], stations[eb]):
                return True
        return False

    # Pass 1: Greedily connect nearest neighbors avoiding crossings (max degree 4)
    for d, u, v in candidates:
        if taxi_degree[u] < 4 and taxi_degree[v] < 4:
            if not edge_crosses(u, v, taxi_edges):
                taxi_edges.add((min(u, v), max(u, v)))
                taxi_degree[u] += 1
                taxi_degree[v] += 1

    # Pass 2: Ensure every station has at least 2 taxi links
    for u in range(1, TARGET_STATIONS + 1):
        if taxi_degree[u] < 2:
            cur_cands = []
            for v in range(1, TARGET_STATIONS + 1):
                if u != v and (min(u, v), max(u, v)) not in taxi_edges and taxi_degree[v] < 4:
                    d = math.hypot(stations[u][0] - stations[v][0], stations[u][1] - stations[v][1])
                    cur_cands.append((d, v))
            cur_cands.sort()
            for d, v in cur_cands:
                if not edge_crosses(u, v, taxi_edges):
                    taxi_edges.add((min(u, v), max(u, v)))
                    taxi_degree[u] += 1
                    taxi_degree[v] += 1
                    if taxi_degree[u] >= 2:
                        break

    # Build adjacency and assert full connectivity
    taxi_adj = {i: [] for i in range(1, TARGET_STATIONS + 1)}
    for u, v in taxi_edges:
        taxi_adj[u].append(v)
        taxi_adj[v].append(u)

    visited = set()
    q = deque([1])
    visited.add(1)
    while q:
        curr = q.popleft()
        for nxt in taxi_adj[curr]:
            if nxt not in visited:
                visited.add(nxt)
                q.append(nxt)

    if len(visited) != TARGET_STATIONS:
        raise AssertionError(
            f"Taxi network is NOT connected! Only {len(visited)}/{TARGET_STATIONS} reachable."
        )

    for i in range(1, TARGET_STATIONS + 1):
        assert 2 <= taxi_degree[i] <= 4, f"Station {i} degree {taxi_degree[i]} outside [2, 4]"

    # Precompute taxi hop distance matrix via BFS
    taxi_dist = {}
    for src in range(1, TARGET_STATIONS + 1):
        taxi_dist[src] = {}
        q = deque([(src, 0)])
        taxi_dist[src][src] = 0
        while q:
            curr, d = q.popleft()
            for nxt in taxi_adj[curr]:
                if nxt not in taxi_dist[src]:
                    taxi_dist[src][nxt] = d + 1
                    q.append((nxt, d + 1))

    # Helper: find closest station to coordinate
    def find_nearest_station(pt, exclude=set()):
        best = None
        best_d = 1e9
        for sid, pos in stations.items():
            if sid in exclude:
                continue
            d = math.hypot(pos[0] - pt[0], pos[1] - pt[1])
            if d < best_d:
                best_d = d
                best = sid
        return best

    # ── 3. Bus Routes (~60 stops, 2-4 taxi hops) ─────────────────────────────
    def build_bus_line(start_node, target_dir, max_len=9):
        route = [start_node]
        curr = start_node
        dx_target, dy_target = target_dir
        norm = math.hypot(dx_target, dy_target)
        dx_target /= norm
        dy_target /= norm

        for _ in range(max_len - 1):
            best_cand = None
            best_score = -999999
            for cand in range(1, TARGET_STATIONS + 1):
                if cand in route:
                    continue
                hop = taxi_dist[curr][cand]
                if 2 <= hop <= 4:
                    dx = stations[cand][0] - stations[curr][0]
                    dy = stations[cand][1] - stations[curr][1]
                    dist = math.hypot(dx, dy)
                    if dist < 140 or dist > 450:
                        continue
                    cos_sim = (dx * dx_target + dy * dy_target) / dist
                    if cos_sim > 0.55:
                        score = cos_sim * 10 - abs(hop - 2.5) * 2
                        if score > best_score:
                            best_score = score
                            best_cand = cand
            if best_cand is not None:
                route.append(best_cand)
                curr = best_cand
            else:
                break
        return route

    corridors_y = [420, 680, 920, 1150, 1380]
    h_routes = []
    for cy in corridors_y:
        cands = [i for i in range(1, TARGET_STATIONS + 1) if abs(stations[i][1] - cy) < 160]
        cands.sort(key=lambda i: stations[i][0])
        if cands:
            r = build_bus_line(cands[0], (1, 0), max_len=9)
            if len(r) >= 5:
                h_routes.append(r)

    corridors_x = [600, 950, 1400, 1750]
    v_routes = []
    for cx in corridors_x:
        cands = [i for i in range(1, TARGET_STATIONS + 1) if abs(stations[i][0] - cx) < 160]
        cands.sort(key=lambda i: stations[i][1])
        if cands:
            r = build_bus_line(cands[0], (0, 1), max_len=8)
            if len(r) >= 5:
                v_routes.append(r)

    diag_cands_nw = [i for i in range(1, TARGET_STATIONS + 1) if stations[i][0] < 600 and stations[i][1] < 600]
    diag_cands_nw.sort(key=lambda i: stations[i][0] + stations[i][1])
    d1 = build_bus_line(diag_cands_nw[0], (1.2, 0.9), max_len=8) if diag_cands_nw else []

    diag_cands_sw = [i for i in range(1, TARGET_STATIONS + 1) if stations[i][0] < 600 and stations[i][1] > 1200]
    diag_cands_sw.sort(key=lambda i: stations[i][0] - stations[i][1])
    d2 = build_bus_line(diag_cands_sw[0], (1.2, -0.9), max_len=8) if diag_cands_sw else []

    all_bus_routes = h_routes + v_routes + ([d1] if len(d1) >= 4 else []) + ([d2] if len(d2) >= 4 else [])
    bus_stops = set()
    bus_links = set()
    for r in all_bus_routes:
        for s in r:
            bus_stops.add(s)
        for k in range(len(r) - 1):
            u, v = r[k], r[k + 1]
            bus_links.add((min(u, v), max(u, v)))

    # Verify bus hops
    for u, v in bus_links:
        hop = taxi_dist[u][v]
        assert 2 <= hop <= 4, f"Bus link ({u}, {v}) taxi hops {hop} not in [2, 4]"

    # ── 4. Underground (~14 stations, 3 long lines) ──────────────────────────
    # 3 major lines forming a transit triangle:
    # Interchange 1 (L1 & L2): ~ (1100, 850)
    # Interchange 2 (L1 & L3): ~ (1450, 850)
    # Interchange 3 (L2 & L3): ~ (1280, 1150)
    ic1 = find_nearest_station((1100, 850))
    ic2 = find_nearest_station((1450, 850), exclude={ic1})
    ic3 = find_nearest_station((1280, 1150), exclude={ic1, ic2})

    # Line 1: West -> ic1 -> ic2 -> East (6 stations)
    l1_w2 = find_nearest_station((380, 880), exclude={ic1, ic2, ic3})
    l1_w1 = find_nearest_station((740, 860), exclude={ic1, ic2, ic3, l1_w2})
    l1_e1 = find_nearest_station((1850, 860), exclude={ic1, ic2, ic3, l1_w2, l1_w1})
    l1_e2 = find_nearest_station((2100, 880), exclude={ic1, ic2, ic3, l1_w2, l1_w1, l1_e1})
    line1 = [l1_w2, l1_w1, ic1, ic2, l1_e1, l1_e2]

    # Line 2: North -> ic1 -> ic3 -> South (5 stations)
    l2_n2 = find_nearest_station((1050, 320), exclude=set(line1) | {ic3})
    l2_n1 = find_nearest_station((1080, 580), exclude=set(line1) | {ic3, l2_n2})
    l2_s1 = find_nearest_station((1300, 1450), exclude=set(line1) | {ic3, l2_n2, l2_n1})
    line2 = [l2_n2, l2_n1, ic1, ic3, l2_s1]

    # Line 3: NW -> ic2 -> ic3 -> SE (6 stations)
    l3_nw2 = find_nearest_station((480, 420), exclude=set(line1) | set(line2))
    l3_nw1 = find_nearest_station((850, 620), exclude=set(line1) | set(line2) | {l3_nw2})
    l3_se1 = find_nearest_station((1750, 1380), exclude=set(line1) | set(line2) | {l3_nw2, l3_nw1})
    l3_se2 = find_nearest_station((2050, 1550), exclude=set(line1) | set(line2) | {l3_nw2, l3_nw1, l3_se1})
    line3 = [l3_nw2, l3_nw1, ic2, ic3, l3_se1, l3_se2]

    ug_stops = set(line1) | set(line2) | set(line3)
    ug_links = set()
    for line in [line1, line2, line3]:
        for k in range(len(line) - 1):
            ug_links.add((min(line[k], line[k + 1]), max(line[k], line[k + 1])))

    # ── 5. Ferry (4-5 stations along river band) ─────────────────────────────
    river_pts = [(620, 1050), (950, 1070), (1250, 1060), (1550, 1080), (1850, 1050)]
    ferry_stops = []
    for pt in river_pts:
        s = find_nearest_station(pt, exclude=set(ferry_stops))
        ferry_stops.append(s)

    ferry_links = set()
    for k in range(len(ferry_stops) - 1):
        ferry_links.add((min(ferry_stops[k], ferry_stops[k + 1]), max(ferry_stops[k], ferry_stops[k + 1])))

    # ── 6. Start Stations (18 spread out) ────────────────────────────────────
    start_stations = [1]
    while len(start_stations) < 18:
        best_cand = None
        best_d = -1
        for sid, pos in stations.items():
            if sid in start_stations:
                continue
            min_d = min(math.hypot(pos[0] - stations[p][0], pos[1] - stations[p][1]) for p in start_stations)
            if min_d > best_d:
                best_d = min_d
                best_cand = sid
        start_stations.append(best_cand)
    start_stations.sort()

    # ── Degree Calculation ───────────────────────────────────────────────────
    all_links = []
    station_degree = {i: 0 for i in range(1, TARGET_STATIONS + 1)}

    for u, v in sorted(taxi_edges):
        all_links.append({"a": u, "b": v, "type": "taxi"})
        station_degree[u] += 1
        station_degree[v] += 1

    for u, v in sorted(bus_links):
        all_links.append({"a": u, "b": v, "type": "bus"})
        station_degree[u] += 1
        station_degree[v] += 1

    for u, v in sorted(ug_links):
        all_links.append({"a": u, "b": v, "type": "underground"})
        station_degree[u] += 1
        station_degree[v] += 1

    for u, v in sorted(ferry_links):
        all_links.append({"a": u, "b": v, "type": "ferry"})
        station_degree[u] += 1
        station_degree[v] += 1

    # ── JSON Serialization ───────────────────────────────────────────────────
    stations_list = [
        {"id": i, "x": stations[i][0], "y": stations[i][1]}
        for i in range(1, TARGET_STATIONS + 1)
    ]

    map_data = {
        "stations": stations_list,
        "links": all_links,
        "start_stations": start_stations,
    }

    # Write output to game/assets/data/map.json and data/map.json
    out_paths = [
        os.path.join("game", "assets", "data", "map.json"),
        os.path.join("data", "map.json"),
    ]
    for p in out_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(map_data, f, indent=2)

    # ── Console Output ───────────────────────────────────────────────────────
    print(f"Station count: {len(stations)}")
    print("Links per type:")
    print(f"  taxi: {len(taxi_edges)}")
    print(f"  bus: {len(bus_links)} (across {len(bus_stops)} stops)")
    print(f"  underground: {len(ug_links)} (across {len(ug_stops)} stations in 3 lines)")
    print(f"  ferry: {len(ferry_links)} (across {len(ferry_stops)} stations)")
    print(f"Min degree: {min(station_degree.values())}")
    print(f"Max degree: {max(station_degree.values())}")
    print(f"Start stations ({len(start_stations)}): {start_stations}")
    print(f"Map successfully written to: {out_paths[0]}")


if __name__ == "__main__":
    generate_map()
