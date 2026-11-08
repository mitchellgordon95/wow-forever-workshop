# Forever Workshop

Planner for Mitchell's three-character profession pipeline in World of Warcraft: Forever (Classic-style ruleset, launched 2026-11-04). Hunter (Mining, Skinning) feeds a Warrior (Blacksmithing, Engineering) and a Priest (Tailoring, Enchanting). Goals in order: level all six professions, gear the three characters, make gold.

## Parts

- `index.html` — the planner page, a single file with no build step. Published as a claude.ai artifact at https://claude.ai/artifact/1ziCv6uJva63PgicgSQzWp. To republish from a new conversation, pass that URL as `url` to the Artifact tool with this file; publishing without the URL creates a separate artifact.
  - Data: `M` (materials), `R` (recipes, `sk` = [orange, yellow, green, grey] skill thresholds), `TIERS`, `DE` (disenchant bands). Recipe numbers are from Classic-era memory and approximate; Mitchell corrects them in the Recipes tab.
  - State: the page declares the `db` capability. `state/main` holds skills, levels, AH prices (silver per unit), and stock. `recipes/<id>` holds recipe overrides (or `{deleted:true}`), `mats/<id>` custom materials. localStorage mirrors it as a fallback.
  - Import box (Prices tab) accepts the addon's JSON export.
- `addon/ForeverWorkshop/` — WoW addon. `/fw export` opens a box with a JSON snapshot: per-character class, level, skills, bags, bank; Auctionator min-buyout prices for every item seen. Copy it into the page's Import box. The interface number in the `.toc` is a Classic Era guess; if the game lists it as out of date, tick "Load out of date AddOns" or fix the number.

## Working on the Windows machine

- Install the addon by copying or symlinking `addon/ForeverWorkshop` into `<WoW>\_classic_era_\Interface\AddOns\` (or whatever folder Forever uses; look for the one containing `Interface\AddOns`). Mitchell types `/reload` in game after each change.
- Errors: install BugSack + BugGrabber; errors land in `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua` after `/reload`. Or enable `/console scriptErrors 1`.
- The addon's data lands in `WTF\Account\<ACCOUNT>\SavedVariables\ForeverWorkshop.lua` after `/reload` or logout. That file can be parsed and written straight into the artifact database (`state/main`) with the ArtifactData tool, skipping the paste.
- Never automate input to the game client. Blizzard's terms forbid it and the account is at risk. The in-game step is always Mitchell's.
- Offline checks: syntax-check `index.html`'s script with `node -e` (see git history for the one-liner); for Lua, `luac -p Core.lua` if Lua 5.1 is installed. The WoW API is not available offline; stub what you need.

## Conventions

- Keep the page one file. No framework, no build.
- Money in the page's code is copper internally; the Prices tab shows silver.
- Material ids are snake_case of the item name. The importer matches by item name, case-insensitive.
