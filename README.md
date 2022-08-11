# AcediaLauncher 0.1

This is a launcher for packages that rely on AcediaCore and use its `Feature`
class instead of the `Mutator` to enable provided functionality.

## Installation

0. Requires
    [Voting Handler Fix v2](https://forums.tripwireinteractive.com/index.php?threads/mod-voting-handler-fix.43202/)
    installed.
1. Drop `AcediaLauncher` files into `System\` directory of your server;
2. Add `AcediaLauncher.StartUp` to the list of server actors in your
    `KillingFloor.ini`.
    **Do not** manually add `AcediaLauncher.Packages` mutator;
3. [Legacy] If you were using Acedia 0.1 - remove `Acedia.StartUp`.

## Adding packages

To add any Acedia's package, edit `AcediaLauncher.ini` file to add it into
available packages list, e.g.

```ini
[AcediaLauncher.Packages]
useGameModes=false
package="AcediaFixes"
```

Then use that package's config files to choose what `Feature`s to enable
by setting their `autoEnable` setting to `true`.

## [Optional] Game modes

By default AcediaLauncher only auto-starts selected Acedia `Feature`s.
But it also provides a more advanced functionality for configuring voting
options for *Voting Handler Fix v2* mutator.

There is no detailed documentation for this yet, however Acedia's game modes
can be configured in a rather self-descriptive way in `AcediaGameModes.ini`:

```ini
[hard GameMode]
title=1. {$green Hard difficulty}
acronym={$green hard}
difficulty=hard
length=medium

[lawless GameMode]
title=2. {$hotpink No fixes! Anarchy!}
acronym={$red:$blue anarchy}
difficulty=hoe
length=short
includeMutator="AdminPlus_v4.MutAdminPlus"
excludeFeature="AcediaFixes.FixZedTimeLags_Feature"
excludeFeature="AcediaFixes.FixDoshSpam_Feature"
excludeFeature="AcediaFixes.FixDoshSpam_Feature"
excludeFeature="AcediaFixes.FixFFHack_Feature"
excludeFeature="AcediaFixes.FixInfiniteNades_Feature"
excludeFeature="AcediaFixes.FixAmmoSelling_Feature"
excludeFeature="AcediaFixes.FixSpectatorCrash_Feature"
excludeFeature="AcediaFixes.FixDualiesCost_Feature"
excludeFeature="AcediaFixes.FixInventoryAbuse_Feature"
excludeFeature="AcediaFixes.FixProjectileFF_Feature"
excludeFeature="AcediaFixes.FixPipes_Feature"
excludeFeature="AcediaFixes.FixLogSpam_Feature"
excludeFeature="AcediaFixes.Futility_Feature"
excludeFeature="AcediaFixes.FixZedTimeLags_Feature"

[hell GameMode]
title=3. {$crimson Hell On Earth}
acronym={$crimson hoe}
difficulty=hoe
length=long
```

To enable game modes, set `useGameModes=true` in `AcediaLauncher.ini`.
AcediaLauncher relies on *Voting Handler Fix v2* to actually add these options
and will automatically alter its config, so you *don't need to manually change*
`KFMapVote.ini`.
