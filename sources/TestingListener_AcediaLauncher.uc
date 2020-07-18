/**
 *  Overloaded testing events listener to catch when tests that we run during
 *  server loading finish.
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
class TestingListener_AcediaLauncher extends TestingListenerBase
    abstract;

static function TestingEnded(
    array< class<TestCase> >    testQueue,
    array<TestCaseSummary>      results)
{
    local int           i;
    local string        nextLine;
    local array<string> textSummary;
    textSummary = class'TestCaseSummary'.static.GenerateStringSummary(results);
    for (i = 0; i < textSummary.length; i += 1)
    {
        nextLine = _().text.ConvertString(  textSummary[i],
                                            STRING_Formatted, STRING_Plain);
        Log(nextLine);
    }
    //  No longer need to listen to testing events
    SetActive(false);
}

defaultproperties
{
    relatedEvents = class'TestingEvents'
}