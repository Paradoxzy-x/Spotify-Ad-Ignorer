#Persistent
#SingleInstance Force
#NoEnv
#KeyHistory 0
ListLines, Off
SetBatchLines, -1
SetWinDelay, 0
SetWorkingDir, % A_ScriptDir

Menu, Tray, NoStandard
Menu, Tray, Icon, Spotify Ad Ignorer.ico
Menu, Tray, Tip, Spotify Ad Ignorer
Menu, Tray, Click, 1
Menu, Tray, Add, Settings, UserSettingsInit
Menu, Tray, Default, Settings
Menu, Tray, Add
Menu, Tray, Add, Exit

; https://gist.github.com/G33kDude/5b7ba418e685e52c3e6507e5c6972959
; https://gist.github.com/anonymous1184/c06335f3aed215cdea414c33354a728b
#Include Lib\VA.ahk
#Include Lib\AppVolume.ahk
; https://github.com/cocobelgica/AutoHotkey-JSON
#Include Lib\JSON.ahk

; Core config
Global ClientID, ClientSecret, AccessToken, ExpireToken, RefreshToken
; RegistryPath is hardcoded - AuthToken is generated from ClientID & ClientSecret
, RegistryPath, AuthToken
; User settings
, SpotifyPath, AutoplayOnStart, MinimizeOnStart, TimerInterval, HideTrayIcon
; User settings - temp vars for GUI Submit
, SpotifyPathT, AutoplayOnStartT, MinimizeOnStartT, TimerIntervalT, HideTrayIconT
; GUI error messages
, FirstLaunchErrorText, SpotifyAuthErrorText, UserSettingsErrorText
; First time set-up auth
, SpotifyAuthURL, SpotifyAuthState

PrimaryInit()
Return

;--------------------------------------------------------------------------------
;------------------------------------- INIT -------------------------------------
;--------------------------------------------------------------------------------
PrimaryInit() {
  LoadRegistryValues()

  If (!ClientID || !ClientSecret || !SpotifyPath)
    FirstLaunchInit()
  Else
    SecondaryInit()
}

;----------------------------------------
SecondaryInit() {
  Base64encUTF8(AuthToken, ClientID ":" ClientSecret)

  If (!RefreshToken)
    SpotifyAuthInit()
  Else
    TertiaryInit()
}

;----------------------------------------
TertiaryInit() {
  If (A_Now >= ExpireToken)
    GetNewTokens()

  ApplyUserSettings(A_Args)
  AdCheckTimerInit()
}

;--------------------------------------------------------------------------------
;----------------------------- SETTINGS / REGISTRY ------------------------------
;--------------------------------------------------------------------------------
LoadRegistryValues() {
  RegistryPath := "HKCU\Software\Spotify Ad Ignorer"
  LoadCoreConfig()
  LoadUserSettings()
}

;----------------------------------------
LoadCoreConfig() {
  RegRead, ClientID, % RegistryPath, ClientID
  RegRead, ClientSecret, % RegistryPath, ClientSecret
  RegRead, AccessToken, % RegistryPath, AccessToken
  RegRead, ExpireToken, % RegistryPath, ExpireToken
  RegRead, RefreshToken, % RegistryPath, RefreshToken
}

;----------------------------------------
LoadUserSettings() {
  RegRead, SpotifyPath, % RegistryPath, SpotifyPath
  RegRead, AutoplayOnStart, % RegistryPath, AutoplayOnStart
  RegRead, MinimizeOnStart, % RegistryPath, MinimizeOnStart
  RegRead, TimerInterval, % RegistryPath, TimerInterval
  RegRead, HideTrayIcon, % RegistryPath, HideTrayIcon

  If (AutoplayOnStart != 1)
    AutoplayOnStart := 0

  If (MinimizeOnStart != 1)
    MinimizeOnStart := 0

  If (!TimerInterval || TimerInterval < 100)
    TimerInterval := 1500

  If (HideTrayIcon != 1)
    HideTrayIcon := 0
}

;----------------------------------------
SaveUserSettings() {
  RegWrite, REG_SZ, % RegistryPath, SpotifyPath, % SpotifyPathT
  RegWrite, REG_SZ, % RegistryPath, AutoplayOnStart, % AutoplayOnStartT
  RegWrite, REG_SZ, % RegistryPath, MinimizeOnStart, % MinimizeOnStartT
  RegWrite, REG_SZ, % RegistryPath, TimerInterval, % TimerIntervalT
  RegWrite, REG_SZ, % RegistryPath, HideTrayIcon, % HideTrayIconT

  LoadUserSettings()
  ApplyUserSettings()
}

;----------------------------------------
ApplyUserSettings(StartupArgs := "") {
  For N, Param in StartupArgs {
    If (Param == "-show-tray") {
      HideTrayIcon := 0
      Break
    }
  }

  If (HideTrayIcon)
    Menu, Tray, NoIcon
  Else
    Menu, Tray, Icon
}

;----------------------------------------
EraseSettings() {
  RegDelete, % RegistryPath
  ClientID =
  ClientSecret =
  AuthToken =
  AccessToken =
  ExpireToken =
  RefreshToken =
  SpotifyPath := FileExist(A_AppData "\Spotify\Spotify.exe") ? A_AppData "\Spotify\Spotify.exe" : ""
  AutoplayOnStart := 0
  MinimizeOnStart := 0
  TimerInterval := 1500
  HideTrayIcon := 0
}

;--------------------------------------------------------------------------------
;------------------------------ FIRST LAUNCH SETUP ------------------------------
;--------------------------------------------------------------------------------
FirstLaunchInit() {
  EraseSettings()
  FirstLaunchShowGUI()
}

;----------------------------------------
FirstLaunchComplete() {
  RegWrite, REG_SZ, % RegistryPath, ClientID, % ClientID
  RegWrite, REG_SZ, % RegistryPath, ClientSecret, % ClientSecret
  RegWrite, REG_SZ, % RegistryPath, SpotifyPath, % SpotifyPath

  SecondaryInit()
}

;----------------------------------------
FirstLaunchShowGUI() {
  Gui, FirstLaunch:Add, Link, X10 Y10 W400 gFirstLaunchCopyRedirectURI,
(
Open the Spotify <a href="https://developer.spotify.com/dashboard">Developer Dashboard</a>, click on "Create App", then create an app with the following settings:

• App Status: Development mode
• Redirect URI: <a id="URI">http://127.0.0.1:8000/callback</a> (copy to clipboard)

Once it has been created, paste the Client ID and Client Secret below
(Do not share either of these codes with anyone)
)

  Gui, FirstLaunch:Add, Text, X10 Y130, Client ID:
  Gui, FirstLaunch:Add, Edit, X10 Y148 W400 vClientID, % ClientID

  Gui, FirstLaunch:Add, Text, X10 Y180, Client Secret:
  Gui, FirstLaunch:Add, Edit, X10 Y198 W400 vClientSecret, % ClientSecret

  Gui, FirstLaunch:Add, Text, X10 Y230, Path to Spotify.exe:
  Gui, FirstLaunch:Add, Edit, X10 Y248 W333 vSpotifyPath, % SpotifyPath
  Gui, FirstLaunch:Add, Button, X350 Y247 W60 H23 gFirstLaunchOpenFileBrowser, Browse

  Gui, FirstLaunch:Font, cRed
  Gui, FirstLaunch:Add, Text, X10 Y276 W400 Hidden vFirstLaunchErrorText
  Gui, FirstLaunch:Font

  Gui, FirstLaunch:Add, Button, X160 Y296 W100 H40 Default gFirstLaunchSubmitGUI, Confirm

  Gui, FirstLaunch:Show, W420, Spotify Ad Ignorer - Setup
}

;----------------------------------------
FirstLaunchSubmitGUI() {
  Gui, FirstLaunch:Submit, NoHide

  Message := FirstLaunchValidateGUI()

  If (Message) {
    GuiControl, FirstLaunch:Text, FirstLaunchErrorText, % "(Error: " Message ")"
    GuiControl, FirstLaunch:Show, FirstLaunchErrorText
    Return
  }

  Gui, FirstLaunch:Destroy

  FirstLaunchComplete()
}

;----------------------------------------
FirstLaunchGuiClose() {
  Exit()
}

;----------------------------------------
FirstLaunchValidateGUI() {
  If (!ClientID || !ClientSecret || !SpotifyPath)
    Message := "All values are required"

  Return % Message
}

;----------------------------------------
FirstLaunchCopyRedirectURI() {
  Clipboard := "http://127.0.0.1:8000/callback"
}

;----------------------------------------
FirstLaunchOpenFileBrowser() {
  OpenFileBrowser("SpotifyPath")
}

;--------------------------------------------------------------------------------
;------------------------ GRANT ACCESS TO SPOTIFY ACCOUNT -----------------------
;--------------------------------------------------------------------------------
SpotifyAuthInit() {
  Chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  CharsLen := StrLen(Chars)
  SpotifyAuthState =

  Loop, 16 {
    Random, R, 1, % CharsLen
    SpotifyAuthState .= SubStr(Chars, R, 1)
  }

  URL := "https://accounts.spotify.com/en/authorize?client_id=" ClientID "&response_type=code&redirect_uri=http:%2F%2F127.0.0.1:8000%2Fcallback&state=" SpotifyAuthState "&scope=user-read-currently-playing&show_dialog=true"
  Run, % URL
  SpotifyAuthShowGUI(URL)
}

;----------------------------------------
SpotifyAuthComplete() {
  AuthCode := RegexReplace(SpotifyAuthURL, "http://127\.0\.0\.1:8000/callback\?code=([^&]+)&state=" SpotifyAuthState, "$1")
  SpotifyAuthURL =
  SpotifyAuthState =
  AccessToken =

  PostRequest("grant_type=authorization_code&code=" AuthCode "&redirect_uri=http:%2F%2F127.0.0.1:8000%2Fcallback")

  If (!RefreshToken) {
    FirstLaunchShowGUI()
    MsgBox, Unable to retrieve tokens, please check config
    Return
  }

  TertiaryInit()
}

;----------------------------------------
SpotifyAuthShowGUI(URL := "") {
  Gui, SpotifyAuth:Add, Link, X10 Y10 W400,
(
In your browser, authorize your spotify app to access your spotify account
(<a href="%URL%">click here</a> if the URL did not open automatically)

After allowing spotify access, your browser should redirect to an invalid page, paste that redirected URL here

It will look like:
http://127.0.0.1:8000/callback?code=...&&state=...
)

  Gui, SpotifyAuth:Add, Text, X10 Y130, Redirected URL:
  Gui, SpotifyAuth:Add, Edit, X10 Y148 W400 vSpotifyAuthURL

  Gui, SpotifyAuth:Font, cRed
  Gui, SpotifyAuth:Add, Text, X10 Y176 W400 Hidden vSpotifyAuthErrorText
  Gui, SpotifyAuth:Font

  Gui, SpotifyAuth:Add, Button, X160 Y196 W100 H40 Default gSpotifyAuthSubmitGUI, Confirm

  Gui, SpotifyAuth:Show, W420, Spotify Ad Ignorer - Awaiting authorization
}

;----------------------------------------
SpotifyAuthSubmitGUI() {
  Gui, SpotifyAuth:Submit, NoHide

  Message := SpotifyAuthValidateGUI()

  If (Message) {
    GuiControl, SpotifyAuth:Text, SpotifyAuthErrorText, % "(Error: " Message ")"
    GuiControl, SpotifyAuth:Show, SpotifyAuthErrorText
    Return
  }

  Gui, SpotifyAuth:Destroy

  SpotifyAuthComplete()
}

;----------------------------------------
SpotifyAuthGuiClose() {
  Exit()
}

;----------------------------------------
SpotifyAuthValidateGUI() {
  If (!RegexMatch(SpotifyAuthURL, "^http://127\.0\.0\.1:8000/callback"))
    Message := "No callback URL"
  Else If (!RegexMatch(SpotifyAuthURL, "^http://127\.0\.0\.1:8000/callback.+?&state=" SpotifyAuthState "$"))
    Message := "State mismatch, network insecure"
  Else If (RegexMatch(SpotifyAuthURL, "^http://127\.0\.0\.1:8000/callback\?error=access_denied&state="))
    Message := "Spotify rejected the request"
  Else If (!RegexMatch(SpotifyAuthURL, "^http://127\.0\.0\.1:8000/callback\?code=[^&]+&state=" SpotifyAuthState "$"))
    Message := "Invalid callback URL"

  Return % Message
}

;--------------------------------------------------------------------------------
;------------------------------ USER SETTINGS GUI -------------------------------
;--------------------------------------------------------------------------------
UserSettingsInit() {
  LoadUserSettings()
  UserSettingsShowGUI()
}

;----------------------------------------
UserSettingsShowGUI() {
  Gui, UserSettings:Add, Text, X10 Y10, Path to Spotify.exe:
  Gui, UserSettings:Add, Edit, X10 Y28 W333 vSpotifyPathT, % SpotifyPath
  Gui, UserSettings:Add, Button, X350 Y27 W60 H23 gUserSettingsOpenFileBrowser, Browse

  Gui, UserSettings:Add, CheckBox, X10 Y65 Checked%AutoplayOnStart% vAutoplayOnStartT, Auto-play on Startup
  Gui, UserSettings:Add, CheckBox, X10 Y86 Checked%MinimizeOnStart% vMinimizeOnStartT, Minimize on Startup
  Gui, UserSettings:Add, CheckBox, X10 Y107 Checked%HideTrayIcon% vHideTrayIconT, Hide Tray Icon

  Gui, UserSettings:Add, Text, X10 Y134, Timer Interval (ms) - Default 1500, min 100
  Gui, UserSettings:Add, Edit, X10 Y152 W80 Number vTimerIntervalT, % TimerInterval

  Gui, UserSettings:Font, cRed
  Gui, UserSettings:Add, Text, X10 Y180 W400 Hidden vUserSettingsErrorText
  Gui, UserSettings:Font

  Gui, UserSettings:Add, Button, X160 Y200 W100 H40 Default gUserSettingsSubmitGUI, Save
  Gui, UserSettings:Add, Button, X360 Y220 W50 H20 gUninstall, Uninstall

  Gui, UserSettings:Show, W420, Spotify Ad Ignorer - Settings
}

;----------------------------------------
UserSettingsSubmitGUI() {
  Gui, UserSettings:Submit, NoHide

  Message := UserSettingsValidateGUI()

  If (Message) {
    GuiControl, UserSettings:Text, UserSettingsErrorText, % "(Error: " Message ")"
    GuiControl, UserSettings:Show, UserSettingsErrorText
    Return
  }

  Gui, UserSettings:Destroy

  SaveUserSettings()
}

;----------------------------------------
UserSettingsGuiClose() {
  Gui, UserSettings:Destroy
}

;----------------------------------------
UserSettingsValidateGUI() {
  If (!SpotifyPathT)
    Message := "Spotify path cannot be empty"
  Else If (!TimerIntervalT || TimerIntervalT < 100)
    Message := "Invalid timer interval"

  Return % Message
}

;----------------------------------------
UserSettingsOpenFileBrowser() {
  OpenFileBrowser("SpotifyPathT")
}

;--------------------------------------------------------------------------------
;---------------------------- TIMER TO CHECK FOR ADS ----------------------------
;--------------------------------------------------------------------------------
AdCheckTimerInit(IsRestart := false) {
  If (!WinExist("ahk_exe Spotify.exe")) {
    Run, % SpotifyPath (IsRestart || MinimizeOnStart ? " --minimized" : "")
    WinWait, Spotify Free ahk_exe Spotify.exe

    ; Fallback incase spotify doesn't obey the --minimized flag
    If (IsRestart || MinimizeOnStart)
      PostMessage, 0x0112, 0xF020, , , ahk_exe Spotify.exe

    If (IsRestart || AutoplayOnStart) {
      PostMessage, 0x319, , 0xE0000, , , ahk_exe Spotify.exe
      Sleep, 500

      ; Fallback incase the first PostMessage doesn't work
      While (WinExist("Spotify Free ahk_exe Spotify.exe") || AppVolume("Spotify.exe").GetMute() != 0) {
        PostMessage, 0x319, , 0xE0000
        AppVolume("Spotify.exe").SetMute(0)
        Sleep, 500

        If (A_Index > 10)
          ThrowError("Unable to autoplay", 10)
      }
    }

    ; Wait for something to start playing
    WinWaitClose, Spotify Free ahk_exe Spotify.exe

    Sleep, 5000
  }

  SetTimer, AdCheckTimerRun, % TimerInterval, -1
}

;----------------------------------------
AdCheckTimerRun() {
  Static IsMuted, IsPaused

  If (!WinExist("ahk_exe Spotify.exe"))
    Exit()

  WinGetTitle, SpotifyTitle, ahk_exe Spotify.exe

  ; On last check, Spotify was paused
  If (IsPaused) {
    ; Spotify is unpaused
    If (InStr(SpotifyTitle, " - "))
      IsPaused := 0

    If (IsMuted)
      IsMuted := AppVolume("Spotify.exe").SetMute(0)
  }

  ; If (it seems like) an ad is playing
  Else If (SpotifyTitle == "Advertisement") || (!InStr(SpotifyTitle, " - ") && SpotifyTitle != "Drag" && SpotifyTitle != "Open File" && SpotifyTitle != "") {
    ; and the window is active
    If (WinActive()) {
      ; then mute spotify
      If (!IsMuted && AppVolume("Spotify.exe").GetMute() != 1)
        IsMuted := AppVolume("Spotify.exe").SetMute(1)
    }

    ; and the window is not active
    Else {
      ; then hit the API to see if an ad is playing
      If (SpotifyTitle == "Advertisement" || GetCurrentlyPlayingType() == "ad") {
        SetTimer, , Off
        IsMuted := 0
        IsPaused := 0
        ;Sleep, 100
        WinClose
        WinWaitClose, , , 10
        ;Sleep, 1500
        AdCheckTimerInit(true)
      }

      ; if we can't be sure an ad is playing, assume spotify is paused
      Else
        IsPaused := 1
    }
  }

  ; Fallback to ensure Spotify is unmuted when an ad finishes playing
  Else If (IsMuted)
    IsMuted := AppVolume("Spotify.exe").SetMute(0)
}

;----------------------------------------
GetCurrentlyPlayingType(Attempt := 1) {
  If (A_Now >= ExpireToken)
    GetNewTokens()

  P := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  P.Open("GET", "https://api.spotify.com/v1/me/player/currently-playing")
  P.SetRequestHeader("Authorization", "Bearer " AccessToken)
  P.Send()

  If (P.Status > 299) {
    If (Attempt <= 3) {
      GetNewTokens()
      Return GetCurrentlyPlayingType(++Attempt)
    }
    Else
      ThrowError("Exhausted attempts to retrieve tokens", 900)
  }

  If (P.Status == 200) {
    R := JSON.Load(P.ResponseText)
    Type := R.currently_playing_type
  }
  ; Spotify.exe is not running or running but no audio has been started
  Else If (P.Status == 204)
    Type := "no-audio"

  Return % Type ? Type : "ad"
}

;--------------------------------------------------------------------------------
;-------------------------------- GET API TOKENS --------------------------------
;--------------------------------------------------------------------------------
GetNewTokens() {
  PostRequest("grant_type=refresh_token&refresh_token=" RefreshToken "&client_id=" ClientID)
}

;----------------------------------------
PostRequest(Params) {
  P := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  P.Open("POST", "https://accounts.spotify.com/api/token?" Params)
  P.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
  P.SetRequestHeader("Authorization", "Basic " AuthToken)
  P.Send()

  If (Status > 299)
    ThrowError("Unable to retrieve tokens, server error`r`nStatus: " Status "`r`n---`r`n" ResponseText, 300)

  SaveTokens(JSON.Load(P.ResponseText))
}

;----------------------------------------
SaveTokens(R) {
  If (R.access_token) {
    AccessToken := R.access_token
    RegWrite, REG_SZ, % RegistryPath, AccessToken, % AccessToken
  }

  If (R.expires_in) {
    ExpireToken := A_Now
    EnvAdd, ExpireToken, % R.expires_in, Seconds
    RegWrite, REG_SZ, % RegistryPath, ExpireToken, % ExpireToken
  }

  If (R.refresh_token) {
    RefreshToken := R.refresh_token
    RegWrite, REG_SZ, % RegistryPath, RefreshToken, % RefreshToken
  }
}

;--------------------------------------------------------------------------------
;------------------------------- HELPER FUNCTIONS -------------------------------
;--------------------------------------------------------------------------------
OpenFileBrowser(ControlID) {
  GuiControlGet, Path, , % ControlID
  FileSelectFile, File, 1, % Path, Select File - Spotify Ad Ignorer, *.exe

  If (!ErrorLevel && File)
    GuiControl, , % ControlID, % File
}

;----------------------------------------
; https://www.autohotkey.com/boards/viewtopic.php?p=49863#p49863
Base64encUTF8(ByRef OutData, ByRef InData) {
  InDataLen := StrPutVar(InData, InData) - 1
  DllCall("Crypt32.dll\CryptBinaryToStringW", UInt, &InData, UInt, InDataLen, UInt, 1, UInt, 0, UIntP, TChars, "CDECL Int")
  VarSetCapacity(OutData, Req := TChars * (A_IsUnicode ? 2 : 1), 0)
  DllCall("Crypt32.dll\CryptBinaryToStringW", UInt, &InData, UInt, InDataLen, UInt, 1, Str, OutData, UIntP, Req, "CDECL Int")
  OutData := StrReplace(OutData, "`r`n")
  Return TChars
}

;----------------------------------------
StrPutVar(string, ByRef var) {
  VarSetCapacity(var, StrPut(string, "UTF-8"))
  Return StrPut(string, &var, "UTF-8")
}

;--------------------------------------------------------------------------------
;------------------------------------- EXIT -------------------------------------
;--------------------------------------------------------------------------------
Exit() {
  ExitApp
}

;----------------------------------------
ThrowError(Message, ID := 0) {
  MsgBox, % "Error (" ID ")`r`n---`r`n" Message "`r`n---`r`nExiting..."
  Exit()
}

;----------------------------------------
Uninstall() {
  MsgBox, 260, Uninstall - Spotify Ad Ignorer, Erase all Spotify Ad Ignorer settings & then exit?

  IfMsgBox, Yes
  {
    EraseSettings()
    Exit()
  }
}

