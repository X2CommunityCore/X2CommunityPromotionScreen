class CPS_UIArmory_PromotionHeroColumn extends UIArmory_PromotionHeroColumn;

var int Offset;

var array<int> LockedAbilityIndices; // Issue #42

// Start Issue #53
var array<UIImage>	TagBackgroundIcons; // These are parallel arrays
var array<UIText>	TagTexts;
const AbilityTagPrefix = "CPS_AbilityTag_";

struct AbilityTagStruct
{
	var name AbilityName;
	var int iTag;
};
// End Issue #53

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

function OnAbilityInfoClicked(UIButton Button)
{
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local UIButton InfoButton;
	local CPS_UIArmory_PromotionHero PromotionScreen;
	local int idx;

	PromotionScreen = CPS_UIArmory_PromotionHero(Screen);

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	
	foreach InfoButtons(InfoButton, idx)
	{
		if (InfoButton == Button)
		{
			AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityNames[idx]);
			break;
		}
	}
	
	if (AbilityTemplate != none)
		`HQPRES.UIAbilityPopup(AbilityTemplate, PromotionScreen.UnitReference);

	if( InfoButton != none )
		InfoButton.Hide();
}

function SelectAbility(int idx)
{
	local UIArmory_PromotionHero PromotionScreen;
	local bool bSoundPlayed;
	
	PromotionScreen = UIArmory_PromotionHero(Screen);

	if( PromotionScreen.OwnsAbility(AbilityNames[idx]) )
	{
		OnInfoButtonMouseEvent(InfoButtons[idx], class'UIUtilities_Input'.const.FXS_L_MOUSE_UP);
	}
	else 
	{
		// Start Issue #53
		// When player clicks on a visible ability that has not been purchased yet, toggle its ability tag.
		if (!IsAbilityIconLocked(idx) && `GETMCMVAR(ABILITY_TREE_PLANNER_MODE) > 0) 
		{
			ToggleAbilityTagForUnit(idx, PromotionScreen.GetUnit());
			Movie.Pres.PlayUISound(eSUISound_MenuSelect);
			bSoundPlayed = true;
		}
		// End Issue #53

		if (bEligibleForPurchase && PromotionScreen.CanPurchaseAbility(Rank, idx + Offset, AbilityNames[idx]))
		{
			PromotionScreen.ConfirmAbilitySelection(Rank, idx);
		}
		else if (!PromotionScreen.IsAbilityLocked(Rank) && `GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 0) // Issue #53 - display the popup only if tagging is disabled
		{
			// This will display the ability info pop-up when the player directly clicks on an ability
			// located on a rank already reached by the soldier. 
			OnInfoButtonMouseEvent(InfoButtons[idx], class'UIUtilities_Input'.const.FXS_L_MOUSE_UP);
		}
		else if (!bSoundPlayed)
		{
			Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
		}
	}	
}

// Override to handle Scrolling
simulated function SelectNextIcon()
{
	local int newIndex;
	newIndex = m_iPanelIndex; //Establish a baseline so we can loop correctly

	do
	{
		newIndex += 1;
		if( newIndex >= AbilityIcons.Length )
		{
			if (AttemptScroll(false))
			{
				// The screen has scrolled for us, we don't need to wrap around for now
				newIndex--;
			}
			else
			{
				// Wrap around
				newIndex = 0;
			}
		}
	} until( AbilityIcons[newIndex].bIsVisible);
	
	UnfocusIcon(m_iPanelIndex);
	m_iPanelIndex = newIndex;
	FocusIcon(m_iPanelIndex);
	Movie.Pres.PlayUISound(eSUISound_MenuSelect); //bsg-crobinson (5.11.17): Add sound
}

simulated function SelectPrevIcon()
{
	local int newIndex;
	newIndex = m_iPanelIndex; //Establish a baseline so we can loop correctly

	do
	{
		newIndex -= 1;
		if( newIndex < 0 )
		{
			if (AttemptScroll(true))
			{
				// The screen has scrolled for us, we don't need to wrap around for now
				newIndex++;
			}
			else
			{
				// Wrap around
				newIndex = AbilityIcons.Length - 1;
			}
		}
	} until( AbilityIcons[newIndex].bIsVisible);
	
	UnfocusIcon(m_iPanelIndex);
	m_iPanelIndex = newIndex;
	FocusIcon(m_iPanelIndex);
	Movie.Pres.PlayUISound(eSUISound_MenuSelect); //bsg-crobinson (5.11.17): Add sound
}


// Instruct the Screen to Scroll the selection.
// Returns false if the column needs to wrap around, true else
// I.e. if we have <= 4 rows, this will always return false
simulated function bool AttemptScroll(bool Up)
{
	return CPS_UIArmory_PromotionHero(Screen).AttemptScroll(Up);
}

// Start Issue #42
// The little yellow '?' only appears for abilities that are not locked. 
// That's fine if you're hiding the locked abilities, but if you have the RevealAllAbilities config option set, 
// for example, it makes no sense to disallow players from seeing the extra information about the currently-locked abilities.
function OnAbilityIconMouseEvent(UIPanel Panel, int Cmd)
{
	local UIIcon AbilityIcon;
	local bool bHandled;
	local int idx;

	foreach AbilityIcons(AbilityIcon, idx)
	{
		if (Panel == AbilityIcon)
		{
			if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
			{
				SelectAbility(idx);
			}
			else if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_IN)
			{
				OnReceiveFocus();
				AbilityIcon.OnReceiveFocus();
				RealizeAvailableState(idx);

				PreviewAbility(idx);

				// Issue #42 - display yellow question mark button if the ability itself is visible to the player,
				// regardless if they can purchase it or not.
				if (!IsAbilityIconLocked(idx))
				{
					InfoButtons[idx].Show();
				}
				ClearTimer('Hide', InfoButtons[idx]);
			}
			else if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT || cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OUT)
			{
				AbilityIcon.OnLoseFocus();
				RealizeAvailableState(idx);

				HideAbilityPreview();
				SetTimer(0.01, false, 'Hide', InfoButtons[idx]);
			}

			bHandled = true;
			break;
		}
	}

	if (bHandled)
		RealizeVisuals();
}

function AS_SetIconState(int Index, bool bShowHighlight, string Image, string Label, int IconState, string ForegroundColor, string BackgroundColor, bool bIsConnected)
{
	if (IconState == eUIPromotionState_Locked)
	{
		LockedAbilityIndices.AddItem(Index);
	}

	super.AS_SetIconState(Index, bShowHighlight, Image, Label, IconState, ForegroundColor, BackgroundColor, bIsConnected);

	// Issue #53 - draw ability tag if the ability is tagged.
	AS_DrawAbilityTag(Index);
}

function bool IsAbilityIconLocked(const int Index)
{
	return LockedAbilityIndices.Find(Index) != INDEX_NONE;
}
// End Issue #42

// Start Issue #53
/// The following is an explanation of the tag system as a whole.
/// Function: allow the player to tag abilities on the promotion screen,
/// Purpose: planning the future ability tree for individual soldiers or simply marking noteworthy perks.
/// To have meaningful usability, the tag system requires the "Show Perks From Unreached Ranks"
/// MCM config to be enabled.
/// When it is so, the player can switch the tag system between three modes:
/// 1. Disabled
/// 2. Basic - abilities are tagged with a simple hexagon icon.
/// 3. Advanced - abilities are tagged by numbers in the order the player clicks on them.
/// I.e. the first ability to be tagged will have number "1" on it, the second will have "2", etc.
/// These numbers can be used by the player as a sort of priority or unlock order. 
/// Either way, tags are purely informative, the player still has to unlock all perks manually.
///
/// When the player clicks on an ability, the SelectAbility() runs and will call
/// ToggleAbilityTagForUnit(), which will either show or hide the tag appropriately.
///
/// Information about which abilities are tagged is stored on the unit in the form
/// of Unit Values, where the name of the value includes the ability template name,
/// and the value is the order, though it used only in the Advanced mode.
///
/// Each perk column stores parallel arrays of Tag Icons and Tag Text UI elements,
/// though, again, the text is used only in the advanced mode.

function ToggleAbilityTagForUnit(const int Index, XComGameState_Unit UnitState)
{
	local UnitValue	UV;

	// Tag already present? Then hide it.
	if (UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityNames[Index]), UV))
	{
		RemoveAbilityTag(Index);
	}
	else // Tag not present yet? Then add it.
	{
		SetAbilityTag(Index);
	}
}

function SetAbilityTag(const int Index)
{
	local CPS_UIArmory_PromotionHeroColumn	Column;
	local CPS_UIArmory_PromotionHero		PromotionScreen;
	local int								iAbilityTags;
	local name								AbilityName;
	local UnitValue							UV;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	local int iTag;
	local int i;

	PromotionScreen = CPS_UIArmory_PromotionHero(Screen);
	if (PromotionScreen == none)
		return;
		
	// 1. Build an array of all ability tags currently present on the unit.
	UnitState = PromotionScreen.GetUnit();
	for (i = 0; i < PromotionScreen.Columns.Length; i++)
	{
		Column = CPS_UIArmory_PromotionHeroColumn(PromotionScreen.Columns[i]);
		if (Column == none)
			return;

		foreach Column.AbilityNames(AbilityName)
		{
			if (UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityName), UV))
			{
				iAbilityTags++;
			}
		}
	}

	// 2. Set new tag value.
	iTag = iAbilityTags + 1;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tag Ability For Unit");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

	UnitState.SetUnitFloatValue(name(Column.AbilityTagPrefix $ AbilityNames[Index]), iTag, eCleanup_Never);

	`GAMERULES.SubmitGameState(NewGameState);

	// 3. Set the new tag value in the UI.
	AS_DrawAbilityTag(Index, iTag);
}

function AS_DrawAbilityTag(int Index, int iTag = -1)
{
	local UIImage	TagBackgroundIcon;
	local UIText	TagText;
	local int		TagIdx;

	// If called without a tag specified, try to get it from the unit.

	// iTag is used in two ways:
	// 1. Helps determine whether this ability is tagged or now.
	// 2. If the ability is tagged, iTag stores the order number that should be displayed on the tag icon (only in "advanced" mode).
	if (iTag == -1)
	{
		iTag = GetAbilityTag(AbilityNames[Index]);
		if (iTag == -1)
		{
			// Hide the tag icon if it exists when it's not supposed to,
			// can occur while scrolling.
			AS_HideAbilityTag(Index);

			// Exit early if the tag doesn't exist.
			return;
		}
	}

	// Hide all tags if tags are disabled or the ability is not visible anymore 
	// (presumably because MCM setting to show unreached perks has been disabled)
	if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 0 || IsAbilityIconLocked(Index))
	{
		foreach TagBackgroundIcons(TagBackgroundIcon, TagIdx)
		{
			TagBackgroundIcon.Hide(); // This will hide the associated Tag Text automatically.
		}
		return;
	}

	// Check if the icon already exists and show it rather than create a new icon every time.
	foreach TagBackgroundIcons(TagBackgroundIcon, TagIdx)
	{
		if (TagBackgroundIcon.MCName == name("Tag_" $ Index))
		{
			TagBackgroundIcon.Show();

			if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 2)
			{
				TagText = TagTexts[TagIdx];
				SetTagText(TagText, string(iTag), TagBackgroundIcon);
			}
			return;
		}
	}

	// If we're still here, then there's no tag icon for this ability yet, so create one.
	if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 1)
	{
		TagBackgroundIcon = AbilityIcons[Index].Spawn(class'UIImage', AbilityIcons[Index]).InitImage(name("Tag_" $ Index), "img:///UILibrary_CPS.UI.TagIcon");
		TagBackgroundIcon.SetPosition(33, 40).SetSize(38, 38);
		TagBackgroundIcons.AddItem(TagBackgroundIcon);
	}
	else if (`GETMCMVAR(ABILITY_TREE_PLANNER_MODE) == 2)
	{
		TagBackgroundIcon = AbilityIcons[Index].Spawn(class'UIImage', AbilityIcons[Index]).InitImage(name("Tag_" $ Index), "img:///UILibrary_CPS.UI.TagBorder");
		TagBackgroundIcon.SetPosition(33, 40).SetSize(38, 38);
		TagBackgroundIcons.AddItem(TagBackgroundIcon);

		TagText = TagBackgroundIcon.Spawn(class'UIText', TagBackgroundIcon).InitText(name("Tag_" $ Index));

		SetTagText(TagText, string(iTag), TagBackgroundIcon);
		// Reposition the text based on whether it's double digits or not.
		if (iTag > 9)
		{
			TagText.Y += 6;
		}
		else
		{
			TagText.Y += 4;
			TagText.X -= 1;
		}
		TagText.RealizeLocation();

		TagTexts.AddItem(TagText);
	}	
}

function RemoveAbilityTag(const int Index)
{
	local CPS_UIArmory_PromotionHeroColumn	Column;
	local CPS_UIArmory_PromotionHero		PromotionScreen;
	local array<AbilityTagStruct>			AbilityTags;
	local AbilityTagStruct					AbilityTag;
	local name								AbilityName;
	local UnitValue							UV;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	local int i;

	PromotionScreen = CPS_UIArmory_PromotionHero(Screen);
	if (PromotionScreen == none)
		return;

	// Exit early if there's no tag for this ability.
	UnitState = PromotionScreen.GetUnit();
	if (!UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityNames[Index]), UV))
	{
		return;
	}

	// 1. Remove the tag.
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tag Ability For Unit");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	UnitState.ClearUnitValue(name(AbilityTagPrefix $ AbilityNames[Index]));
	
	// 2. Build an array of all other ability tags currently present on the unit.
	for (i = 0; i < PromotionScreen.Columns.Length; i++)
	{
		Column = CPS_UIArmory_PromotionHeroColumn(PromotionScreen.Columns[i]);
		if (Column == none)
			return;
					
		foreach Column.AbilityNames(AbilityName)
		{
			if (UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityName), UV))
			{
				AbilityTag.AbilityName = AbilityName;
				AbilityTag.iTag = UV.fValue;
				AbilityTags.AddItem(AbilityTag);
			}
		}
	}

	// 3. Sort in order of ascending tag values
	AbilityTags.Sort(SortAbilityTags);

	// 4. Reset tags to start from 1 and increase by one.
	for (i = 0; i < AbilityTags.Length; i++)
	{
		AbilityTags[i].iTag = i + 1;
	}

	// 5. Set new tag values.
	foreach AbilityTags(AbilityTag)
	{
		UnitState.SetUnitFloatValue(name(AbilityTagPrefix $ AbilityTag.AbilityName), AbilityTag.iTag, eCleanup_Never);
	}
	`GAMERULES.SubmitGameState(NewGameState);

	// 6. Hide tag in UI
	AS_HideAbilityTag(Index);

	// 7. Update UI text of all tags to account for new values.
	for (i = 0; i < PromotionScreen.Columns.Length; i++)
	{
		Column = CPS_UIArmory_PromotionHeroColumn(PromotionScreen.Columns[i]);		
		Column.UpdateAllTagTexts();
	}	
}

function AS_HideAbilityTag(int Index)
{
	local UIImage TagBackgroundIcon;

	foreach TagBackgroundIcons(TagBackgroundIcon)
	{
		if (TagBackgroundIcon.MCName == name("Tag_" $ Index))
		{
			TagBackgroundIcon.Hide();
		}
	}
}

simulated function int SortAbilityTags(AbilityTagStruct TagA, AbilityTagStruct TagB)
{
	if (TagA.iTag < TagB.iTag)
		return 1;

	if (TagA.iTag > TagB.iTag)
		return -1;

	return 0;
}

function UpdateAllTagTexts()
{
	local UIText	TagText;
	local int		iTag;
	local int		i;
	local int		TagIdx;

	for (i = 0; i < AbilityNames.Length; i++)
	{
		iTag = GetAbilityTag(AbilityNames[i]);
		if (iTag > 0)
		{
			foreach TagTexts(TagText, TagIdx)
			{
				if (TagText.MCName == name("Tag_" $ i))
				{
					SetTagText(TagText, string(iTag), TagBackgroundIcons[TagIdx]);
					break;
				}
			}
		}
	}
}

function int GetAbilityTag(const name TemplateName)
{
	local XComGameState_Unit UnitState;
	local UnitValue UV;

	UnitState = UIArmory_PromotionHero(Screen).GetUnit();

	if (UnitState.GetUnitValue(name(AbilityTagPrefix $ TemplateName), UV))
	{
		return UV.fValue;
	}

	return -1;
}

function SetTagText(out UIText TagText, string strText, UIPanel BackgroundIconParentPanel)
{
	if (Len(strText) > 1)
	{
		// Smaller font size for double digits
		TagText.SetCenteredText(class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 20), BackgroundIconParentPanel);
	}
	else
	{
		TagText.SetCenteredText(class'UIUtilities_Text'.static.GetColoredText(strText, eUIState_Normal, 24), BackgroundIconParentPanel);
	}
}
// End Issue #53