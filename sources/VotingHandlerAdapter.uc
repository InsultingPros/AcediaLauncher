/**
 *      Acedia currently lacks its own means to provide a map/mode voting
 *  (and new voting mod with proper GUI would not be whitelisted anyway).
 *  This is why this class was made - to inject existing voting handlers with
 *  data from Acedia's game modes.
 *      Requires `GameInfo`'s voting handler to be derived from
 *  `XVotingHandler`, which is satisfied by pretty much every used handler.
 *      Copyright 2021 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class VotingHandlerAdapter extends AcediaObject
    dependson(VotingHandler);

/**
 *      All usage of this object should start with `InjectIntoVotingHandler()`
 *  method that will read all the `GameMode` configs and fill voting handler's
 *  config with their data, while making a backup of all values.
 *  Backup can be restored with `RestoreVotingHandlerConfigBackup()` method.
 *  How that affects the clients depends on whether restoration was done before,
 *  during or after the replication. It is intended to be done after
 *  server travel has started.
 *      the process of injection is to create an ordered list of game modes
 *  (`availableGameModes`) and generate appropriate voting handler's configs
 *  with `BuildVotingHandlerConfig()`, saving them in the same order inside
 *  the voting handler. Picked game mode is then determined by index of
 *  the picked voting handler's option.
 *
 *      Additionally this class has a static internal state that allows it to
 *  transfer data along the server travel - it is used mainly to remember picked
 *  game mode and enforce game's difficulty by altering and restoring
 *  `GameInfo`'s variable.
 *  To make such transfer happen one must call `PrepareForServerTravel()` before
 *  server travel to set the internal static state and
 *  then `SetupGameModeAfterTravel()` after travel (when the new map is loading)
 *  to read (and forget) from internal state.
 */

//      Aliases are an unnecessary overkill for difficulty names, so just define
//  them in special `string` arrays.
//      We accept detect not just these exact words, but any of their prefixes.
var private const array<string> beginnerSynonyms;
var private const array<string> normalSynonyms;
var private const array<string> hardSynonyms;
var private const array<string> suicidalSynonyms;
var private const array<string> hoeSynonyms;

//      All available game modes for Acedia, loaded during initialization.
//      This array is directly produces replacement for `XVotingHandler`'s
//  `gameConfig` array and records of `availableGameModes` relate to those of
//  `gameConfig` with the same index.
//      So if we know that a voting option with a certain index was chosen -
//  it means that user picked game mode from `availableGameModes` with
//  the same index.
var private array<Text> availableGameModes;

//  Finding voting handler is not cheap, so only do it once and then store it.
var private NativeActorRef                          votingHandlerReference;
//  Save `VotingHandler`'s config to restore it before server travel -
//  otherwise Acedia will alter its config
var private array<VotingHandler.MapVoteGameConfig>  backupVotingHandlerConfig;

//  Setting default value of this flag to `true` indicates that map switching
//  just occurred and we need to recover some information from the previous map.
var private bool    isServerTraveling;
//  We should not rely on "VotingHandler" to inform us from which game mode its
//  selected config option originated after server travel, so we need to
//  remember it in this default variable before switching maps.
var private string  targetGameMode;
//  Acedia's game modes intend on supporting difficulty switching, but
//  `KFGameType` does not support appropriate flags, so we enforce default
//  difficulty by overwriting default value of its `gameDifficulty` variable.
//  But to not affect game's configs we must restore old value after new map is
//  loaded. Store it in default variable for that.
var private float   storedGameDifficulty;

var private LoggerAPI.Definition fatNoXVotingHandler, fatBadGameConfigIndexVH;
var private LoggerAPI.Definition fatBadGameConfigIndexAdapter; 

protected function Finalizer()
{
    _.memory.Free(votingHandlerReference);
    _.memory.FreeMany(availableGameModes);
    votingHandlerReference      = none;
    availableGameModes.length   = 0;
}

/**
 *  Replaces `XVotingHandler`'s configs with Acedia's game modes.
 *  Backup of replaced configs is made internally, so that they can be restored
 *  on map change.
 */
public final function InjectIntoVotingHandler()
{
    local int                                       i;
    local GameMode                                  nextGameMode;
    local XVotingHandler                            votingHandler;
    local array<VotingHandler.MapVoteGameConfig>    newVotingHandlerConfig;
    if (votingHandlerReference != none) {
        return;
    }
    votingHandler = XVotingHandler(_.unreal.FindActorInstance(
        _.unreal.GetGameType().VotingHandlerClass));
    if (votingHandler == none)
    {
        _.logger.Auto(fatNoXVotingHandler);
        return;
    }
    votingHandlerReference = _.unreal.ActorRef(votingHandler);
    class'GameMode'.static.Initialize();
    availableGameModes = class'GameMode'.static.AvailableConfigs();
    for (i = 0; i < availableGameModes.length; i += 1)
    {
        nextGameMode = GameMode(class'GameMode'.static
            .GetConfigInstance(availableGameModes[i]));
        newVotingHandlerConfig[i] = BuildVotingHandlerConfig(nextGameMode);
        //  Report omitted mutators / server options
        nextGameMode.ReportBadMutatorNames();
        nextGameMode.ReportBadOptions();
    }
    backupVotingHandlerConfig   = votingHandler.gameConfig;
    votingHandler.gameConfig    = newVotingHandlerConfig;
}

private function VotingHandler.MapVoteGameConfig BuildVotingHandlerConfig(
    GameMode gameMode)
{
    local VotingHandler.MapVoteGameConfig result;
    result.gameClass    = _.text.ToString(gameMode.GetGameTypeClass());
    result.gameName     = _.text.ToColoredString(gameMode.GetTitle());
    result.prefix       = _.text.ToString(gameMode.GetMapPrefix());
    result.acronym      = _.text.ToString(gameMode.GetAcronym());
    result.mutators     = BuildMutatorString(gameMode);
    result.options      = BuildOptionsString(gameMode);
    return result;
}

private function string BuildMutatorString(GameMode gameMode)
{
    local int           i;
    local string        result;
    local array<Text>   usedMutators;
    usedMutators = gameMode.GetIncludedMutators();
    for (i = 0; i < usedMutators.length; i += 1)
    {
        if (i > 0) {
            result $= ",";
        }
        result $= _.text.ToString(usedMutators[i]);
    }
    return result;
}

private function string BuildOptionsString(GameMode gameMode)
{
    local bool                  optionWasAdded;
    local string                result;
    local string                nextKey, nextValue;
    local CollectionIterator    iter;
    local AssociativeArray      options;
    options = gameMode.GetOptions();
    for (iter = options.Iterate(); !iter.HasFinished(); iter.Next())
    {
        nextKey     = Text(iter.GetKey()).ToString();
        nextValue   = Text(iter.Get()).ToString();
        if (optionWasAdded) {
            result $= "?";
        }
        result $= (nextKey $ "=" $ nextValue);
        optionWasAdded = true;
    }
    options.Empty(true);
    options.FreeSelf();
    iter.FreeSelf();
    return result;
}

/**
 *  Makes necessary preparations for the server travel.
 */
public final function PrepareForServerTravel()
{
    local int               pickedVHConfig;
    local GameMode          nextGameMode;
    local string            nextGameClassName;
    local class<GameInfo>   nextGameClass;
    local XVotingHandler    votingHandler;
    if (votingHandlerReference == none)     return;
    votingHandler = XVotingHandler(votingHandlerReference.Get());
    if (votingHandler == none)              return;
    //  Server travel caused by something else than `XVotingHandler`
    if (!votingHandler.bLevelSwitchPending) return;

    pickedVHConfig = votingHandler.currentGameConfig;
    if (pickedVHConfig < 0 || pickedVHConfig >= votingHandler.gameConfig.length)
    {
        _.logger.Auto(fatBadGameConfigIndexVH)
            .ArgInt(pickedVHConfig)
            .ArgInt(votingHandler.gameConfig.length);
        return;
    }
    if (pickedVHConfig >= availableGameModes.length)
    {
        _.logger.Auto(fatBadGameConfigIndexAdapter)
            .ArgInt(pickedVHConfig)
            .ArgInt(availableGameModes.length);
        return;
    }
    nextGameClassName = votingHandler.gameConfig[pickedVHConfig].gameClass;
    if (string(_.unreal.GetGameType().class) ~= nextGameClassName) {
        nextGameClass = _.unreal.GetGameType().class;
    }
    else
    {
        nextGameClass =
            class<GameInfo>(_.memory.LoadClass_S(nextGameClassName));
    }
    default.isServerTraveling = true;
    default.targetGameMode = availableGameModes[pickedVHConfig].ToString();
    nextGameMode = GetConfigFromString(default.targetGameMode);
    default.storedGameDifficulty = nextGameClass.default.gameDifficulty;
    nextGameClass.default.gameDifficulty = GetNumericDifficulty(nextGameMode);
}

/**
 *  Restore `GameInfo`'s settings after the server travel and
 *  apply selected `GameMode`.
 *
 *  @return `GameMode` picked before server travel
 *      (the one that must be running now).
 */
public final function GameMode SetupGameModeAfterTravel()
{
    if (!default.isServerTraveling) {
        return none;
    }
    _.unreal.GetGameType().default.gameDifficulty = default.storedGameDifficulty;
    default.isServerTraveling = false;
    return GetConfigFromString(targetGameMode);
}

/**
 *  Restores `XVotingHandler`'s config to the values that were overridden by
 *  `VHAdapter`'s `InjectIntoVotingHandler()` method.
 */
public final function RestoreVotingHandlerConfigBackup()
{
    local XVotingHandler votingHandler;
    if (votingHandlerReference == none) return;
    votingHandler = XVotingHandler(votingHandlerReference.Get());
    if (votingHandler == none)          return;

    votingHandler.gameConfig            = backupVotingHandlerConfig;
    votingHandler.default.gameConfig    = backupVotingHandlerConfig;
    votingHandler.SaveConfig();
}

//  `GameMode`'s name as a `string` -> `GameMode` instance
private function GameMode GetConfigFromString(string configName)
{
    local GameMode  result;
    local Text      nextConfigName;
    nextConfigName = _.text.FromString(configName);
    result = GameMode(class'GameMode'.static.GetConfigInstance(nextConfigName));
    _.memory.Free(nextConfigName);
    return result;
}

//  Convert `GameMode`'s difficulty's textual representation into
//  KF's numeric one.
private final function int GetNumericDifficulty(GameMode gameMode)
{
    local int i;
    local string difficulty;
    difficulty = Locs(_.text.ToString(gameMode.GetDifficulty()));
    for (i = 0; i < default.beginnerSynonyms.length; i += 1)
    {
        if (IsPrefixOf(difficulty, default.beginnerSynonyms[i])) {
            return 1;
        }
    }
    for (i = 0; i < default.normalSynonyms.length; i += 1)
    {
        if (IsPrefixOf(difficulty, default.normalSynonyms[i])) {
            return 2;
        }
    }
    for (i = 0; i < default.hardSynonyms.length; i += 1)
    {
        if (IsPrefixOf(difficulty, default.hardSynonyms[i])) {
            return 4;
        }
    }
    for (i = 0; i < default.suicidalSynonyms.length; i += 1)
    {
        if (IsPrefixOf(difficulty, default.suicidalSynonyms[i])) {
            return 5;
        }
    }
    for (i = 0; i < default.hoeSynonyms.length; i += 1)
    {
        if (IsPrefixOf(difficulty, default.hoeSynonyms[i])) {
            return 7;
        }
    }
    return int(difficulty);
}

protected final static function bool IsPrefixOf(string prefix, string value)
{
    return (InStr(value, prefix) == 0);
}

defaultproperties
{
    beginnerSynonyms(0) = "easy"
    beginnerSynonyms(1) = "beginer"
    beginnerSynonyms(2) = "beginner"
    beginnerSynonyms(3) = "begginer"
    beginnerSynonyms(4) = "begginner"
    normalSynonyms(0)   = "regular"
    normalSynonyms(1)   = "default"
    normalSynonyms(2)   = "normal"
    hardSynonyms(0)     = "harder" // "hard" is prefix of this, so it will count
    hardSynonyms(1)     = "difficult"
    suicidalSynonyms(0) = "suicidal"
    hoeSynonyms(0)      = "hellonearth"
    hoeSynonyms(1)      = "hellon earth"
    hoeSynonyms(2)      = "hell onearth"
    hoeSynonyms(3)      = "hoe"
    fatNoXVotingHandler             = (l=LOG_Fatal,m="`XVotingHandler` class is missing. Make sure your server setup supports Acedia's game modes (by used voting handler derived from `XVotingHandler`).")
    fatBadGameConfigIndexVH         = (l=LOG_Fatal,m="`XVotingHandler`'s `currentGameConfig` variable value of %1 is out-of-bounds for `XVotingHandler.gameConfig` of length %2. Report this issue.")
    fatBadGameConfigIndexAdapter    = (l=LOG_Fatal,m="`XVotingHandler`'s `currentGameConfig` variable value of %1 is out-of-bounds for `VHAdapter` of length %2. Report this issue.")
}