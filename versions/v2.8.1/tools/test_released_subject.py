"""Release event routing/guards and conversion contract checks, not an engine test.

Government, population-rights and vanilla council effects need the documented
in-game release test. Here their boundary is explicitly mocked, not reimplemented.
"""
import unittest
from test_feedback import Engine, Scope, country, read, get

class ReleaseEngine(Engine):
    def __init__(self, source):
        super().__init__()
        self.from_scope=source
        self.converted=[]
        self.external_events=[]
        self.created_leaders=0
        for key,_,block in read('events/rse_released_subject_events.txt'):
            if key=='country_event': self.events[get(block,'id')]=block
        self.triggers.update({key:block for key,_,block in read('common/scripted_triggers/rse_released_subject_triggers.txt')})
        self.conversion=dict((key,block) for key,_,block in read('common/scripted_effects/rse_released_subject_effects.txt'))['rse_establish_released_servitor']

    def scope(self,key,s):
        if key=='from': return self.from_scope
        if key=='overlord': return getattr(s,'overlord',None)
        if key=='owner_main_species': return getattr(s,'main_species',None)
        return super().scope(key,s)

    def condition(self,k,op,v,s):
        if k in ('from','overlord','owner_main_species'): return self.test(v,self.scope(k,s))
        if k=='rse_is_rogue_servitor': return ('servitor' in s.flags)==(v=='yes')
        if k=='is_country_type': return v=='default'
        return super().condition(k,op,v,s)

    def execute(self,block,s):
        # Release events only use standalone if blocks (no if/else chains).
        for entry in block:
            k,_,v=entry
            if k in ('from','owner_main_species'):
                self.execute(v,self.scope(k,s))
            elif k=='rse_establish_released_servitor':
                guard=get(get(self.conversion,'if'),'limit')
                if self.test(guard,s):
                    self.converted.append(s)
                    s.flags.update(('rse_released_subject_converted','servitor'))
            elif k=='country_event' and get(v,'id').startswith('game_start.'):
                self.external_events.append(get(v,'id'))
            elif k=='create_leader': self.created_leaders+=1
            elif k=='refresh_leader_pool': pass
            elif k=='ai_chance': pass
            else: super().execute([entry],s)

def setup():
    parent=country();parent.flags.add('servitor');parent.main_species=Scope(robotic=True)
    child=Scope();child.overlord=parent
    child.main_species=Scope(robotic=False,traits={'trait_rse_protected_founder'})
    return ReleaseEngine(parent),parent,child

class ReleaseTests(unittest.TestCase):
    def test_offer_once_decline_has_no_conversion(self):
        e,parent,child=setup()
        e.event('rse_subject.1',child);e.event('rse_subject.1',child)
        self.assertEqual(len(e.queue),1)
        self.assertIs(e.targets['rse_released_subject'],child)
        e.tick()
        before=set(child.flags)
        e.option('rse_subject.2','rse_subject.2.keep',parent)
        self.assertEqual(child.flags,before)
        self.assertFalse(e.converted)

    def test_conversion_guard_and_concurrent_offers(self):
        e,parent,child=setup()
        second=Scope();second.overlord=parent;second.main_species=child.main_species
        e2=ReleaseEngine(parent) # independent local event-chain targets
        e.event('rse_subject.1',child);e2.event('rse_subject.1',second)
        e.tick();e2.tick()
        e.option('rse_subject.2','rse_subject.2.convert',parent)
        self.assertEqual([id(x) for x in e.converted],[id(child)])
        self.assertNotIn('rse_released_subject_converted',second.flags)
        with self.assertRaises(AssertionError): e.option('rse_subject.2','rse_subject.2.convert',parent)
        e2.option('rse_subject.2','rse_subject.2.convert',parent)
        self.assertEqual([id(x) for x in e2.converted],[id(second)])

    def test_changed_overlord_and_noneligible_releases(self):
        for mode in ('foreign','machine','route','independent'):
            e,parent,child=setup()
            if mode=='foreign': child.main_species.traits.clear()
            elif mode=='machine': child.main_species.robotic=True
            elif mode=='route': parent.flags.discard('rse_route_exclusive_service')
            else: child.overlord=None
            e.event('rse_subject.1',child)
            self.assertFalse(e.queue)
        e,parent,child=setup()
        e.event('rse_subject.1',child);e.tick()
        child.overlord=Scope()
        with self.assertRaises(AssertionError): e.option('rse_subject.2','rse_subject.2.convert',parent)
        e.option('rse_subject.2','rse_subject.2.keep',parent)
        self.assertFalse(e.converted)

    def test_council_initialization_once(self):
        e,parent,child=setup()
        child.flags.update(('servitor','rse_released_subject_converted'))
        e.event('rse_subject.3',child);e.event('rse_subject.3',child)
        self.assertEqual(e.external_events,['game_start.70','game_start.71'])
        self.assertEqual(e.created_leaders,3)

    def test_no_war_side_effects_and_flat_agenda(self):
        effects=read('common/scripted_effects/rse_released_subject_effects.txt')
        def keys(nodes):
            for key,_,value in nodes:
                yield key
                if isinstance(value,list): yield from keys(value)
        forbidden={'set_subject_of','set_agreement_terms','set_purge_type','save_global_event_target_as','rse_convert_to_supervisory_zone'}
        self.assertFalse(forbidden & set(keys(effects)))
        body=get(get(effects,'rse_establish_released_servitor'),'if')
        self.assertEqual(get(get(body,'change_dominant_species'),'change_all'),'no')
        self.assertEqual(get(get(body,'change_government'),'authority'),'auth_machine_intelligence')
        self.assertIn('rse_released_subject_converted',str(get(body,'limit')))
        agenda=get(read('common/council_agendas/rse_agendas.txt'),'agenda_rse_expand_service')
        self.assertEqual(get(get(agenda,'modifier'),'planet_pop_assembly_add'),'5')
        self.assertIsNone(get(get(agenda,'modifier'),'planet_pop_assembly_mult'))
        finish=get(read('common/static_modifiers/rse_static_modifiers.txt'),'rse_agenda_expand_service')
        self.assertEqual(get(finish,'planet_pop_assembly_add'),'10')
        self.assertIsNone(get(finish,'planet_pop_assembly_mult'))
        self.assertEqual(get(agenda,'agenda_finish_modifier_duration'),'1800')
        self.assertEqual(get(agenda,'agenda_cooldown'),'3600')

if __name__=='__main__': unittest.main(verbosity=2)
