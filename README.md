# NJLogon
NinjaTrader Logon

The program is a console application (64 bit). The program does not save/store or transmit any data. The NJLogon.exe program is digitally code signed.

The only required parameter is the password (/pw).
If any parameter value has a space character, wrap the data in double quotes “this has spaces”.
Each parameter and value are separated by a space.
Create a short cut to the NJLogon.exe program and pass the parameters in the target field.

Parameters
/pw..........password

/pexe        path to the NinjaTrader.exe program.
             Default path is: “C:\Program Files\NinjaTrader 8\bin\NinjaTrader.exe”

/to          Timeout. The time limit to attempt logon, default 45 seconds. Range 10-300 seconds. 

/u           user name. This should not be needed. 

/syncOff     Clock synchronize. 
             Default is the program will attempt to synchronize the PC clock with a time server configured in the OS. (no parameter required)

/verbose     Verbose logging of program progress. Default is off.

Example:

/pw	myPassword
/pexe	“C:\Program Files\NinjaTrader 8\bin\NinjaTrader.exe”
/to	20
/u	“Jane Doe”
/syncOff
/verbose	

Example:
C:\NJLogon.exe /pw aPassword /to 30 

The program was built with Delphi 10.2.3.
No third-party components used.

