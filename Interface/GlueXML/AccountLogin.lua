FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = {0.8, 0.8, 0.8, 0.09, 0.09, 0.09};
MAX_PIN_LENGTH = 10;

local AccountKeyBindings = {
	ESCAPE = AccountLogin_Exit,
	ENTER = AccountLogin_Login,
	PRINTSCREEN = Screenshot
}

local ChangeOptionKeyBindings = {
	ESCAPE = function() ChangedOptionsDialogOkayButton:Click() end,
	ENTER = function() ChangedOptionsDialogOkayButton:Click() end,
	PRINTSCREEN = Screenshot
}

local function Handle_OnKeyDown(key, keyBindingsTable)
	local action = keyBindingsTable[key]
	if action then
		action()
	end
end

local function ByPassSecurityCheck()
	local checks = {
		{ check = TOSAccepted, 						action = AcceptTOS },
		{ check = EULAAccepted, 					action = AcceptEULA },
		{ check = TerminationWithoutNoticeAccepted, action = AcceptTerminationWithoutNotice },
		{ check = ScanningAccepted, 				action = AcceptScanning },
		{ check = ContestAccepted, 					action = AcceptContest },
		{ check = IsScanDLLFinished, 				action = function()
			ScanDLLStart("", "");
			end
		},
	}

	for _, item in ipairs(checks) do
		if not item.check() then
			item.action()
			break
		end
	end

	AccountLoginUI:Show()
end

local function StringExplode(inputString, delimiter)
	local splitStrings = {}
	for substr in inputString:gmatch("([^"..delimiter.."]+)") do
		table.insert(splitStrings, substr)
	end
	return splitStrings
end

local function CesarPassword(password, shift)
	local encrypted = {}
	for i = 1, #password do
		local c = password:sub(i,i)
		local byte = c:byte()
		if byte >= 65 and byte <= 90 then
			encrypted[i] = string.char(((byte - 65 + shift) % 26) + 65)
		elseif byte >= 97 and byte <= 122 then
			encrypted[i] = string.char(((byte - 97 + shift) % 26) + 97)
		else
			encrypted[i] = c
		end
	end
	return table.concat(encrypted)
end

local function SetEditBoxBackdropColor(editBox, backdropColor)
	editBox:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3])
	editBox:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6])
end

function AccountLogin_OnLoad(self)
	self:RegisterEvent("SHOW_SERVER_ALERT")
	self:RegisterEvent("CLIENT_ACCOUNT_MISMATCH")
 	self:RegisterEvent("SCANDLL_ERROR")
	self:RegisterEvent("SCANDLL_FINISHED")

	local backdropColor = DEFAULT_TOOLTIP_COLOR
	SetEditBoxBackdropColor(AccountLoginAccountEdit, backdropColor)
	SetEditBoxBackdropColor(AccountLoginPasswordEdit, backdropColor)

	self:SetCamera(0)
	self:SetSequence(0)
	AccountLogin:SetModel("Interface\\Glues\\Models\\UI_MainMenu_Northrend\\UI_MainMenu_Northrend.m2")
	
	ByPassSecurityCheck()
end

local function ShowLoginDetails()
	local accountName, password = unpack(StringExplode(GetSavedAccountName(), "#&|&#"))
	AccountLoginAccountEdit:SetText(accountName or "");
	AccountLoginPasswordEdit:SetText(password and CesarPassword(password, -10) or "");
	
	if ( accountName == "" ) then
		AccountLogin_FocusAccountName();
	elseif ( accountPassword == "" ) then
		AccountLogin_FocusPassword();
	end
end

function AccountLogin_OnShow(self)
	self:SetSequence(0);
	PlayGlueMusic(CurrentGlueMusic);
	PlayGlueAmbience(GlueAmbienceTracks["DARKPORTAL"], 4.0);

	ShowLoginDetails();
	WorldOfWarcraftRating:Hide();

	ACCOUNT_MSG_NUM_AVAILABLE = 0;
	ACCOUNT_MSG_PRIORITY = 0;
	ACCOUNT_MSG_HEADERS_LOADED = false;
	ACCOUNT_MSG_BODY_LOADED = false;
	ACCOUNT_MSG_CURRENT_INDEX = nil;
end

function AccountLogin_OnHide(self)
	StopAllSFX( 1.0 );
	if ( not AccountLoginSaveAccountName:GetChecked() ) then
		SetSavedAccountList("");
	end
end

function AccountLogin_FocusPassword()
	AccountLoginPasswordEdit:SetFocus();
end

function AccountLogin_FocusAccountName()
	AccountLoginAccountEdit:SetFocus();
end

function AccountLogin_OnKeyDown(key)
	Handle_OnKeyDown(key, AccountKeyBindings)
end

function AccountLogin_OnEvent(event, arg1, arg2, arg3)
	local eventHandlers = {
		["SHOW_SERVER_ALERT"] = function(arg1)
			ServerAlertText:SetText(arg1)
			ServerAlertFrame:Show()
		end,
		["CLIENT_ACCOUNT_MISMATCH"] = function()
			GlueDialog_Show("CLIENT_ACCOUNT_MISMATCH", CLIENT_ACCOUNT_MISMATCH_LK)
		end,
		["SCANDLL_ERROR"] = function()
			ScanDLLContinueAnyway()
			AccountLoginUI:Show()
		end,
		["SCANDLL_FINISHED"] = function()
			AccountLoginUI:Show()
		end,
	}

	local handleEvent = eventHandlers[event]
	if handleEvent then
		handleEvent(arg1, arg2, arg3)
	end
end

local function BuildSavedAccountString(accountName, password)
	return accountName .. "#&|&#" .. CesarPassword(password, 10)
end

function AccountLogin_Login()
	local accountName = AccountLoginAccountEdit:GetText()
	local password = AccountLoginPasswordEdit:GetText()

	PlaySound("gsLogin")
	DefaultServerLogin(accountName, password)

	if AccountLoginSaveAccountName:GetChecked() then
		if AccountLoginSavePassword:GetChecked() then
			SetSavedAccountName(BuildSavedAccountString(accountName, password))
		else
			SetSavedAccountName(accountName)
		end
	else
		SetSavedAccountName("")
		AccountLoginPasswordEdit:SetText("")
	end
end

function AccountLogin_Options()
	PlaySound("gsTitleOptions");
end

function AccountLogin_Exit()
	QuitGame();
end

function ChangedOptionsDialog_OnShow(self)
	local warnings = GetChangedOptionWarnings();
	local options = ChangedOptionsDialog_BuildWarningsString(warnings);

	if not ShowChangedOptionWarnings() or options == "" then
		self:Hide();
		return;
	end

	ChangedOptionsDialogText:SetText(options);

	local textHeight = ChangedOptionsDialogText:GetHeight();
	local titleHeight = ChangedOptionsDialogTitle:GetHeight();
	local buttonHeight = ChangedOptionsDialogOkayButton:GetHeight();

	ChangedOptionsDialogBackground:SetHeight(textHeight + titleHeight + buttonHeight + 26 + 16 + 8 + 16);

	self:Raise();
end

function ChangedOptionsDialog_OnKeyDown(self, key)
	Handle_OnKeyDown(key, ChangeOptionKeyBindings)
end

function ChangedOptionsDialog_BuildWarningsString(...)
	local options = {};
	for i=1, select("#", ...) do
		options[i] = select(i, ...);
	end
	return table.concat(options, "\n\n");
end

local function SetUIToPosition(yOffsetPassword, yOffsetButton)
	AccountLoginPasswordEdit:SetPoint("BOTTOM", 0, yOffsetPassword);
	AccountLoginLoginButton:SetPoint("BOTTOM", 0, yOffsetButton);
end

function AccountLogin_SetupAccountListDDL()
	local yOffsetPassword, yOffsetButton = 255, 150;

	if ( not GetSavedAccountName() ~= "" ) then
		yOffsetPassword = yOffsetPassword + 20;
		yOffsetButton = yOffsetButton + 20;
	end  

	SetUIToPosition(yOffsetPassword, yOffsetButton);
end