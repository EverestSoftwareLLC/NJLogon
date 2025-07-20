program NJLogon;

{$APPTYPE CONSOLE}

{$R *.res}

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

{$REGION 'Notes'}

//the only required parameter is the password.

//parameters, switches, wrap any values with spaces in "asasdf asdf"
// password                                     /pw XXX
// njTrader exe path, if default is not used    /pexe "XXX"
// timeout if default is not used (45 seconds)  /to value    cannot be less that 10 seconds or more than 300
// user name, if NJ is not saving it            /u "name"
// sync pc clock                                /syncOff     do not sync the pc clock with a time server

// verbose                                      /verbose     debugging

// example /pw passwordtest /pexe "the path to njTrader.exe" /to 60  /u "Jane Doe"

//if a parameter is used and the value is missing it is an error.

{$ENDREGION}

uses
 System.SysUtils,Windows,Math,Vcl.ExtCtrls,Vcl.Clipbrd,
 Console in '..\Shared\Console.pas',
 GetProcessUnit in 'GetProcessUnit.pas',
 ClockSyncUnit in 'ClockSyncUnit.pas';

const
 cPWSwitch              = 'pw';
 cExeSwitch             = 'pexe';
 cTimeoutSwitch         = 'to';
 cUserSwitch            = 'u';
 cSyncOffSwitch         = 'syncOff';
 cVerboseSwitch         = 'verbose';

 startTimeout           = 45;
 njExePath              = 'C:\Program Files\NinjaTrader 8\bin\NinjaTrader.exe';

var
 processID:longword;
 mutexHandle:THandle;
 watchdogTimer:TTimer;
 mainWindowHandle:HWND;
 timeout,timerCounter:integer;
 exePath,userName,password:string;
 globalError,closeProgram,syncIsOff,verboseLogging:boolean;

type                                  // Dummy class to hold timer event handler
 TTimerEventHandler = class
 class procedure TimerPulse(Sender: TObject);
end;

{$REGION 'Helpers'}
procedure ButtonClick(x,y:integer);
begin
 SetCursorPos(x,y);
 mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
 mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
end;

procedure WriteLineEx(const s1:string);
begin
 if verboseLogging then
  WriteLn(s1);
end;

procedure DoSendKeys(const mods,keys:string);
const
 cDown          = 0;
 cUp            = 1;
 cToggle        = 2;

 procedure SendKey(vKey: SmallInt; op:integer);
 var
  GInput: array[0..0] of tagINPUT; //GENERALINPUT; // doesn't have to be array :)
 begin
  ZeroMemory(@GInput,sizeOf(GInput));
  GInput[0].Itype:=INPUT_KEYBOARD;
  GInput[0].ki.wVk:=vKey;
  GInput[0].ki.wScan:=0;
  GInput[0].ki.time:=0;
  GInput[0].ki.dwExtraInfo:=0;
  GInput[0].ki.dwFlags:=0;                             //keydown

  case op of
   cDown:
    begin
     SendInput(1, GInput[0],SizeOf(GInput));
     Sleep(100);
    end;
   cUp:
    begin
     GInput[0].ki.dwFlags:=KEYEVENTF_KEYUP;
     SendInput(1, GInput[0],SizeOf(GInput));
     Sleep(100);
    end;
   cToggle:
    begin
     SendInput(1, GInput[0],SizeOf(GInput));
     Sleep(100);
     GInput[0].ki.dwFlags:=KEYEVENTF_KEYUP;
     SendInput(1, GInput[0],SizeOf(GInput));
     Sleep(100);
    end;
  end;
 end;

 procedure DoMods(op:integer);
 var
  i:integer;
 begin
  for i:=1 to length(mods) do
   begin
    case mods[i] of
     '+':               SendKey($10, op);
     '^':               SendKey($11, op);
     '%':               SendKey($12, op);
    end;
   end;
 end;

 procedure DoKeys(op:integer);
 var
  i:integer;
 begin
  for i:=1 to length(keys) do
   SendKey(VkKeyScan(keys[i]), op);
 end;

begin
 if (keys = '') then
  Exit;

 DoMods(cDown);
 DoKeys(cToggle);
 DoMods(cUp);
end;
{$ENDREGION}

{$REGION 'Get window by class and caption'}
function EnumWindowProc(H:HWnd; trash:integer):boolean;stdCall;
var
 aRect:TRect;
 fullName:string;
 windHandle:HWnd;
 buffer:array[0..255] of char;
begin
 EnumWindowProc:=true;
 GetClassName(H,buffer,255);                 //I know 256
 fullName:=buffer;
 if (pos('HwndWrapper',fullName) <> 0) then  //we search for partial because each instance has guid added at end
  begin                                      //we found one. There normally is more than one.
   windHandle:=FindWindow(PWideChar(fullName),'Welcome');
   if (windHandle = 0) then
    Exit;

   WriteLineEx(fullName);
   WriteLineEx(IntToHex(windHandle,8));
   if (windHandle <> 0) then
    begin
     Windows.GetWindowRect(windHandle,aRect);
     WriteLineEx(aRect.Left.ToString + ' ' + aRect.Top.ToString + ' ' + aRect.Right.ToString + ' ' +aRect.Bottom.ToString);

     if (aRect.Left <> 0) and (aRect.top <> 0) then
      begin
       mainWindowHandle:=windHandle;
       EnumWindowProc:=false;
      end;
    end;
  end;
end;

procedure GetWindowByCaption;
var
 trashInt:integer;
begin
 trashInt:=0;           //compiler happy
 EnumWindows(@EnumWindowProc,trashInt);
end;
{$ENDREGION}

class procedure TTimerEventHandler.TimerPulse(Sender: TObject);
var
 aRect:TRect;
 restartTimer:boolean;
begin
 watchdogTimer.Enabled:=false;
 restartTimer:=false;
 try
  Inc(timerCounter);
  WriteLn('Timer: ' + timerCounter.ToString);
  if (timerCounter >= timeout) then
   begin
    closeProgram:=true;
    WaitAnyKeyPressed('Timeout waiting for NJTrader expired. Program will end. Press any key.');
    Exit;
   end;

  if (processID = 0) then                     //not found
   processID:=GetProcessesByName('NinjaTrader.exe');

  if (processID <> 0) then                    //found
   WriteLineEx('NinjaTrader.exe running ' + IntToHex(processID,8));

  if (mainWindowHandle = 0) then
   mainWindowHandle:=GetMainWindowHandle(processID);

  if (mainWindowHandle <> 0) then
   begin
    WriteLineEx('Main window found ' + IntToHex(mainWindowHandle,8));

    if (not SetForegroundWindow(mainWindowHandle)) then
     begin
      watchdogTimer.Enabled:=false;
      closeProgram:=true;
      WaitAnyKeyPressed(SysErrorMessage(GetLastError));
      Exit;
     end;

    Windows.GetWindowRect(mainWindowHandle,aRect);
    WriteLineEx(IntToHex(mainWindowHandle,8) + ' ' + aRect.Left.ToString + ' ' + aRect.Top.ToString +
                                               ' ' + aRect.Right.ToString + ' ' +aRect.Bottom.ToString);

    if (aRect.Left = 0) and (aRect.top = 0) then
     begin
 //At times, the window returned is not the main window.
 //If the left and top of the rect are 0 then it is not the main window.
 //Assuming the window is not actually in the top left. It appears to always open at center of a screen.
 //So enumumerate all the windows and try to find one with a class name containing HwndWrapper that is not 0,0.

      WriteLineEx('Expanded window search');
      GetWindowByCaption;
      restartTimer:=true;
      Exit;                      //handle next pass
     end;

    if not IsWindowVisible(mainWindowHandle) then
     WriteLineEx(IntToHex(mainWindowHandle,8) + ' window is not visible');

    if (userName <> '') then
     begin                              //???clear the field first
      WriteLineEx('Send user name.');
      ButtonClick(aRect.Left + 30, aRect.Top + 138);
      Clipboard.AsText:=userName;
      DoSendKeys('^','v');                              //ctrl v, paste
     end;

    WriteLineEx('Send password.');
    Clipboard.AsText:=password;
    ButtonClick(aRect.Left + 30, aRect.Top + 210);   //password
    DoSendKeys('^','v');                                //ctrl v, paste
    DoSendKeys('',chr(VK_RETURN));

    Clipboard.Clear;                            //remove password from clipboard
    restartTimer:=false;
    closeProgram:=true;
    WriteLineEx('Close program from timer.');
    Exit;
   end
  else
   restartTimer:=true;

 finally
  watchdogTimer.Enabled:=restartTimer;
  WriteLineEx('Timer: ' + timerCounter.ToString + ' end');
 end;

end;

{$REGION 'ParseParameters'}
procedure ParseParameters;
var
 s1:string;
begin
 WriteLineEx('Parameter count: '  + ParamCount.ToString);
 if (ParamCount < 1) then
  begin
   globalError:=true;
   WaitAnyKeyPressed('At least one parameter must be used, the password.');
   Exit;
  end;

 s1:='';
 if FindCmdLineSwitch(cPWSwitch,s1,true,[clstValueNextParam]) then
  begin
   if (s1 = '') then
    begin
     globalError:=true;
     WaitAnyKeyPressed('The password is empty (blank).');
     Exit;
    end;
   password:=s1;
  end;

 s1:='';
 if FindCmdLineSwitch(cExeSwitch,s1,true,[clstValueNextParam]) then
  begin
   if (s1 = '') then
    begin
     globalError:=true;
     WaitAnyKeyPressed('The "NJTrader.exe" is empty (blank).');
     Exit;
    end;
   exePath:=s1;
  end;

 s1:='';
 if FindCmdLineSwitch(cTimeoutSwitch,s1,true,[clstValueNextParam]) then
  begin
   if (s1 = '') then
    begin
     globalError:=true;
     WaitAnyKeyPressed('The timeout value is empty (blank).');
     Exit;
    end;
   timeout:=StrToIntDef(s1,startTimeout);
  end;

 s1:='';
 if FindCmdLineSwitch(cUserSwitch,s1,true,[clstValueNextParam]) then
  begin
   if (s1 = '') then
    begin
     globalError:=true;
     WaitAnyKeyPressed('The user name is empty (blank).');
     Exit;
    end;
   userName:=s1;
  end;

 s1:='';
 if FindCmdLineSwitch(cSyncOffSwitch,s1,true,[clstValueNextParam]) then
  syncIsOff:=true;

 s1:='';
 if FindCmdLineSwitch(cVerboseSwitch,s1,true,[clstValueNextParam]) then
  verboseLogging:=true;
end;
{$ENDREGION}

procedure Initialize;
begin
 WriteLineEx('Initialize');
 timeout:=45;
 timerCounter:=0;
 exePath:=njExePath;
 userName:='';
 closeProgram:=false;
 mainWindowHandle:=0;
 syncIsOff:=false;
 verboseLogging:=false;
end;

procedure LastCheckBeforeLaunch;
begin
 WriteLineEx('LastCheckBeforeLaunch');
 if not FileExists(exePath) then
  begin
   globalError:=true;
   WriteLn('NinjaTrader.exe would not be found.');
   WaitAnyKeyPressed(exePath);
   Exit;
  end;

 timeout:=EnsureRange(timeout,10,300);          //in seconds
end;

procedure MsgPump;                               //console apps do not have message pumps
var
 Msg:TMsg;
begin
 while GetMessage(Msg, 0, 0, 0) do
  begin
   DispatchMessageW(Msg);

   if closeProgram then
    Break;

   SleepEx(10,false);
  end;
end;

procedure AnotherRunning;     //only one program can be active
var
 s1:string;
begin
 mutexHandle:=CreateMutex(nil,true,'NJ_Running_Mutex');
 if (GetLastError = ERROR_ALREADY_EXISTS) then
  Halt;

 s1:=GetFileData(ParamStr(0),3);
 WriteLn('Version: ' + s1);
end;

begin
 AnotherRunning;
 watchdogTimer:=nil;    //compiler happy
 try
  try
   Initialize;
   ParseParameters;
   if globalError then
    Exit;

   LastCheckBeforeLaunch;
   if globalError then
    Exit;

   if not syncIsOff then
    begin
     WriteLineEx('SyncClock');
     SyncClock;
    end;

   watchdogTimer:=TTimer.Create(nil);
   watchdogTimer.enabled:=false;
   watchdogTimer.Interval:=1000;
   watchdogTimer.OnTimer:=TTimerEventHandler.TimerPulse;

   processID:=GetProcessesByName('NinjaTrader.exe');   //is it already running
   if (processID = 0) then
    WinExec(exePath);

   watchdogTimer.enabled:=true;

   WriteLineEx('MsgPump start.');
   MsgPump;
   WriteLineEx('MsgPump end.');
  except
   on E: Exception do
    WriteLn('Exception' +  E.ClassName, ': ', E.Message);
  end;

 if verboseLogging then
  WaitAnyKeyPressed('Press any key to close.');

 finally
  if (syncFileName <> '') then
   System.SysUtils.DeleteFile(syncFileName);     //safety
  watchdogTimer.Free;

  if (mutexHandle <> 0) then
   CloseHandle(mutexHandle);
 end;
end.
