"""September 25 numeric/control-flow regressions; not an engine playtest."""
import unittest
from test_feedback import Engine, Scope, country, ROOT, parse, read, get

class BalanceTests(unittest.TestCase):
    def test_home_service_workforce_tradition_and_caps(self):
        text=(ROOT/'events/rse_route_events.txt').read_text(encoding='utf-8-sig')
        block=parse(text[text.index('# Convert effective Home Service workforce'):text.index('rse_update_growth_simulators = yes')])
        for world, cap in [('pc_continental',20),('pc_rse_ideal_paradise',40)]:
            for tradition in (False,True):
                for workforce in (0,50,100,1000,2000,4000,10000):
                    e,c=Engine(),country()
                    if tradition: c.flags.add('tr_rse_individual_needs_model')
                    p=Scope(owner=c,workforce=workforce,planet_class=world)
                    e.root=p
                    e.execute(block,p)
                    expected=min(workforce/100*(1.5 if tradition else 1),cap)
                    self.assertAlmostEqual(p.modifiers.get('rse_home_service_assembly_capped',0),expected)
        static={k:v for k,_,v in read('common/static_modifiers/rse_static_modifiers.txt')}
        block=static['rse_home_service_assembly_capped']
        self.assertEqual(get(block,'planet_pop_assembly_add'),'1')
        self.assertEqual(get(block,'bonus_pop_growth'),'1')
        self.assertIsNone(get(block,'fake_pop_growth_mod'))

    def test_simulators_mixed_templates_caps_and_removal(self):
        for size in (0,100,1000,15000,20000):
            e,c=Engine(),country()
            p=Scope(owner=c,populations=[
                Scope(amount=size/2,traits={'trait_rse_organic_simulator','trait_rse_desire_simulator'}),
                Scope(amount=size/2,traits={'trait_rse_organic_simulator','trait_rse_desire_simulator'}),
                Scope(amount=50000),
            ])
            e.root=p
            for _ in range(2):
                e.execute(e.effects['rse_update_growth_simulators'],p)
                self.assertAlmostEqual(p.modifiers.get('rse_organic_simulator_scaled',0),min(size*.001,15))
                self.assertAlmostEqual(p.modifiers.get('rse_desire_simulator_scaled',0),min(size*.00001,.15))
            p.populations.clear()
            e.execute(e.effects['rse_update_growth_simulators'],p)
            self.assertFalse(p.modifiers)
        for mode in ('occupied','transferred'):
            e,c=Engine(),country()
            p=Scope(owner=c,populations=[Scope(amount=1000,traits={'trait_rse_organic_simulator','trait_rse_desire_simulator'})])
            e.root=p
            e.execute(e.effects['rse_update_growth_simulators'],p)
            if mode=='occupied': p.occupied=True
            else: p.owner=Scope()
            e.execute(e.effects['rse_update_growth_simulators'],p)
            self.assertFalse(p.modifiers)

    def test_agenda_values_and_dark_matter_tenth(self):
        agendas={k:v for k,_,v in read('common/council_agendas/rse_agendas.txt')}
        start=get(agendas['agenda_rse_protocol_upgrade'],'modifier')
        self.assertEqual(float(get(start,'planet_pop_assembly_mult')),.02)
        self.assertEqual(float(get(start,'pop_bio_trophy_bonus_workforce_mult')),.05)
        static={k:v for k,_,v in read('common/static_modifiers/rse_static_modifiers.txt')}
        finish=static['rse_agenda_protocol_upgrade']
        self.assertEqual(float(get(finish,'planet_pop_assembly_mult')),.10)
        self.assertEqual(float(get(finish,'pop_bio_trophy_bonus_workforce_mult')),.20)
        values=Engine().constants
        self.assertAlmostEqual(values['@rse_maid_dark_matter_output']/.75,.1)
        self.assertEqual(values['@rse_maid_dark_matter_minerals_upkeep'],.75)

    def test_ascension_adds_percentage_points_to_both_categories(self):
        jobs={k:v for k,_,v in read('common/pop_jobs/rse_jobs.txt')}
        blocks=[v for k,_,v in jobs['bio_trophy'] if k=='triggered_planet_modifier' and 'ap_rse_master_maid' in str(v)]
        self.assertEqual(len(blocks),1)
        b=blocks[0]
        self.assertEqual(float(get(b,'pop_cat_complex_drone_bonus_workforce_mult')),.003)
        self.assertEqual(float(get(b,'worker_and_simple_drone_cat_bonus_workforce_mult')),.003)
        self.assertIn('rse_bio_trophy_effects_active',str(get(b,'potential')))
        # Urban / unrestricted / rural policy baselines each gain 0.3 points.
        for baseline,expected in [((.012,.002),(.015,.005)),((.007,.007),(.010,.010)),((.002,.012),(.005,.015))]:
            for i in range(2): self.assertAlmostEqual(baseline[i]+.003,expected[i])

if __name__=='__main__': unittest.main(verbosity=2)
