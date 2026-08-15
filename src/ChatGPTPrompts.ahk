#Requires AutoHotkey v2.0
#SingleInstance Force
#NoEnv

; Public entry point for the prompt menu app.

; Store prompts outside the repo and in a user-writable location by default.
#Warn All, Off
global PromptDataDir := EnvGet("APPDATA") . "\ChatGPTPrompts"

#Include "ChatGPT_Prompts.ahk"

A_IconTip := "ChatGPT Prompt Menu"
A_TrayMenu.Delete()
A_TrayMenu.Add("Open Prompts Folder", (*) => Run('explorer.exe "' . PromptDataDir . '"'))
A_TrayMenu.Add("Exit", (*) => ExitApp())

InitChatGPTMenu()
Persistent
