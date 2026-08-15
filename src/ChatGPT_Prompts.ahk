GetPromptsDir() {
    global PromptDataDir

    return IsSet(PromptDataDir) ? PromptDataDir : (A_ScriptDir "\Prompts")
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
    pDir := GetPromptsDir()
    if DirExist(pDir)
        return

    DirCreate(pDir)

    grammarPrompt := (
        "Your task is to take the text provided and rewrite it into a clear, grammatically correct "
        . "version while preserving the original meaning as closely as possible. Correct any spelling "
        . "mistakes, punctuation errors, verb tense issues, word choice problems, and other grammatical "
        . "mistakes.`n`nINPUT:`n<clipboard>"
    )
    FileAppend(grammarPrompt, pDir "\Grammar Rewrite.txt", "UTF-8")

    compactPrompt := (
        "Summarize the conversation so far in a single, compact block of text. Preserve the main goals, "
        . "requirements, code, and decisions made by the user and assistant. Omit repeated explanations "
        . "and minor details. Keep the summary as specific and actionable as possible so that a new "
        . "conversation can continue from this point without losing context"
    )
    FileAppend(compactPrompt, pDir "\Compact Conversation.txt", "UTF-8")
}

GetPromptFiles() {
    promptFiles := []
    pDir := GetPromptsDir()

    Loop Files, pDir "\*.txt"
    {
        promptFiles.Push({
            Name: SubStr(A_LoopFileName, 1, -4),
            Path: A_LoopFilePath
        })
    }

    SortPromptFiles(promptFiles)
    return promptFiles
}

SortPromptFiles(promptFiles) {
    if promptFiles.Length < 2
        return

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

    for _, promptFile in promptFiles
        promptMenu.Add(promptFile.Name, ExecutePrompt.Bind(promptFile.Path))

    if promptFiles.Length = 0 {
        promptMenu.Add("(No prompts found)", (*) => "")
        promptMenu.Disable("(No prompts found)")
    }

    promptMenu.Add()
    promptMenu.Add("Add New Prompt", (*) => AddPromptGui())
    promptMenu.Add("Manage Prompts", () => ShowPromptManager())
    promptMenu.Add("Open Prompts Folder", () => Run('explorer.exe "' GetPromptsDir() '"'))
    promptMenu.Add("Change Shortcut", () => ChangeShortcutGui())
    promptMenu.Show()
}

ExecutePrompt(filePath, *) {
    try {
        clipboardText := A_Clipboard
        promptText := FileRead(filePath, "UTF-8")
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
    titleEdit := addGui.Add("Edit", "w400", "")

    addGui.Add("Text", "w400", "Prompt Content:")
    contentEdit := addGui.Add("Edit", "w400 r10", "")

    addGui.Add(
        "Text",
        "w400 cBlue",
        "Tip: Use `<clipboard>` where you want copied text to be inserted."
    )

    saveButton := addGui.Add("Button", "w100 Default", "Save Prompt")
    saveButton.OnEvent("Click", SaveNewPrompt.Bind(addGui, titleEdit, contentEdit))
    addGui.Show()
}

SaveNewPrompt(guiObj, titleEdit, contentEdit, *) {
    title := Trim(titleEdit.Value)
    content := Trim(contentEdit.Value)

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

    filePath := GetPromptsDir() "\" safeTitle ".txt"
    if FileExist(filePath) {
        overwrite := MsgBox(
            "A prompt named `"" safeTitle "`" already exists."
            . "`n`nReplace it?",
            "Replace Prompt",
            "YesNo Icon?"
        )
        if overwrite != "Yes"
            return
    }

    try {
        promptFile := FileOpen(filePath, "w", "UTF-8")
        if !IsObject(promptFile)
            throw Error("The prompt file could not be opened for writing.")

        promptFile.Write(content)
        promptFile.Close()
        guiObj.Destroy()
        TrayTip(
            "Your new prompt `"" safeTitle "`" has been added to the menu.",
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
        errorMessage := "`"" safeTitle "`" is a reserved Windows filename. Please choose another title."
        return false
    }

    errorMessage := ""
    return true
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
        () => Run('explorer.exe "' GetPromptsDir() '"')
    )
    promptList.OnEvent(
        "DoubleClick",
        EditManagedPrompt.Bind(promptList, promptPaths)
    )

    RefreshPromptManager(promptList, promptPaths)
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
}

GetManagedPromptPath(promptList, promptPaths, &filePath) {
    selectedIndex := promptList.Value
    if selectedIndex < 1 || selectedIndex > promptPaths.Length {
        MsgBox("Select a prompt first.", "Manage Prompts", 0x30)
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
        Run('notepad.exe "' filePath '"')
    } catch as err {
        MsgBox("The prompt could not be opened:`n" err.Message, "Error", 0x10)
    }
}

RenameManagedPrompt(promptList, promptPaths, *) {
    if !GetManagedPromptPath(promptList, promptPaths, &oldPath)
        return

    SplitPath(oldPath, , , , &currentName)
    result := InputBox(
        "Enter a new name for the prompt:",
        "Rename Prompt",
        "w400",
        currentName
    )
    if result.Result != "OK"
        return

    if !TryGetSafePromptTitle(result.Value, &safeTitle, &validationError) {
        MsgBox(validationError, "Invalid Prompt Title", 0x10)
        return
    }

    newPath := GetPromptsDir() "\" safeTitle ".txt"
    if StrCompare(oldPath, newPath, false) = 0
        return

    if FileExist(newPath) {
        MsgBox(
            "A prompt named `"" safeTitle "`" already exists.",
            "Rename Prompt",
            0x10
        )
        return
    }

    try {
        FileMove(oldPath, newPath)
        RefreshPromptManager(promptList, promptPaths)
        TrayTip("The prompt is now named `"" safeTitle "`".", "Prompt Renamed", 1)
    } catch as err {
        MsgBox("The prompt could not be renamed:`n" err.Message, "Error", 0x10)
    }
}

DeleteManagedPrompt(promptList, promptPaths, *) {
    if !GetManagedPromptPath(promptList, promptPaths, &filePath)
        return

    SplitPath(filePath, , , , &promptName)
    confirmation := MsgBox(
        "Delete the prompt `"" promptName "`"?`n`nThis cannot be undone.",
        "Delete Prompt",
        "YesNo Icon!"
    )
    if confirmation != "Yes"
        return

    try {
        FileDelete(filePath)
        RefreshPromptManager(promptList, promptPaths)
        TrayTip("The prompt `"" promptName "`" was deleted.", "Prompt Deleted", 1)
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
    hotkeyControl := shortcutGui.Add("Hotkey", "w300", CurrentPromptHotkey)

    saveButton := shortcutGui.Add("Button", "w100 Default", "Save Shortcut")
    saveButton.OnEvent(
        "Click",
        SaveNewShortcut.Bind(shortcutGui, hotkeyControl)
    )
    shortcutGui.Show()
}

SaveNewShortcut(guiObj, hotkeyControl, *) {
    global CurrentPromptHotkey

    newHotkey := hotkeyControl.Value
    oldHotkey := CurrentPromptHotkey

    if newHotkey = "" {
        MsgBox("Please enter a valid shortcut.", "Error", 0x10)
        return
    }

    try {
        Hotkey(newHotkey, ShowPromptMenu, "On")
    } catch as err {
        MsgBox(
            "Invalid shortcut combination."
            . "`n`n" err.Message,
            "Shortcut Error",
            0x10
        )
        return
    }

    iniPath := GetPromptsDir() "\settings.ini"
    try {
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
        if newHotkey != oldHotkey {
            try Hotkey(newHotkey, "Off")
            try Hotkey(oldHotkey, ShowPromptMenu, "On")
            try IniWrite(oldHotkey, iniPath, "Settings", "MenuShortcut")
        }

        MsgBox(
            "The shortcut was not changed."
            . "`n`n" err.Message,
            "Shortcut Error",
            0x10
        )
    }
}
