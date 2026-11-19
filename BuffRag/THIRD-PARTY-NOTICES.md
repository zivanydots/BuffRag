# Licence scope and third-party assets

BuffRag's original code, documentation and custom artwork are distributed under the MIT licence in LICENSE.

The MIT licence does not grant rights to Blizzard Entertainment's or other third parties' names, trademarks, game artwork or other assets. Those remain subject to their respective owners' rights and terms.

BuffRag references spell and item icons supplied by the game client; those game icon files are not included in this addon. Custom BuffRag artwork is separate from those game assets. BuffRag is not affiliated with or endorsed by Blizzard Entertainment.

## Combat spell-ID snapshot

v0.1.41 also derives pet caster-target rules in CombatData.lua from that build's SpellEffect and pet skill-line records. A pet's self target means the pet, not the player or a party member. The reproducible extractor is tools/build-combat-data.ps1; native pet spellbook flags supplement it for controllable pets absent from the static snapshot.

v0.1.40 adds ActionData.lua: numeric healing, dispel-type and resurrection metadata derived from the same build's SpellEffect table, retrieved through https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938. Reproduce with tools/build-action-data.ps1 and tools/references/SpellEffect-70938.csv. No spell descriptions or third-party addon code are included. Live APIs supply item use-spell identity and helpful/harmful targeting; users can override item categories.

v0.1.36 also extracts active Warlock/Hunter pet spell IDs and family labels from the same build's SkillLine/SkillLineAbility tables, applying passive/hidden filtering. Native pet spellbooks supplement the snapshot for any class with a controllable pet. Native pet spellbook APIs: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua. No third-party pet addon code was copied.

CombatData.lua contains numeric active class/talent spell IDs extracted from Blizzard's Forever DB2 tables for build **1.60.1.70938**, retrieved through the Wago.Tools CSV mirror on 17 November 2026. Blizzard's live service (https://us.version.battle.net/wowf/versions) and the installed client both reported that build. Tables: SkillLine, SkillLineAbility, Talent, TalentTab, SpellMisc and SpellName at https://wago.tools/db2/SkillLineAbility/csv?build=1.60.1.70938 (substitute table name). Source CSVs and the extraction script are retained in tools/references and tools/build-combat-data.ps1 outside the release addon. Blizzard owns its game data; no third-party addon code or spell descriptions were copied for this snapshot. Live client APIs provide names, tooltips, icons, target classification and learned state.

Spell-rank references for Shadow Ward, Fire Ward and Frost Ward were checked against the direct client data exported by Talents Forever: https://talentsforever.com/export/warlock.json and https://talentsforever.com/export/mage.json. Data attribution: Talents Forever (https://talentsforever.com/), CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Game names, spell text and icons remain Blizzard Entertainment's. BuffRag supplies its own selection and action behavior.

## Embedded minimap libraries

The unmodified files in Libs retain their upstream terms; they are not relicensed under BuffRag's MIT licence.

- LibStub, minor 2: public domain, as stated in its source header. Source: https://github.com/WoWUIDev/Ace3/tree/master/LibStub
- CallbackHandler-1.0, minor 8: Ace3 Development Team; see Libs/Ace3-LICENSE.txt. Source: https://github.com/WoWUIDev/Ace3/tree/master/CallbackHandler-1.0
- LibDataBroker-1.1, minor 4: Tekkub and contributors. Source: https://github.com/tekkub/libdatabroker-1-1. Retained unmodified and embedded as directed by the author's addon packaging instructions at https://www.wowace.com/projects/libdatabroker-1-1. The upstream project lists All Rights Reserved; no MIT grant is claimed. Its original README is included in Libs/LibDataBroker-README.textile.
- LibDBIcon-1.0, minor 57: see the published Ace3 Style BSD notice retained in Libs/LibDBIcon-LICENSE.html. Source: https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0/LibDBIcon-1.0.lua. Project: https://www.wowace.com/projects/libdbicon-1-0/.
