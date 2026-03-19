# Drive Care & Longevity

You built an ark. Here's how to keep it alive.

## Ewaste Drives and the Free Wipe

If you're loading drives from an ewaste bin or office cleanout, you were
going to wipe them anyway. `ark stamp` handles this: after cloning the
loadout, it **zero-fills all remaining free space** on the drive — a full
overwrite of whatever was there before. One command turns a disposal chore
into a contribution to the preservation of human knowledge.

Every drive that passes SMART is a candidate. Load it, verify it, bag it,
shelf it. The more copies you scatter, the harder this knowledge is to lose.

## Realistic Expectations

A used hard drive that passes SMART checks and successfully writes and
verifies a full loadout is, statistically, a good drive. But "good" doesn't
mean "forever."

**Unpowered shelf life:** 5-10 years with high confidence, often much longer.
The failure mode isn't sudden — magnetic signals on the platters weaken
gradually until the drive's built-in error correction can't recover them.
This is bitrot: not a dramatic crash, but a slow fade.

**What helps:**
- Spinning the drive up every 1-2 years and running `ark verify`
- Storing in cool, stable temperatures (a closet, not an attic or garage)
- Keeping moisture away (see [Storage](#storage) below)
- Making multiple copies (this matters more than anything else)

**What kills drives in storage:**
- Humidity — corrodes the PCB and connectors
- Temperature swings — thermal cycling stresses components
- Physical shock — even a short drop onto concrete
- Time — lubricant on the platters redistributes, heads can stick (stiction)

## 2.5" vs 3.5" Drives

Both work. The tradeoffs are practical, not technical.

| | 2.5" (laptop) | 3.5" (desktop) |
|---|---|---|
| **Typical sizes** | 250 GB - 1 TB | 500 GB - 4 TB |
| **Power** | USB bus-powered | Needs 12V — powered dock or desktop SATA |
| **Portability** | Pocket-sized, one cable | Needs a dock (~$15-25) or desktop |
| **Mechanical robustness** | Designed for laptops, decent shock tolerance | Heavier platters, beefier construction |
| **Ewaste availability** | Common (laptops) | Very common (desktops, DVRs, NAS units) |
| **Best for** | Go-bags, field use, "break glass" kits | Bulk archival, shelf backups, swap docks |

If you're pulling drives from ewaste, you'll find far more 3.5" drives,
often in larger capacities. A powered USB-to-SATA dock lets you swap
them in and out like cartridges — load, verify, bag, shelf, next.

## Storage

The goal is: dry, cool, shielded, and easy to get to when you need it.

### The Setup

1. **Anti-static bag** — the silvery metalized kind, not pink poly.
   Prevents ESD damage to the PCB and provides mild RF shielding.

2. **Desiccant pack inside** — silica gel, the kind that comes in shoe
   boxes. Absorbs moisture that would otherwise corrode contacts and traces.
   Toss in one or two packs.

3. **Fold the bag closed tightly** — no tape or heat seal needed. Fold it
   over a couple of times so water can't get in if the outer layer gets wet.
   You want to be able to open it easily when the time comes.

4. **Fireproof bag** — the outer shell. Protects against fire but traps
   moisture, which is why the desiccant goes *inside* the anti-static bag.

That's it. Anti-static bag (with desiccant) folded shut, inside a fireproof
bag. Under $10 in materials, minutes to assemble.

### What NOT to Do

- **Don't vacuum seal.** Hard drives have a barometric breather hole — the
  read/write heads fly on a thin air cushion above the platters. Pressure
  differentials can stress the seal or affect head flight.

- **Don't store in attics, garages, or sheds.** Temperature swings are
  worse than steady warmth. A climate-controlled closet beats a cool but
  damp basement.

- **Don't stack drives.** Lay them flat or on edge in a way that won't
  let them fall. A 3.5" drive falling off a shelf onto tile is a dead drive.

### EMP & Faraday Shielding

A disconnected drive on a shelf has short PCB traces — not great antennas.
The metal chassis provides some shielding on its own. The realistic EMP
risk isn't to your shelf drives, it's to drives that are *plugged into
equipment that's plugged into the wall* — the power line acts as the
antenna, and the surge travels inward.

That said: the metalized anti-static bag already provides mild RF
shielding. If you want more margin, wrap the bag in aluminum foil before
putting it in the fireproof bag. Looks silly, costs nothing, and provides
real protection against the one scenario where your shelf copy becomes
the only surviving copy.

For the genuinely concerned: a metal ammo can (~$10-15 at surplus stores)
with foil tape on the seam is a solid Faraday enclosure that also handles
impact protection and stacking.

## The Real Strategy

Drives are cheap. Data is identical. **Make several.**

Two copies in the same house protects against drive failure. Two copies
in different buildings protects against fire and flood. Two copies in
different cities protects against everything short of civilization-scale
events — and at that point, you'll be glad you made a third.

Every drive you load at an ewaste event costs you about 20 minutes and
$2.50 in adapters. The content is the same. The checksums are the same.
Treat drives like seeds: scatter them widely, check on them occasionally,
and trust that most of them will be there when you need one.

### Maintenance Schedule

| Interval | Action |
|----------|--------|
| At creation | Run `ark verify <loadout>` — confirm checksums |
| Every 1-2 years | Spin up, run `ark verify`, reseal and re-shelve |
| Every 5 years | Consider recopying to a fresh drive |
| When SMART warns | Replace immediately — copy to a new drive and retire the old one |

## Quick Reference

```
GOOD                           BAD
─────────────────────────────  ─────────────────────────────
Anti-static bag + desiccant    Bare drive in a drawer
Folded closed, easy to open    Vacuum sealed
Fireproof bag (outer layer)    Ziplock alone (no ESD protection)
Cool closet shelf              Attic / garage / car trunk
Flat or on edge, stable        Stacked / precariously shelved
Multiple copies, spread out    One precious drive, one location
Verify every 1-2 years         Load it and forget it forever
```
