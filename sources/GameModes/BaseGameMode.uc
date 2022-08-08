/**
 *  Base class for a game mode config, contains all the information Acedia's
 *  game modes must have, including settings
 *  (`includeFeature`, `includeFeatureAs` and `excludeFeature`)
 *  for picking used `Feature`s.
 *
 *  Contains three types of methods:
 *      1. Getters for its values;
 *      2. `UpdateFeatureArray()` method for updating list of `Feature`s to
 *          be used based on game info's settings;
 *      3. `Report...()` methods that perform various validation checks
 *           (and log them) on config data.
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
class BaseGameMode extends AcediaConfig
    dependson(Packages)
    abstract;

//  Name of the game mode players will see in voting (formatted string)
var protected config string         title;
//  Preferable difficulty level (plain string)
var protected config string         difficulty;
//  `Mutator`s to add with this game mode
var protected config array<string>  includeMutator;
//  `Feature`s to include (with "default" config)
var protected config array<string>  includeFeature;
//  `Feature`s to exclude from game mode, regardless of other settings
//  (this one has highest priority)
var protected config array<string>  excludeFeature;

struct FeatureConfigPair
{
    var public string feature;
    var public string config;
};
//  `Feature`s to include (with specified config).
//  Higher priority than `includeFeature`, but lower than `excludeFeature`.
var protected config array<FeatureConfigPair> includeFeatureAs;

var private LoggerAPI.Definition warnBadMutatorName, warnBadFeatureName;

protected function HashTable ToData()
{
    local int       i;
    local HashTable result;
    local HashTable nextPair;
    local ArrayList nextArray;

    result = _.collections.EmptyHashTable();
    result.SetFormattedString(P("title"), title);
    result.SetString(P("difficulty"), difficulty);
    nextArray = _.collections.EmptyArrayList();
    for (i = 0; i < includeFeature.length; i += 1) {
        nextArray.AddString(includeFeature[i]);
    }
    result.SetItem(P("includeFeature"), nextArray);
    _.memory.Free(nextArray);
    nextArray = _.collections.EmptyArrayList();
    for (i = 0; i < excludeFeature.length; i += 1) {
        nextArray.AddItem(_.text.FromString(excludeFeature[i]));
    }
    result.SetItem(P("excludeFeature"), nextArray);
    _.memory.Free(nextArray);
    nextArray = _.collections.EmptyArrayList();
    for (i = 0; i < includeMutator.length; i += 1) {
        nextArray.AddItem(_.text.FromString(includeFeature[i]));
    }
    result.SetItem(P("includeMutator"), nextArray);
    _.memory.Free(nextArray);
    nextArray = _.collections.EmptyArrayList();
    for (i = 0; i < includeFeatureAs.length; i += 1)
    {
        nextPair = _.collections.EmptyHashTable();
        nextPair.SetString(P("feature"), includeFeatureAs[i].feature);
        nextPair.SetString(P("config"), includeFeatureAs[i].config);
        nextArray.AddItem(nextPair);
        _.memory.Free(nextPair);
    }
    result.SetItem(P("includeFeatureAs"), nextArray);
    _.memory.Free(nextArray);
    return result;
}

protected function FromData(HashTable source)
{
    local int       i;
    local ArrayList nextArray;
    local HashTable nextPair;

    if (source == none) {
        return;
    }
    title =  source.GetFormattedString(P("title"));
    title =  source.GetString(P("title"));
    nextArray = source.GetArrayList(P("includeFeature"));
    includeFeature = DynamicIntoStringArray(nextArray);
    _.memory.Free(nextArray);
    nextArray = source.GetArrayList(P("excludeFeature"));
    excludeFeature = DynamicIntoStringArray(nextArray);
    _.memory.Free(nextArray);
    nextArray = source.GetArrayList(P("includeMutator"));
    includeMutator = DynamicIntoStringArray(nextArray);
    _.memory.Free(nextArray);
    nextArray = source.GetArrayList(P("includeFeatureAs"));
    if (nextArray == none) {
        return;
    }
    includeFeatureAs.length = 0;
    for (i = 0; i < nextArray.GetLength(); i += 1)
    {
        nextPair = nextArray.GetHashTable(i);
        includeFeatureAs[i] = HashTableIntoPair(nextPair);
        _.memory.Free(nextPair);
    }
    _.memory.Free(nextArray);
}

private final function FeatureConfigPair HashTableIntoPair(HashTable source)
{
    local Text              nextText;
    local FeatureConfigPair result;

    if (source == none) {
        return result;
    }
    nextText = source.GetText(P("feature"));
    if (nextText != none) {
        result.feature = nextText.ToString();
    }
    nextText = source.GetText(P("config"));
    if (nextText != none) {
        result.config = nextText.ToString();
    }
    return result;
}

private final function array<string> DynamicIntoStringArray(ArrayList source)
{
    local int           i;
    local Text          nextText;
    local array<string> result;

    if (source == none) {
        return result;
    }
    for (i = 0; i < source.GetLength(); i += 1)
    {
        nextText = source.GetText(i);
        if (nextText != none) {
            includeFeature[i] = nextText.ToString();
        }
    }
}

protected function array<Text> StringToTextArray(array<string> input)
{
    local int           i;
    local array<Text>   result;

    for (i = 0; i < input.length; i += 1) {
        result[i] = _.text.FromString(input[i]);
    }
    return result;
}

/**
 *  @return Name of the `GameInfo` class to be used with the caller game mode.
 */
public function Text GetGameTypeClass()
{
    return none;
}

/**
 *  @return Human-readable name of the caller game mode.
 *      Players will see it as the name of the mode in the voting options.
 */
public function Text GetTitle()
{
    return _.text.FromFormattedString(title);
}

/**
 *  @return Specified difficulty for the game mode.
 *      Interpretation of this value can depend on each particular game mode.
 */
public function Text GetDifficulty()
{
    return _.text.FromString(difficulty);
}

/**
 *  Checks `Feature`-related settings (`includeFeature`, `includeFeatureAs` and
 *  `excludeFeature`) for correctness and reports any issues.
 *  Currently correctness check simply ensures that all listed `Feature`s
 *  actually exist.
 */
public function ReportIncorrectSettings(
    array<Packages.FeatureConfigPair> featuresToEnable)
{
    local int           i;
    local array<string> featureNames, featuresToReplace;

    for (i = 0; i < featuresToEnable.length; i += 1) {
        featureNames[i] = string(featuresToEnable[i].featureClass);
    }
    ValidateFeatureArray(includeFeature, featureNames, "includeFeatures");
    ValidateFeatureArray(excludeFeature, featureNames, "excludeFeatures");
    for (i = 0; i < includeFeatureAs.length; i += 1) {
        featuresToReplace[i] = includeFeatureAs[i].feature;
    }
    ValidateFeatureArray(featuresToReplace, featureNames, "includeFeatureAs");
}

/**
 *  Checks `Mutator`-related settings (`includeMutator`) for correctness and
 *  reports any issues.
 *  Currently correctness check performs a simple validity check for mutator,
 *  to make sure it would not define a new option in server's URL.
 *
 *  See `ValidateServerURLName()` for more information.
 */
public function ReportBadMutatorNames()
{
    local int i;

    for (i = 0; i < includeMutator.length; i += 1)
    {
        if (!ValidateServerURLName(includeMutator[i]))
        {
            _.logger.Auto(warnBadMutatorName)
                .Arg(_.text.FromString(includeMutator[i]))
                .Arg(_.text.FromString(string(name)));
        }
    }
}

/**
 *  Makes sure that a word to be used in server URL as a part of an option
 *  does not contain "," / "?" / "=" or whitespace.
 *  This is useful to make sure that user-specified mutator entries only add
 *  one mutator or option's key / values will not specify only one pair,
 *  avoiding "?opt1=value1?opt2=value2" entries.
 */
protected function bool ValidateServerURLName(string entry)
{
    if (InStr(entry, "=") >= 0) return false;
    if (InStr(entry, "?") >= 0) return false;
    if (InStr(entry, ",") >= 0) return false;
    if (InStr(entry, " ") >= 0) return false;
    return true;
}

//  Is every element `subset` present inside `whole`?
private function ValidateFeatureArray(
    array<string>   subset,
    array<string>   whole,
    string          arrayName)
{
    local int   i, j;
    local bool  foundItem;

    for (i = 0; i < subset.length; i += 1)
    {
        foundItem = false;
        for (j = 0; j < whole.length; j += 1)
        {
            if (subset[i] ~= whole[j])
            {
                foundItem = true;
                break;
            }
        }
        if (!foundItem)
        {
            _.logger.Auto(warnBadFeatureName)
                .Arg(_.text.FromString(includeMutator[i]))
                .Arg(_.text.FromString(string(name)))
                .Arg(_.text.FromString(arrayName));
        }
    }
}

/**
 *  Updates passed `Feature` settings according to this game mode's settings.
 *
 *  @param  featuresToEnable    Settings to update.
 *      `FeatureConfigPair` is a pair of `Feature` (`featureClass`) and its
 *      config's name (`configName`).
 *      If `configName` is set to `none`, then corresponding `Feature`
 *      should not be enabled.
 *      Otherwise it should be enabled with a specified config.
 */
public function UpdateFeatureArray(
    out array<Packages.FeatureConfigPair> featuresToEnable)
{
    local int       i;
    local Text      newConfigName;
    local string    nextFeatureClassName;

    for (i = 0; i < featuresToEnable.length; i += 1)
    {
        nextFeatureClassName = string(featuresToEnable[i].featureClass);
        //  `excludeFeature`
        if (FeatureExcluded(nextFeatureClassName))
        {
            _.memory.Free(featuresToEnable[i].configName);
            featuresToEnable[i].configName = none;
            continue;
        }
        //  `includeFeatureAs`
        newConfigName = TryReplacingFeatureConfig(nextFeatureClassName);
        if (newConfigName != none)
        {
            _.memory.Free(featuresToEnable[i].configName);
            featuresToEnable[i].configName = newConfigName;
        }
        //  `includeFeature`
        if (    featuresToEnable[i].configName == none
            &&  FeatureInIncludedArray(nextFeatureClassName))
        {
            featuresToEnable[i].configName = P("default").Copy();
        }
    }
}

private function bool FeatureExcluded(string featureClassName)
{
    local int i;

    for (i = 0; i < excludeFeature.length; i += 1)
    {
        if (excludeFeature[i] ~= featureClassName) {
            return true;
        }
    }
    return false;
}

private function Text TryReplacingFeatureConfig(string featureClassName)
{
    local int i;

    for (i = 0; i < includeFeatureAs.length; i += 1)
    {
        if (includeFeatureAs[i].feature ~= featureClassName) {
            return _.text.FromString(includeFeatureAs[i].config);
        }
    }
    return none;
}

private function bool FeatureInIncludedArray(string featureClassName)
{
    local int i;

    for (i = 0; i < includeFeature.length; i += 1)
    {
        if (includeFeature[i] ~= featureClassName) {
            return true;
        }
    }
    return false;
}

public function array<Text> GetIncludedMutators()
{
    local int           i;
    local array<string> validatedMutators;

    for (i = 0; i < includeMutator.length; i += 1)
    {
        if (ValidateServerURLName(includeMutator[i])) {
            validatedMutators[validatedMutators.length] = includeMutator[i];
        }
    }
    return StringToTextArray(validatedMutators);
}

defaultproperties
{
    configName = "AcediaGameModes"
    warnBadMutatorName = (l=LOG_Warning,m="Mutator \"%1\" specified for game mode \"%2\" contains invalid characters and will be ignored. This is a configuration error, you should fix it.")
    warnBadFeatureName = (l=LOG_Warning,m="Feature \"%1\" specified for game mode \"%2\" in array `%3` does not exist in enabled packages and will be ignored. This is a configuration error, you should fix it.")
}