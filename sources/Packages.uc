/**
 *      Main and only Acedia mutator used for loading Acedia packages
 *  and providing access to mutator events' calls.
 *      Name is chosen to make config files more readable.
 *      Copyright 2020-2022 Anton Tarasenko
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
    config(Acedia);

//  Acedia's reference to a `Global` object.
var private Global          _;
var private ServerGlobal    _server;
var private ClientGlobal    _client;

//  Load Acedia on the client as well?
var private config bool clientside;
//  Array of predefined services that must be started along with Acedia mutator.
var private config array<string> package;
//  Set to `true` to activate Acedia's game modes system
var private config bool     useGameModes;
//  Responsible for setting up Acedia's game modes in current voting system
var VotingHandlerAdapter    votingAdapter;

var Mutator_OnMutate_Signal             onMutateSignal;
var Mutator_OnModifyLogin_Signal        onModifyLoginSignal;
var Mutator_OnCheckReplacement_Signal   onCheckReplacementSignal;

var private LoggerAPI.Definition infoFeatureEnabled;
var private LoggerAPI.Definition errNoServerLevelCore, errorCannotRunTests;

struct FeatureConfigPair
{
    var public class<Feature>   featureClass;
    var public Text             configName;
};

//  "Constructor"
simulated function PreBeginPlay()
{
    if (level.netMode == NM_DedicatedServer) {
        InitializeServer();
    }
    else {
        InitializeClient();
    }
}

private simulated function InitializeClient()
{
    _ = class'Global'.static.GetInstance();
    class'ClientLevelCore'.static.CreateLevelCore(self);
}

private function InitializeServer()
{
    local int                       i;
    local LevelCore                 serverCore;
    local GameMode                  currentGameMode;
    local array<FeatureConfigPair>  availableFeatures;

    if (clientside) {
        AddToPackageMap("Acedia");
    }
    CheckForGarbage();
    //  Launch and setup core Acedia
    _       = class'Global'.static.GetInstance();
    _server = class'ServerGlobal'.static.GetInstance();
    _client = class'ClientGlobal'.static.GetInstance();
    serverCore = class'ServerLevelCore'.static.CreateLevelCore(self);
    for (i = 0; i < package.length; i += 1) {
        _.environment.RegisterPackage_S(package[i]);
    }
    if (serverCore != none) {
        _server.ConnectServerLevelCore();
    }
    else
    {
        _.logger.Auto(errNoServerLevelCore);
        return;
    }
    if (class'TestingService'.default.runTestsOnStartUp) {
        RunStartUpTests();
    }
    SetupMutatorSignals();
    //  Determine required features and launch them
    availableFeatures = GetAutoConfigurationInfo();
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
    _.environment.ShutDown();
    if (nextMutator != none) {
    	nextMutator.ServerTraveling(URL, bItems);
    }
    Destroy();
}

//  Checks whether Acedia has left garbage after the previous map.
//  This can lead to serious problems, so such diagnostic check is warranted.
private function CheckForGarbage()
{
    local int           leftoverObjectAmount;
    local int           leftoverActorAmount;
    local int           leftoverDBRAmount;
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

public final function array<FeatureConfigPair> GetAutoConfigurationInfo()
{
    local int                       i;
    local array< class<Feature> >   availableFeatures;
    local FeatureConfigPair         nextPair;
    local array<FeatureConfigPair>  result;

    availableFeatures = _.environment.GetAvailableFeatures();
    for (i = 0; i < availableFeatures.length; i += 1)
    {
        nextPair.featureClass   = availableFeatures[i];
        nextPair.configName     = availableFeatures[i].static
            .GetAutoEnabledConfig();
        result[result.length] = nextPair;
    }
    return result;
}

private function EnableFeatures(array<FeatureConfigPair> features)
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
    local ServerUnrealService service;

    service = ServerUnrealService(class'ServerUnrealService'.static.Require());
    onMutateSignal              = Mutator_OnMutate_Signal(
        service.GetSignal(class'Mutator_OnMutate_Signal'));
    onModifyLoginSignal         = Mutator_OnModifyLogin_Signal(
        service.GetSignal(class'Mutator_OnModifyLogin_Signal'));
    onCheckReplacementSignal    = Mutator_OnCheckReplacement_Signal(
        service.GetSignal(class'Mutator_OnCheckReplacement_Signal'));
}

private final function RunStartUpTests()
{
    local TestingService testService;

    testService = TestingService(class'TestingService'.static.Require());
    testService.PrepareTests();
    if (testService.filterTestsByName) {
        testService.FilterByName(testService.requiredName);
    }
    if (testService.filterTestsByGroup) {
        testService.FilterByGroup(testService.requiredGroup);
    }
    if (!testService.Run()) {
        _.logger.Auto(errorCannotRunTests);
    }
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

function ModifyLogin(out string portal, out string options)
{
    if (onModifyLoginSignal != none) {
        onModifyLoginSignal.Emit(portal, options);
    }
    super.ModifyLogin(portal, options);
}

defaultproperties
{
    clientside      = false
    useGameModes    = false
    //  This is a server-only mutator
    remoteRole      = ROLE_SimulatedProxy
    bAlwaysRelevant = true
    //  Mutator description
    GroupName       = "Package loader"
    FriendlyName    = "Acedia loader"
    Description     = "Launcher for Acedia packages"
    infoFeatureEnabled      = (l=LOG_Info,m="Feature `%1` enabled with config \"%2\".")
    errNoServerLevelCore    = (l=LOG_Error,m="Cannot create `ServerLevelCore`!")
    errorCannotRunTests     = (l=LOG_Error,m="Could not perform Acedia's tests.")
}