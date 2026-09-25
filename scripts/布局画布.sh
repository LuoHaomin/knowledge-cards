#!/bin/bash
# canvas 自动布局（力导向，默认）：
#   节点互斥 + 连线弹簧 + 向心力，迭代收敛；连线方向按最终几何关系自动选边
# 用法：
#   ./布局画布.sh 文件1.canvas [文件2.canvas ...]   # 力导向
#   ./布局画布.sh --分层 文件.canvas               # 分层依赖布局（适合纯 DAG）
#   ./布局画布.sh                                   # 无参数处理所有板块画布
cd "$(dirname "$0")"
LAYERED=0
if [ "$1" = "--分层" ]; then LAYERED=1; shift; fi
if [ $# -eq 0 ]; then set -- [0-9]*.canvas; fi

python3 - "$LAYERED" "$@" <<'EOF'
import json, sys, math, random
from collections import deque

layered = sys.argv[1] == '1'
X_GAP, Y_GAP, W, H = 420, 230, 300, 100

# ---------- 力导向（Fruchterman–Reingold 改良版） ----------
def force_layout(byid, edges, iters=900):
    ids = list(byid)
    n = len(ids)
    if n == 0: return
    # 初值：沿用现有坐标（保持大致轮廓，且结果确定）
    pos = {i: [float(byid[i].get('x', 0)), float(byid[i].get('y', 0))] for i in ids}
    # 坐标全部重合时摊开
    if len({(round(p[0]), round(p[1])) for p in pos.values()}) < n:
        for k, i in enumerate(ids):
            pos[i] = [math.cos(k/n*2*math.pi)*600, math.sin(k/n*2*math.pi)*600]
    k = 330                                   # 理想边长（节点宽 300 + 间隙）
    arep = 4e6                                # 互斥强度（兼防重叠：宽节点需要强斥力）
    T = 220.0                                 # 温度（步长上限）退火
    adj = {i: [] for i in ids}
    for e in edges:
        if e['fromNode'] != e['toNode']:
            adj[e['fromNode']].append(e['toNode'])
            adj[e['toNode']].append(e['fromNode'])
    cx = sum(p[0] for p in pos.values())/n
    cy = sum(p[1] for p in pos.values())/n
    for _ in range(iters):
        fx = {i: 0.0 for i in ids}; fy = {i: 0.0 for i in ids}
        # 互斥
        for a in range(n):
            for b in range(a+1, n):
                ia, ib = ids[a], ids[b]
                dx = pos[ia][0]-pos[ib][0]; dy = pos[ia][1]-pos[ib][1]
                d2 = dx*dx + dy*dy
                d = math.sqrt(d2) or 0.01
                # 节点宽 300：水平方向要求更大间距
                min_d = 390 if abs(dx) > abs(dy) else 210
                f = arep/d2
                if d < min_d: f += (min_d-d)*8     # 软碰撞：过近时强推
                ux, uy = dx/d, dy/d
                fx[ia] += ux*f; fy[ia] += uy*f
                fx[ib] -= ux*f; fy[ib] -= uy*f
        # 弹簧吸引
        for e in edges:
            ia, ib = e['fromNode'], e['toNode']
            if ia == ib: continue
            dx = pos[ib][0]-pos[ia][0]; dy = pos[ib][1]-pos[ia][1]
            d = math.hypot(dx, dy) or 0.01
            f = (d-k)*0.12
            ux, uy = dx/d, dy/d
            fx[ia] += ux*f; fy[ia] += uy*f
            fx[ib] -= ux*f; fy[ib] -= uy*f
        # 对齐力（箭头刚性）：大致水平的边把两端 y 拉齐，竖直的边把 x 拉齐
        for e in edges:
            ia, ib = e['fromNode'], e['toNode']
            if ia == ib: continue
            dx = pos[ib][0]-pos[ia][0]; dy = pos[ib][1]-pos[ia][1]
            if abs(dx) > abs(dy):     # 水平边：消除竖直错位
                f = dy * 0.25
                fy[ia] += f; fy[ib] -= f
            else:                      # 竖直边：消除水平错位
                f = dx * 0.25
                fx[ia] += f; fx[ib] -= f
        # 向心 + 更新（带温度钳制）
        for i in ids:
            fx[i] += (cx-pos[i][0])*0.012; fy[i] += (cy-pos[i][1])*0.012
            mag = math.hypot(fx[i], fy[i])
            if mag > T:
                fx[i], fy[i] = fx[i]/mag*T, fy[i]/mag*T
            pos[i][0] += fx[i]; pos[i][1] += fy[i]
        T = max(T*0.995, 6)
    for i in ids:
        byid[i]['x'] = round(pos[i][0]); byid[i]['y'] = round(pos[i][1])
        byid[i]['width'], byid[i]['height'] = W, H

def sides_by_geometry(byid, edges):
    # 挂边 = 中心连线从盒子的哪个面穿出/穿入：
    # 出口取与方向向量点积最大的外法向；入口取点积最小（= 最迎着方向）的外法向
    normals = {'right': (1,0), 'left': (-1,0), 'bottom': (0,1), 'top': (0,-1)}
    for e in edges:
        a, b = byid[e['fromNode']], byid[e['toNode']]
        vx = (b['x']+W/2) - (a['x']+W/2)
        vy = (b['y']+H/2) - (a['y']+H/2)
        if vx == 0 and vy == 0: continue
        e['fromSide'] = max(normals, key=lambda sd: normals[sd][0]*vx + normals[sd][1]*vy)
        e['toSide']   = min(normals, key=lambda sd: normals[sd][0]*vx + normals[sd][1]*vy)

# ---------- 分层布局（保留为可选） ----------
def layered_layout(byid, edges):
    E = [(e['fromNode'], e['toNode'], e) for e in edges]
    color = {i: 0 for i in byid}; back = set()
    def dfs(u):
        color[u] = 1
        for s, t, _ in E:
            if s == u:
                if color[t] == 1: back.add((u, t))
                elif color[t] == 0: dfs(t)
        color[u] = 2
    sys.setrecursionlimit(100000)
    for i in byid:
        if color[i] == 0: dfs(i)
    dag = [(s, t, e) for s, t, e in E if (s, t) not in back]
    indeg = {i: 0 for i in byid}; outs = {i: [] for i in byid}
    for s, t, _ in dag:
        indeg[t] += 1; outs[s].append(t)
    q = deque(i for i in byid if indeg[i] == 0)
    layer = {i: 0 for i in byid}
    while q:
        u = q.popleft()
        for t in outs[u]:
            layer[t] = max(layer[t], layer[u]+1)
            indeg[t] -= 1
            if indeg[t] == 0: q.append(t)
    layers = sorted(set(layer.values()))
    L = {l: sorted(i for i in byid if layer[i] == l) for l in layers}
    pos = {}
    def assign():
        for l in layers:
            for kk, m in enumerate(L[l]): pos[m] = (l, kk)
    assign()
    for _ in range(6):
        for li in range(1, len(layers)):
            l, lp = layers[li], layers[li-1]
            def bary(n, l=l, lp=lp):
                nb = [pos[s][1] for s, t, _ in dag if t == n and layer[s] == lp]
                return (sum(nb)/len(nb)) if nb else pos[n][1]
            L[l] = sorted(L[l], key=lambda n: (bary(n), pos[n][1]))
        assign()
        for li in range(len(layers)-2, -1, -1):
            l, ln = layers[li], layers[li+1]
            def bary2(n, l=l, ln=ln):
                nb = [pos[t][1] for s, t, _ in dag if s == n and layer[t] == ln]
                return (sum(nb)/len(nb)) if nb else pos[n][1]
            L[l] = sorted(L[l], key=lambda n: (bary2(n), pos[n][1]))
        assign()
    for l in layers:
        row = L[l]; x0 = -(len(row)-1)*X_GAP/2
        for kk, m in enumerate(row):
            byid[m]['x'] = int(x0 + kk*X_GAP); byid[m]['y'] = l*Y_GAP
            byid[m]['width'], byid[m]['height'] = W, H
    for s, t, e in E:
        ls, lt = layer.get(s, 0), layer.get(t, 0)
        if lt > ls:   e['fromSide'], e['toSide'] = 'bottom', 'top'
        elif lt < ls: e['fromSide'], e['toSide'] = 'top', 'bottom'
        elif pos[s][1] < pos[t][1]: e['fromSide'], e['toSide'] = 'right', 'left'
        else:         e['fromSide'], e['toSide'] = 'left', 'right'

for path in sys.argv[2:]:
    d = json.load(open(path))
    nodes = [n for n in d['nodes'] if n.get('type') == 'file']
    byid = {n['id']: n for n in nodes}
    edges = [e for e in d['edges'] if e['fromNode'] in byid and e['toNode'] in byid]
    if layered: layered_layout(byid, edges)
    else:
        force_layout(byid, edges)
        sides_by_geometry(byid, edges)
    json.dump(d, open(path, 'w'), ensure_ascii=False, indent=2)
    print(f'{path}: {len(nodes)} 节点 {len(edges)} 边，{"分层" if layered else "力导向"}布局完成')
EOF
