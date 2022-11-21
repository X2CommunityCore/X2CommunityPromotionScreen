class CPS_UIArmory_PromotionHeroColumn extends UIArmory_PromotionHeroColumn;

var int Offset;

var array<int> LockedAbilityIndices; // Issue #42

// Start Issue #53 - These are parallel arrays.
// Stores references to ability tag icons. Each perk in the column can potentially have its own tag icon,
// which can be visible or hidden depending on if the ability is currently tagged or not.
var array<CPS_UIAbilityTag>	AbilityTagIcons;
// Unit Value prefix.
const AbilityTagPrefix = "CPS_AbilityTag_";
struct AbilityTagStruct
{
	var name AbilityName;
	var int iTagText;
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

// Start Issue #57
//
// Add some handling for left-stick press so that it will always pop
// up the ability information panel if the ability is not hidden.
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_L3:
			if (!IsAbilityIconLocked(m_iPanelIndex + CPS_UIArmory_PromotionHero(Screen).Position))
			{
				OnAbilityInfoClicked(InfoButtons[m_iPanelIndex]);
				bHandled = true;
			}
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}
// End Issue #57

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
	// Hide the tag icon if it is present on an ability that's not supposed to be tagged,
	// this can happen when scrolling.
	AS_SyncAbilityTagIcon(Index);
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
/// Then the player can switch the tag system between three modes:
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
/// and the value is the order, though it is used only in the Advanced mode.
///
/// Each perk column stores an array of created ability tag icons.

// Called when the user clicks on an ability. Makes state changes.
function ToggleAbilityTagForUnit(const int Index, XComGameState_Unit UnitState)
{
	if (IsAbilityTaggedForUnit(Index, UnitState))
	{
		RemoveAbilityTag(Index);
		// clear new unit value ? here?
	}
	else
	{
		SetAbilityTag(Index);
		// set new unit value here?
		// this index is the same index that would be sent to confirm ability selection as branch
		// it adds position to its value however, but position usually stays as 0 unless setPosition changes that specific var
		// would also need to clear this same value on unit purchase
	}
}

private function bool IsAbilityTaggedForUnit(const int Index, XComGameState_Unit UnitState)
{
	local UnitValue	UV;

	return UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityNames[Index]), UV);
}

// Called when the user opens or scrolls the promotion screen. Pure UI, makes no state changes.
private function AS_SyncAbilityTagIcon(int Index)
{
	local int iTagText;

	// Hide ability tag if it's not visible anymore,
	// presumably because MCM setting to show unreached perks has been disabled.
	if (IsAbilityIconLocked(Index))
	{
		AS_HideAbilityTag(Index);
		return;
	}

	iTagText = GetAbilityTagText(AbilityNames[Index]);
	if (iTagText == -1)
	{
		AS_HideAbilityTag(Index);
	}
	else
	{ 
		AS_DrawAbilityTag(Index, iTagText);
	}
}

final function SetAbilityTag(const int Index)
{
	local int					iNumAbilityTags;
	local XComGameState_Unit	UnitState;
	local XComGameState			NewGameState;
	local int					iTagText;
	
	UnitState = GetUnit();
	iNumAbilityTags = GetNumAbilityTags(UnitState);
	iTagText = iNumAbilityTags + 1;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tag Ability For Unit");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

	// Unit value has two purposes:
	// 1. Track if this ability is tagged or not.
	// 2. In advanced tagging mode, track the order in which abilities have been tagged, 
	// the displayed tag text should correspond to the value of the Unit Value.
	UnitState.SetUnitFloatValue(name(AbilityTagPrefix $ AbilityNames[Index]), iTagText, eCleanup_Never);

	`GAMERULES.SubmitGameState(NewGameState);

	AS_DrawAbilityTag(Index, iTagText);
}

private function int GetNumAbilityTags(XComGameState_Unit UnitState)
{
	local UnitValue					UV;
	local int						iNumAbilityTags;
	local SoldierRankAbilities		AbilityTree;
	local SoldierClassAbilityType	AbilityType;

	foreach UnitState.AbilityTree(AbilityTree)
	{
		foreach AbilityTree.Abilities(AbilityType)
		{
			if (UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityType.AbilityName), UV))
			{
				iNumAbilityTags++;
			}
		}
	}
	return iNumAbilityTags;
}

private function AS_DrawAbilityTag(int Index, int iTagText)
{
	local CPS_UIAbilityTag AbilityTagIcon;

	// Check if the icon already exists and show it rather than create a new icon every time.
	foreach AbilityTagIcons(AbilityTagIcon)
	{
		if (AbilityTagIcon.iRankIndex == Index)
		{
			AbilityTagIcon.AbilityName = AbilityNames[Index];
			AbilityTagIcon.Show();
			AbilityTagIcon.MaybeSetTagNumberText(iTagText);
			return;
		}
	}

	// If we're still here, then there's no tag icon for this spot on the perk column yet, so create one.
	AbilityTagIcon = AbilityIcons[Index].Spawn(class'CPS_UIAbilityTag', AbilityIcons[Index]).InitAbilityTag(AbilityNames[Index]);
	AbilityTagIcon.MaybeSetTagNumberText(iTagText);
	AbilityTagIcon.iRankIndex = Index;
	AbilityTagIcons.AddItem(AbilityTagIcon);
}

final function RemoveAbilityTag(const int Index)
{
	local array<AbilityTagStruct>	AbilityTags;
	local AbilityTagStruct			AbilityTag;
	local UnitValue					UV;
	local XComGameState_Unit		UnitState;
	local XComGameState				NewGameState;
	local SoldierRankAbilities		AbilityTree;
	local SoldierClassAbilityType	AbilityType;
	local int i;

	// 1. Remove the tag.
	UnitState = GetUnit();
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tag Ability For Unit");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	UnitState.ClearUnitValue(name(AbilityTagPrefix $ AbilityNames[Index]));
	
	// 2. Build an array of all other ability tags currently present on the unit.
	foreach UnitState.AbilityTree(AbilityTree)
	{
		foreach AbilityTree.Abilities(AbilityType)
		{
			if (UnitState.GetUnitValue(name(AbilityTagPrefix $ AbilityType.AbilityName), UV))
			{
				AbilityTag.AbilityName = AbilityType.AbilityName;
				AbilityTag.iTagText = UV.fValue;
				AbilityTags.AddItem(AbilityTag);
			}
		}
	}

	// 3. Sort in order of ascending tag values
	AbilityTags.Sort(SortAbilityTags);

	// 4. Reset tags to start from 1 and increase by one.
	for (i = 0; i < AbilityTags.Length; i++)
	{
		AbilityTags[i].iTagText = i + 1;
	}

	// 5. Set new tag values.
	foreach AbilityTags(AbilityTag)
	{
		UnitState.SetUnitFloatValue(name(AbilityTagPrefix $ AbilityTag.AbilityName), AbilityTag.iTagText, eCleanup_Never);
	}
	`GAMERULES.SubmitGameState(NewGameState);

	// 6. Hide tag in UI
	AS_HideAbilityTag(Index);

	// 7. Update UI text of all tags to account for new values.
	UpdateAllTagTexts();
}

private function AS_HideAbilityTag(int Index)
{
	local CPS_UIAbilityTag AbilityTagIcon;

	foreach AbilityTagIcons(AbilityTagIcon)
	{
		if (AbilityTagIcon.iRankIndex == Index)
		{
			AbilityTagIcon.Hide();
			return;
		}
	}
}

private simulated function int SortAbilityTags(AbilityTagStruct TagA, AbilityTagStruct TagB)
{
	if (TagA.iTagText < TagB.iTagText)
		return 1;

	if (TagA.iTagText > TagB.iTagText)
		return -1;

	return 0;
}

private function UpdateAllTagTexts()
{
	local CPS_UIArmory_PromotionHero		PromotionScreen;
	local CPS_UIArmory_PromotionHeroColumn	Column;
	local CPS_UIAbilityTag					AbilityTagIcon;
	local int								iTagText;
	local int i;
	
	PromotionScreen = CPS_UIArmory_PromotionHero(Screen);

	for (i = 0; i < PromotionScreen.Columns.Length; i++)
	{
		Column = CPS_UIArmory_PromotionHeroColumn(PromotionScreen.Columns[i]);
		foreach Column.AbilityTagIcons(AbilityTagIcon)
		{
			iTagText = GetAbilityTagText(AbilityTagIcon.AbilityName);
			if (iTagText != -1)
			{
				AbilityTagIcon.MaybeSetTagNumberText(iTagText);
			}
		}
	}
}

private function int GetAbilityTagText(const name TemplateName)
{
	local XComGameState_Unit UnitState;
	local UnitValue UV;

	UnitState = GetUnit();

	if (UnitState.GetUnitValue(name(AbilityTagPrefix $ TemplateName), UV))
	{
		return UV.fValue;
	}

	return -1;
}

private function XComGameState_Unit GetUnit()
{
	return UIArmory_PromotionHero(Screen).GetUnit();
}
// End Issue #53
