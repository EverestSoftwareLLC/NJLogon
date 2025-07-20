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

unit GetProcessUnit;

interface

uses
  Windows, TlHelp32, SysUtils,Winapi.ShellAPI,System.AnsiStrings;

function GetProcessesByName(const ProcessName: string):longWord;
function GetMainWindowHandle(ProcessID: DWORD): HWND;
procedure WinExec(const fName:string);
function GetFileData(const fName:string; which:integer):string;

implementation

function GetProcessesByName(const ProcessName: string):longWord;
var
 Snapshot: THandle;
 ProcessEntry:TProcessEntry32;
begin
 result:=0;
 Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
 if (Snapshot = INVALID_HANDLE_VALUE) then
  Exit;

 try
  ProcessEntry.dwSize := SizeOf(TProcessEntry32);
  if (Process32First(Snapshot, ProcessEntry)) then
   begin
    repeat
     if SameText(ProcessEntry.szExeFile, ProcessName) then
      begin
       result:=ProcessEntry.th32ProcessID;
       Break;
      end;
     until not Process32Next(Snapshot, ProcessEntry);
    end;
 finally
  CloseHandle(Snapshot);
 end;
end;

function GetMainWindowHandle(ProcessID: DWORD):HWND;
var
 wnd:HWND;
 TargetProcessID: DWORD;
begin
 result:=0;
 wnd:=GetTopWindow(0);
 while (wnd <> 0) do
  begin
   GetWindowThreadProcessId(wnd, @TargetProcessID);
   if (TargetProcessID = ProcessID) and (GetWindow(wnd, GW_OWNER) = 0) then
    begin
     result:=wnd;
     Exit;
    end;
   wnd:=GetNextWindow(wnd , GW_HWNDNEXT);
  end;
end;

{$REGION 'ShellExecute'}
procedure WinExec(const fName:string);
var
 shellExecuteInfo:TSHELLEXECUTEINFO;
begin
 FillChar(shellExecuteInfo,sizeOf(TShellExecuteInfo),0);
 with shellExecuteInfo do
  begin
   cbSize:=sizeOf(TShellExecuteInfo);
   fMask:=SEE_MASK_FLAG_NO_UI or SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_DDEWAIT;
   wnd:=HWND_DESKTOP;
   lpVerb:=nil;
   lpFile:=PChar(fName);
   lpParameters:=PChar('');
   lpDirectory:=PChar('');
   nShow:=SW_SHOWNORMAL;
  end;
 ShellExecuteEx(@shellExecuteInfo);
end;
{$ENDREGION}

function GetFileData(const fName:string; which:integer):string;
const
 infoNum = 10;
 InfoStr : array[1..infoNum] of string =
        ('CompanyName','FileDescription','FileVersion','InternalName','LegalCopyright',
         'LegalTradeMarks','OriginalFileName','ProductName','ProductVersion','Comments');
var
 temp:integer;
 n,len:cardinal;
 TransLen:longword;
 LangCharSet:AnsiString;
 buf,PTransBuffer:PAnsiChar;
 value:PChar;
begin
 n:=GetFileVersionInfoSize(PChar(fName),n);
 result:='Error';
 if (n > 0) then
  begin

   buf:=nil;
   try
    buf:=AllocMem(n);
    GetFileVersionInfo(PChar(fName),0,n,buf);

    VerQueryValue(buf, '\VarFileInfo\Translation',Pointer(PTransBuffer), TransLen);
    if (TransLen >= 4) then
     begin
      temp:=0;
      System.AnsiStrings.StrLCopy(@temp,PTransBuffer, 2);
      LangCharSet:=AnsiString(IntToHex(temp, 4));
      System.AnsiStrings.StrLCopy(@temp,PTransBuffer + 2, 2);
      LangCharSet:=LangCharSet + AnsiString(IntToHex(temp, 4));
     end
    else
     Exit;

    VerQueryValue(buf,PChar(string('StringFileInfo\' + string(LangCharSet) + '\' + InfoStr[which])),
                  Pointer(value),len);

    result:=value;
   finally
    if Assigned(buf) then
     FreeMem(buf,n);
   end;
  end
 else
  begin
   result:=SysErrorMessage(GetLastError);
  end;
end;

end.
