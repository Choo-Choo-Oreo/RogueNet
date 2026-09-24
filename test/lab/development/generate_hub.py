"""Generates test/lab/development/: one big entrance-role hub with test cells behind wood doors.
Run from the repo root: python test/lab/development/generate_hub.py"""
import json, os
OUT = 'test/lab/development'
FLOOR, WALL = 'floor_smooth_stone', 'wall_smooth_stone'
TILE = {'.': FLOOR, 'L': 'floor_lava', '~': 'floor_water', 'A': 'floor_acid'}
MINION = {'r': 'rat', 'R': 'rat_blind', 'T': 'rat_toothless', 'b': 'bat', 'B': 'bat_echo', 'h': 'hamster',
          'H': 'hamster_flying', 'D': 'hamster_demonic', 'e': 'leech', 'E': 'leech_flesh', 'w': 'wolf',
          'X': 'wolf_hellhound', 'S': 'skeleton_archer', 'g': 'wraith', 'M': 'minotaur'}


def rows(*lines):
    w = max(len(l) for l in lines)
    return [l.ljust(w, '.') for l in lines]


cells = []


def cell(name, interior, door_x=None, door_w=2, doors=()):
    interior = rows(*interior)
    if door_x is None:
        door_x = (len(interior[0]) - door_w) // 2
    cells.append(dict(name=name, rows=interior, door_x=door_x, door_w=door_w, doors=list(doors)))


# ---- one cell per minion ----
for n, l in [('rat', 'r'), ('rat_blind', 'R'), ('rat_toothless', 'T'), ('bat', 'b'), ('bat_echo', 'B'),
             ('hamster', 'h'), ('hamster_flying', 'H'), ('hamster_demonic', 'D'), ('leech', 'e'),
             ('leech_flesh', 'E'), ('wolf', 'w'), ('wolf_hellhound', 'X'), ('skeleton_archer', 'S'),
             ('wraith', 'g')]:
    cell('minion_' + n, ['.........', '.........', '....%s....' % l, '.........', '.........'])
cell('minion_minotaur', ['...........', '...........', '...........', '.....M.....',
                         '...........', '...........', '...........'])

# ---- bug 1: spawn fit (a 1-wide nook a 2x2 body cannot stand in, a spawn beside a hole in the floor) ----
cell('bug1_spawn_fit', [
    '...........',
    '.#.#.#.#...',
    '.#M#.#r#...',
    '.###.###...',
    '...........',
    '..r  ......',
    '...........'])

# A sealed 1-wide corridor, 17 long, with the Minotaur pinned in the middle of it: no 2x2 spot
# within 6 tiles. It must be skipped (or moved somewhere legal), never spawned inside the walls.
cell('bug1_no_room_for_boss', ['.....' + '#' * 20] * 6
     + ['.....#' + '.' * 8 + 'M' + '.' * 8 + '##']
     + ['.....' + '#' * 20] * 6, door_x=1)

# A chasm across the room (a space is a hole: no floor, no wall) with a bridge at the far side, and
# a rat on each side of it. Whichever side the door is on, one rat must use the bridge, never the holes.
cell('bug1_hole_band', ['...............', '.r.............'] + ['...............'] * 2
     + ['            ...'] * 3 + ['...............'] * 2 + ['.r.............', '...............'])

# ---- bug 2: flow field keyed by body size (2-wide gap, then 1-wide gap) ----
cell('bug2_two_wide_gap', [
    '.......#.......',
    '.M.....#.......',
    '.......#.......',
    '...............',
    '...............',
    '.r.....#.......',
    '.......#.......'], door_x=11)
cell('bug2_one_wide_gap', [
    '.......#.......',
    '.M.....#.......',
    '.......#.......',
    '...............',
    '.......#.......',
    '.r.....#.......',
    '.......#.......'], door_x=11)

# A bedrock wall (%, cannot be smashed) with a 1-wide gap; the Minotaur stands in front of the gap and
# cannot fit through it, the rats are behind it. It must step aside and let them by. The gap is on
# the row you arrive on, so the Minotaur has a straight line to you and no reason to walk off.
cell('bug6_boss_blocks_gap', [
    '.......%.......',
    '.....M.........',
    '.......%.......',
    '.......%.......',
    '.......%.......',
    '.r.....%.......',
    '.r.....%.......'], door_x=11)

# ---- bug 3: wall smash (plain wall, a door in the way, pillars with a way round) ----
cell('bug3_smash_plain', [
    '.....###.......',
    '.M...###.......',
    '.....###.......',
    '.....###.......',
    '.....###.......'], door_x=11)
cell('bug3_smash_door', [
    '......##.......',
    '.M....##.......',
    '......##.......',
    '......##.......',
    '......##.......'], door_x=11, doors=[dict(x=6, y=2, orient='v', width=2)])
cell('bug3_smash_pillar', [
    '...............',
    '...............',
    '.M....###......',
    '......###......',
    '......###......',
    '...............',
    '...............'], door_x=11)

# ---- bug 4: a melee minion waits behind a ranged one ----
cell('bug4_corridor_archer', [
    '.....#######.....',
    '.....#######.....',
    '.....#######.....',
    '..rr..S..........',
    '.....#######.....',
    '.....#######.....',
    '.....#######.....'], door_x=13)
cell('bug4_open_archer', [
    '...............',
    '...............',
    '....r..........',
    '...rrS.........',
    '....r..........',
    '...............',
    '...............'], door_x=11)

# ---- bug 5: boss zone flicker ----
cell('bug5_boss_crowd', [
    '...............',
    '..r.......r....',
    '...............',
    '..r.......r....',
    '.......M.......',
    '..r.......r....',
    '...............',
    '..r.......r....',
    '...............'])

# ---- manual cells: things the headless sim cannot judge, for you to try by hand (see the README) ----
# Bug 5: a big open room with pillars to run around. Lead the Minotaur and its crowd in circles and
# watch the rats near it: they should not jitter in and out of its way.
_arena = ['.' * 27 for _ in range(15)]
for py, px in [(3, 6), (3, 19), (10, 6), (10, 19), (6, 12)]:
    for dy in (0, 1):
        _arena[py + dy] = _arena[py + dy][:px] + '##' + _arena[py + dy][px + 2:]
for (x, y, ch) in [(13, 1, 'M'), (4, 1, 'r'), (6, 1, 'r'), (8, 1, 'r'), (10, 1, 'r'), (16, 1, 'r'), (18, 1, 'r'),
                   (20, 1, 'r'), (22, 1, 'r'), (9, 13, 'S'), (17, 13, 'S')]:
    _arena[y] = _arena[y][:x] + ch + _arena[y][x + 1:]
cell('manual_boss_chase_arena', _arena, door_x=12, door_w=3)

# Bug 4: a long 1-wide corridor with an archer and four rats behind it, to watch the swap.
cell('manual_corridor_swap', [
    '.....#################.....',
    '.....#################.....',
    '.....#################.....',
    '.rrrrS.................'.ljust(27, '.'),
    '.....#################.....',
    '.....#################.....',
    '.....#################.....'], door_x=24)

# The wall-walking Minotaur: tight 2-wide gaps, pillars and corners to squeeze it through.
cell('manual_minotaur_corners', [
    '.......................',
    '.###.###.###.###.###...',
    '.###.###.###.###.###...',
    '.......................',
    '.M.....................',
    '.......................',
    '.###.###.###.###.###...',
    '.###.###.###.###.###...',
    '.......................'], door_x=21)

# Bug 3: a thick wall with a long way round along the bottom. Does it smash or walk?
cell('manual_smash_or_walk', [
    '.....######.........',
    '.....######.........',
    '.....######.........',
    '.M...######.........',
    '.....######.........',
    '.....######.........',
    '.....######.........',
    '.....######.........',
    '....................'.ljust(20, '.')], door_x=17)

# ---- terrain routing (a hazard band with a stone way round) ----
cell('terrain_lava', [
    '......LLL......',
    '.w....LLL...b..',
    '......LLL......',
    '......LLL......',
    '...............',
    '...............'], door_x=11)
cell('terrain_water', [
    '......~~~......',
    '.r....~~~...H..',
    '......~~~......',
    '......~~~......',
    '...............',
    '...............'], door_x=11)
cell('terrain_acid', [
    '......AAA......',
    '.X....AAA......',
    '......AAA......',
    '......AAA......',
    '...............',
    '...............'], door_x=11)

# ---- doors: which minions get through a 1, 2 and 3 wide door ----
cell('doors_widths', [
    'M..S...r..g....',
    '...............',
    '...............',
    '#.###..###...##',
    '...............',
    '...............',
    '...............'],
    door_x=6, doors=[dict(x=1, y=3, orient='h', width=1), dict(x=5, y=3, orient='h', width=2),
                     dict(x=10, y=3, orient='h', width=3)])

# ---- a crowd, for performance ----
swarm = ['.' * 21 for _ in range(13)]
for y in range(1, 12, 2):
    swarm[y] = '.' + 'r.' * 10
cell('swarm_rats', swarm, door_w=3)


# ---- what must be true (checked by test/sim/dev_sim.gd; keep a cell after its bug is fixed) ----
# Creatures named here must get within 3 tiles of the player once the door is open. "big" is any
# 2x2 body. Every cell also fails if any creature ever stands on a wall, void or no-floor tile.
REACH = {
    'minion_minotaur': ['big'],
    'bug1_spawn_fit': ['rat'],
    'bug1_hole_band': ['rat'],
    'bug2_two_wide_gap': ['big', 'rat'],
    'bug2_one_wide_gap': ['big', 'rat'],  # the Minotaur does not fit the gap: it smashes the wall
    'bug6_boss_blocks_gap': ['rat'],
    'bug3_smash_plain': ['big'],
    'bug3_smash_door': ['big'],
    'bug3_smash_pillar': ['big'],
    'bug4_corridor_archer': ['rat'],
    'bug4_open_archer': ['rat'],
}

# Where the player stands instead of at the door (interior column, row), for cells that test a
# straight line to the creature. The sim and the Test Lab both use it for "step inside".
PLAYER_AT = {'terrain_lava': (13, 1), 'terrain_water': (13, 1), 'terrain_acid': (13, 1)}

# The Minotaur is expected to be skipped here, so the cell may spawn fewer creatures than it pins.
MAY_SKIP = ['bug1_no_room_for_boss']
# A boss standing still may change its zone at most this many times (bug 5: it flipped with its facing).
ZONE_CHANGES_MAX = {'bug5_boss_crowd': 2}
# Walking creatures may spend at most this many samples (0.25 s each) on slow or harmful ground when
# a stone way round exists. Found in the Test Lab: the crowd fan-out drifted a hellhound into acid.
WADE_MAX = {'terrain_lava': 0, 'terrain_water': 0, 'terrain_acid': 0}


# ---- what the Test Lab (test/lab/TestLab.tscn) shows you for each cell ----
# (what it is, what to do, what counts as wrong). Kept here beside the cell so the two cannot drift.
# Cells with no entry here get the generic one-creature text.
NOTES = {
    'bug1_spawn_fit': ('The Minotaur is pinned in a 1-wide nook it cannot stand in, and a rat sits beside a hole in the floor.',
                       'Let them come for you.',
                       'The Minotaur is moved to a free 2x2 spot, never left inside a wall. The rat never walks on the hole.'),
    'bug1_no_room_for_boss': ('The Minotaur is pinned in a sealed 1-wide corridor with no 2x2 spot nearby.',
                              'Just look inside; nothing should be there.',
                              'A Minotaur exists here (it must be skipped). The debug log (F4) should say "No room for a 2x2".'),
    'bug1_hole_band': ('A chasm across the room with a bridge at one side and a rat on each side.',
                       'Stand opposite a rat and watch it cross.',
                       'A rat walking on the holes instead of using the bridge.'),
    'bug2_two_wide_gap': ('A rat and the Minotaur chase you through a 2-wide gap.',
                          'Stand past the gap and wait.',
                          'Either one stopping at the gap and never coming through.'),
    'bug2_one_wide_gap': ('The same, but the gap is 1 wide, so the Minotaur cannot fit.',
                          'Stand past the gap, in line with it, and press Enter.',
                          'The Minotaur cannot fit the gap, so it should smash the wall (even with a straight line through the gap) and both reach you. It parks in front of the gap instead.'),
    'bug6_boss_blocks_gap': ('An unbreakable wall with a 1-wide gap. The Minotaur stands right in front of the gap (it cannot fit through), rats behind it.',
                             'Stand on the far side of the wall, in line with the gap, and press Enter.',
                             'The Minotaur should step back and hold while the rats squeeze through the gap to you. It stays parked in front of the gap, or the rats jam behind it.'),
    'bug3_smash_plain': ('The Minotaur behind a solid wall with no way round.',
                         'Stand on the far side and wait.',
                         'It should break the wall and reach you. It gives up, or walks through the wall without breaking it.'),
    'bug3_smash_door': ('The Minotaur behind a closed door.',
                        'Stand on the far side.',
                        'It should smash the door (or open it) and reach you.'),
    'bug3_smash_pillar': ('The Minotaur among pillars, with a way round.',
                          'Stand behind the pillars.',
                          'It should walk round or smash through, and never stand inside a pillar.'),
    'bug4_corridor_archer': ('An archer with rats queued behind it in a 1-wide corridor.',
                             'Stand at the far end.',
                             'The archer and the rats should trade places until the rats reach you. Someone stuck, or a swap that looks like a jump.'),
    'bug4_open_archer': ('An archer among rats in the open.',
                         'Stand at the far side.',
                         'The archer holds back and shoots while the rats run past it.'),
    'bug5_boss_crowd': ('The Minotaur idling among rats.',
                        'Watch from the door without waking it, then step in.',
                        "Rats jittering in and out of the Minotaur's way while it stands or turns."),
    'manual_boss_chase_arena': ('A pillared arena with the Minotaur and its crowd.',
                                'Run circles round the pillars so they chase you.',
                                'Bug 5: rats jittering near the Minotaur. Archers should hold back and shoot. Anything standing in a wall.'),
    'manual_corridor_swap': ('A long 1-wide corridor: an archer with four rats behind it.',
                             'Enter from the far end.',
                             'Bug 4: the archer and rats should walk past each other. Say if the swap reads badly.'),
    'manual_minotaur_corners': ('Pillars with 1-wide gaps (Minotaur cannot use them) and open bands (2+).',
                                'Run the Minotaur through the pillars, changing side often.',
                                'The Minotaur standing in a wall or clipping a corner. (Screenshot it and note the tile from F4.)'),
    'manual_smash_or_walk': ('A thick wall with a long way round along the bottom.',
                             'Stand on the far side of the wall, then walk around it once.',
                             'Decide what it should do: walk round, smash, or both. Right now it walks to the wall, loses its target and never smashes.'),
    'terrain_lava': ('A lava band with a stone way round.', 'Stand across the band.',
                     'Walkers must route round; flyers may cross. Anything walking through lava.'),
    'terrain_water': ('A water band with a stone way round.', 'Stand across the band.',
                      'Walkers must route round; flyers may cross. Anything wading through.'),
    'terrain_acid': ('An acid band with a stone way round.', 'Stand across the band.',
                     'Walkers should take the stone way round, not wade through the acid (a flyer may cross). Acid will become a damaging tile later.'),
    'doors_widths': ('Minotaur, archer, rat and wraith behind 1, 2 and 3 wide wooden doors.',
                     'Open each door and step back.',
                     'The Minotaur cannot use the 1-wide door; everyone else should get out of theirs.'),
    'swarm_rats': ('About 60 rats in one room.', 'Open the door and fight or run.',
                   'Frame rate (F4 shows it) dropping badly, or rats stuck in a pile.'),
}


# ================= pack =================
def build_block(c):
    h, w = len(c['rows']), len(c['rows'][0])
    W, H = w + 2, h + 2
    floor = [[None] * W for _ in range(H)]
    walls = [[WALL] * W for _ in range(H)]
    spawns = []
    for y in range(h):
        for x in range(w):
            ch = c['rows'][y][x]
            if ch == '%':
                walls[y + 1][x + 1] = 'barrier_bedrock'  # cannot be smashed
                continue
            if ch == '#':
                continue
            walls[y + 1][x + 1] = None
            if ch == ' ':
                continue  # a hole: no floor, no wall
            floor[y + 1][x + 1] = TILE.get(ch, FLOOR)
            if ch in MINION:
                spawns.append((x + 1, y + 1, MINION[ch]))
    return dict(W=W, H=H, floor=floor, walls=walls, spawns=spawns, c=c)


blocks = [build_block(c) for c in cells]
upper, lower = [], []
for b in blocks:  # keep the two rows about the same length
    (upper if sum(x['W'] for x in upper) <= sum(x['W'] for x in lower) else lower).append(b)
HUB_H = 5
W = 2 + max(sum(b['W'] for b in upper), sum(b['W'] for b in lower))
UH = LH = max(b['H'] for b in upper + lower)  # equal, so the room's centre is in the hub
H = UH + HUB_H + LH
floor = [[None] * W for _ in range(H)]
walls = [[WALL] * W for _ in range(H)]
spawn_cells, objects, doors = [], [], []
cell_meta = []  # for test/sim/dev_cells.json: where each cell is, for the headless runner


def torch(x, y):
    objects.append({'type': 'torch', 'position': {'x': x * 16.0 + 8, 'y': y * 16.0 + 8}, 'rotation': 0.0})


for y in range(UH, UH + HUB_H):
    for x in range(1, W - 1):
        floor[y][x] = FLOOR
        walls[y][x] = None
for x in range(6, W - 1, 10):
    torch(x, UH)
    torch(x, UH + HUB_H - 1)


def place(b, ox, oy, door_side):
    for y in range(b['H']):
        for x in range(b['W']):
            floor[oy + y][ox + x] = b['floor'][y][x]
            walls[oy + y][ox + x] = b['walls'][y][x]
    c = b['c']
    gy = oy + (b['H'] - 1 if door_side == 'south' else 0)
    for i in range(c['door_w']):
        floor[gy][ox + 1 + c['door_x'] + i] = FLOOR
        walls[gy][ox + 1 + c['door_x'] + i] = None
    doors.append({'cell': {'x': ox + 1 + c['door_x'], 'y': gy}, 'orient': 'h', 'width': c['door_w'], 'type': 'wood'})
    for d in c['doors']:
        dx, dy = ox + 1 + d['x'], oy + 1 + d['y']
        doors.append({'cell': {'x': dx, 'y': dy}, 'orient': d['orient'], 'width': d['width'], 'type': 'wood'})
        if d['orient'] == 'h':
            for i in range(d['width']):
                floor[dy][dx + i] = FLOOR
                walls[dy][dx + i] = None
        else:
            for j in range(d['width']):
                for i in range(2):
                    floor[dy + j][dx + i] = FLOOR
                    walls[dy + j][dx + i] = None
    for (sx, sy, m) in b['spawns']:
        spawn_cells.append({'position': {'x': ox + sx, 'y': oy + sy}, 'minion': m})
    torch(ox + 1, oy + 1 if door_side == 'south' else oy + b['H'] - 2)
    # Entry tile: two tiles inside the cell from the door's first cell, on the door's side of the wall.
    step = -2 if door_side == 'south' else 2
    note = NOTES.get(c['name']) or ('%s alone in a plain room.' % c['name'].replace('minion_', ''), 'Open the door, then walk up to it, away from it and round it.',
                                    'It should notice you, chase or shoot as it is meant to, and never stand in a wall.')
    cell_meta.append({'name': c['name'], 'door': {'x': ox + 1 + c['door_x'], 'y': gy},
                      'entry': {'x': ox + 1 + c['door_x'], 'y': gy + step},
                      'rect': {'x': ox, 'y': oy, 'w': b['W'], 'h': b['H']},
                      'reach': REACH.get(c['name'], []), 'may_skip': c['name'] in MAY_SKIP,
                      'zone_changes_max': ZONE_CHANGES_MAX.get(c['name'], -1),
                      'wade_max': WADE_MAX.get(c['name'], -1),
                      'index': [k['name'] for k in cells].index(c['name']),
                      'player_at': ({'x': ox + 1 + PLAYER_AT[c['name']][0], 'y': oy + 1 + PLAYER_AT[c['name']][1]}
                                    if c['name'] in PLAYER_AT else None),
                      'what': note[0], 'try': note[1], 'look': note[2]})


x = 1
for b in upper:
    place(b, x, UH - b['H'], 'south')
    x += b['W']
x = 1
for b in lower:
    place(b, x, UH + HUB_H, 'north')
    x += b['W']

mid = UH + HUB_H // 2
for yy in (mid, mid + 1):
    for xx in (0, W - 1):
        walls[yy][xx] = None
connectors = [
    {'a': {'x': 0, 'y': mid}, 'b': {'x': 0, 'y': mid + 1}, 'free': True, 'door': 'none'},
    {'a': {'x': W - 1, 'y': mid}, 'b': {'x': W - 1, 'y': mid + 1}, 'free': True, 'door': 'none'}]
cx, cy = W // 2, H // 2
assert floor[cy][cx] == FLOOR and walls[cy][cx] is None, (cx, cy)


def room(rid, role, tags, w, h, fl, wl, conns, extra=None):
    d = {'format': 2, 'id': rid, 'width': w, 'height': h, 'role': role, 'tags': tags,
         'floor': fl, 'walls': wl, 'connectors': conns}
    if extra:
        d.update(extra)
    return d


def dump(d):
    def arr(a):
        return '[\n\t\t' + ',\n\t\t'.join(json.dumps(r) for r in a) + '\n\t]'
    parts = ['\t%s: %s' % (json.dumps(k), arr(v) if k in ('floor', 'walls') else json.dumps(v)) for k, v in d.items()]
    return '{\n' + ',\n'.join(parts) + '\n}\n'


os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.startswith('Development_') and f.endswith('.json'):
        os.remove(os.path.join(OUT, f))
hub_id = 'Development_Hub_%dx%d' % (W, H)
with open('%s/%s.json' % (OUT, hub_id), 'w', newline='\n') as fh:
    fh.write(dump(room(hub_id, 'entrance', ['development'], W, H, floor, walls, connectors,
                       {'spawn_cells': spawn_cells, 'doors': doors, 'objects': objects})))


def stub(rid, role, tags):
    fl = [[None] * 5 for _ in range(5)]
    wl = [[WALL] * 5 for _ in range(5)]
    for y in range(1, 4):
        for x in range(1, 4):
            fl[y][x] = FLOOR
            wl[y][x] = None
    wl[2][0] = None
    with open('%s/%s.json' % (OUT, rid), 'w', newline='\n') as fh:
        fh.write(dump(room(rid, role, tags, 5, 5, fl, wl,
                           [{'a': {'x': 0, 'y': 2}, 'b': {'x': 0, 'y': 2}, 'free': True, 'door': 'none'}])))


stub('Development_Boss_Stub_5x5', 'boss', ['development'])
stub('Development_Treasure_Stub_5x5', 'normal', ['development', 'treasure'])
os.makedirs('test/sim', exist_ok=True)
with open('test/sim/dev_cells.json', 'w', newline='\n') as fh:
    json.dump({'hub': hub_id, 'width': W, 'height': H, 'cells': cell_meta}, fh, indent=1)
    fh.write('\n')
print(hub_id, len(cells), 'cells,', len(spawn_cells), 'pinned spawns,', len(doors), 'doors')
for c in cells:
    print(' ', c['name'])
