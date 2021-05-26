//---------------------------------------------------------------------------------------
//  FILE:    UISL_CPS.uc
//  AUTHOR:  Iridar
//  PURPOSE: Issue #26 - Displays warning popup at the game start if both CPS and NPSBD
//  are active. Based on similar functionality used in Highlander, developed by Musashi.
//---------------------------------------------------------------------------------------
class UISL_CPS extends UIScreenListener;

var localized string strDisablePopup;
var localized string strPopupText;

event OnInit(UIScreen Screen)
{
	// Show the popup when playing with -review launch argument (non-debug mode).
	if(UIShell(Screen) != none && UIShell(Screen).DebugMenuContainer == none)
	{
		Screen.SetTimer(3.0f, false, nameof(DisplayWarningPopup), self);
	}
}

simulated function DisplayWarningPopup()
{
	local TDialogueBoxData kDialogData;

	//local X2WOTCCH_DialogCallbackData CallbackData;

	//CallbackData = new class'X2WOTCCH_DialogCallbackData';
	//CallbackData.DependencyData = Dep;

	kDialogData.strTitle = class'UIAlert'.default.m_strSoldierShakenHeader; // "Attention"
	kDialogData.eType = eDialog_Normal; // eDialog_Alert - yellow text and frames
	kDialogData.strText = strPopupText;
	kDialogData.fnCallbackEx = WarningPopupCB;
	kDialogData.strAccept = strDisablePopup;
	kDialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericAccept;
	//kDialogData.xUserData = CallbackData;

	`PRESBASE.UIRaiseDialog(kDialogData);
}


simulated function WarningPopupCB(Name eAction, UICallbackData xUserData)
{
	`PRESBASE.PlayUISound(eSUISound_MenuSelect);

	if (eAction == 'eUIAction_Accept')
	{

	}
	else
	{		

	}
}
/*
simulated function string GetIncompatibleModsText(ModDependency Dep)
{
	return class'UIUtilities_Text'.static.GetColoredText(Repl(class'X2WOTCCH_ModDependencies'.default.ModIncompatible, "%s", Dep.ModName, true), eUIState_Header) $ "\n\n" $
			class'UIUtilities_Text'.static.GetColoredText(MakeBulletList(Dep.Children), eUIState_Bad) $ "\n";
}*/