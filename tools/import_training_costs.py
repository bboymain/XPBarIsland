"""Import Forever base prices from a local What's Training 11.4.5 checkout."""
import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
REVISION = '4b0ccdf214680ba1d5bd8805dbca71e30c59b82d'
CLASSES = ('Warrior', 'Paladin', 'Hunter', 'Rogue', 'Priest', 'Shaman', 'Mage', 'Warlock', 'Druid')


def generate(source):
    lua = LuaRuntime()
    lua.execute('classes = {}; wt = {forClass = function(c) classes[c] = {}; return classes[c] end}')
    result = [
        'local ADDON, ns = ...', '',
        "-- Forever base training prices from What's Training 11.4.5 (trainer-derived data).",
        '-- https://github.com/fusionpit/WhatsTraining/tree/' + REVISION + '/Classes/Camelot',
        '-- Imported 2026-11-12. MIT license: see THIRD_PARTY_NOTICES.txt.',
        '-- Regenerate: python tools/import_training_costs.py <WhatsTraining checkout>',
        '-- Trainer-cache prices override these base prices, including discounts.',
        '-- Missing spell IDs stay unknown; no Classic-price substitution.',
        '-- Format: CLASS[spellID] = { level = learnedLevel, cost = copper }',
        'ns.trainingCosts = {',
    ]
    for name in CLASSES:
        path = source / 'Classes' / 'Camelot' / (name + '.lua')
        lua.execute('local _, wt = "WhatsTraining", wt\n' + path.read_text().replace('local _, wt = ...', ''))
        prices = {}
        for level, rows in lua.globals().classes[name.upper()].spellsByLevel.items():
            for _, row in rows.items():
                spell_id, cost = row['id'], row['cost']
                assert isinstance(spell_id, int) and spell_id > 0
                assert isinstance(level, int) and 1 <= level <= 60
                assert isinstance(cost, int) and cost >= 0
                entry = (level, cost)
                assert spell_id not in prices or prices[spell_id] == entry, f'Conflicting price: {name} {spell_id}'
                prices[spell_id] = entry
        assert prices, name
        result.append('    ' + name.upper() + ' = {')
        for spell_id, (level, cost) in sorted(prices.items()):
            result.append(f'        [{spell_id}] = {{ level = {level}, cost = {cost} }},')
        result.append('    },')
    result.extend(['}', ''])
    return '\n'.join(result)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    import subprocess
    revision = subprocess.check_output(['git', '-C', str(args.source), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != REVISION:
        parser.error('Use the pinned 11.4.5 revision ' + REVISION)
    target = ROOT / 'Data' / 'TrainingCosts.lua'
    current = target.read_text()
    helpers = current[current.index('local function spellKey'):]
    target.write_text(generate(args.source) + '\n' + helpers, encoding='utf-8')
    license_text = (args.source / 'LICENSE').read_text()
    (ROOT / 'THIRD_PARTY_NOTICES.txt').write_text(
        "Training price data adapted from What's Training? 11.4.5\n"
        'https://github.com/fusionpit/WhatsTraining\n\n' + license_text, encoding='utf-8')
    print('Imported all nine Forever class price tables; retained lookup and trainer-cache logic.')
