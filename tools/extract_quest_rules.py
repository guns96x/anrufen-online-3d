"""Decode quest footer structures; keep undecoded fields rather than guess them.

Reward section byte lengths validate the structure independently of the text.
The first apparent 'reward' number is a byte length, NOT money. Three original
records store a zero length; their otherwise valid layout is flagged explicitly.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def decode(row):
    words = row['footer_words']
    arity = words[4]
    assert 0 <= arity <= 3
    pos = 5 + arity
    minimum_level, unknown = words[pos:pos + 2]
    pos += 2
    byte_length, currency_amount, experience_amount, reward_mode, count = words[pos:pos + 5]
    length_valid = byte_length == (len(words) - pos - 3) * 4
    assert length_valid or row['id'] in (80288, 80061, 80062)
    pos += 5
    items = []
    for _ in range(count):
        item_id, quantity, conditional = words[pos:pos + 3]
        pos += 3
        assert 10000 <= item_id < 40000 and 1 <= quantity <= 1000000
        assert conditional in (0, 1)
        entry = dict(id=item_id, quantity=quantity, conditional=bool(conditional))
        if conditional:
            entry['condition_words'] = words[pos:pos + 7]
            pos += 7
        items.append(entry)
    assert words[pos] == 0
    title_count = words[pos + 1]
    pos += 2
    titles = words[pos:pos + title_count]
    assert all(180000 <= title < 190000 for title in titles)
    pos += title_count
    return dict(id=row['id'], next_id=row['next_id'], giver_id=row['giver_id'],
                turnin_id=row['turnin_id'], giver_scene=row['giver_scene'],
                turnin_scene=row['turnin_scene'], source_type=words[3],
                counters=words[5:5 + arity], minimum_turnin_level=minimum_level,
                unknown_pre_reward=unknown, reward_amounts=[currency_amount, experience_amount],
                reward_mode=reward_mode, items=items, titles=titles,
                remaining_words=words[pos:], reward_length_valid=length_valid)


def extract():
    source = json.loads((ROOT/'data/original/quest_graph.json').read_text(encoding='utf-8'))
    quests = {key: decode(row) for key, row in source['quests'].items()}
    assert len(quests) == 712
    assert quests['80004']['reward_amounts'] == [300, 45]
    assert quests['80004']['titles'] == [180049]
    assert quests['80005']['counters'] == [1, 1, 1]
    assert quests['80005']['minimum_turnin_level'] == 8
    assert [x['id'] for x in quests['80006']['items']] == [30000, 30024]
    return dict(archive_sha256=source['archive_sha256'], quests=quests,
                caveats=['Objective actor/item IDs and acceptance prerequisites are not stored '
                         'in this footer. Conditional reward words and source_type/reward_mode '
                         'are preserved without assigning unverified semantics.',
                         'Runtime interprets reward_amounts as currency then experience. '
                         'This mapping is inferred from the purchase tutorial and progression '
                         'across level-gated quests; the client has no field names.'])


if __name__ == '__main__':
    result = extract()
    (ROOT/'data/original/quest_rules.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('QUEST_RULES: 712 decoded; 709 byte lengths verified; 3 source zero-length exceptions')
