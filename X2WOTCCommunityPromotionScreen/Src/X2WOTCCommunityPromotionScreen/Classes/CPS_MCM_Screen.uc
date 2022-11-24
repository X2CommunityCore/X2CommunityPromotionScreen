class CPS_MCM_Screen extends Object config(X2WOTCCommunityPromotionScreen_NullConfig);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoCheckBoxVars(SHOW_INVENTORY_SLOT);
`MCM_API_AutoCheckBoxVars(SHOW_UNREACHED_PERKS);
`MCM_API_AutoCheckBoxVars(DISABLE_TRAINING_CENTER_REQUIREMENT);
`MCM_API_AutoCheckBoxVars(DISABLE_NEWCLASS_POPUPS);
`MCM_API_AutoCheckBoxVars(DISABLE_COMINT_POPUPS);
`MCM_API_AutoCheckBoxVars(AUTO_PROMOTE);
`MCM_API_AutoIndexDropdownVars(ABILITY_TREE_PLANNER_MODE);


`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoCheckBoxFns(SHOW_INVENTORY_SLOT, 3);
`MCM_API_AutoCheckBoxFns(SHOW_UNREACHED_PERKS, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_TRAINING_CENTER_REQUIREMENT, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_NEWCLASS_POPUPS, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_COMINT_POPUPS, 1);
`MCM_API_AutoCheckBoxFns(AUTO_PROMOTE, 1);
`MCM_API_AutoIndexDropdownFns(ABILITY_TREE_PLANNER_MODE, 2);

event OnInit(UIScreen Screen)
{
	`MCM_API_Register(Screen, ClientModCallback);
}

//Simple one group framework code
simulated function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode)
{
	local MCM_API_SettingsPage Page;
	local MCM_API_SettingsGroup Group;

	LoadSavedSettings();
	Page = ConfigAPI.NewSettingsPage(ModName);
	Page.SetPageTitle(PageTitle);
	Page.SetSaveHandler(SaveButtonClicked);
	Page.EnableResetButton(ResetButtonClicked);

	Group = Page.AddGroup('Group', GroupHeader);
	`MCM_API_AutoAddCheckBox(Group, SHOW_UNREACHED_PERKS, /* Issue #53 */ SHOW_UNREACHED_PERKS_ChangeHandler);

	// Issue #53
	Group.AddDropdown('ABILITY_TREE_PLANNER_MODE', ABILITY_TREE_PLANNER_MODE_Label, ABILITY_TREE_PLANNER_MODE_Tip, ABILITY_TREE_PLANNER_MODE_Strings, ABILITY_TREE_PLANNER_MODE_Strings[ABILITY_TREE_PLANNER_MODE], ABILITY_TREE_PLANNER_MODE_SaveHandler).SetEditable(SHOW_UNREACHED_PERKS);
	`MCM_API_AutoAddCheckBox(Group, AUTO_PROMOTE);	
	`MCM_API_AutoAddCheckBox(Group, SHOW_INVENTORY_SLOT);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_TRAINING_CENTER_REQUIREMENT);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_NEWCLASS_POPUPS);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_COMINT_POPUPS);	

	Page.ShowSettings();
}

// Start Issue #53
simulated function SHOW_UNREACHED_PERKS_ChangeHandler(MCM_API_Setting _Setting, bool _SettingValue)
{
	SHOW_UNREACHED_PERKS = _SettingValue;
	// Lock the ABILITY_TREE_PLANNER_MODE if SHOW_UNREACHED_PERKS is disabled.
	_Setting.GetParentGroup().GetSettingByName('ABILITY_TREE_PLANNER_MODE').SetEditable(SHOW_UNREACHED_PERKS);
}
// End Issue #53

simulated function LoadSavedSettings()
{
	SHOW_INVENTORY_SLOT = `GETMCMVAR(SHOW_INVENTORY_SLOT);
	SHOW_UNREACHED_PERKS = `GETMCMVAR(SHOW_UNREACHED_PERKS);
	DISABLE_TRAINING_CENTER_REQUIREMENT = `GETMCMVAR(DISABLE_TRAINING_CENTER_REQUIREMENT);
	DISABLE_NEWCLASS_POPUPS = `GETMCMVAR(DISABLE_NEWCLASS_POPUPS);
	DISABLE_COMINT_POPUPS = `GETMCMVAR(DISABLE_COMINT_POPUPS);
	ABILITY_TREE_PLANNER_MODE = `GETMCMVAR(ABILITY_TREE_PLANNER_MODE);
	AUTO_PROMOTE = `GETMCMVAR(AUTO_PROMOTE);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(SHOW_INVENTORY_SLOT);
	`MCM_API_AutoReset(SHOW_UNREACHED_PERKS);
	`MCM_API_AutoReset(DISABLE_TRAINING_CENTER_REQUIREMENT);
	`MCM_API_AutoReset(DISABLE_NEWCLASS_POPUPS);
	`MCM_API_AutoReset(DISABLE_COMINT_POPUPS);
	`MCM_API_AutoReset(AUTO_PROMOTE);
	`MCM_API_AutoIndexReset(ABILITY_TREE_PLANNER_MODE);
}

simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	// Start Issue #53
	// Disable the ABILITY_TREE_PLANNER_MODE if SHOW_UNREACHED_PERKS is disabled.
	if (!SHOW_UNREACHED_PERKS)
	{
		ABILITY_TREE_PLANNER_MODE = 0;
	}
	// End Issue #53

	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();

	// Issue #62
	class'X2DownloadableContentInfo_X2WOTCCommunityPromotionScreen'.static.Update_ViewLockedSkills_UISL();
}


