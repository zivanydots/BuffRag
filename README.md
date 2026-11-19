# Buff Rag

**One-button buffing for all WoW Forever classes.** Buff Rag puts clickable buffs, bag items and optional combat abilities beside your Blizzard unit frames. Settings are saved per character.

[Download on CurseForge](https://www.curseforge.com/wow/addons/buffrag) · [GitHub releases](https://github.com/zivanydots/BuffRag/releases)

![Warlock buffs and a bag item beside the player frame](BuffRag%200.2.26%20Screenshots/buff-icons-on-player-frame.png)

## Get started

1. Install with CurseForge, or extract the release ZIP so `BuffRag.toc` is in `Interface/AddOns/BuffRag` under your WoW Forever installation. Restart the game after a manual install.
2. Open Buff Rag outside combat with `/brag`, the **BR** minimap icon, or **Options → AddOns → Buff Rag → Open Options**.
3. Configure your rows and click **Save**. The **^** beside the title collapses the window. Middle-click the minimap icon to hide it. Restore it from **Global Settings**.

If Buff Rag warns about FelBot, disable FelBot in WoW's AddOns list and reload.

## Buffs

Enable the buffs you want, choose which frames show each icon, and drag rows or use the arrows to set the order. A buff supplied by another player also clears its missing-buff icon. Unlearned abilities are greyed out.

- **Queue** runs through its selected entries in order. Hold **SHIFT** by default and left-click the unit frame.
- **Bypass Q** runs its own selected entries in order. Hold **CTRL** by default and left-click the unit frame.
- **Manual casting** always works by clicking the individual icon when it is available. Leave both queue boxes off for actions you only want to pick manually.
- **One-button self buffing** is available through the keyboard shortcut in **Global Settings**. Use the same settings tab to change the frame modifiers.

A Paladin can show several blessings on raid frames, keep them out of both queues and click the blessing assigned to them. A Rogue can choose which hand to poison. A Warlock can queue creation and application of a weapon stone, or put Soulstone in Bypass Q for quick access. Tick **Keep in bag** for Soulstone so your clutch save starts with a stone in your bag.

![Buff order, queues, target frames and Keep in bag](BuffRag%200.2.26%20Screenshots/buffs-order-and-targets.png)

## Bag Items

Drag a usable item from your bags onto **Bag Items**. Choose where its icon appears and whether it joins a buff queue. Move the **Bag Items** row on the Buffs tab to choose where these items enter the buff order. Use the cog beside an item to adjust its options, such as buff detection or the targets and effects it supports.

With Combat enabled, tick **Combat** for items you want to use there and position the **Bag Items** row on the relevant Combat frame tab. For example, add a bandage, enable it for friendly frames and use it from its icon during Combat or when a unit needs healing in Post-combat.

![Bag Items list showing scrolls, a torch, a Healthstone and a Warding Candle](BuffRag%200.2.26%20Screenshots/bag-items-list.png)

<details>
<summary>See item options for Warding Candle</summary>

![Warding Candle options with Curse and Disease selected](BuffRag%200.2.26%20Screenshots/bag-item-options-warding-candle.png)

</details>

## Combat and Post-combat

Turn on **Enable in combat** in **Global Settings**. On the **Combat** tab, select Self, Party, Raid, Target or Focus. Target and Focus have separate Friendly and Enemy profiles.

- Use **Copy from...** to copy settings and order for abilities shared with another profile. Friendly profiles copy from each other, and Enemy Target and Enemy Focus copy from each other. Target keybinds stay on Target.
- Assign **SHIFT**, **CTRL** or **ALT** to the top three slots for that frame. Hold the modifier and left-click the frame to cast. Click any displayed icon to cast it directly.
- Choose **Icon only** for additional abilities. On Friendly and Enemy **Target Frame**, click **Set key** and press a key to bind the ability. Right-click an assigned key to clear it.
- Tick **Out of combat** to show an enabled ability before the buff icons. Frame modifiers still run their assigned buff queues in Buff mode. An **Icon only** Target ability can use its assigned key here too.
- During **Combat**, player and pet dispel icons show a marker for a matching effect. Friendly casts look for harmful effects and enemy casts look for beneficial effects.
- **Post-combat** keeps useful heals, dispels and resurrection actions available on each friendly frame until the unit recovers.
- Optional **cast-result overlays** in Global Settings show a tick for a completed cast, a cross for a failed or interrupted cast, and a question mark when the result is unconfirmed.

For example, assign a pet interrupt to CTRL on Enemy Target, bind Fear to a key so it is ready before the pull, or put a Priest's most-used heals on raid-frame modifiers.

![Enemy Target Combat profile with Spell Lock on CTRL and keybind controls for Icon only spells](BuffRag%200.2.26%20Screenshots/combat-enemy-target-keybinds.png)

<details>
<summary>See Global Settings and cast-result examples</summary>

![Global Settings with modifier choices, keyboard shortcut and cast feedback examples](BuffRag%200.2.26%20Screenshots/global-settings-and-cast-feedback.png)

</details>

## Place your icons

Click **Configure Frame Icons**, select a frame, and set the anchor, growth direction, size and offsets. Use the Standard or Raid Style preview for Party frames. Blue previews show Buff icons and orange previews show Combat icons when Combat is enabled. Click **Save** in the placement window to keep your changes.

![Configure Frame Icons showing the blue Buff preview on five raid-style Party frames](BuffRag%200.2.26%20Screenshots/configure-frame-icons-raid-style-party.png)

## Get help

Click **?** beside the collapse arrow and open **Debug Commands**. Use `/brag debug cast` after an unconfirmed cast. For a slowdown, run `/brag debug perf start`, reproduce the issue, then run `/brag debug perf print` outside combat to stop recording and copy the report.

Buff Rag works with Blizzard unit frames. If an icon is missing, check the row is enabled for the selected frame and that you have the spell, pet or item available.

By **Zivany Dots**. [Licence](BuffRag/LICENSE) · [Third-party notices](BuffRag/THIRD-PARTY-NOTICES.md)
