import sys, collections, dive
for biome in sys.argv[1:]:
    base, rooms, defines = dive.load(biome)
    bosses = collections.Counter(); fails = 0; kinds = collections.Counter(); n = 0; sizes = []; vast = 0
    for seed in range(200):
        for a in range(20):
            P, ok, t = dive.generate(rooms, seed * 100 + a, defines)
            if ok: break
        if not ok: fails += 1
        for p in P:
            r = rooms[p['id']]; b = r['base']
            if r.get('role') == 'boss': bosses[b] += 1
            k = 'corridor' if r.get('role') == 'corridor' else 'maze' if 'maze' in r.get('tags', []) else r.get('role', 'normal')
            kinds[k] += 1; n += 1
            if 'vast' in r.get('tags', []): vast += 1
        sizes.append(sum(rooms[p['id']]['width'] * rooms[p['id']]['height'] for p in P))
    print(biome, 'fails', fails, dict(bosses), {k: '%.0f%%' % (100 * v / n) for k, v in kinds.items()},
          'avg rooms %.1f' % (n / 200), 'avg tiles %d' % (sum(sizes) / 200), 'vast/run %.2f' % (vast / 200))
