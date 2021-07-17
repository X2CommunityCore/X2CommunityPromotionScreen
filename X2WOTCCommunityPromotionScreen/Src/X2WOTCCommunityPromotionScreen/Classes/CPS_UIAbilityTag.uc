class CPS_UIAbilityTag extends UIImage;

var UIText TagText;
var int iRankIndex; // Position of this ability tag icon on the promotion screen column.
var name AbilityName;

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

simulated function CPS_UIAbilityTag InitAbilityTag(name InitName)
{
	InitImage();
	AbilityName = InitName;
	SetPosition(33, 40);
	SetSize(38, 38);

	return self;
}

simulated function UIImage LoadImage(string NewPath)
{
	if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 1)
	{
		NewPath = "img:///UILibrary_CPS.UI.TagIcon";
	}
	else if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 2)
	{
		NewPath = "img:///UILibrary_CPS.UI.TagBorder";
	}

	return super.LoadImage(NewPath);
}
	
simulated function MaybeSetTagNumberText(int iText)
{
	local string strText;

	// Draw ability tag text only in the "advanced" mode.
	if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 2)
	{
		if (TagText == none)
		{
			TagText = Spawn(class'UIText', self).InitText(MCName);
		}
		else
		{	
			// Explicitly showing the text may be necessary if the user
			// tagged some abilities in the basic mode, then switched
			// to the advanced mode.
			TagText.Show();
		}

		strText = string(iText);

		if (Len(strText) > 1)
		{
			// Smaller font size for double digits
			TagText.SetCenteredText(class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 20), self);
			TagText.Y = 6;
		}
		else
		{
			TagText.SetCenteredText(class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 24), self);
			TagText.Y = 4;
			TagText.X = -1;
		}
		TagText.RealizeLocation();
	}
	else if (TagText != none) 
	{
		// Otherwise hide the text if it is present.
		// This may be necessary if the user tagged some abilities
		// in the advanced mode and then switched to the basic mode.
		TagText.Hide();
	}
}
	