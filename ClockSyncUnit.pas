{$REGION 'copyright '}
(*
The MIT License (MIT) https://mit-license.org/

Copyright 2025 Everest Software LLC https://www.hmisys.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the “Software”), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sub-license, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Based on an example from "devatechnologies" on the old NJ forums.
https://forum.ninjatrader.com/forum/ninjatrader-8/platform-technical-support-aa/1237868-starting-up-ninjatrader-desktop-8-1-without-typing-username-and-password-every-time/page6?view=thread
Post #89
*)

{$ENDREGION}
unit ClockSyncUnit;

interface

uses Windows,Messages,System.Classes,System.IOUtils,System.SysUtils,GetProcessUnit;

var
 syncFileName:string;

procedure SyncClock;

implementation

function GetTemporaryDirectory:string;
var
 tempPath: array[0..MAX_PATH] of Char;
begin
 GetTempPath(MAX_PATH,@tempPath);
 result:=tempPath
end;

procedure SyncClock;
var
 aStrList:TStringList;
begin
 syncFileName:=GetTemporaryDirectory + '\' + TPath.GetGUIDFileName + '.bat';
 aStrList:=nil;
 try
  aStrList:=TStringList.Create;
  aStrList.Add('net start w32time');
  aStrList.Add('w32tm /resync');
  aStrList.Add('net stop w32time');
  aStrList.Add(Format('@del "%s"', [syncFileName]));    //delete the batch file
  aStrList.SaveToFile(syncFileName);
  WinExec(PAnsiChar(AnsiString(syncFileName)));
 finally
  aStrList.Free;
 end;
end;
end.
