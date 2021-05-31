//---------------------------------------------------------------------------------------
//  FILE:    UISL_CPS.uc
//  AUTHOR:  Iridar
//  PURPOSE: Issue #26 - Displays warning popup at the game start if both CPS and NPSBD
//  are active. Based on similar functionality used in Highlander, developed by Musashi.
//---------------------------------------------------------------------------------------
class UISL_CPS extends UIScreenListener config(X2WOTCCommunityPromotionScreen_NULLCONFIG);

var localized string strDisablePopup;
var localized string strPopupText;

var config bool bDisablePopup;

event OnInit(UIScreen Screen)
{
	// Show the popup when playing with -review launch argument (non-debug mode).
	if(UIShell(Screen) != none && UIShell(Screen).DebugMenuContainer == none && !bDisablePopup)
	{
		Screen.SetTimer(3.0f, false, nameof(DisplayWarningPopup), self);
	}
}

simulated function DisplayWarningPopup()
{
	local TDialogueBoxData kDialogData;

	kDialogData.strTitle = class'UIAlert'.default.m_strSoldierShakenHeader; // "Attention"
	kDialogData.eType = eDialog_Normal; // eDialog_Alert - yellow text and frames
	kDialogData.strText = strPopupText;
	kDialogData.fnCallbackEx = WarningPopupCB;
	kDialogData.strAccept = strDisablePopup;
	kDialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericAccept;

	`PRESBASE.UIRaiseDialog(kDialogData);
}

simulated function WarningPopupCB(Name eAction, UICallbackData xUserData)
{
	`PRESBASE.PlayUISound(eSUISound_MenuSelect);

	if (eAction == 'eUIAction_Accept')
	{
		bDisablePopup = true;
		self.SaveConfig();
	}
}