"""Erzeugt data/fixtures/catalog.json aus kompakten, manuell geprüften Tabellen.

Nur ein Hilfsskript für den Beispielkatalog; die echte Pipeline wird tools/data_pipeline (Dart).
"""
import json, pathlib

RB, XY, SM, SV = "red-blue", "x-y", "sun-moon", "scarlet-violet"
OK, GAP, NO = "confirmed_available", "not_researched", "confirmed_unavailable"

def g1(hp, atk, de, sp, spe): return {"hp": hp, "atk": atk, "def": de, "special": sp, "spe": spe}
def st(hp, atk, de, spa, spd, spe): return {"hp": hp, "atk": atk, "def": de, "spa": spa, "spd": spd, "spe": spe}
def ab(*ids, hidden=None):
    out = [{"id": i} for i in ids]
    if hidden: out.append({"id": hidden, "hidden": True})
    return out

def prof(av, types=None, stats=None, abilities=None):
    p = {"availability": av}
    if types: p["types"] = types
    if stats: p["stats"] = stats
    if abilities: p["abilities"] = abilities
    return p

def line(rb_stats, modern, types, abil, sm=GAP, sv=GAP):
    profiles = {
        RB: prof(OK, types, rb_stats),
        XY: prof(OK, types, modern, abil),
        SM: prof(sm, types if sm == OK else None, modern if sm == OK else None, abil if sm == OK else None),
        SV: prof(sv, types if sv == OK else None, modern if sv == OK else None, abil if sv == OK else None),
    }
    return {k: v for k, v in profiles.items()}

species = []
forms = []
def add(num, sid, de, en, profiles, aliases=None, form_id=None, form_name=None, default=True):
    if form_id is None:
        species.append({"id": sid, "national": num, "name": {"de": de, "en": en}, **({"aliases": aliases} if aliases else {})})
    f = {"id": form_id or sid, "species": sid, "default": default, "profiles": profiles}
    if form_name: f["name"] = form_name
    forms.append(f)

gp = ["grass", "poison"]; fi = ["fire"]; ff = ["fire", "flying"]; wa = ["water"]
add(1, "bulbasaur", "Bisasam", "Bulbasaur", line(g1(45,49,49,65,45), st(45,49,49,65,65,45), gp, ab("overgrow", hidden="chlorophyll")))
add(2, "ivysaur", "Bisaknosp", "Ivysaur", line(g1(60,62,63,80,60), st(60,62,63,80,80,60), gp, ab("overgrow", hidden="chlorophyll")))
add(3, "venusaur", "Bisaflor", "Venusaur", line(g1(80,82,83,100,80), st(80,82,83,100,100,80), gp, ab("overgrow", hidden="chlorophyll")))
add(4, "charmander", "Glumanda", "Charmander", line(g1(39,52,43,50,65), st(39,52,43,60,50,65), fi, ab("blaze", hidden="solar-power")))
add(5, "charmeleon", "Glutexo", "Charmeleon", line(g1(58,64,58,65,80), st(58,64,58,80,65,80), fi, ab("blaze", hidden="solar-power")))
add(6, "charizard", "Glurak", "Charizard", line(g1(78,84,78,85,100), st(78,84,78,109,85,100), ff, ab("blaze", hidden="solar-power")))
add(7, "squirtle", "Schiggy", "Squirtle", line(g1(44,48,65,50,43), st(44,48,65,50,64,43), wa, ab("torrent", hidden="rain-dish")))
add(8, "wartortle", "Schillok", "Wartortle", line(g1(59,63,80,65,58), st(59,63,80,65,80,58), wa, ab("torrent", hidden="rain-dish")))
add(9, "blastoise", "Turtok", "Blastoise", line(g1(79,83,100,85,78), st(79,83,100,85,105,78), wa, ab("torrent", hidden="rain-dish")))

el = ["electric"]; pika_ab = ab("static", hidden="lightning-rod")
pika_modern = st(35,55,40,50,50,90)
add(25, "pikachu", "Pikachu", "Pikachu", {
    RB: prof(OK, el, g1(35,55,30,50,90)),
    XY: prof(OK, el, pika_modern, pika_ab),
    SM: prof(OK, el, pika_modern, pika_ab),
    SV: prof(OK, el, pika_modern, pika_ab),
})
rai_modern = st(60,90,55,90,80,110)
add(26, "raichu", "Raichu", "Raichu", {
    RB: prof(OK, el, g1(60,90,55,90,100)),
    XY: prof(OK, el, rai_modern, pika_ab),
    SM: prof(OK, el, rai_modern, pika_ab),
    SV: prof(OK, el, rai_modern, pika_ab),
})
add(26, "raichu", None, None, {
    RB: prof(NO), XY: prof(NO),
    SM: prof(OK, ["electric", "psychic"], st(60,85,50,95,85,110), ab("surge-surfer")),
    SV: prof(GAP),
}, form_id="raichu-alola", form_name={"de": "Alola-Raichu", "en": "Alolan Raichu"}, default=False)

cle_ab = ab("cute-charm", "magic-guard", hidden="friend-guard")
add(35, "clefairy", "Piepi", "Clefairy", {
    RB: prof(OK, ["normal"], g1(70,45,48,60,35)),
    XY: prof(OK, ["fairy"], st(70,45,48,60,65,35), cle_ab),
    SM: prof(OK, ["fairy"], st(70,45,48,60,65,35), cle_ab),
    SV: prof(GAP),
})
cla_ab = ab("cute-charm", "magic-guard", hidden="unaware")
add(36, "clefable", "Pixi", "Clefable", {
    RB: prof(OK, ["normal"], g1(95,70,73,85,60)),
    XY: prof(OK, ["fairy"], st(95,70,73,85,90,60), cla_ab),
    SM: prof(OK, ["fairy"], st(95,70,73,95,90,60), cla_ab),
    SV: prof(GAP),
})
eev_ab = ab("run-away", "adaptability", hidden="anticipation"); eev = st(55,55,50,45,65,55)
add(133, "eevee", "Evoli", "Eevee", {
    RB: prof(OK, ["normal"], g1(55,55,50,65,55)),
    XY: prof(OK, ["normal"], eev, eev_ab),
    SM: prof(OK, ["normal"], eev, eev_ab),
    SV: prof(OK, ["normal"], eev, eev_ab),
})

def lvl(n): return {"kind": "minLevel", "level": n}
early = [RB, XY]
evolutions = [
    {"from": "bulbasaur", "to": "ivysaur", "condition": lvl(16), "versionGroups": early},
    {"from": "ivysaur", "to": "venusaur", "condition": lvl(32), "versionGroups": early},
    {"from": "charmander", "to": "charmeleon", "condition": lvl(16), "versionGroups": early},
    {"from": "charmeleon", "to": "charizard", "condition": lvl(36), "versionGroups": early},
    {"from": "squirtle", "to": "wartortle", "condition": lvl(16), "versionGroups": early},
    {"from": "wartortle", "to": "blastoise", "condition": lvl(36), "versionGroups": early},
    {"from": "pikachu", "to": "raichu", "condition": {"kind": "useItem", "item": "thunder-stone"}, "versionGroups": [RB, XY, SV]},
    {"from": "pikachu", "to": "raichu-alola", "condition": {"kind": "allOf", "of": [
        {"kind": "useItem", "item": "thunder-stone"}, {"kind": "region", "region": "alola"}]}, "versionGroups": [SM]},
    {"from": "clefairy", "to": "clefable", "condition": {"kind": "useItem", "item": "moon-stone"}, "versionGroups": [RB, XY, SM]},
]

def ruleset(rid, gen, era, formula, modern):
    return {"id": rid, "generation": gen, "typeChartEra": era, "statFormula": formula, "partySize": 6,
            "hasAbilities": modern, "hasHeldItems": gen >= 2, "hasNatures": modern, "unifiedSpecial": gen == 1}

def names(**kv): return {k: v for k, v in kv.items()}

catalog = {
    "schemaVersion": 1,
    "revision": "fixture-2026.10.0",
    "rulesets": [ruleset("gen1", 1, "gen1", "gen1_2", False), ruleset("gen6", 6, "gen6plus", "modern", True),
                 ruleset("gen7", 7, "gen6plus", "modern", True), ruleset("gen9", 9, "gen6plus", "modern", True)],
    "versionGroups": [
        {"id": RB, "generation": 1, "ruleset": "gen1", "order": 1, "name": names(de="Rot / Blau", en="Red / Blue")},
        {"id": XY, "generation": 6, "ruleset": "gen6", "order": 6, "name": names(de="X / Y", en="X / Y")},
        {"id": SM, "generation": 7, "ruleset": "gen7", "order": 7, "name": names(de="Sonne / Mond", en="Sun / Moon")},
        {"id": SV, "generation": 9, "ruleset": "gen9", "order": 9, "name": names(de="Karmesin / Purpur", en="Scarlet / Violet")},
    ],
    "versions": [
        {"id": "red", "versionGroup": RB, "name": names(de="Rot", en="Red")},
        {"id": "blue", "versionGroup": RB, "name": names(de="Blau", en="Blue")},
        {"id": "x", "versionGroup": XY, "name": names(de="X", en="X")},
        {"id": "y", "versionGroup": XY, "name": names(de="Y", en="Y")},
        {"id": "sun", "versionGroup": SM, "name": names(de="Sonne", en="Sun")},
        {"id": "moon", "versionGroup": SM, "name": names(de="Mond", en="Moon")},
        {"id": "scarlet", "versionGroup": SV, "name": names(de="Karmesin", en="Scarlet")},
        {"id": "violet", "versionGroup": SV, "name": names(de="Purpur", en="Violet")},
    ],
    "abilities": [{"id": i, "name": names(de=d, en=e)} for i, d, e in [
        ("overgrow", "Notdünger", "Overgrow"), ("chlorophyll", "Chlorophyll", "Chlorophyll"),
        ("blaze", "Großbrand", "Blaze"), ("solar-power", "Solarkraft", "Solar Power"),
        ("torrent", "Sturzbach", "Torrent"), ("rain-dish", "Regengenuss", "Rain Dish"),
        ("static", "Statik", "Static"), ("lightning-rod", "Blitzfänger", "Lightning Rod"),
        ("surge-surfer", "Surfschwanz", "Surge Surfer"), ("cute-charm", "Charmebolzen", "Cute Charm"),
        ("magic-guard", "Magieschild", "Magic Guard"), ("friend-guard", "Freundeshut", "Friend Guard"),
        ("unaware", "Unkenntnis", "Unaware"), ("run-away", "Angsthase", "Run Away"),
        ("adaptability", "Anpassung", "Adaptability"), ("anticipation", "Vorahnung", "Anticipation")]],
    "items": [{"id": "thunder-stone", "name": names(de="Donnerstein", en="Thunder Stone")},
              {"id": "moon-stone", "name": names(de="Mondstein", en="Moon Stone")}],
    "species": species,
    "forms": forms,
    "evolutions": evolutions,
}
out = pathlib.Path(__file__).resolve().parents[2] / "data/fixtures/catalog.json"
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out, len(forms), "forms")
