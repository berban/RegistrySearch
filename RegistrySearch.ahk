RegJump(KeyLocation, KeyName)
{
	Global RegJumpPath
	Run, % """" RegJumpPath """ """ KeyLocation (KeyName = "" ? "" : "\" RegExReplace(KeyName, "\\.*")) """"
}

IniRead()
If RunAsAdmin and !A_IsAdmin {
	Run, % "*RunAs " (A_IsCompiled ? "" : """" A_AhkPath """ ") """" A_ScriptFullPath """", , UseErrorLevel
	ExitApp
}

Icon := Object()
ImageListID := IL_Create(Icons)
Icons := IniRead("", "slIcons p d")
Loop, Parse, Icons, `n
{
	StringSplit, @, % %A_LoopField%, :
	If (@ := IL_Add(ImageListID, @1, @2))
		Icon[SubStr(A_LoopField, 7)] := "Icon" @
}

SetBatchLines, %BatchLines%
Menu, Tray, Icon, Shell32.dll, 23
Dots := "................................................................................"
Rootkeys := RegExReplace(SearchOrder, "\W+", "|")
IniFile := SubStr(A_ScriptFullPath, 1, InStr(A_ScriptFullPath, ".", 0, 0)) "ini"
Hotkey, %CloseHotkey%, GuiClose, UseErrorLevel

Gui, Font, s%TreeViewFontSize%
Gui, Add, TreeView, % "x" Margins " y" Margins " w" TreeViewWidth " h" Height " ImageList" ImageListID " gGuiEvent vResultsTreeView"
Gui, Font, s%MainFontSize%
Gui, Add, Checkbox, % "x" Margins * 2 + TreeViewWidth " y" Margins " w" CheckboxWidth " h" InputHeight " vKeyCheck " (KeyCheck ? "+" : "-") "Checked", Key?
Gui, Add, Edit, % "x+" Margins " yp w" EditWidth " h" InputHeight " vKeyString", %KeyString%
Gui, Add, Checkbox, % "x" Margins * 2 + TreeViewWidth " y+" Margins " w" CheckboxWidth " h" InputHeight " vValueCheck " (ValueCheck ? "+" : "-") "Checked", Value?
Gui, Add, Edit, % "x+" Margins " yp w" EditWidth " h" InputHeight " vValueString", %ValueString%
Gui, Add, Checkbox, % "x" Margins * 2 + TreeViewWidth " y+" Margins " w" CheckboxWidth " h" InputHeight " vRegExCheck " (RegExCheck ? "+" : "-") "Checked", RegEx?
Gui, Add, Button, % "x+" Margins " yp w" EditWidth " h" InputHeight " gToggleSearch vSearchButton +Default", Search
Gui, Font, , Courier New
Gui, Add, Edit, % "x" Margins * 2 + TreeViewWidth " y+" Margins " w" (CheckboxWidth + Margins + EditWidth) " h" (Height - Margins * 3 - InputHeight * 3) " vOutput +ReadOnly"
Gui, Show, % "w" (TreeViewWidth + CheckboxWidth + EditWidth + Margins * 4) " h" (Height + Margins * 2), Registry Search
Sleep 30
GuiControl, Focus, KeyString
Sleep 30
ControlSend, Edit1, ^a, A
Return

ToggleSearch:
If (Search := !Search)
	SetTimer, Search, -50
Return

Search:
Gui, Submit, NoHide
If !((KeyCheck and (KeyString != "")) or (ValueCheck and (ValueString != ""))) {
	MsgBox, 262160, %A_ScriptName%: Error, Select either key or value.
	Search := False
	Return
}
ValueStringSearch := ValueString, KeyStringSearch := KeyString
If ValueCheck and (ValueString = "")
	GuiControl, , ValueString, % ValueStringSearch := KeyString
If KeyCheck and (KeyString = "")
	GuiControl, , KeyString, % KeyStringSearch := ValueString
GuiControl, , SearchButton, Stop...
GuiControl, Disable, KeyString
GuiControl, Disable, ValueString
GuiControl, , Output, Searching...
IniWrite, %KeyCheck%, %IniFile%, Script Settings, Key Check
IniWrite, %ValueCheck%, %IniFile%, Script Settings, Value Check
IniWrite, %KeyString%, %IniFile%, Script Settings, Key String
IniWrite, %ValueString%, %IniFile%, Script Settings, Value String
IniWrite, %RegExCheck%, %IniFile%, Script Settings, RegEx Check
Found := n := 0
SearchTime := -A_TickCount, Draw := True
TV_Delete()
Resutls := ""
Results := Object()
GuiControl, -Redraw, ResultsTreeView
Loop, Parse, Rootkeys, |
	If A_LoopField
		Loop, Reg, %A_LoopField%, RKV ; Settings := "R" (KeyCheck ? "K" : "") (ValueCheck ? "V" : "")
		{
			If (A_LoopRegType != "Key") and ValueCheck {
				RegRead, RegValue
				If RegExCheck {
					If RegExMatch(RegValue, ValueStringSearch)
						Match := True
				} Else If InStr(RegValue, ValueStringSearch)
					Match := True
			}
			If KeyCheck {
				If RegExCheck {
					If RegExMatch(A_LoopRegName, KeyStringSearch)
						Match := True
				} Else If InStr(A_LoopRegName, KeyStringSearch)
					Match := True
			}
			If Match {
				If Draw
					GuiControl, -Redraw, ResultsTreeView
				Found += AddKey(A_LoopRegKey "\" A_LoopRegSubKey, A_LoopRegName = "" ? "(Default)" : A_LoopRegName, A_LoopRegType = "Key" ? A_LoopRegType : SubStr(A_LoopRegType, 5), RegValue, Found + 1, A_LoopRegTimeModified), Match := Draw := False
			}
			n += 1
			If !Mod(A_Index, UpdateEvery) {
				If !Draw and (Draw := True)
					GuiControl, +Redraw, ResultsTreeView
				GuiControl, , Output, % "Searching" SubStr(Dots, 1, Mod(n//UpdateEvery, StrLen(Dots))) "`n`n" n " of " NumberOfKeys " searched (" Round(n/NumberOfKeys*100,1) "%)`n`n" Found " found.`n`n" RegExReplace(A_LoopRegKey "\" A_LoopRegSubKey "\" (A_LoopRegName ? A_LoopRegName : "(Default)"), "\\", "`n")
			} Else If !Search
				Break
		}
SearchTime := (SearchTime + A_TickCount) // 1000
If Search
	IniWrite, % NumberOfKeys := n, %IniFile%, Script Settings, Number Of Keys
GuiControl, , Output, % (Search ? "Search complete" : "Search cancelled") " (" SearchTime " seconds).`n`n" n " of " NumberOfKeys " searched (" Round(n/NumberOfKeys*100,1) "%).`n`n" Found " found."
GuiControl, +Redraw, ResultsTreeView
GuiControl, , SearchButton, Search
GuiControl, , KeyString, %KeyString%
GuiControl, Enable, KeyString
GuiControl, , ValueString, %ValueString%
GuiControl, Enable, ValueString
Return

AddKey(Location, Name, Type, Value, Number, Modified)
{
	Global Results, Icon
	If (Results[Results[Location "\" Name, "TV"], "Number"] != "")
		Return 0
	Address := StrSplit(Location, "\")
	ParentNode := 0
	For a,b in Address
	{
		AddressString .= (A_Index = 1 ? "" : "\") b
		If (Results[AddressString,"TV"] = "")
			Results[AddressString,"TV"] := TV_Add(b, ParentNode, Icon["Blank"]), Results[Results[AddressString,"TV"], "Location"] := AddressString
		ParentNode := Results[AddressString,"TV"]
	}
	Results[Location "\" Name, "TV"] := Node := TV_Add(Name, ParentNode, Icon[Type] " Vis Bold")
	Results[Node, "Location"] := Location
	Results[Node, "Name"] := Name
	Results[Node, "Type"] := Type
	Results[Node, "Value"] := Value
	Results[Node, "Number"] := Number
	Results[Node, "Modified"] := Modified
	Return True
}

GuiEvent:
If (A_GuiEvent = "DoubleClick") {
	Node := A_EventInfo
	TV_Modify(Node, "Expand")
	RegJump(Results[Node, "Location"], Results[Node, "Name"])
} Else If (A_GuiEvent = "s")
	GuiControl, , Output, % Results[A_EventInfo, "Number"] ? "Result " Results[A_EventInfo, "Number"] " of " Found "`n`n" Results[A_EventInfo, "Location"] "\" Results[A_EventInfo, "Name"] "`n`n" (Results[A_EventInfo, "Value"] ? Results[A_EventInfo, "Value"] : "(no value)") "`n`nType:      " Results[A_EventInfo, "Type"] "`nModified:  " Results[A_EventInfo, "Modified"] : Found " results (" SearchTime " seconds)`n`n" Results[A_EventInfo, "Location"] "\" Results[A_EventInfo, "Name"]
Return

GuiEscape:
GuiClose:
ExitApp

#SingleInstance, Force

;================================================== Library Functions ===================================================

IniRead(_IniFile="", _Options="") ; http://www.autohotkey.com/forum/topic72442.html
{
	Local _Reading, _Prepend, _Entries, _nSec, _nKey, _@, _@1, _@2, _@3, _@4, _@5 := 1, _Literal := """", _Commands := "sa|ka|sl|sr|p|d|r|e|t|c|b|f"
	;--------------------------------------OPTIONS-------------------------------------------------------
	; Each letter or word below is a flag that corresponds to one of the settings of the function. These settings can take any string as a value. A) By default, each setting takes the value assigned in the first column below. B) You may change settings by including that flag in the Options parameter of the function. In this case the passed option will take the value assigned in the 2nd column below. C) Indicate any other value with a string immediately following the corresponding flag. Include spaces in this string by surrounding it with quotes. Separate each flag and string pairing with a space.
	;----------------------------------------------------------------------------------------------------
	; DEFAULT                 USER DEFAULT             NAME                    ABOUT
	, _sa := "",              _sa_user := "Sections*"  ;sa = Section Array     Creates the specified pseudoarray containing each section header that was read. An asterisk (*) will be replaced by the item number, otherwise it will be appended to the end. Item 0 will contain the size of the ray. Only applicable if all sections are being read (s = "")
	, _ka := "",              _ka_user := "Keys*"      ;ka = Key Array         Same as above but for individual keys. Similar to the d option
	, _sl := "",              _sl_user := "*"          ;sl = Section (Literal) Section to use out of whole file. If multiple sections have the same name the first will be used. Specify an asterisk (*) to only read the first section. Leave blank to read the entire file
	, _sr := "",              _sr_user := ""           ;sr = Section (RegEx)   Same as above but will extract from all sections whose names match the given regular expression
	, _p := "",               _p_user := "*_"          ;p = Prepend            Prepend this string to the variables. An asterisk (*) will be replaced by the current section name
	, _d := "",               _d_user := "`n"          ;d = Delimited List     Instead of returning the number of keys read, the function will return a string of all variables created (i.e. all keys read with any additional modifications made by _r or _p) delimited by the indicated character(s)
	, _r := "",               _r_user := "_"           ;r = Replace Bad Chars  One or more characters in key or section names that are unsuitable for AutoHotkey variable names will be replaced by this character
	, _e := "fso",            _e_user := ""            ;e = Error Behavior     Indicate/omit any combination of the characters f/s/o/r to display an error dialog/exit silently if the ini file cannot be found/the desired section cannot be found/a preexisting variable will be overwritten/r will replace any inappropriate characters
	, _t := True,             _t_user := False         ;t = Trim Whitespace    Trims whitespaces from the beginning and end of all keys and values
	, _c := True,             _c_user := False         ;c = Allow Comments     Specifying true for Allow Comments will exclude all comments from ini values. Comments are delimited with a space and then a semicolon (;) as in AutoHotkey
	, _b := True,             _b_user := False         ;b = Use Booleans       If b is true then keys with the string "true", "false", "yes", or "no" will be interpreted as 1 or 0 so as to work nicely with AutoHotkey IF statements
	, _f := True,             _f_user := False         ;f = Deref Values       If f is true then Transform, Deref will be used on all key values. For instance, this allows you to give a filepath a %A_ScriptDir%\File.dat
	;---------------------------------USER CONFIGURATIONS------------------------------------------------
	, _UserConfig_Foo := "x12 y34"
	, _UserConfig_Bar := "cWhite -a"
	;----------------------------------------------------------------------------------------------------
	While (_@5 := RegExMatch(_Options, "i)(?:^|\s)(?:!(\w+)|(\+|-)?(" _Commands ")(" _Literal "(?:[^" _Literal "]|" _Literal _Literal ")*" _Literal "(?= |$)|[^ ]*))", _@, _@5 + StrLen(_@)))
		If (_@1 <> "")
			_Options := SubStr(_Options, 1, _@5 + StrLen(_@)) _UserConfig_%_@1% SubStr(_Options, _@5 + StrLen(_@))
		Else If (_@4 <> "") {
			If (InStr(_@4, _Literal) = 1) and (_@4 <> _Literal) and (SubStr(_@4, 0, 1) = _Literal) and (_@4 := SubStr(_@4, 2, -1))
				StringReplace, _@4, _@4, %_Literal%%_Literal%, %_Literal%, All
			_%_@3% := _@4
		} Else
			_%_@3% := _@2 = "+" ? True : _@2 = "-" ? False : _%_@3%_user
	If (_IniFile = "") {
		If !FileExist(_IniFile := SubStr(A_ScriptFullPath, 1, InStr(A_ScriptFullPath, ".", 0, 0)) "ini") {
			If InStr(_e, "f")
				MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, The IniFile parameter was omitted or blank, which the function interprets as an ini file with the same name as the script and in the same dir, i.e.:`n`n%_IniFile%`n`nThis file does not exist.
			Return
		}
	} Else If (IniFile = "*") {
		Loop, *.ini
		{
			_IniFile := A_LoopFileFullPath
			Break
		}
		If (_IniFile = "*") {
			If InStr(_e, "f")
				MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, No .ini file found in working directory.`n`not avoid this error, specify an explicit .ini file path in the first parameter of the function.
			Return
		}
	} Else If !FileExist(_IniFile) {
		If InStr(_e, "f")
			MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, File "%_IniFile%" not found or does not exist.
		Return
	}
	If RegExMatch(_r, "[^\w#@$?]") or RegExMatch(_p, "[^\w*#@$?]") {
		MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, Neither the p nor r options may contain characters that are not alloewd in AutoHotkey variable names.
		Return
	}
	_Entries := _d = "" ? 0 : _d
	If !InStr(_p, "*")
		_Prepend := _p
	If (_sl <> "") {
		If (_sr <> "") {
			MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, Please enter either a sl (Section - Literal) or sr (Section - RegEx) value, not both.
			Return
		}
	} Else If (_sr = "")
		_Reading := True
	If (_sa <> "") {
		If RegExMatch(_sa, "[^\w#@$?*]")
			_sa := RegExReplace(_sa, "[^\w#@$?*]")
		If !InStr(_sa, "*")
			_sa .= "*"
	}
	If (_ka <> "") {
		If RegExMatch(_ka, "[^\w#@$?*]")
			_ka := RegExReplace(_ka, "[^\w#@$?*]")
		If !InStr(_ka, "*")
			_ka .= "*"
		If (_ka = _sa) {
			MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, The sa (Section Output Array) and ka (Key Output Array) options cannot be the same.
			Return
		}
	}
	Loop, Read, %_IniFile%
		If RegExMatch(A_LoopReadLine, "^[^=]*\[\K[^\]]+(?=\])", _@) {
			If _t
				_@ = %_@%
			If (_sr <> "")
				_Reading := RegExMatch(_@, _sr) ? True : False
			Else If (_sl <> "")
				If _Reading
					Break
				Else If (_@ = _sl) or (_sl = "*")
					_Reading := True
			If !_Reading
				Continue
			If InStr(_p, "*") {
				StringReplace, _Prepend, _p, *, % RegExReplace(_@, "[^\w#_t$?]+", _r, _@2), All
				If _@2 and InStr(_e, "r") {
					MsgBox, 262420, %A_ScriptName% - %A_ThisFunc%(): Error, The section "%_@%" contains characters not allowed in AutoHotkey variable names. Replace these characters with "%_r%"?`n`nTo change the replacement character, use the r option.
					IfMsgBox NO
						Return
				}
			}
			If _sa {
				_nSec += 1
				StringReplace, _@1, _sa, *, %_nSec%, All
				%_@1% := _@
			}
		} Else If _Reading and InStr(A_LoopReadLine, "=") {
			_@ := SubStr(A_LoopReadLine, 1, InStr(A_LoopReadLine, "=") - 1), _@2 := SubStr(A_LoopReadLine, InStr(A_LoopReadLine, "=") + 1)
			If _t {
				_@ = %_@%
				_@2 = %_@2%
			}
			If _c
				_@2 := RegExReplace(_@2, "(?:\s+|^);.*")
			_@1 := RegExReplace(_@, "[^\w#_t$?]+", _r)
			If (_@1 <> _@) and InStr(_e, "r") {
				MsgBox, 262420, %A_ScriptName% - %A_ThisFunc%(): Error, The key name "%_@%" contains characters not allowed in AutoHotkey variable names. Replace these characters with "%_r%"?`n`nTo change the replacement character, use the r option.
				IfMsgBox NO
					Return
			}
			If (%_Prepend%%_@1% <> "") and InStr(_e, "o") {
				MsgBox, 262420, %A_ScriptName% - %A_ThisFunc%(): Error, The variable "%_Prepend%%_@1%" has already been assigned, either by %A_ThisFunc%() or elsewhere in the script. Overwrite it with "%_@2%" (the value from the .ini file)?`n`nTo avoid this error, try using the p or s options to make output variable names more unique.
				IfMsgBox NO
					Return
			}
			If _f
				Transform, _@2, Deref, %_@2%
			%_Prepend%%_@1% := !_b ? _@2 : _@2 = "True" or _@2 = "Yes" ? True : _@2 = "False" or _@2 = "No" ? False : _@2
			If (_d <> "") {
				StringReplace, _Entries, _Entries, %_d%%_Prepend%%_@1%%_d%, %_d%, All
				_Entries .= _Prepend _@1 _d
			} Else
				_Entries += 1
			If _ka {
				_nKey += 1
				StringReplace, _@, _ka, *, %_nKey%, All
				%_@% := _Prepend _@1
			}
		}
	If (_sl <> "") and !_Reading and InStr(_e, "s")
		MsgBox, 262160, %A_ScriptName% - %A_ThisFunc%(): Error, Section "%_sl%" was not found in ini file "%_IniFile%", therefore no variables were assigned.`n`nTo avoid this error, use the sr (Section Name - RegEx) option instead of sl (Section Name - Literal), or omit both options.
	If _sa {
		StringReplace, _@, _sa, *, 0, All
		%_@% := _nSec
	}
	If _ka {
		StringReplace, _@, _ka, *, 0, All
		%_@% := _nKey
	}
	Return _d = "" ? _Entries : SubStr(_Entries, 2, -1)
}
