class CPS_UIArmory_PromotionHeroColumn extends UIArmory_PromotionHeroColumn;

var int Offset;

var array<int> LockedAbilityIndices; // Issue #42

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
	
	PromotionScreen = UIArmory_PromotionHero(Screen);

	if( PromotionScreen.OwnsAbility(AbilityNames[idx]) )
		OnInfoButtonMouseEvent(InfoButtons[idx], class'UIUtilities_Input'.const.FXS_L_MOUSE_UP);
	else if (bEligibleForPurchase && PromotionScreen.CanPurchaseAbility(Rank, idx + Offset, AbilityNames[idx]))
		PromotionScreen.ConfirmAbilitySelection(Rank, idx);
	else if (!PromotionScreen.IsAbilityLocked(Rank))
		OnInfoButtonMouseEvent(InfoButtons[idx], class'UIUtilities_Input'.const.FXS_L_MOUSE_UP);
	else
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
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
}

function bool IsAbilityIconLocked(const int Index)
{
	return LockedAbilityIndices.Find(Index) != INDEX_NONE;
}
// End Issue #42