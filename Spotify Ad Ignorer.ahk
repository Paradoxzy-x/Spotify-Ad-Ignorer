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
Menu, Tray, Add, Exit
Menu, Tray, Default, Exit

; https://gist.github.com/G33kDude/5b7ba418e685e52c3e6507e5c6972959
; https://gist.github.com/anonymous1184/c06335f3aed215cdea414c33354a728b
#Include Lib\VA.ahk
#Include Lib\AppVolume.ahk

Global SpotifyPath, RegistryPath, DefaultPath
RegistryPath := "HKCU\Software\Spotify Ad Ignorer"
DefaultPath := A_AppData "\Spotify\Spotify.exe"
RegRead, SpotifyPath, % RegistryPath, SpotifyPath

If (SpotifyPath == "")
  FirstLaunchShowGUI()
Else
  AdCheckTimerInit()
Return

;--------------------------------------------------------------------------------
;------------------------------ FIRST LAUNCH SETUP ------------------------------
;--------------------------------------------------------------------------------
FirstLaunchShowGUI() {
  If (FileExist(DefaultPath))
    SpotifyPath := DefaultPath

  Gui, FirstLaunch:Add, Text, X10 Y10, Path to Spotify.exe:
  Gui, FirstLaunch:Add, Edit, X10 Y28 W333 vSpotifyPath, % SpotifyPath
  Gui, FirstLaunch:Add, Button, X350 Y27 W60 H23 gFirstLaunchOpenFileBrowser, Browse
  Gui, FirstLaunch:Add, Button, X160 Y60 W100 H40 Default gFirstLaunchSubmitGUI, Confirm
  Gui, FirstLaunch:Show, W420, Spotify Ad Ignorer - Setup
}

;----------------------------------------
FirstLaunchSubmitGUI() {
  Gui, FirstLaunch:Submit
  Gui, FirstLaunch:Destroy

  RegWrite, REG_SZ, % RegistryPath, SpotifyPath, % SpotifyPath
  AdCheckTimerInit()
}

;----------------------------------------
FirstLaunchGuiClose() {
  Exit()
}

;----------------------------------------
FirstLaunchOpenFileBrowser() {
  GuiControlGet, Path, , SpotifyPath
  FileSelectFile, File, 1, % Path, Select File - Spotify Ad Ignorer, *.exe

  If (!ErrorLevel && File)
    GuiControl, , SpotifyPath, % File
}

;--------------------------------------------------------------------------------
;---------------------------- TIMER TO CHECK FOR ADS ----------------------------
;--------------------------------------------------------------------------------
AdCheckTimerInit(IsRestart := false) {
  If (!WinExist("ahk_exe Spotify.exe")) {
    Run, % SpotifyPath " --minimized"
    WinWait, Spotify Free ahk_exe Spotify.exe

    ; Fallback incase spotify doesn't obey the --minimized flag
    PostMessage, 0x0112, 0xF020, , , ahk_exe Spotify.exe

    ; Play
    PostMessage, 0x319, , 0xE0000, , , ahk_exe Spotify.exe
    Sleep, 500

    ; Fallback incase the first PostMessage doesn't work
    While (WinExist("Spotify Free ahk_exe Spotify.exe") || AppVolume("Spotify.exe").GetMute() != 0) {
    ;While (AppVolume("Spotify.exe").GetMute() != 0) {
      PostMessage, 0x319, , 0xE0000
      AppVolume("Spotify.exe").SetMute(0)
      Sleep, 500

      If (A_Index > 10) {
        MsgBox, % "Error`r`n---`r`nUnable to autoplay`r`n---`r`nExiting..."
        Exit()
      }
    }

    ; Wait for something to start playing
    WinWaitClose, Spotify Free ahk_exe Spotify.exe

    Sleep, 5000
  }

  SetTimer, AdCheckTimer, 1500, -1
}

;----------------------------------------
AdCheckTimer() {
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
      ; then restart
      If (SpotifyTitle != "Spotify Free") {
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
Exit() {
  ExitApp
}
