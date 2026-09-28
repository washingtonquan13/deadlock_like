"""Writes sim replay scenarios for F: FSW/FSD/FSA/FSWA as recorded, plus a strafe_mult=0.87 counterfactual (s6 DRD 336/386)."""
import json, os
here = os.path.dirname(os.path.abspath(__file__)); src = os.path.join(here, '..', 's7_open')
for n in ['FSW', 'FSD', 'FSA', 'FSWA']:
    s = json.load(open(os.path.join(src, n + '.json')))
    json.dump(s, open(os.path.join(here, 'sim_%s.json' % n), 'w'), indent=1)
    s2 = dict(s); s2['fixed'] = {'strafe_mult': 0.87}
    json.dump(s2, open(os.path.join(here, 'sim_%s_sm087.json' % n), 'w'), indent=1)
