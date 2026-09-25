"""Execute the feedback scripts in a limited deterministic test harness.

This checks script control flow, NOT Stellaris engine timing, modifier cache,
UI formatting or scope acceptance. Those remain in TEST_CHECKLIST.md.
"""
from pathlib import Path
from dataclasses import dataclass, field
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

def parse(text):
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|#[^\n]*|>=|<=|!=|[{}=<>]|[^\s{}=<>]+', text)
    tokens = [t for t in tokens if not t.startswith('#')]
    pos = 0
    def block(nested=False):
        nonlocal pos
        entries = []
        while pos < len(tokens) and tokens[pos] != '}':
            if tokens[pos + 1] not in ('=', '>', '<', '>=', '<=', '!='):
                entries.append((tokens[pos], 'list', tokens[pos]))
                pos += 1
                continue
            key, op = tokens[pos:pos + 2]
            pos += 2
            assert op in ('=', '>', '<', '>=', '<=', '!='), (key, op)
            if tokens[pos] == '{':
                pos += 1
                val = block(True)
            else:
                val = tokens[pos].strip('"')
                pos += 1
            entries.append((key, op, val))
        if nested:
            assert tokens[pos] == '}'
            pos += 1
        return entries
    return block()

def get(block, key, default=None):
    return next((v for k, _, v in block if k == key), default)

def read(path):
    return parse((ROOT / path).read_text(encoding='utf-8-sig'))

@dataclass
class Scope:
    owner: object = None
    variables: dict = field(default_factory=dict)
    flags: set = field(default_factory=set)
    traits: set = field(default_factory=set)
    leaders: list = field(default_factory=list)
    buildings: set = field(default_factory=set)
    modifiers: dict = field(default_factory=dict)
    durations: dict = field(default_factory=dict)
    leader_class: str = 'scientist'
    robotic: bool = True
    ruler: bool = False
    node: bool = False
    occupied: bool = False
    skill: int = 5
    capacity: float = 0
    populations: list = field(default_factory=list)
    amount: float = 0
    workforce: float = 0
    planet_class: str = 'pc_continental'

class Engine:
    def __init__(self):
        self.events, self.effects, self.triggers = {}, {}, {}
        self.targets, self.queue = {}, []
        self.root = None
        self.constants = {k: float(v) for k, _, v in read('common/scripted_variables/rse_variables.txt')}
        for path in ('events/rse_conversion_events.txt', 'events/rse_leader_picker_events.txt', 'events/rse_leader_events.txt'):
            for k, _, v in read(path):
                if k.endswith('_event'):
                    self.events[get(v, 'id')] = v
        for path in ('common/scripted_effects/rse_leader_picker_effects.txt', 'common/scripted_effects/rse_growth_effects.txt'):
            self.effects.update({k: v for k, _, v in read(path)})
        for path in ('common/scripted_triggers/rse_leader_picker_triggers.txt', 'common/scripted_triggers/rse_conversion_triggers.txt'):
            self.triggers.update({k: v for k, _, v in read(path)})
        self.triggers['rse_has_exclusive_route'] = [('has_country_flag', '=', 'rse_route_exclusive_service')]
        self.static = {k: v for k, _, v in read('common/static_modifiers/rse_static_modifiers.txt')}

    def scope(self, key, s):
        if key == 'root': return self.root
        if key == 'owner': return s.owner
        if key.startswith('event_target:'): return self.targets.get(key.split(':', 1)[1])
        raise AssertionError(key)

    def number(self, v, s):
        if v.startswith('@'): return self.constants[v]
        try: return float(v)
        except ValueError: pass
        if v.startswith('root.'): return self.root.variables[v[5:]]
        return s.variables[v]

    @staticmethod
    def compare(a, op, b):
        return {'=': a == b, '>': a > b, '<': a < b, '>=': a >= b, '<=': a <= b, '!=': a != b}[op]

    def test(self, block, s):
        if s is None: return False
        return all(self.condition(k, op, v, s) for k, op, v in block)

    def condition(self, k, op, v, s):
        if k in ('OR', 'NOR'):
            result = any(self.condition(a, b, c, s) for a, b, c in v)
            return result if k == 'OR' else not result
        if k in ('NOT', 'NAND'): return not self.test(v, s)
        if k in self.triggers: return self.test(self.triggers[k], s) == (v == 'yes')
        if k in ('has_country_flag', 'has_carrier_flag'): return v in s.flags
        if k == 'has_trait': return v in s.traits
        if k == 'exists': return self.scope(v, s) is not None
        if k in ('owner', 'root') or k.startswith('event_target:'): return self.test(v, self.scope(k, s))
        if k == 'any_owned_leader': return any(self.test(v, x) for x in s.leaders)
        if k == 'is_same_value': return s is self.scope(v, s)
        if k == 'leader_class': return s.leader_class == v
        if k in ('is_robotic_species', 'is_ruler', 'is_gestalt_node', 'is_occupied_flag'):
            attr = {'is_robotic_species': 'robotic', 'is_ruler': 'ruler', 'is_gestalt_node': 'node', 'is_occupied_flag': 'occupied'}[k]
            return getattr(s, attr) == (v == 'yes')
        if k == 'has_base_skill': return self.compare(s.skill, op, float(v))
        if k == 'has_tradition': return v in s.flags
        if k == 'is_planet_class': return v == s.planet_class
        if k == 'is_variable_set': return v in s.variables
        if k == 'check_variable':
            _, cmp, rhs = next(x for x in v if x[0] == 'value')
            return self.compare(s.variables[get(v, 'which')], cmp, self.number(rhs, s))
        if k == 'has_modifier': return v in s.modifiers
        if k == 'has_active_building': return v in s.buildings
        raise AssertionError(('unimplemented trigger', k))

    def execute(self, block, s):
        previous = False
        for k, _, v in block:
            if k == 'if':
                previous = self.test(get(v, 'limit', []), s)
                if previous: self.execute([x for x in v if x[0] != 'limit'], s)
            elif k == 'else':
                if not previous: self.execute(v, s)
            elif k == 'else_if':
                if not previous:
                    previous = self.test(get(v, 'limit', []), s)
                    if previous: self.execute([x for x in v if x[0] != 'limit'], s)
            elif k in ('hidden_effect',): self.execute(v, s)
            elif k in self.effects: self.execute(self.effects[k], s)
            elif k in ('root', 'owner') or k.startswith('event_target:'):
                self.execute(v, self.scope(k, s))
            elif k == 'every_owned_leader':
                for leader in list(s.leaders):
                    if self.test(get(v, 'limit', []), leader): self.execute([x for x in v if x[0] != 'limit'], leader)
            elif k in ('set_variable', 'change_variable', 'divide_variable', 'multiply_variable'):
                name, value = get(v, 'which'), self.number(get(v, 'value'), s)
                if k == 'set_variable': s.variables[name] = value
                elif k == 'change_variable': s.variables[name] += value
                elif k == 'multiply_variable': s.variables[name] *= value
                else: s.variables[name] /= value
            elif k == 'clear_variable': s.variables.pop(v, None)
            elif k in ('set_country_flag', 'set_carrier_flag'): s.flags.add(v)
            elif k in ('remove_country_flag', 'remove_carrier_flag'): s.flags.discard(v)
            elif k == 'save_event_target_as': self.targets[v] = s
            elif k == 'add_trait': s.traits.add(get(v, 'trait'))
            elif k == 'remove_trait': s.traits.discard(v)
            elif k == 'set_timed_country_flag':
                s.flags.add(get(v, 'flag'))
                s.durations[get(v, 'flag')] = self.number(get(v, 'days'), s)
            elif k in ('country_event', 'colony_event'):
                if get(v, 'days'): self.queue.append((get(v, 'id'), s))
                else: self.event(get(v, 'id'), s)
            elif k == 'remove_modifier': s.modifiers.pop(v, None)
            elif k == 'export_modifier_to_variable':
                key = get(v, 'modifier')
                value = s.capacity if key == 'job_patrol_drone_add' else 0
                for mod, mult in s.modifiers.items(): value += float(get(self.static[mod], key, 0)) * mult
                s.variables[get(v, 'variable')] = value
            elif k == 'export_trigger_value_to_variable':
                trigger = get(v, 'trigger')
                if trigger == 'count_owned_pop_amount':
                    limit = get(get(v, 'parameters'), 'limit')
                    value = sum(p.amount for p in s.populations if self.test(limit, p))
                elif trigger == 'total_workforce_with_job_tag':
                    assert get(get(v, 'parameters'), 'tags') == [('rse_home_service', 'list', 'rse_home_service')]
                    value = s.workforce
                else: raise AssertionError(trigger)
                s.variables[get(v, 'variable')] = value
            elif k == 'add_modifier': s.modifiers[get(v, 'modifier')] = self.number(get(v, 'multiplier'), s)
            elif k in ('check_planet_employment', 'custom_tooltip'): pass
            else: raise AssertionError(('unimplemented effect', k))

    def event(self, name, s):
        self.root = s
        block = self.events[name]
        if self.test(get(block, 'trigger', []), s): self.execute(get(block, 'immediate', []), s)

    def option(self, event, name, s):
        self.root = s
        opt = next(v for k, _, v in self.events[event] if k == 'option' and get(v, 'name') == name)
        assert self.test(get(opt, 'trigger', []), s), name
        self.execute([x for x in opt if x[0] not in ('name', 'trigger')], s)

    def tick(self):
        pending, self.queue = self.queue, []
        for name, s in pending: self.event(name, s)

def country():
    s = Scope()
    s.flags.update(('rse_route_exclusive_service', 'rse_surrounded_traits_unlocked'))
    return s

class FeedbackTests(unittest.TestCase):
    def test_capacity_rescan_upgrade_demolition_and_duplicate_hooks(self):
        e, c = Engine(), country()
        p = Scope(owner=c, capacity=300, buildings={'building_rse_maid_base'})
        for capacity in (300, 500, 100, 0, 400):
            p.capacity = capacity
            e.event('rse_conversion.1', p)
            e.event('rse_conversion.1', p)
            self.assertEqual(len(e.queue), 1)
            e.tick()
            self.assertEqual(p.modifiers.get('rse_patrol_capacity_conversion', 0) * 100, capacity)
            e.event('rse_conversion.2', p)  # duplicate delayed callback is inert
            self.assertEqual(p.modifiers.get('rse_patrol_capacity_conversion', 0) * 100, capacity)
            # Even forced dispatch that skips the event trigger remains inert.
            e.execute(get(e.events['rse_conversion.2'], 'immediate'), p)
            self.assertEqual(p.modifiers.get('rse_patrol_capacity_conversion', 0) * 100, capacity)
        p.buildings.add('building_rse_maid_center')
        e.event('rse_conversion.3', p); e.tick()
        self.assertEqual(p.modifiers['rse_patrol_capacity_conversion'], 4)
        p.buildings.clear()
        e.event('rse_conversion.1', p)
        self.assertFalse(p.modifiers)

    def test_transfer_occupation_and_demolition_during_delay(self):
        for mode in ('transfer', 'occupation', 'demolition'):
            e, c = Engine(), country()
            p = Scope(owner=c, capacity=100, buildings={'building_rse_maid_base'})
            e.event('rse_conversion.1', p)
            if mode == 'transfer': p.owner = Scope()
            elif mode == 'occupation': p.occupied = True
            else: p.buildings.clear()
            e.tick()
            self.assertFalse(p.modifiers)

    def test_pagination_and_cancel(self):
        for cls in ('official', 'commander', 'scientist'):
            for n in (1, 4, 5, 8, 9, 17):
                e, c = Engine(), country()
                c.leaders = [Scope(owner=c, leader_class=cls) for _ in range(n)]
                e.event('rse_picker.1', c)
                e.option('rse_picker.1', 'rse_picker.class_' + cls, c)
                seen = []
                for page in range((n + 3) // 4):
                    slots = [e.targets[f'rse_picker_candidate_{i}'] for i in range(1, 5) if f'rse_picker_slot_{i}' in c.flags]
                    self.assertEqual([id(x) for x in slots], [id(x) for x in c.leaders[page*4:page*4+4]])
                    seen.extend(slots)
                    if n > 4: e.option('rse_picker.2', 'rse_picker.next', c)
                self.assertEqual(len({id(x) for x in seen}), n)
                self.assertEqual(c.variables['rse_picker_offset'], 0)
                e.option('rse_picker.2', 'rse_picker.cancel', c)
                self.assertNotIn('rse_picker_open', c.flags)
                self.assertNotIn('rse_surrounded_selection_cooldown', c.flags)

    def test_eligibility_cooldown_and_selected_only(self):
        e, c = Engine(), country()
        chosen = Scope(owner=c)
        c.leaders = [chosen, Scope(owner=c, skill=4), Scope(owner=c, robotic=False), Scope(owner=c, ruler=True), Scope(owner=c, node=True), Scope(owner=c, traits={'leader_trait_rse_bridal'})]
        e.event('rse_picker.1', c)
        e.option('rse_picker.1', 'rse_picker.class_scientist', c)
        self.assertEqual(c.variables['rse_picker_count'], 1)
        e.option('rse_picker.2', 'rse_picker.candidate_1', c)
        self.assertEqual(c.durations['rse_surrounded_selection_cooldown'], 720)
        e.option('rse_proto.201', 'rse_proto.201.a', c)
        self.assertIn('leader_trait_rse_bridal', chosen.traits)
        self.assertNotIn('leader_trait_rse_surrounded_pending', chosen.traits)
        self.assertTrue(all('leader_trait_rse_bridal' not in x.traits for x in c.leaders[1:5]))

    def test_empty_class_and_stale_candidate(self):
        e, c = Engine(), country()
        e.event('rse_picker.1', c)
        with self.assertRaises(AssertionError): e.option('rse_picker.1', 'rse_picker.class_scientist', c)
        c.leaders = [Scope(owner=c)]
        e.option('rse_picker.1', 'rse_picker.class_scientist', c)
        c.leaders[0].owner = Scope()
        with self.assertRaises(AssertionError): e.option('rse_picker.2', 'rse_picker.candidate_1', c)
        self.assertNotIn('rse_surrounded_selection_cooldown', c.flags)

if __name__ == '__main__':
    unittest.main(verbosity=2)
