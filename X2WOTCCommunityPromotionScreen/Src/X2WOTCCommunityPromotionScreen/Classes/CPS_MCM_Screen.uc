class CPS_MCM_Screen extends Object config(X2WOTCCommunityPromotionScreen_NullConfig);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoIndexDropdownVars(SHOW_UNREACHED_PERKS_MODE);
`MCM_API_AutoCheckBoxVars(DISABLE_TRAINING_CENTER_REQUIREMENT);
`MCM_API_AutoCheckBoxVars(DISABLE_NEWCLASS_POPUPS);
`MCM_API_AutoCheckBoxVars(DISABLE_COMINT_POPUPS);
`MCM_API_AutoIndexDropdownVars(ABILITY_TREE_PLANNER_MODE);

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoIndexDropdownFns(SHOW_UNREACHED_PERKS_MODE, 3);
`MCM_API_AutoCheckBoxFns(DISABLE_TRAINING_CENTER_REQUIREMENT, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_NEWCLASS_POPUPS, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_COMINT_POPUPS, 1);
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

	// Issue #69
	Group.AddDropdown('SHOW_UNREACHED_PERKS_MODE', SHOW_UNREACHED_PERKS_MODE_Label, SHOW_UNREACHED_PERKS_MODE_Tip, SHOW_UNREACHED_PERKS_MODE_Strings, SHOW_UNREACHED_PERKS_MODE_Strings[SHOW_UNREACHED_PERKS_MODE], SHOW_UNREACHED_PERKS_MODE_SaveHandler, SHOW_UNREACHED_PERKS_MODE_ChangeHandler);

	// Issue #53
	Group.AddDropdown('ABILITY_TREE_PLANNER_MODE', ABILITY_TREE_PLANNER_MODE_Label, ABILITY_TREE_PLANNER_MODE_Tip, ABILITY_TREE_PLANNER_MODE_Strings, ABILITY_TREE_PLANNER_MODE_Strings[ABILITY_TREE_PLANNER_MODE], ABILITY_TREE_PLANNER_MODE_SaveHandler).SetEditable(SHOW_UNREACHED_PERKS_MODE != 0);
	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_TRAINING_CENTER_REQUIREMENT);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_NEWCLASS_POPUPS);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_COMINT_POPUPS);	

	Page.ShowSettings();
}

// Start Issue #53
simulated function SHOW_UNREACHED_PERKS_MODE_ChangeHandler(MCM_API_Setting _Setting, string _SettingValue)
{
    SHOW_UNREACHED_PERKS_MODE = SHOW_UNREACHED_PERKS_MODE_Strings.Find(_SettingValue);

    // Unlock / lock the ABILITY_TREE_PLANNER_MODE depending on if unreached perks are shown or not.
	_Setting.GetParentGroup().GetSettingByName('ABILITY_TREE_PLANNER_MODE').SetEditable(SHOW_UNREACHED_PERKS_MODE > 0); 
}
// End Issue #53

simulated function LoadSavedSettings()
{
	SHOW_UNREACHED_PERKS_MODE = `GETMCMVAR(SHOW_UNREACHED_PERKS_MODE);
	DISABLE_TRAINING_CENTER_REQUIREMENT = `GETMCMVAR(DISABLE_TRAINING_CENTER_REQUIREMENT);
	DISABLE_NEWCLASS_POPUPS = `GETMCMVAR(DISABLE_NEWCLASS_POPUPS);
	DISABLE_COMINT_POPUPS = `GETMCMVAR(DISABLE_COMINT_POPUPS);
	ABILITY_TREE_PLANNER_MODE = `GETMCMVAR(ABILITY_TREE_PLANNER_MODE);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoIndexReset(SHOW_UNREACHED_PERKS_MODE);
	`MCM_API_AutoReset(DISABLE_TRAINING_CENTER_REQUIREMENT);
	`MCM_API_AutoReset(DISABLE_NEWCLASS_POPUPS);
	`MCM_API_AutoReset(DISABLE_COMINT_POPUPS);
	`MCM_API_AutoIndexReset(ABILITY_TREE_PLANNER_MODE);
}

simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	// Start Issue #53
	// Disable the ABILITY_TREE_PLANNER_MODE if SHOW_UNREACHED_PERKS is disabled.
	if (SHOW_UNREACHED_PERKS_MODE == 0)
	{
		ABILITY_TREE_PLANNER_MODE = 0;
	}
	// End Issue #53

	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();

	// Issue #62
	class'X2DownloadableContentInfo_X2WOTCCommunityPromotionScreen'.static.Update_ViewLockedSkills_UISL();
}


