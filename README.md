# Buff Rag

**One-button buffing for all WoW Forever classes.** Buff Rag puts clickable buffs, bag items and optional combat abilities beside your Blizzard unit frames. Settings are saved per character.

[Download on CurseForge](https://www.curseforge.com/wow/addons/buffrag) · [GitHub releases](https://github.com/zivanydots/BuffRag/releases)

![Warlock buffs, stone creation icons and a bag item beside the player frame](BuffRag%20v0.2.35%20Screenshots/buff-icons-on-player-frame.png)

## Get started

1. Install with CurseForge, or extract the release ZIP so `BuffRag.toc` is in `Interface/AddOns/BuffRag` under your WoW Forever installation. Restart the game after a manual install.
2. Open Buff Rag outside combat with `/brag`, the **BR** minimap icon, or **Options → AddOns → Buff Rag → Open Options**.
3. Configure your rows and click **Save**. The title-bar arrow collapses or expands the window. The cog below it opens the separate **Global Settings** window. Middle-click the minimap icon to hide it, or restore it under **Global Settings → General**.

If Buff Rag warns about FelBot, disable FelBot in WoW's AddOns list and reload.

## Buff Mode

Enable the buffs you want, choose which frames show each icon, and drag rows or use the arrows to set the order. A buff supplied by another player also clears its missing-buff icon. Unlearned abilities are greyed out.

- **Queue** runs through selected entries in order. Hold **SHIFT** by default and left-click the unit frame.
- **Bypass Q** is off by default. Enable it under **Global Settings → Buff Mode** to show the extra column in Buff Mode and Bag Items. Hold **CTRL** by default and left-click a frame to run only Bypass Q entries in list order, skipping the standard queue.
- **Manual casting** works by clicking an available icon. Leave the queue boxes clear for actions you only want to use this way.
- **Self-buff shortcut** applies the next eligible Queue entry to your own character. Set it under **Global Settings → Buff Mode**, where you can also change the frame-click modifiers.

Frame clicks check the recipient's range when you click. The queues prefer ready actions, and WoW reports missing mana or reagents if it attempts a blocked spell.

A Paladin can show several blessings on raid frames, keep them out of both queues and click the blessing assigned to them. A Rogue can choose which hand to poison. A Warlock can queue creation and application of a weapon stone, or put Soulstone in Bypass Q for quick access. Tick **Keep in bag** for Soulstone so your clutch save starts with a stone in your bag.

![Buff Mode showing Warlock buff order, frame selection and Keep in bag](BuffRag%20v0.2.35%20Screenshots/buff-mode-order-and-targets.png)

<details>
<summary>See Buff Mode settings and the self-buff shortcut</summary>

![Global Settings showing the standard queue modifier, optional Bypass Q and the self-buff shortcut](BuffRag%20v0.2.35%20Screenshots/global-settings-buff-mode.png)

</details>

## Bag Items

Drag a usable item from your bags onto **Bag Items**. Choose where its icon appears and whether it joins a buff queue. Move the **Bag Items** row in Buff Mode to choose where those items enter the buff order. Use the cog beside an item to adjust its options, such as buff detection or the targets and effects it supports.

With Combat Mode enabled, tick **Combat** for items you want to use there and choose their frames. Move the **Bag Items** row on the relevant Combat Mode frame tab to position those icons. A bandage can go on friendly frames, or you can add an Iron Grenade for PvP. Combat items stay out of the buff queues.

![Bag Items showing scrolls, a torch, a Healthstone and the Combat checkbox](BuffRag%20v0.2.35%20Screenshots/bag-items-list.png)

<details>
<summary>See combat item options</summary>

![Scroll of Spirit combat item options showing targeting and dispel reminders](BuffRag%20v0.2.35%20Screenshots/bag-item-combat-options-scroll-of-spirit.png)

</details>

## Combat Mode and Post-combat

Click **Enable Combat Mode** in the overview or under **Global Settings → Combat Mode**. Combat Mode keeps your configured actions visible during combat so you can choose when to cast. Select Self, Party, Raid, Target or Focus in the configuration table. Target and Focus have separate Friendly and Enemy profiles.

Combat Mode also works in duels. An attackable duel opponent uses the Enemy profile for Target and Focus.

![Combat Mode overview with casting, bag item, preview and dispel examples](BuffRag%20v0.2.35%20Screenshots/combat-mode-disabled-overview.png)

- Use **Copy from...** to copy settings and order for abilities shared with another profile. Friendly profiles copy from each other, and Enemy Target and Enemy Focus copy from each other. Keybinds stay with their original frame.
- Assign **SHIFT**, **CTRL** or **ALT** to the top three slots for that frame. Hold the modifier and left-click the frame to cast. Click any displayed icon to cast it directly.
- Choose **Icon only** for additional abilities. On Friendly and Enemy **Target** and **Focus**, click **Set key** and press a key or combination such as **SHIFT+4**. If WoW already uses the shortcut, Buff Rag warns you. Enter the shortcut again to confirm the change, then click **Save** to apply it. Right-click an assigned key to clear it.
- Tick **Out of combat** on an enabled ability to keep it available before your buff icons. Try it for an opener such as a Mage's Polymorph or a Warlock's Fear. Modifiers assigned to buff queues keep running those queues in Buff Mode. An **Icon only** Target or Focus ability can use its assigned key here too.
- Creature-specific actions hide in Buff Mode and dim during combat when the selected creature type is incompatible. For example, both Banish and Subjugate Demon show on a demon, and only Banish shows on an elemental. If WoW restricts the creature type, the action keeps its usual appearance.
- During combat, player and pet dispel icons show a symbol when they can remove a matching effect. Friendly casts look for harmful effects and enemy casts look for beneficial effects. A Hunter's Tranquilizing Shot shows the Enrage symbol when an enemy is enraged.
- **Post-combat** makes configured dispels available on friendly frames when needed. To set up resurrection, enable its **Dead only** row for Party, Raid, Friendly Target or Friendly Focus. It appears when that unit is dead. Druid Rebirth can also appear during combat.
- Optional **cast-result overlays** in Global Settings show a green tick for a completed cast and a red cross for a failed or interrupted cast. Both marks fade over one global cooldown.

For example, assign a pet interrupt to CTRL on Enemy Target, bind Fear to a key so it is ready before the pull, or put a Priest's most-used heals on raid-frame modifiers.

![Enemy Target Combat Mode profile with Fear bound to 4 and Spell Lock set to Icon only](BuffRag%20v0.2.35%20Screenshots/combat-mode-enemy-target-keybinds.png)

<details>
<summary>See Global Settings and cast-result examples</summary>

![Global Settings for Combat Mode, showing cast feedback examples and icon opacity](BuffRag%20v0.2.35%20Screenshots/global-settings-combat-mode.png)

</details>

## Place your icons

Click **Configure Frame Icons** and select a frame tab or click a visible preview icon to select its frame. Set the anchor, growth direction and size, then drag any preview icon to position its stack. The position sliders update as you drag. Use the Standard or Raid Style preview for Party frames.

When Combat Mode is enabled, use the switch at the top to change previews. Blue icons show buffs. Orange icons show combat actions, including abilities opted into **Out of combat** that appear before the blue buffs in the Buff Mode preview.

Click **Save** to keep your placement. **Reset** restores the icon settings from when you opened the window, and **Defaults** restores the original layout.

![Configure Frame Icons showing blue Buff Mode previews on four standard Party frames](BuffRag%20v0.2.35%20Screenshots/configure-frame-icons-standard-party-buff-preview.png)

<details>
<summary>See the orange Combat Mode preview</summary>

![Configure Frame Icons showing orange Combat Mode icons next to the player and target frames](BuffRag%20v0.2.35%20Screenshots/configure-frame-icons-target-combat-preview.png)

</details>

## PvP diminishing returns

Enable **DR tracking** in **Global Settings → DR** to track reset timers for supported crowd control on hostile targets. A `~` marks an estimated reset time. **Estimate from unconfirmed casts** is available for supported targeted spells such as Fear, Sap and Polymorph. Readable effects from you or your pet can refine the countdown. Area effects such as Psychic Scream need a readable aura before Buff Rag can estimate their timer. Matched immune casts leave the existing countdown running. Use `/brag debug dr` to see the abilities supported for your class.

Open **Configure Frame Icons → DR** to choose **Show DR above enemy nameplates**, **Show DR on Target and Focus frames**, or both. The Target, Focus, and Nameplates tabs each have their own icon size and placement. Green icons show each enabled display in the preview. Use **DR icon opacity** in Global Settings to adjust the live icons.

## Get help

Click **?** beside the collapse arrow and open **Debug Commands**. Use `/brag debug cast` after an unconfirmed cast. For a slowdown, run `/brag debug perf start`, reproduce the issue, then run `/brag debug perf print` outside combat to stop recording and copy the report.

Buff Rag works with Blizzard unit frames. If an icon is missing, check the row is enabled for the selected frame and that you have the spell, pet or item available.

By **Zivany Dots**. [Licence](BuffRag/LICENSE) · [Third-party notices](BuffRag/THIRD-PARTY-NOTICES.md)
