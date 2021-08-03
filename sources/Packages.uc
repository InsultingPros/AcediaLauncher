/**
 *      Main and only Acedia mutator used for loading Acedia packages
 *  and providing access to mutator events' calls.
 *      Name is chosen to make config files more readable.
 *      Copyright 2020 Anton Tarasenko
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

//      Default value of this variable will be used to store
//  reference to the active Acedia mutator,
//  as well as to ensure there's only one copy of it.
//      We can't use 'Singleton' class for that,
//  as we have to derive from 'Mutator'.
var private Packages selfReference;

//  Acedia's reference to a `Global` object.
var private Global _;

//  Package's manifest is supposed to always have a name of
//  "<package_name>.Manifest", this variable stores the ".Manifest" part
var private const string manifestSuffix;

//  Array of predefined services that must be started along with Acedia mutator.
var private config array<string> package;

//  AcediaCore package that this launcher is build for
var private config const string corePackage;

static public final function Packages GetInstance()
{
    return default.selfReference;
}

event PreBeginPlay()
{
    //  Enforce one copy rule and remember a reference to that copy
    if (default.selfReference != none)
    {
        Destroy();
        return;
    }
    default.selfReference = self;
    BootUp();
    if (class'TestingService'.default.runTestsOnStartUp) {
        RunStartUpTests();
    }
}

private final function BootUp()
{
    local int               i;
    local class<_manifest>  nextManifest;
    //  Load core
    Spawn(class'CoreService');
    _ = class'Global'.static.GetInstance();
    nextManifest = LoadManifestClass(corePackage);
    if (nextManifest == none)
    {
        /*_.logger.Fatal("Cannot load required AcediaCore package \""
            $ corePackage $ "\". Acedia will shut down.");*/
        Destroy();
        return;
    }
    LoadManifest(nextManifest);
    //  Load packages
    for (i = 0; i < package.length; i += 1)
    {
        nextManifest = LoadManifestClass(package[i]);
        if (nextManifest == none)
        {
            /*_.logger.Failure("Cannot load `Manifest` for package \""
                $ package[i] $ "\". Check if it's missing or"
                @ "if it's name is spelled incorrectly.");*/
            continue;
        }
        LoadManifest(nextManifest);
    }
    //  Inject broadcast handler
    InjectBroadcastHandler();
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
    if (testService.Run())
    {
        //  This listener will output test results into server's console
        class'TestingListener_AcediaLauncher'.static.SetActive(true);
    }
    else
    {
        //_.logger.Failure("Could not launch Acedia's start up testing process.");
    }
}

private final function class<_manifest> LoadManifestClass(string packageName)
{
    return class<_manifest>(DynamicLoadObject(  packageName $ manifestSuffix,
                                                class'Class', true));
}

private final function LoadManifest(class<_manifest> manifestClass)
{
    local int i;
    for (i = 0; i < manifestClass.default.aliasSources.length; i += 1)
    {
        if (manifestClass.default.aliasSources[i] == none) continue;
        //Spawn(manifestClass.default.aliasSources[i]);
        _.memory.Allocate(manifestClass.default.aliasSources[i]);
    }
    LaunchServicesAndFeatures(manifestClass);
    if (class'Commands_Feature'.static.IsEnabled()) {
        RegisterCommands(manifestClass);
    }
    for (i = 0; i < manifestClass.default.testCases.length; i += 1)
    {
        class'TestingService'.static
            .RegisterTestCase(manifestClass.default.testCases[i]);
    }
}

private final function RegisterCommands(class<_manifest> manifestClass)
{
    local int               i;
    local Commands_Feature  commandsFeature;
    commandsFeature =
        Commands_Feature(class'Commands_Feature'.static.GetInstance());
    for (i = 0; i < manifestClass.default.commands.length; i += 1)
    {
        if (manifestClass.default.commands[i] == none) continue;
        commandsFeature.RegisterCommand(manifestClass.default.commands[i]);
    }
}

private final function LaunchServicesAndFeatures(class<_manifest> manifestClass)
{
    local int   i;
    local Text  autoConfigName;
    //  Services
    for (i = 0; i < manifestClass.default.services.length; i += 1)
    {
        if (manifestClass.default.services[i] == none) continue;
        manifestClass.default.services[i].static.Require();
    }
    //  Features
    for (i = 0; i < manifestClass.default.features.length; i += 1)
    {
        if (manifestClass.default.features[i] == none) continue;
        manifestClass.default.features[i].static.LoadConfigs();
        autoConfigName =
            manifestClass.default.features[i].static.GetAutoEnabledConfig();
        if (autoConfigName != none) {
            manifestClass.default.features[i].static.EnableMe(autoConfigName);
        }
        _.memory.Free(autoConfigName);
    }
}

private final function InjectBroadcastHandler()
{
    local BroadcastEventsObserver                   ourBroadcastHandler;
    local BroadcastEventsObserver.InjectionLevel    injectionLevel;
    injectionLevel = class'BroadcastEventsObserver'.default.usedInjectionLevel;
    if (level == none || level.game == none)    return;
    if (injectionLevel == BHIJ_None)            return;

    ourBroadcastHandler = Spawn(class'BroadcastEventsObserver');
    if (injectionLevel == BHIJ_Registered)
    {
        level.game.broadcastHandler
            .RegisterBroadcastHandler(ourBroadcastHandler);
        return;
    }
    //      Here `injectionLevel == BHIJ_Root` holds.
    //      Swap out level's first handler with ours
    //  (needs to be done for both actor reference and it's class)
    ourBroadcastHandler.nextBroadcastHandler = level.game.broadcastHandler;
    ourBroadcastHandler.nextBroadcastHandlerClass = level.game.broadcastClass;
    level.game.broadcastHandler = ourBroadcastHandler;
    level.game.broadcastClass   = class'BroadcastEventsObserver';
}

//  Acedia is only able to run in a server mode right now,
//  so this function is just a stub.
public final function bool IsServerOnly()
{
    return true;
}

//  Provide a way to handle CheckReplacement event
function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    return class'MutatorEvents'.static.
        CallCheckReplacement(other, isSuperRelevant);
}

function Mutate(string command, PlayerController sendingController)
{
    if (class'MutatorEvents'.static.CallMutate(command, sendingController)) {
        super.Mutate(command, sendingController);
    }
}

defaultproperties
{
    corePackage     = "AcediaCore_0_2"
    manifestSuffix  = ".Manifest"
    //  This is a server-only mutator
    remoteRole      = ROLE_None
    bAlwaysRelevant = true
    //  Mutator description
    GroupName       = "Package loader"
    FriendlyName    = "Acedia loader"
    Description     = "Launcher for Acedia packages"
}