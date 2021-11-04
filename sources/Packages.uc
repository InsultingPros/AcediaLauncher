/**
 *      Main and only Acedia mutator used for loading Acedia packages
 *  and providing access to mutator events' calls.
 *      Name is chosen to make config files more readable.
 *      Copyright 2020-2021 Anton Tarasenko
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
class Packages extends Mutator
    dependson(CoreService)
    config(Acedia);

//      Default value of this variable will be used to store
//  reference to the active Acedia mutator,
//  as well as to ensure there's only one copy of it.
//      We can't use 'Singleton' class for that,
//  as we have to derive from 'Mutator'.
var private Packages selfReference;

//  Acedia's reference to a `Global` object.
var private Global _;

//  Array of predefined services that must be started along with Acedia mutator.
var private config array<string> package;
//  Set to `true` to activate Acedia's game modes system
var private config bool     useGameModes;
//  Responsible for setting up Acedia's game modes in current voting system
var VotingHandlerAdapter    votingAdapter;

var Mutator_OnMutate_Signal             onMutateSignal;
var Mutator_OnCheckReplacement_Signal   onCheckReplacementSignal;

var private LoggerAPI.Definition infoFeatureEnabled;

static public final function Packages GetInstance()
{
    return default.selfReference;
}

//  "Constructor"
event PreBeginPlay()
{
    local GameMode                              currentGameMode;
    local array<CoreService.FeatureConfigPair>  availableFeatures;
    CheckForGarbage();
    //  Enforce one copy rule and remember a reference to that copy
    if (default.selfReference != none)
    {
        Destroy();
        return;
    }
    default.selfReference = self;
    //  Launch and setup core Acedia
    class'CoreService'.static.LaunchAcedia(self, package);
    _ = class'Global'.static.GetInstance();
    SetupMutatorSignals();
    //  Determine required features and launch them
    availableFeatures = CoreService(class'CoreService'.static.GetInstance())
        .GetAutoConfigurationInfo();
    if (useGameModes)
    {
        votingAdapter = VotingHandlerAdapter(
            _.memory.Allocate(class'VotingHandlerAdapter'));
        votingAdapter.InjectIntoVotingHandler();
        currentGameMode = votingAdapter.SetupGameModeAfterTravel();
        if (currentGameMode != none) {
            currentGameMode.UpdateFeatureArray(availableFeatures);
        }
    }
    EnableFeatures(availableFeatures);
}

//  "Finalizer"
function ServerTraveling(string URL, bool bItems)
{
    if (votingAdapter != none)
    {
        votingAdapter.PrepareForServerTravel();
        votingAdapter.RestoreVotingHandlerConfigBackup();
        _.memory.Free(votingAdapter);
        votingAdapter = none;
    }
    default.selfReference = none;
    CoreService(class'CoreService'.static.GetInstance()).ShutdownAcedia();
    if (nextMutator != none) {
    	nextMutator.ServerTraveling(URL, bItems);
    }
    Destroy();
}

//  Checks whether Acedia has left garbage after the previous map.
//  This can lead to serious problems, so such diagnostic check is warranted.
private function CheckForGarbage()
{
    local int leftoverObjectAmount, leftoverActorAmount, leftoverDBRAmount;
    local AcediaObject  nextObject;
    local AcediaActor   nextActor;
    local DBRecord      nextRecord;
    foreach AllObjects(class'AcediaObject', nextObject) {
        leftoverObjectAmount += 1;
    }
    foreach AllActors(class'AcediaActor', nextActor) {
        leftoverActorAmount += 1;
    }
    foreach AllObjects(class'DBRecord', nextRecord) {
        leftoverDBRAmount += 1;
    }
    if (    leftoverObjectAmount == 0 && leftoverActorAmount == 0
        &&  leftoverDBRAmount == 0)
    {
        Log("Acedia garbage check: nothing was found.");
    }
    else
    {
        Log("Acedia garbage check: garbage was found." @
            "This can cause problems, report it.");
        Log("Leftover object:" @ leftoverObjectAmount);
        Log("Leftover actors:" @ leftoverActorAmount);
        Log("Leftover database records:" @ leftoverDBRAmount);
    }
}

private function EnableFeatures(array<CoreService.FeatureConfigPair> features)
{
    local int i;
    for (i = 0; i < features.length; i += 1)
    {
        if (features[i].featureClass == none)   continue;
        if (features[i].configName == none)     continue;
        features[i].featureClass.static.EnableMe(features[i].configName);
        _.logger.Auto(infoFeatureEnabled)
            .Arg(_.text.FromString(string(features[i].featureClass)))
            .Arg(features[i].configName);  //  consumes `configName`
    }
}

//  Fetches and sets up signals that `Mutator` needs to provide
private function SetupMutatorSignals()
{
    local UnrealService service;
    service = UnrealService(class'UnrealService'.static.Require());
    onMutateSignal              = Mutator_OnMutate_Signal(
        service.GetSignal(class'Mutator_OnMutate_Signal'));
    onCheckReplacementSignal    = Mutator_OnCheckReplacement_Signal(
        service.GetSignal(class'Mutator_OnCheckReplacement_Signal'));
}

/**
 *  Below `Mutator` events are redirected into appropriate signals.
 */
function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    if (onCheckReplacementSignal != none) {
        return onCheckReplacementSignal.Emit(other, isSuperRelevant);
    }
    return true;
}

function Mutate(string command, PlayerController sendingController)
{
    if (onMutateSignal != none) {
        onMutateSignal.Emit(command, sendingController);
    }
    super.Mutate(command, sendingController);
}

defaultproperties
{
    useGameModes    = false
    //  This is a server-only mutator
    remoteRole      = ROLE_None
    bAlwaysRelevant = true
    //  Mutator description
    GroupName       = "Package loader"
    FriendlyName    = "Acedia loader"
    Description     = "Launcher for Acedia packages"
    infoFeatureEnabled = (l=LOG_Info,m="Feature `%1` enabled with config \"%2\".")
}