class CPS_MCM_Screen extends Object config(X2WOTCCommunityPromotionScreen_NullConfig);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoCheckBoxVars(SHOW_UNREACHED_PERKS);
`MCM_API_AutoCheckBoxVars(DISABLE_TRAINING_CENTER_REQUIREMENT);
`MCM_API_AutoCheckBoxVars(DISABLE_NEWCLASS_POPUPS);
`MCM_API_AutoCheckBoxVars(DISABLE_COMINT_POPUPS);

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoCheckBoxFns(SHOW_UNREACHED_PERKS, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_TRAINING_CENTER_REQUIREMENT, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_NEWCLASS_POPUPS, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_COMINT_POPUPS, 1);

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
	`MCM_API_AutoAddCheckBox(Group, SHOW_UNREACHED_PERKS);
	`MCM_API_AutoAddCheckBox(Group, DISABLE_TRAINING_CENTER_REQUIREMENT);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_NEWCLASS_POPUPS);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_COMINT_POPUPS);	

	Page.ShowSettings();
}

simulated function LoadSavedSettings()
{
	SHOW_UNREACHED_PERKS = `GETMCMVAR(SHOW_UNREACHED_PERKS);
	DISABLE_TRAINING_CENTER_REQUIREMENT = `GETMCMVAR(DISABLE_TRAINING_CENTER_REQUIREMENT);
	DISABLE_NEWCLASS_POPUPS = `GETMCMVAR(DISABLE_NEWCLASS_POPUPS);
	DISABLE_COMINT_POPUPS = `GETMCMVAR(DISABLE_COMINT_POPUPS);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(SHOW_UNREACHED_PERKS);
	`MCM_API_AutoReset(DISABLE_TRAINING_CENTER_REQUIREMENT);
	`MCM_API_AutoReset(DISABLE_NEWCLASS_POPUPS);
	`MCM_API_AutoReset(DISABLE_COMINT_POPUPS);
}

simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}


