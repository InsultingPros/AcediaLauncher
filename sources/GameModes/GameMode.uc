/**
 *  The only implementation for `BaseGameMode` suitable for standard
 *  killing floor game types.
 *      Copyright 2021-2022 Anton Tarasenko
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
class GameMode extends BaseGameMode
    perobjectconfig
    config(AcediaGameModes);

struct GameOption
{
    var public string key;
    var public string value;
};
//  Allow to specify additional server options for this game mode
var protected config array<GameOption> option;
//  Specify `GameInfo`'s class to use, default is "KFMod.KFGameType"
//  (plain string)
var protected config string gameTypeClass;
//  Short version of the name of the game mode players will see in
//  voting handler messages sometimes (plain string)
var protected config string acronym;
//  Map prefix - only maps that start with specified prefix will be voteable for
//  this game mode (plain string)
var protected config string mapPrefix;

var private LoggerAPI.Definition warnBadOption; 

protected function DefaultIt()
{
    title = "Acedia game mode";
    difficulty = "Hell On Earth";
    gameTypeClass = "KFMod.KFGameType";
    acronym = "";
    mapPrefix = "KF";
    includeFeature.length = 0;
    excludeFeature.length = 0;
    includeMutator.length = 0;
    option.length = 0;
}

protected function HashTable ToData()
{
    local int       i;
    local ArrayList nextArray;
    local HashTable result, nextPair;

    result = super.ToData();
    if (result == none) {
        return none;
    }
    result.SetString(P("gameTypeClass"), gameTypeClass);
    result.SetString(P("acronym"), acronym);
    result.SetString(P("mapPrefix"), mapPrefix);
    nextArray = _.collections.EmptyArrayList();
    for (i = 0; i < option.length; i += 1)
    {
        nextPair = _.collections.EmptyHashTable();
        nextPair.SetString(P("key"), option[i].key);
        nextPair.SetString(P("value"), option[i].value);
        nextArray.AddItem(nextPair);
        _.memory.Free(nextPair);
    }
    result.SetItem(P("option"), nextArray);
    _.memory.Free(nextArray);
    return result;
}

protected function FromData(HashTable source)
{
    local int           i;
    local GameOption    nextGameOption;
    local ArrayList     nextArray;
    local HashTable     nextPair;

    super.FromData(source);
    if (source == none) {
        return;
    }
    gameTypeClass = source.GetString(P("gameTypeClass"));
    acronym = source.GetString(P("acronym"));
    mapPrefix = source.GetString(P("mapPrefix"));
    nextArray = source.GetArrayList(P("option"));
    if (nextArray == none) {
        return;
    }
    option.length = 0;
    for (i = 0; i < nextArray.GetLength(); i += 1)
    {
        nextPair = HashTable(nextArray.GetItem(i));
        if (nextPair == none) {
            continue;
        }
        nextGameOption.key      = nextPair.GetString(P("key"));
        nextGameOption.value    = nextPair.GetString(P("value"));
        option[option.length]   = nextGameOption;
        _.memory.Free(nextPair);
    }
    _.memory.Free(nextArray);
}

public function Text GetGameTypeClass()
{
    if (gameTypeClass == "") {
        return P("KFMod.KFGameType").Copy();
    }
    else {
        return _.text.FromString(gameTypeClass);
    }
}

public function Text GetAcronym()
{
    if (acronym == "") {
        return _.text.FromString(string(name));
    }
    else {
        return _.text.FromString(acronym);
    }
}

public function Text GetMapPrefix()
{
    if (acronym == "") {
        return _.text.FromString("KF-");
    }
    else {
        return _.text.FromString(mapPrefix);
    }
}

/**
 *  Checks option-related settings (`option`) for correctness and reports
 *  any issues.
 *  Currently correctness check performs a simple validity check for mutator,
 *  to make sure it would not define a new option in server's URL.
 *
 *  See `ValidateServerURLName()` in `BaseGameMode` for more information.
 */
public function ReportBadOptions()
{
    local int i;

    for (i = 0; i < option.length; i += 1)
    {
        if (    !ValidateServerURLName(option[i].key)
            ||  !ValidateServerURLName(option[i].value))
        {
            _.logger.Auto(warnBadOption)
                .Arg(_.text.FromString(option[i].key))
                .Arg(_.text.FromString(option[i].value))
                .Arg(_.text.FromString(string(name)));
        }
    }
}

/**
 *  @return Server options as key-value pairs in an `HashTable`.
 */
public function HashTable GetOptions()
{
    local int       i;
    local HashTable result;

    result = _.collections.EmptyHashTable();
    for (i = 0; i < option.length; i += 1)
    {
        if (!ValidateServerURLName(option[i].key))      continue;
        if (!ValidateServerURLName(option[i].value))    continue;
        result.SetItem( _.text.FromString(option[i].key),
                        _.text.FromString(option[i].value));
    }
    return result;
}

defaultproperties
{
    configName = "AcediaGameModes"
    warnBadOption = (l=LOG_Warning,m="Option with key \"%1\" and value \"%2\" specified for game mode \"%3\" contains invalid characters and will be ignored. This is a configuration error, you should fix it.")
}