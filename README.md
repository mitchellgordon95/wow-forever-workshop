# Forever Workshop

A planner for running three World of Warcraft: Forever characters as one crafting pipeline: a Hunter who mines and skins, a Warrior who smiths and engineers, and a Priest who tailors and enchants.

**Page:** https://claude.ai/artifact/1ziCv6uJva63PgicgSQzWp (private artifact; source is `index.html`)

- **Map** of how materials flow between the six professions, with gaps flagged at your current skill levels.
- **Next steps**: skill-up recipes ranked by net cost per skill point at your auction-house prices, and a farm-or-buy list for the gatherer.
- **Ladder**: 1–300 skill bars banded by material tier, plus skinning and disenchant reference tables.
- **Stack check**: pick a material and quantity; get a use-or-sell verdict.
- **Recipes**: the full dataset, editable in place.

`addon/ForeverWorkshop` is a small WoW addon. `/fw export` copies a snapshot of skills, bags, bank and Auctionator prices to paste into the page's Import box.

Recipe data is Classic-era and approximate. Fix it in the page when a tooltip disagrees.
