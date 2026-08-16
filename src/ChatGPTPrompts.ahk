#Requires AutoHotkey v2.0
#SingleInstance Force

; Public entry point for the prompt menu app.

; Store prompts outside the repo and in a user-writable location by default.
#Warn All, Off
global PromptDataDir := EnvGet("APPDATA") . "\ChatGPTPrompts"

class FilePromptStore {
    __New(dataDir := "") {
        this.DataDir := dataDir ? dataDir : (A_ScriptDir "\Prompts")
    }

    GetPromptsDir() {
        return this.DataDir
    }

    EnsurePromptStorage() {
        if !DirExist(this.DataDir) {
            try {
                DirCreate(this.DataDir)
            } catch as err {
                throw Error(Format("Unable to create prompts directory at {}: {}", this.DataDir, err.Message))
            }
        }

        grammarPath := this.DataDir "\Grammar Rewrite.txt"
        compactPath := this.DataDir "\Compact Conversation.txt"

        if !FileExist(grammarPath) {
            grammarPrompt := (
                "Your task is to take the text provided and rewrite it into a clear, grammatically correct "
                . "version while preserving the original meaning as closely as possible. Correct any spelling "
                . "mistakes, punctuation errors, verb tense issues, word choice problems, and other grammatical "
                . "mistakes.`n`nINPUT:`n<clipboard>"
            )

            try {
                FileAppend(grammarPrompt, grammarPath, "UTF-8")
            } catch as err {
                throw Error(Format("Unable to write default prompt file {}: {}", "Grammar Rewrite.txt", err.Message))
            }
        }

        if !FileExist(compactPath) {
            compactPrompt := (
                "Summarize the conversation so far in a single, compact block of text. Preserve the main goals, "
                . "requirements, code, and decisions made by the user and assistant. Omit repeated explanations "
                . "and minor details. Keep the summary as specific and actionable as possible so that a new "
                . "conversation can continue from this point without losing context"
            )

            try {
                FileAppend(compactPrompt, compactPath, "UTF-8")
            } catch as err {
                throw Error(Format("Unable to write default prompt file {}: {}", "Compact Conversation.txt", err.Message))
            }
        }
    }

    GetPromptFiles() {
        promptFiles := []

        Loop Files, this.DataDir "\*.txt", "R"
        {
            promptFiles.Push({
                Name: SubStr(A_LoopFileFullPath, StrLen(this.DataDir) + 2, -4),
                Path: A_LoopFilePath
            })
        }

        return promptFiles
    }

    ReadPrompt(filePath) {
        return FileRead(filePath, "UTF-8")
    }

    EnsurePromptFileReadable(filePath) {
        testFile := FileOpen(filePath, "r", "UTF-8")
        if !IsObject(testFile) {
            throw Error(Format("Unable to open prompt file: {}", filePath))
        }

        testFile.Close()
    }

    PromptPath(promptTitle) {
        return this.DataDir "\" promptTitle ".txt"
    }

    PromptExists(filePath) {
        return !!FileExist(filePath)
    }

    SavePrompt(filePath, content) {
        promptFile := FileOpen(filePath, "w", "UTF-8")
        if !IsObject(promptFile) {
            throw Error("The prompt file could not be opened for writing.")
        }

        try {
            bytesWritten := promptFile.Write(content)
            if (bytesWritten <= 0) {
                throw Error("No data was written to the prompt file.")
            }
        } finally {
            promptFile.Close()
        }
    }

    RenamePrompt(oldPath, newPath) {
        FileMove(oldPath, newPath)
    }

    DeletePrompt(filePath) {
        FileDelete(filePath)
    }
}

GetPromptStore() {
    global PromptStoreInstance, PromptDataDir

    if IsSet(PromptStoreInstance)
        return PromptStoreInstance

    PromptStoreInstance := FilePromptStore(IsSet(PromptDataDir) ? PromptDataDir : "")
    return PromptStoreInstance
}

GetPromptsDir() {
    return GetPromptStore().GetPromptsDir()
}

InitChatGPTMenu() {
    global CurrentPromptHotkey

    EnsurePromptStorage()
    iniPath := GetPromptsDir() "\settings.ini"
    defaultHotkey := "^!p"
    CurrentPromptHotkey := IniRead(iniPath, "Settings", "MenuShortcut", defaultHotkey)

    try {
        Hotkey(CurrentPromptHotkey, ShowPromptMenu, "On")
    } catch as err {
        CurrentPromptHotkey := defaultHotkey
        Hotkey(CurrentPromptHotkey, ShowPromptMenu, "On")

        try {
            IniWrite(CurrentPromptHotkey, iniPath, "Settings", "MenuShortcut")
        } catch as writeErr {
            MsgBox(
                "The saved prompt-menu shortcut was invalid, so Ctrl+Alt+P is being used for this session."
                . "`n`nThe corrected shortcut could not be saved:"
                . "`n" writeErr.Message,
                "Prompt Menu Shortcut",
                0x30
            )
        }
    }
}

EnsurePromptStorage() {
    try {
        GetPromptStore().EnsurePromptStorage()
    } catch as err {
        MsgBox("The prompt folder could not be initialized.`n`n" err.Message, "Storage Error", 0x10)
        throw
    }
}

GetPromptFiles() {
    promptFiles := GetPromptStore().GetPromptFiles()
    SortPromptFiles(promptFiles)
    return promptFiles
}

SortPromptFiles(promptFiles) {
    if promptFiles.Length < 2 {
        return
    }

    Loop promptFiles.Length - 1 {
        index := A_Index + 1
        current := promptFiles[index]
        previousIndex := index - 1

        while previousIndex >= 1
            && StrCompare(promptFiles[previousIndex].Name, current.Name, false) > 0 {
            promptFiles[previousIndex + 1] := promptFiles[previousIndex]
            previousIndex--
        }

        promptFiles[previousIndex + 1] := current
    }
}

ShowPromptMenu(*) {
    EnsurePromptStorage()
    promptFiles := GetPromptFiles()
    promptMenu := Menu()

    BuildPromptMenu(promptMenu, promptFiles)

    if promptFiles.Length = 0 {
        promptMenu.Add("(No prompts found)", ReturnNoop)
        promptMenu.Disable("(No prompts found)")
    }

    promptMenu.Add()
    promptMenu.Add("Add New Prompt", ShowAddPromptMenuItem)
    promptMenu.Add("Manage Prompts", ShowManagePromptsMenuItem)
    promptMenu.Add("Open Prompts Folder", OpenPromptsFolder)
    promptMenu.Add("Change Shortcut", ShowChangeShortcutMenuItem)
    promptMenu.Show()
}

ReturnNoop(*) {
    return
}

ShowAddPromptMenuItem(*) {
    AddPromptGui()
}

ShowManagePromptsMenuItem(*) {
    ShowPromptManager()
}

ShowChangeShortcutMenuItem(*) {
    ChangeShortcutGui()
}

    BuildPromptMenu(promptMenu, promptFiles) {
        subMenus := Map()

    for _, promptFile in promptFiles {
        pathParts := StrSplit(promptFile.Name, "\")
        promptName := pathParts.Pop()
        currentMenu := promptMenu
        currentKey := ""

        for _, folderName in pathParts {
            safeFolder := "📁 " . EscapeMenuLabel(folderName)
            currentKey := currentKey = "" ? folderName : currentKey "\" . folderName

            if !subMenus.Has(currentKey) {
                newSubmenu := Menu()
                subMenus[currentKey] := newSubmenu
                currentMenu.Add(safeFolder, newSubmenu)
            }

            currentMenu := subMenus[currentKey]
        }

        currentMenu.Add(EscapeMenuLabel(promptName), ExecutePrompt.Bind(promptFile.Path))
    }
}

EscapeMenuLabel(label) {
    return StrReplace(label, "&", "&&")
}

ExecutePrompt(filePath, *) {
    try {
        clipboardText := A_Clipboard
        promptText := GetPromptStore().ReadPrompt(filePath)
        finalText := StrReplace(promptText, "<clipboard>", clipboardText)
        PasteText(finalText)
    } catch as err {
        MsgBox(
            "The prompt could not be pasted."
            . "`n`nFile: " filePath
            . "`nError: " err.Message,
            "Prompt Error",
            0x10
        )
    }
}

; Paste text, then restore the previous clipboard if the user has not copied anything new.
PasteText(text) {
    savedClipboard := ClipboardAll()

    try {
        A_Clipboard := text
        if !ClipWait(1)
            throw Error("Windows did not make the prompt text available on the clipboard.")

        Send "^v"
        SetTimer(RestorePromptClipboard.Bind(savedClipboard, text), -500)
    } catch {
        try {
            SendText(text)
            SetTimer(RestorePromptClipboard.Bind(savedClipboard, text), -500)
            return
        } catch {
        }

        A_Clipboard := savedClipboard
        throw
    }
}

RestorePromptClipboard(savedClipboard, pastedText) {
    ; Do not overwrite clipboard content the user copied after the paste.
    if A_Clipboard = pastedText
        A_Clipboard := savedClipboard
}

AddPromptGui() {
    EnsurePromptStorage()

    addGui := Gui("AlwaysOnTop", "Add New Prompt")
    addGui.Add("Text", "w400", "Prompt Title (will be the menu name):")
    addGui.Add("Edit", "vPromptTitle w400", "")

    addGui.Add("Text", "w400", "Prompt Content:")
    addGui.Add("Edit", "vPromptContent w400 r10", "")

    addGui.Add(
        "Text",
        "w400 cBlue",
        "Tip: Use `<clipboard>` where you want copied text to be inserted."
    )

    saveButton := addGui.Add("Button", "w100 Default", "Save Prompt")
    saveButton.OnEvent("Click", SaveNewPrompt.Bind(addGui))
    addGui.Show()
}

SaveNewPrompt(guiObj, *) {
    formData := guiObj.Submit(false)
    title := Trim(formData.PromptTitle)
    content := Trim(formData.PromptContent)

    if title = "" {
        MsgBox("Please enter a title for the prompt.", "Error", 0x10)
        return
    }

    if content = "" {
        MsgBox("Please enter the prompt content.", "Error", 0x10)
        return
    }

    if !TryGetSafePromptTitle(title, &safeTitle, &validationError) {
        MsgBox(validationError, "Invalid Prompt Title", 0x10)
        return
    }

    filePath := GetPromptStore().PromptPath(safeTitle)
    if !ValidatePromptNameCollision(safeTitle, filePath, "") {
        return
    }

    if GetPromptStore().PromptExists(filePath) {
        overwrite := MsgBox(
            "A prompt named `"" safeTitle `"` already exists."
            . "`n`nReplace it?",
            "Replace Prompt",
            "YesNo Icon?"
        )
        if overwrite != "Yes"
            return
    }

    try {
        GetPromptStore().SavePrompt(filePath, content)
        guiObj.Destroy()
        TrayTip(
            "Your new prompt `"" safeTitle `"` has been added to the menu.",
            "Prompt Saved",
            1
        )
    } catch as err {
        MsgBox("Failed to save the prompt:`n" err.Message, "Error", 0x10)
    }
}

TryGetSafePromptTitle(title, &safeTitle, &errorMessage) {
    safeTitle := RegExReplace(Trim(title), '[\\/:\*\?"<>\|]', "_")
    safeTitle := RegExReplace(safeTitle, "[ .]+$")

    if safeTitle = "" {
        errorMessage := "The title must contain at least one valid filename character."
        return false
    }

    if RegExMatch(safeTitle, "i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$") {
        errorMessage := "`"" safeTitle `"` is a reserved Windows filename. Please choose another title."
        return false
    }

    errorMessage := ""
    return true
}

ValidatePromptNameCollision(safeTitle, targetPath, currentPath := "") {
    if !GetPromptStore().PromptExists(targetPath) {
        return true
    }

    if currentPath != "" && StrCompare(targetPath, currentPath, false) = 0 {
        return true
    }

    confirm := MsgBox(
        "The sanitized title `"" safeTitle `"` matches an existing prompt file.`n"
        . "Different raw titles can map to the same saved file name.`n`n"
        . "Overwrite anyway?",
        "Prompt Name Conflict",
        "YesNo Icon?"
    )

    return confirm = "Yes"
}

ShowPromptManager(*) {
    EnsurePromptStorage()

    managerGui := Gui("AlwaysOnTop Resize", "Manage Prompts")
    managerGui.SetFont("s10")
    managerGui.Add("Text", "w420", "Select a prompt to edit, rename, or delete:")
    promptList := managerGui.Add("ListBox", "w420 r12")
    promptPaths := []

    editButton := managerGui.Add("Button", "xm w90", "Edit")
    renameButton := managerGui.Add("Button", "x+10 w90", "Rename")
    deleteButton := managerGui.Add("Button", "x+10 w90", "Delete")
    folderButton := managerGui.Add("Button", "x+10 w120", "Open Folder")

    editButton.Enabled := false
    renameButton.Enabled := false
    deleteButton.Enabled := false

    editButton.OnEvent("Click", EditManagedPrompt.Bind(promptList, promptPaths))
    renameButton.OnEvent(
        "Click",
        RenameManagedPrompt.Bind(promptList, promptPaths)
    )
    deleteButton.OnEvent(
        "Click",
        DeleteManagedPrompt.Bind(promptList, promptPaths)
    )
    folderButton.OnEvent(
        "Click",
        OpenPromptsFolder
    )
    promptList.OnEvent(
        "DoubleClick",
        EditManagedPrompt.Bind(promptList, promptPaths)
    )
    promptList.OnEvent(
        "Change",
        UpdatePromptManagerActionStates.Bind(promptList, promptPaths, editButton, renameButton, deleteButton)
    )

    RefreshPromptManager(promptList, promptPaths)
    UpdatePromptManagerActionStates(promptList, promptPaths, editButton, renameButton, deleteButton)
    managerGui.Show()
}

RefreshPromptManager(promptList, promptPaths) {
    promptList.Delete()
    promptPaths.Length := 0
    promptNames := []

    for _, promptFile in GetPromptFiles() {
        promptNames.Push(promptFile.Name)
        promptPaths.Push(promptFile.Path)
    }

    if promptNames.Length
        promptList.Add(promptNames)
    else
        promptList.Add(["(No prompts found)"])
}

UpdatePromptManagerActionStates(promptList, promptPaths, editButton, renameButton, deleteButton, *) {
    hasSelection := (promptList.Value >= 1 && promptList.Value <= promptPaths.Length)
    editButton.Enabled := hasSelection
    renameButton.Enabled := hasSelection
    deleteButton.Enabled := hasSelection
}

GetManagedPromptPath(promptList, promptPaths, &filePath) {
    selectedIndex := promptList.Value
    if selectedIndex < 1 || selectedIndex > promptPaths.Length {
        filePath := ""
        return false
    }

    filePath := promptPaths[selectedIndex]
    return true
}

EditManagedPrompt(promptList, promptPaths, *) {
    if !GetManagedPromptPath(promptList, promptPaths, &filePath)
        return

    try {
        GetPromptStore().EnsurePromptFileReadable(filePath)
        Run('notepad.exe "' filePath '"')
    } catch as err {
        MsgBox("The prompt could not be opened:`n" err.Message, "Error", 0x10)
    }
}

OpenPromptsFolder(*) {
    Run('explorer.exe "' GetPromptsDir() '"')
}

RenameManagedPrompt(promptList, promptPaths, *) {
    if !GetManagedPromptPath(promptList, promptPaths, &oldPath)
        return

    SplitPath(oldPath, , , , &currentName)
    result := ShowRenameInput(currentName)
    if result.Result != "OK"
        return

    if !TryGetSafePromptTitle(result.Value, &safeTitle, &validationError) {
        MsgBox(validationError, "Invalid Prompt Title", 0x10)
        return
    }

    newPath := GetPromptStore().PromptPath(safeTitle)
    if !ValidatePromptNameCollision(safeTitle, newPath, oldPath) {
        return
    }

    if StrCompare(oldPath, newPath, false) = 0
        return

    try {
        GetPromptStore().RenamePrompt(oldPath, newPath)
        RefreshPromptManager(promptList, promptPaths)
        TrayTip("The prompt is now named `"" safeTitle `"`.", "Prompt Renamed", 1)
    } catch as err {
        MsgBox("The prompt could not be renamed:`n" err.Message, "Error", 0x10)
    }
}

ShowRenameInput(defaultValue) {
    state := { ok: false, value: defaultValue }
    renameGui := Gui("+AlwaysOnTop", "Rename Prompt")
    renameGui.SetFont("s10")
    renameGui.Add("Text", "w380", "Enter a new name for the prompt:")
    renameGui.Add("Edit", "vRenamePrompt w380", defaultValue)
    okButton := renameGui.Add("Button", "w90 Default x10 y+10", "OK")
    cancelButton := renameGui.Add("Button", "x+10 w90", "Cancel")

    okButton.OnEvent(
        "Click",
        ( * ) => (
            formData := renameGui.Submit(false),
            state.ok := true,
            state.value := formData.RenamePrompt,
            renameGui.Destroy()
        )
    )
    cancelButton.OnEvent(
        "Click",
        ( * ) => renameGui.Destroy()
    )
    renameGui.OnEvent(
        "Close",
        ( * ) => renameGui.Destroy()
    )

    renameGui.Show()
    WinWaitClose(renameGui.Hwnd)

    return state.ok
        ? { Result: "OK", Value: state.value }
        : { Result: "Cancel", Value: defaultValue }
}

DeleteManagedPrompt(promptList, promptPaths, *) {
    if !GetManagedPromptPath(promptList, promptPaths, &filePath)
        return

    SplitPath(filePath, , , , &promptName)
    confirmation := MsgBox(
        "Delete the prompt `"" promptName `"`?`n`nThis cannot be undone.",
        "Delete Prompt",
        "YesNo Icon!"
    )
    if confirmation != "Yes"
        return

    try {
        GetPromptStore().DeletePrompt(filePath)
        RefreshPromptManager(promptList, promptPaths)
        TrayTip("The prompt `"" promptName `"` was deleted.", "Prompt Deleted", 1)
    } catch as err {
        MsgBox("The prompt could not be deleted:`n" err.Message, "Error", 0x10)
    }
}

ChangeShortcutGui() {
    global CurrentPromptHotkey

    shortcutGui := Gui("AlwaysOnTop", "Change Menu Shortcut")
    shortcutGui.Add(
        "Text",
        "w300",
        "Click the box below and press your new shortcut key combination:"
    )
    shortcutGui.Add("Hotkey", "vShortcut w300", CurrentPromptHotkey)

    saveButton := shortcutGui.Add("Button", "w100 Default", "Save Shortcut")
    saveButton.OnEvent("Click", SaveNewShortcut.Bind(shortcutGui))
    shortcutGui.Show()
}

SaveNewShortcut(guiObj, *) {
    global CurrentPromptHotkey

    formData := guiObj.Submit(false)
    newHotkey := formData.Shortcut
    oldHotkey := CurrentPromptHotkey

    if newHotkey = "" {
        MsgBox("Please enter a valid shortcut.", "Error", 0x10)
        return
    }

    if newHotkey = oldHotkey {
        guiObj.Destroy()
        return
    }

    iniPath := GetPromptsDir() "\settings.ini"

    try {
        Hotkey(newHotkey, ShowPromptMenu, "On")
        IniWrite(newHotkey, iniPath, "Settings", "MenuShortcut")

        if oldHotkey != "" && oldHotkey != newHotkey
            Hotkey(oldHotkey, "Off")

        CurrentPromptHotkey := newHotkey
        guiObj.Destroy()
        TrayTip(
            "Your ChatGPT prompt-menu shortcut is now configured.",
            "Shortcut Saved",
            1
        )
    } catch as err {
        try Hotkey(newHotkey, "Off")
        try Hotkey(oldHotkey, ShowPromptMenu, "On")

        if newHotkey != oldHotkey {
            try IniWrite(oldHotkey, iniPath, "Settings", "MenuShortcut")
        }

        errMsg := "The shortcut could not be changed."
        if InStr(StrLower(err.Message), "already") || InStr(StrLower(err.Message), "in use") {
            errMsg .= "`n`nThis shortcut may already be used by another app or system shortcut."
        }

        MsgBox(
            errMsg . "`n`n" err.Message,
            "Shortcut Error",
            0x10
        )
    }
}

InitChatGPTMenu()
