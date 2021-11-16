//---------------------------------------------------------------------------------------
//  FILE:    CPS_UIArmory_PromotionHero.uc
//  AUTHORS: Tzarnal - MoonWolf, Peter Ledbrook, Iridar
//  PURPOSE: Replaces promotion screen for regular soldiers and faction heroes with a
//           faction hero-style promotion screen with expanded functionality and 
//			 customizability.
//---------------------------------------------------------------------------------------
class CPS_UIArmory_PromotionHero extends UIArmory_PromotionHero config(PromotionUIMod);

var UIScrollbar	Scrollbar;

var config bool bLog;

// Vars for Issue #7
enum EReasonLocked
{
	eReason_LacksPrerequisites,
	eReason_NoClassPerkPurchased,
	eReason_NoTrainingCenter,
	eReason_NotEnoughAP,
	eReason_NotHighEnoughRank
};
var localized array<string> arr_strLocReasonsLocked;
// End Issue #7

// Position is the number by which we offset all ability indices.
// 0 <= Position <= MaxPosition
var int Position, MaxPosition;

var int AdjustXOffset;

var localized string m_strMutuallyExclusive;

// Start Issue #24
// Cached Soldier Info
var bool					bHasBrigadierRank;
var bool					bAsResistanceHero;	// Whether this unit uses the Faction Hero promotion scheme, where they have to pay AP for each ability.
var int						AbilitiesPerRank;	// Number of ability rows in soldier class template, not counting the "XCOM" row for regular soldiers. 
var X2SoldierClassTemplate	ClassTemplate;
var bool					bCanSpendAP;
// End Issue #24


struct CPSAbilityMetaInfo
{
	var name TemplateName;
	var int iRank;
	var int iRow;
	var bool bPowerfulAbility;
	var bool bColonelRankAbility;
	var bool bClassAbility;
	var bool bUnitMeetsAbilityPrerequisites;
	var bool bUnitHasPurchasedClassPerkAtRank;
	var bool bUnitMeetsRankRequirement;
	var bool bUnitCanSpendAP;
	var bool bAsResistanceHero;
};

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

simulated function OnInit()
{
	super.OnInit();

	`LOG(self.Class.name @ GetFuncName(), bLog, 'PromotionScreen');

	if (bHasBrigadierRank)
	{
		ResizeScreenForBrigadierRank();
		AnimatIn();
	}
	else
	{
		MC.FunctionVoid("AnimateIn");
	}

	Show();
}

//Override functions
simulated function InitPromotion(StateObjectReference UnitRef, optional bool bInstantTransition)
{
	local XComGameState_Unit Unit; // bsg-nlong (1.25.17): Used to determine which column we should start highlighting

	`LOG(self.Class.name @ GetFuncName(), bLog, 'PromotionScreen');

	Position = 0;

	Hide();

	// If the AfterAction screen is running, let it position the camera
	AfterActionScreen = UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction'));
	if (AfterActionScreen != none)
	{
		bAfterActionPromotion = true;
		PawnLocationTag = AfterActionScreen.GetPawnLocationTag(UnitRef, "Blueprint_AfterAction_HeroPromote");
		CameraTag = GetPromotionBlueprintTag(UnitRef);
		DisplayTag = name(GetPromotionBlueprintTag(UnitRef));
	}
	else
	{
		CameraTag = string(default.DisplayTag);
		DisplayTag = default.DisplayTag;
	}

	

	// Don't show nav help during tutorial, or during the After Action sequence.
	bUseNavHelp = class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M2_WelcomeToArmory') || Movie.Pres.ScreenStack.IsInStack(class'UIAfterAction');

	super.InitArmory(UnitRef, , , , , , bInstantTransition);

	CacheSoldierInfo(); // Issue #24

	InitColumns();

	PopulateData();

	//Only set position and animate in the scrollbar once after data population. Prevents scrollbar flicker on scrolling.
	if (Scrollbar != none)
	{
		Scrollbar.SetPosition(1350, 310); // Strangely, this works for both brigadiers and regular soldiers.
		
		Scrollbar.MC.SetNum("_alpha", 0);
		Scrollbar.AddTweenBetween("_alpha", 0, 100, 0.2f, 0.3f);
	}
	DisableNavigation(); // bsg-nlong (1.25.17): This and the column panel will have to use manual naviation, so we'll disable the navigation here

	// bsg-nlong (1.25.17): Focus a column so the screen loads with an ability highlighted
	if( `ISCONTROLLERACTIVE )
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
		if( Unit != none )
		{
			m_iCurrentlySelectedColumn = m_iCurrentlySelectedColumn;
		}
		else
		{
			m_iCurrentlySelectedColumn = 0;
		}

		Columns[m_iCurrentlySelectedColumn].OnReceiveFocus();
	}
	// bsg-nlong (1.25.17): end
}


simulated function SetUnitReference(StateObjectReference NewUnitRef)
{
	super.SetUnitReference(NewUnitRef);
	// Reset these values when we cycle to another soldier
	Position = 0;
	MaxPosition = 0;
	CacheSoldierInfo(); // Issue #24
}

function CacheSoldierInfo()
{
	local XComGameState_Unit Unit;

	Unit = GetUnit();

	ClassTemplate = Unit.GetSoldierClassTemplate();	
	bHasBrigadierRank = Unit.AbilityTree.Length > 7;
	CacheAbilitiesPerRank();
	bCanSpendAP = CanSpendAP();
	bAsResistanceHero = IsUnitResistanceHero(Unit);
}

simulated function PopulateData()
{
	local XComGameState_Unit Unit;
	local CPS_UIArmory_PromotionHeroColumn Column;
	local string HeaderString, rankIcon, classIcon;
	local int iRank, maxRank;
	local bool bHighlightColumn;
	local Vector ZeroVec;
	local Rotator UseRot;
	local XComUnitPawn UnitPawn;
	local XComGameState_ResistanceFaction FactionState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState NewGameState;

	Unit = GetUnit();

	FactionState = Unit.GetResistanceFaction();
	
	rankIcon = Unit.GetSoldierRankIcon(Unit.GetRank());
	classIcon = Unit.GetSoldierClassIcon();

	HeaderString = m_strAbilityHeader;
	if (Unit.GetRank() != 1 && Unit.HasAvailablePerksToAssign())
	{
		HeaderString = m_strSelectAbility;
	}

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	if (Unit.IsResistanceHero() && !XComHQ.bHasSeenHeroPromotionScreen)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Opened Hero Promotion Screen");
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		XComHQ.bHasSeenHeroPromotionScreen = true;
		`XEVENTMGR.TriggerEvent('OnHeroPromotionScreen', , , NewGameState);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else if (Unit.GetRank() >= 2 && Unit.ComInt >= eComInt_Gifted && !`GETMCMVAR(DISABLE_COMINT_POPUPS))
	{
		// Check to see if Unit has high combat intelligence, display tutorial popup if so
		`HQPRES.UICombatIntelligenceIntro(Unit.GetReference());
	}

	if (ActorPawn == none || (Unit.GetRank() == 1 && bAfterActionPromotion)) //This condition is TRUE when in the after action report, and we need to rank someone up to squaddie
	{
		//Get the current pawn so we can extract its rotation
		UnitPawn = Movie.Pres.GetUIPawnMgr().RequestPawnByID(AfterActionScreen, UnitReference.ObjectID, ZeroVec, UseRot);
		UseRot = UnitPawn.Rotation;

		//Free the existing pawn, and then create the ranked up pawn. This may not be strictly necessary since most of the differences between the classes are in their equipment. However, it is easy to foresee
		//having class specific soldier content and this covers that possibility
		Movie.Pres.GetUIPawnMgr().ReleasePawn(AfterActionScreen, UnitReference.ObjectID);
		CreateSoldierPawn(UseRot);

		if (bAfterActionPromotion && !Unit.bCaptured)
		{
			//Let the pawn manager know that the after action report is referencing this pawn too			
			UnitPawn = Movie.Pres.GetUIPawnMgr().RequestPawnByID(AfterActionScreen, UnitReference.ObjectID, ZeroVec, UseRot);
			AfterActionScreen.SetPawn(UnitReference, UnitPawn);
		}
	}

	// Display the "soldier has a new class" popup if required (issue #1)
	if (Unit.bNeedsNewClassPopup && !`GETMCMVAR(DISABLE_NEWCLASS_POPUPS))
	{
		`HQPRES.UIClassEarned(Unit.GetReference());
		Unit.bNeedsNewClassPopup = false;  //Prevent from queueing up more of these popups on toggling soldiers.
	}

	AS_SetRank(rankIcon);
	AS_SetClass(classIcon);

	if (FactionState != none)
	{
		AS_SetFaction(FactionState.GetFactionIcon());
		AS_SetHeaderData(Caps(FactionState.GetFactionTitle()), Caps(Unit.GetName(eNameType_FullNick)), HeaderString, m_strSharedAPLabel, m_strSoldierAPLabel);
	}
	else
	{
		AS_SetHeaderData("", Caps(Unit.GetName(eNameType_FullNick)), HeaderString, m_strSharedAPLabel, m_strSoldierAPLabel);
	}

	AS_SetAPData(GetSharedAbilityPoints(), Unit.AbilityPoints);
	AS_SetCombatIntelData(Unit.GetCombatIntelligenceLabel());
	
	AS_SetPathLabels(
		m_strBranchesLabel,
		GetLocalizedAbilityTreeTitle(0 + Position),
		GetLocalizedAbilityTreeTitle(1 + Position),
		GetLocalizedAbilityTreeTitle(2 + Position),
		GetLocalizedAbilityTreeTitle(3 + Position)
	);

	// Fix None-context
	maxRank = Columns.Length; //class'X2ExperienceConfig'.static.GetMaxRank();
	for (iRank = 0; iRank < maxRank; iRank++)
	{
		Column = CPS_UIArmory_PromotionHeroColumn(Columns[iRank]);		
		Column.Offset = Position;

		// Start Issue #18 - show "new rank" banner only if the player has an ability to choose and can afford it.
		//bHasColumnAbility = UpdateAbilityIcons_Override(Column);
		//bHighlightColumn = (!bHasColumnAbility && (iRank+1) == Unit.GetRank());
		UpdateAbilityIcons_Override(Column);
		bHighlightColumn = Unit.HasAvailablePerksToAssign() && (iRank+1) == Unit.GetRank(); 
		// End Issue #18

		Column.AS_SetData(bHighlightColumn, m_strNewRank, Unit.GetSoldierRankIcon(iRank+1), Caps(Unit.GetSoldierRankName(iRank+1)));
	}
	
	RealizeScrollbar();
	HidePreview();
}

// Start Issue #36
//
// We override ChangeSelectedColumn() so that we can inject better behavior
// for controller navigation between abilities.
simulated function ChangeSelectedColumn(int oldIndex, int newIndex)
{
	local int i, NewColumnAbilityIndex, NewColumnAbilities, OldColumnAbilityIndex;
	local UIArmory_PromotionHeroColumn OldColumn, NewColumn;

	i = 0;
	OldColumn = Columns[oldIndex];
	NewColumn = Columns[newIndex];
	NewColumnAbilities = NewColumn.AbilityIcons.Length;

	if (`ISCONTROLLERACTIVE && (OldColumn != none) && (NewColumn != none))
	{
		OldColumnAbilityIndex = OldColumn.m_iPanelIndex;
		// KDM : When selecting a new column, we want to preserve the
		// currently selected row whenever possible; this can not occur
		// when the old column's selected row is below the total number
		// of rows in the new column.
		NewColumnAbilityIndex = (OldColumnAbilityIndex < NewColumnAbilities) ? OldColumnAbilityIndex : (NewColumnAbilities - 1);

		// KDM : We are only interested in rows with a visible ability
		// icon; search for one in an upwards, looping, manner.
		while ((!NewColumn.AbilityIcons[NewColumnAbilityIndex].bIsVisible) && (i < NewColumnAbilities))
		{
			NewColumnAbilityIndex--;
			if (NewColumnAbilityIndex < 0)
			{
				NewColumnAbilityIndex = NewColumnAbilities - 1;
			}

			i++;
		}

		// KDM : When a column receives focus, it selects the ability
		// icon at m_iPanelIndex; therefore, we need to set this value
		// before calling super.ChangeSelectedColumn().
		NewColumn.m_iPanelIndex = NewColumnAbilityIndex;
	}

	super(UIArmory_PromotionHero).ChangeSelectedColumn(oldIndex, newIndex);
}
// End Issue #36

function string GetLocalizedAbilityTreeTitle(const int iRowIndex)
{
	local string strAbilityTreeTitle;
	local XComLWTuple Tuple;

	if (ClassTemplate.AbilityTreeTitles.Length > iRowIndex)
	{
		strAbilityTreeTitle = ClassTemplate.AbilityTreeTitles[iRowIndex];
	}
	else if (iRowIndex == 0 && strAbilityTreeTitle == "")
	{
		strAbilityTreeTitle = ClassTemplate.LeftAbilityTreeTitle;
	}
	else if (iRowIndex == 1 && strAbilityTreeTitle == "")
	{
		strAbilityTreeTitle = ClassTemplate.RightAbilityTreeTitle;
	}

	// Start Issue #22
	/// Mods can listen to 'OverrideLocalizedAbilityTreeTitle' event to use their own logic 
	/// to set localized names for ability trees. Typical use case would be adding a localized name
	/// for a new row of abilities that were dynamically inserted into unit's ability tree.
	/// iRowIndex begins at 0, starting with the top row, which corresponds to left ability column
	/// on the "old" promotion screen.
	///
	/// ```event
	/// EventID: OverrideLocalizedAbilityTreeTitle,
	/// EventData: [in int iRowIndex, inout string strAbilityTreeTitle],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	/// ```
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'OverrideLocalizedAbilityTreeTitle';
	Tuple.Data.Add(2);
	Tuple.Data[0].kind = XComLWTVInt;
	Tuple.Data[0].i = iRowIndex;
	Tuple.Data[1].kind = XComLWTVString;
	Tuple.Data[1].s = strAbilityTreeTitle;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, GetUnit());

	return Tuple.Data[1].s;
	// End Issue #22
}

function HidePreview()
{
	// Start Issue #106
	local XComGameState_Unit Unit;
	local string ClassName, ClassDesc;

	Unit = GetUnit();

	ClassName = Caps(Unit.GetSoldierClassDisplayName());
	ClassDesc = Unit.GetSoldierClassSummary();
	// End Issue #106

	// By default when not previewing an ability, display class data
	AS_SetDescriptionData("", ClassName, ClassDesc, "", "", "", "");
}

function bool UpdateAbilityIcons_Override(out CPS_UIArmory_PromotionHeroColumn Column)
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate, NextAbilityTemplate;
	local array<SoldierClassAbilityType> AbilityTree, NextRankTree;
	local XComGameState_Unit Unit;
	local UIPromotionButtonState ButtonState;
	local int iAbility;
	local bool bHasColumnAbility, bConnectToNextAbility;
	local string AbilityName, AbilityIcon, BGColor, FGColor;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	Unit = GetUnit();

	// Start issue #74 - do not call GetRankAbilities with higher ranks than what exists on the unit.
	// AbilityTree is left empty and no abilities will be added to the column for ranks higher than the unit has.
	// This also avoids the associated rescreen error from misuse of GetRankAbilities().
	if (Column.Rank < Unit.AbilityTree.Length)
	{
		AbilityTree = Unit.GetRankAbilities(Column.Rank);
	}
	// End Issue #74

	// MaxPosition is the maximum value for Position
	MaxPosition = Max(AbilityTree.Length - NUM_ABILITIES_PER_COLUMN, MaxPosition);

	Column.AbilityNames.Length = 0;	

	for (iAbility = Position; iAbility < Position + NUM_ABILITIES_PER_COLUMN; iAbility++)
	{
		if (iAbility < AbilityTree.Length)
		{
			AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[iAbility].AbilityName);
		}
		else
		{
			AbilityTemplate = none;
		}
		
		if (AbilityTemplate != none)
		{
			if (Column.AbilityNames.Find(AbilityTemplate.DataName) == INDEX_NONE)
			{
				Column.AbilityNames.AddItem(AbilityTemplate.DataName);
			}

			// The unit is not yet at the rank needed for this column
			if (!`GETMCMVAR(SHOW_UNREACHED_PERKS) && Column.Rank >= Unit.GetRank())
			{
				AbilityName = class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedTitle, eUIState_Disabled);
				AbilityIcon = class'UIUtilities_Image'.const.UnknownAbilityIcon;
				ButtonState = eUIPromotionState_Locked;
				FGColor = class'UIUtilities_Colors'.const.BLACK_HTML_COLOR;
				BGColor = class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR;
				bConnectToNextAbility = false; // Do not display prereqs for abilities which aren't available yet
			}
			else // The ability could be purchased
			{
				AbilityName = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(AbilityTemplate.LocFriendlyName);
				AbilityIcon = AbilityTemplate.IconImage;

				if (Unit.HasSoldierAbility(AbilityTemplate.DataName))
				{
					// The ability has been purchased
					ButtonState = eUIPromotionState_Equipped;
					FGColor = class'UIUtilities_Colors'.const.NORMAL_HTML_COLOR;
					BGColor = class'UIUtilities_Colors'.const.BLACK_HTML_COLOR;
					bHasColumnAbility = true;
				}
				else if(CanPurchaseAbility(Column.Rank, iAbility, AbilityTemplate.DataName))
				{
					// The ability is unlocked and unpurchased, and can be afforded
					ButtonState = eUIPromotionState_Normal;
					FGColor = class'UIUtilities_Colors'.const.PERK_HTML_COLOR;
					BGColor = class'UIUtilities_Colors'.const.BLACK_HTML_COLOR;
				}
				else
				{
					// The ability is unlocked and unpurchased, but cannot be afforded
					ButtonState = eUIPromotionState_Normal;
					FGColor = class'UIUtilities_Colors'.const.BLACK_HTML_COLOR;
					BGColor = class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR;
				}
				
				// Look ahead to the next rank and check to see if the current ability is a prereq for the next one
				// If so, turn on the connection arrow between them
				//if (Column.Rank < (class'X2ExperienceConfig'.static.GetMaxRank() - 2) && Unit.GetRank() > (Column.Rank + 1))
				//if (Column.Rank < (Columns.Length - 2) && (Unit.GetRank() > (Column.Rank + 1) || `GETMCMVAR(SHOW_UNREACHED_PERKS))) // Issue #61 - always connect abilities if "Show unreached perks" is enabled.
				if (Column.Rank < (Unit.AbilityTree.Length - 1) && (Unit.GetRank() > (Column.Rank + 1) || `GETMCMVAR(SHOW_UNREACHED_PERKS))) // Issue #74 - do not check for prereqs beyond the units ability tree.
				{
					bConnectToNextAbility = false;
					NextRankTree = Unit.GetRankAbilities(Column.Rank + 1);

					if (iAbility < NextRankTree.Length)
					{
						NextAbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(NextRankTree[iAbility].AbilityName);
						if (NextAbilityTemplate != none && NextAbilityTemplate.PrerequisiteAbilities.Find(AbilityTemplate.DataName) != INDEX_NONE)
						{
							bConnectToNextAbility = true;
						}
					}
				}

				Column.SetAvailable(true);
			}

			Column.AS_SetIconState(iAbility - Position, false, AbilityIcon, AbilityName, ButtonState, FGColor, BGColor, bConnectToNextAbility);
		}
		else
		{
			Column.AbilityNames.AddItem(''); // Make sure we add empty spots to the name array for getting ability info
			Column.AbilityIcons[iAbility - Position].Hide();
			Column.InfoButtons[iAbility - Position].Hide();
			Column.MC.ChildSetBool("EquippedAbility" $ (iAbility - Position), "_visible", false);
		}
	}

	// bsg-nlong (1.25.17): Select the first available/visible ability in the column
	// NPSBDP: It is possible for ranks to have no abilities if we offset them in a way that hides all ability icons
	// So only do this if we have visible ability icons
	while(`ISCONTROLLERACTIVE && !AllAbilityIconsHidden(Column) && !Column.AbilityIcons[Column.m_iPanelIndex].bIsVisible)
	{
		Column.m_iPanelIndex +=1;
		if( Column.m_iPanelIndex >= Column.AbilityIcons.Length )
		{
			Column.m_iPanelIndex = 0;
		}
	}
	// bsg-nlong (1.25.17): end

	return bHasColumnAbility;
}

simulated function bool AllAbilityIconsHidden(UIArmory_PromotionHeroColumn Column)
{
	local int i;
	for (i = 0; i < Column.AbilityIcons.Length; i++)
	{
		if (Column.AbilityIcons[i].bIsVisible)
		{
			return false;
		}
	}
	return true;
}

// Start Issue #38
// KDM : UIArmory_Promotion.UpdateNavHelp() has to be overridden, in order to
// change individual help item's placement, since there is no way to remove
// individual components of the navigation help system.
simulated function UpdateNavHelp()
{
	local int i;
	local string PrevKey, NextKey;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit Unit;
	local XGParamTag LocTag;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));

	if (!bIsFocused)
	{
		return;
	}

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
	if (NavHelp == none)
		return; // Issue #28 - prevent 'accessed none' log warnings.

	NavHelp.ClearButtonHelp();

	if (UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction')) != none)
	{
		NavHelp.AddBackButton(OnCancel);

		if (!`ISCONTROLLERACTIVE)
		{
			if (!XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID)).ShowPromoteIcon())
			{
				NavHelp.AddContinueButton(OnCancel);
			}
		}

		if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M7_WelcomeToGeoscape'))
		{
			NavHelp.AddLeftHelp(m_strMakePosterTitle, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_X_SQUARE, MakePosterButton);
		}

		if (`ISCONTROLLERACTIVE)
		{
			NavHelp.AddCenterHelp(m_strInfo, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_LSCLICK_L3);
			
			if (IsAllowedToCycleSoldiers() && class'UIUtilities_Strategy'.static.HasSoldiersToCycleThrough(UnitReference, CanCycleTo))
			{
				NavHelp.AddCenterHelp(m_strTabNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1); // bsg-jrebar (5/23/17): Removing inlined buttons
			}

			NavHelp.AddCenterHelp(m_strRotateNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSTICK); // bsg-jrebar (5/23/17): Removing inlined buttons
		}
	}
	else
	{
		NavHelp.AddBackButton(OnCancel);

		if (XComHQPresentationLayer(Movie.Pres) != none)
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_PrevUnit);
			PrevKey = `XEXPAND.ExpandString(PrevSoldierKey);
			LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_NextUnit);
			NextKey = `XEXPAND.ExpandString(NextSoldierKey);

			if (class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M7_WelcomeToGeoscape') != eObjectiveState_InProgress &&
				RemoveMenuEvent == '' && NavigationBackEvent == '' && !`ScreenStack.IsInStack(class'UISquadSelect'))
			{
				NavHelp.AddGeoscapeButton();
			}

			if (Movie.IsMouseActive() && IsAllowedToCycleSoldiers() && class'UIUtilities_Strategy'.static.HasSoldiersToCycleThrough(UnitReference, CanCycleTo))
			{
				NavHelp.SetButtonType("XComButtonIconPC");
				i = eButtonIconPC_Prev_Soldier;
				NavHelp.AddCenterHelp( string(i), "", PrevSoldier, false, PrevKey);
				i = eButtonIconPC_Next_Soldier; 
				NavHelp.AddCenterHelp( string(i), "", NextSoldier, false, NextKey);
				NavHelp.SetButtonType("");
			}
		}

		if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M7_WelcomeToGeoscape'))
		{
			if (`ISCONTROLLERACTIVE)
			{
				NavHelp.AddLeftHelp(m_strMakePosterTitle, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_X_SQUARE, MakePosterButton);
			}
			else
			{
				NavHelp.AddLeftHelp(m_strMakePosterTitle, , MakePosterButton);
			}
		}

		if (`ISCONTROLLERACTIVE)
		{
			// KDM : Add the 'show abilities' tip to the left help panel so it
			// doesn't overlap with the cycle soldiers tip.
			NavHelp.AddLeftHelp(m_strInfo, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LSCLICK_L3);
			
			if (IsAllowedToCycleSoldiers() && class'UIUtilities_Strategy'.static.HasSoldiersToCycleThrough(UnitReference, CanCycleTo))
			{
				NavHelp.AddCenterHelp(m_strTabNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1); // bsg-jrebar (5/23/17): Removing inlined buttons
			}

			NavHelp.AddCenterHelp(m_strRotateNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSTICK); // bsg-jrebar (5/23/17): Removing inlined buttons
		}

		XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();

		if (XComHQ.HasFacilityByName('RecoveryCenter') && IsAllowedToCycleSoldiers() && !`ScreenStack.IsInStack(class'UIFacility_TrainingCenter')
			&& !`ScreenStack.IsInStack(class'UISquadSelect') && !`ScreenStack.IsInStack(class'UIAfterAction') && Unit.GetSoldierClassTemplate().bAllowAWCAbilities)
		{
			if (`ISCONTROLLERACTIVE)
			{
				NavHelp.AddRightHelp(m_strHotlinkToRecovery, class'UIUtilities_Input'.consT.ICON_BACK_SELECT);
			}
			else
			{
				NavHelp.AddRightHelp(m_strHotlinkToRecovery, , JumpToRecoveryFacility);
			}
		}

		NavHelp.Show();
	}
}
// End Issue #38

simulated function RealizeScrollbar()
{
	// We only need a scrollbar when we can actually scroll
	if(MaxPosition > 0)
	{
		if(Scrollbar == none)
		{			
			Scrollbar = Spawn(class'UIScrollbar', self).InitScrollbar();
			Scrollbar.SetHeight(450);						
		}
		Scrollbar.NotifyValueChange(OnScrollBarChange, 0.0, MaxPosition);
	}
	else if (Scrollbar != none)
	{
		// We need to handle removal too -- we may have switched soldiers
		Scrollbar.Remove();
		Scrollbar = none;
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	bHandled = true;

	switch(Cmd)
	{				
		//case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		//case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		//case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		//	if (Page > 1)
		//	{
		//		Page -= 1;
		//		PopulateData();
		//	}
		//	break;
		//case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
		//case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		//case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		//	if (Page < MaxPages)
		//	{
		//		Page += 1;
		//		PopulateData();
		//	}
		//	break;
		case class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_DOWN:
			if( Scrollbar != none )
				Scrollbar.OnMouseScrollEvent(-1);				
			break;
		case class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_UP:
			if( Scrollbar != none )
				Scrollbar.OnMouseScrollEvent(1);				
			break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || OnUnrealCommand_UIArmory_PromotionHero_Override(cmd, arg);
}

function OnScrollBarChange(float newValue)
{	
	local int OldPosition;
	OldPosition = Position;
	Position = Clamp(int(newValue), 0, MaxPosition);
	if (OldPosition != Position)
		PopulateData();
}

// Attempt to scroll the selection.
// Return false if the column needs to wrap around, true else
// Called from Column Navigation code
simulated function bool AttemptScroll(bool Up)
{
	local bool bWrapped;
	local int TargetPosition;

	if (Scrollbar == none)
	{
		// We don't scroll, so bail out early
		return false;
	}
	// Scrollbars are awkward. They always use percentages, have delayed callbacks, and you can't specify a step size
	// We'll calculate an appropriate percentage, because that yields better results than sending "scroll" commands
	bWrapped = false;
	TargetPosition = Position;
	if (Up)
	{
		if (Position == 0)
		{
			TargetPosition = MaxPosition;
			bWrapped = true;
		}
		else
		{
			TargetPosition--;
		}
	}
	else
	{
		if (Position == MaxPosition)
		{
			TargetPosition = 0;
			bWrapped = true;
		}
		else
		{
			TargetPosition++;
		}
	}
	if (TargetPosition != Position)
	{
		Scrollbar.SetThumbAtPercent(float(TargetPosition) / float(MaxPosition));
	}
	return !bWrapped;
}

function InitColumns()
{
	local CPS_UIArmory_PromotionHeroColumn Column;
	local int i, numCols;

	numCols = bHasBrigadierRank ? 8 : 7;

	Columns.Length = 0;

	for (i = 0; i < numCols; i++)
	{
		Column = Spawn(class'CPS_UIArmory_PromotionHeroColumn', self);
		Column.MCName = name("rankColumn"$i);
		Column.InitPromotionHeroColumn(i);
		Columns.AddItem(Column);
	}
}

function bool CanPurchaseAbility(int Rank, int Branch, name AbilityName)
{
	local string DummyString;
	return CanPurchaseAbilityEx(Rank, Branch, AbilityName, DummyString);
}

// Issue #7: Include the reason why an ability was locked in `strLocReasonLocked`.
// Issue #3: Allow to adjust and override the logic of this function through Events.
function bool CanPurchaseAbilityEx(int Rank, int Branch, name AbilityName, out string strLocReasonLocked)
{
	local XComGameState_Unit UnitState;
	local CPSAbilityMetaInfo MetaInfo;
	local bool bCanPurchaseAbility;
	local EReasonLocked iReasonLocked;
	
	UnitState = GetUnit();

	FillAbilityMetaInfo(MetaInfo, UnitState, Rank, Branch, AbilityName);
	TriggerOverrideCanPurchaseAbilityProperties(MetaInfo, UnitState);

	bCanPurchaseAbility = true;
	if (!MetaInfo.bUnitMeetsRankRequirement)
	{
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_NotHighEnoughRank;
	} 
	else if (MetaInfo.bUnitHasPurchasedClassPerkAtRank && !MetaInfo.bUnitCanSpendAP && !MetaInfo.bAsResistanceHero)
	{	
		// Don't allow non-hero units to purchase additional abilities with AP without a training center.
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_NoTrainingCenter;
	}
	else if (!MetaInfo.bClassAbility && !MetaInfo.bUnitCanSpendAP && !MetaInfo.bAsResistanceHero)
	{	
		// Don't allow non-hero units to purchase abilities on the "XCOM" perk row without a training center.
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_NoTrainingCenter;
	}
	else if (!MetaInfo.bClassAbility && MetaInfo.bUnitCanSpendAP && !MetaInfo.bUnitHasPurchasedClassPerkAtRank && !MetaInfo.bAsResistanceHero)
	{
		// Don't allow non hero units to purchase abilities on the "XCOM" perk row before getting a soldier class perk on this rank.
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_NoClassPerkPurchased;
	}
	else if (!MetaInfo.bUnitMeetsAbilityPrerequisites)
	{
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_LacksPrerequisites;
	}
	else if (!CanAffordAbility(Rank, Branch))
	{
		bCanPurchaseAbility = false;
		iReasonLocked = eReason_NotEnoughAP;
	}	

	return TriggerOverrideCanPurchaseAbility(MetaInfo, UnitState, bCanPurchaseAbility, iReasonLocked, strLocReasonLocked);
}

private function TriggerOverrideCanPurchaseAbilityProperties(out CPSAbilityMetaInfo MetaInfo, XComGameState_Unit UnitState)
{
	local XComLWTuple Tuple;

	/// Mods can listen to the 'CPS_OverrideCanPurchaseAbilityProperties' event to modify properties that
	/// affect the Community Promotion Screen's decision whether this unit should be able to unlock this ability,
	/// e.g. by making "XCOM" row abilities follow the same unlock rules as soldier class abilities.
	///
	/// Here are the Ability Unlock Rules normally used by the Community Promotion Screen:
	///
	/// # Ability Unlock Rules
	/// 1. Only abilities of the soldier's current rank or lower can be unlocked (bUnitMeetsRankRequirement).
	/// 2. Soldier must be able to afford the Ability Point cost. 
	/// Keep in mind in some cases the Ability Point cost can be zero.
	/// 3. Soldier must meet the ability's prerequisites, 
	/// e.g. have the required perks and no mutually exclusive perks (bUnitMeetsAbilityPrerequisites).
	///
	/// # Additional Ability Unlock Rules for regular soldiers (!bAsResistanceHero)
	/// 1. Soldiers can unlock one soldier class ability per rank for free (bClassAbility && !bUnitHasPurchasedClassPerkAtRank).
	/// 2. Unlocking more than one ability per rank requires Training Center (bClassAbility && bHasPurchasedClassPerkAtRank && bCanSpendAP).
	/// 3. Unlocking non-class perks requires Training Center (!bClassAbility && bCanSpendAP).
	/// Keep in mind the Training Center requirement can be disabled by mod users in CPS's ModConfigMenu.
	///
	/// Changes done to these properties by listeners will apply only for this ability and this soldier, 
	/// including `bAsResistanceHero`.
	/// CPS's decision based on these properties can still be overridden by the 'CPS_OverrideCanPurchaseAbility' event later.
	///
	///```event
	/// EventID: CPS_OverrideCanPurchaseAbilityProperties,
	/// EventData: [in name AbilityTemplateName,
	///		in int iRank,
	///		in int iRow,
	///		inout bool bPowerfulAbility,
	///		inout bool bColonelRankAbility,
	///		inout bool bClassAbility,
	///		inout bool bUnitMeetsAbilityPrerequisites,
	///		inout bool bUnitHasPurchasedClassPerkAtRank,
	///		inout bool bUnitMeetsRankRequirement,
	///		inout bool bUnitCanSpendAP,
	///		inout bool bAsResistanceHero,
	///		in int AbilitiesPerRank],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	///```	
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_OverrideCanPurchaseAbilityProperties';

	FillTupleFromAbilityMetaInfo(MetaInfo, Tuple);

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState);

	UpdateAbilityMetaInfoFromTuple(MetaInfo, Tuple);
}

private function bool TriggerOverrideCanPurchaseAbility(CPSAbilityMetaInfo MetaInfo, XComGameState_Unit UnitState, const bool bCanPurchaseAbility, const EReasonLocked iReasonLocked, out string strLocReasonLocked)
{
	local XComLWTuple Tuple;

	/// Mods can listen to the 'CPS_OverrideCanPurchaseAbility' event to use their own logic 
	/// to make the final decision whether this unit should be able to unlock this ability.
	///
	/// - If a mod wants to allow unlocking this ability, then setting `bCanPurchaseAbility = true;` is enough.
	/// - If a mod wants to disallow unlocking this ability, then setting `bCanPurchaseAbility = false;` is enough,
	///	though ideally the mod should also provide a `strLocReasonLocked` string that will be displayed in the UI
	/// as a reason why this ability cannot be unlocked at this time.
	/// Alternatively, if the mod wants to use one of the standard CPS reasons,
	/// they can put the specific reason's array index into `eReasonLocked`.
	///
	///```event
	/// EventID: CPS_OverrideCanPurchaseAbility,
	/// EventData: [in name AbilityTemplateName,
	///		in int iRank,
	///		in int iRow,
	///		in bool bPowerfulAbility,
	///		in bool bColonelRankAbility,
	///		in bool bClassAbility,
	///		in bool bUnitMeetsAbilityPrerequisites,
	///		in bool bUnitHasPurchasedClassPerkAtRank,
	///		in bool bUnitMeetsRankRequirement,
	///		in bool bUnitCanSpendAP,
	///		in bool bAsResistanceHero,
	///		in int AbilitiesPerRank,
	///		in bool bUnitCanAffordAP,
	///		inout bool bCanPurchaseAbility,
	///		inout int eReasonLocked,
	///		out string strLocReasonLocked],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	///```	
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_OverrideCanPurchaseAbility';
	
	FillTupleFromAbilityMetaInfo(MetaInfo, Tuple);

	Tuple.Data.Add(4);
	Tuple.Data[12].kind = XComLWTVBool;
	Tuple.Data[12].b = CanAffordAbility(MetaInfo.iRank, MetaInfo.iRow);
	Tuple.Data[13].kind = XComLWTVBool;
	Tuple.Data[13].b = bCanPurchaseAbility;
	Tuple.Data[14].kind = XComLWTVInt;
	Tuple.Data[14].i = iReasonLocked;
	Tuple.Data[15].kind = XComLWTVString;
	Tuple.Data[15].s = "";

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState);

	if (Tuple.Data[13].b) // bCanPurchaseAbility
	{
		return true;
	}
	if (Tuple.Data[15].s != "")
	{	
		strLocReasonLocked = Tuple.Data[15].s;
	}
	else if (Tuple.Data[14].i >= 0 && Tuple.Data[14].i <= eReason_MAX)
	{
		strLocReasonLocked = arr_strLocReasonsLocked[Tuple.Data[14].i]; // iReasonLocked
	}
	
	return false;
}

// Issue #10: Allow to adjust and override the logic of this function through Events.
function int GetAbilityPointCost(int Rank, int Branch)
{
	local XComGameState_Unit				UnitState;
	local array<SoldierClassAbilityType>	AbilityTree;
	local CPSAbilityMetaInfo				MetaInfo;
	local int								iAbilityCost;

	UnitState = GetUnit();
	AbilityTree = UnitState.GetRankAbilities(Rank);	

	FillAbilityMetaInfo(MetaInfo, UnitState, Rank, Branch, AbilityTree[Branch].AbilityName);
	TriggerOverrideGetAbilityPointCostProperties(MetaInfo, UnitState);
	
	if (GetCustomAbilityCost(UnitState, MetaInfo.TemplateName, iAbilityCost))
	{
		// Do nothing, iAbilityCost will already hold the config value.
	}
	else 
	{
		if (MetaInfo.bPowerfulAbility && (MetaInfo.bAsResistanceHero || !MetaInfo.bClassAbility))
		{
			// Ability Cost is increased for "powerful" abilities in XCOM row of regular soldiers, 
			// or anywhere in the Faction Heroes' ability tree.	
			iAbilityCost = class'X2StrategyGameRulesetDataStructures'.default.PowerfulAbilityPointCost;
		}
		else if (MetaInfo.bAsResistanceHero && MetaInfo.bColonelRankAbility && !bHasBrigadierRank)
		{
			// Colonel+ rank abilities of Faction Heroes have increased cost as well, 
			// unless the class has a Brigadier Rank, 
			// in which case we default to configuration array of ability costs below.
			iAbilityCost = class'X2StrategyGameRulesetDataStructures'.default.PowerfulAbilityPointCost;
		}
		else
		{
			iAbilityCost = GetDefaultAbilityPointCostForRank(Rank);
		}	
	}

	return TriggerOverrideAbilityPointCost(MetaInfo, UnitState, iAbilityCost);
}

private function TriggerOverrideGetAbilityPointCostProperties(out CPSAbilityMetaInfo MetaInfo, XComGameState_Unit UnitState)
{
	local XComLWTuple Tuple;

	/// Mods can listen to the 'CPS_OverrideGetAbilityPointCostProperties' event to modify properties that
	/// affect the Community Promotion Screen's decisions when it calculates Ability Point cost
	/// for this ability and this unit.
	///
	/// Here are the Ability Point Cost Rules normally used by the Community Promotion Screen:
	///
	///	# Ability Costs
	/// CPS draws AP Cost values from two places:
	/// 1. `class'X2StrategyGameRulesetDataStructures'.default.AbilityPointCosts` array - holds the "default" cost.
	/// 2. `class'X2StrategyGameRulesetDataStructures'.default.PowerfulAbilityPointCost` - holds the "powerful" cost.
	/// Ability is considered "powerful" if it's listed in `class'X2StrategyGameRulesetDataStructures'.default.PowerfulAbilities` array.
	///
	/// # Regular Soldiers
	/// 1. First class ability unlock on this rank after being promoted to this rank is free (!bUnitHasPurchasedClassPerkAtRank).
	/// 2. Default AP cost is used at all other times, except for:
	/// 3. "Powerful" non-class abilities use the "powerful" cost (bPowerfulAbility && !bClassAbility). 
	/// Again, this applies only to non-class perks, e.g. perks in the "XCOM" row.
	/// 
	/// # Faction Heroes (bAsResistanceHero)
	/// 1. Default AP cost is used at all times, except for:
	/// 2. All "powerful" abilities use the "powerful" cost (bPowerfulAbility).
	/// 3. Colonel Rank abilities use the "powerful" cost (bColonelRankAbility)
	///
	/// Changes done to these properties by listeners will apply only for this ability and this soldier, 
	/// including `bAsResistanceHero`.
	/// CPS's decision based on these properties can still be overridden by the 'CPS_OverrideAbilityPointCost' event later.
	///
	///```event
	/// EventID: CPS_OverrideGetAbilityPointCostProperties,
	/// EventData: [in name AbilityTemplateName,
	///		in int iRank,
	///		in int iRow,
	///		inout bool bPowerfulAbility,
	///		inout bool bColonelRankAbility,
	///		inout bool bClassAbility,
	///		inout bool bUnitMeetsAbilityPrerequisites,
	///		inout bool bUnitHasPurchasedClassPerkAtRank,
	///		inout bool bUnitMeetsRankRequirement,
	///		inout bool bUnitCanSpendAP,
	///		inout bool bAsResistanceHero,
	///		in int AbilitiesPerRank],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	///```	
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_OverrideGetAbilityPointCostProperties';
	
	FillTupleFromAbilityMetaInfo(MetaInfo, Tuple);

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState);

	UpdateAbilityMetaInfoFromTuple(MetaInfo, Tuple);
}

private function int TriggerOverrideAbilityPointCost(out CPSAbilityMetaInfo MetaInfo, XComGameState_Unit UnitState, const int iAbilityPointCost)
{
	local XComLWTuple Tuple;

	// Start Issue #10
	/// Mods can listen to 'CPS_OverrideAbilityPointCost' event to use their own logic 
	/// to determine abiility point cost for this particular unit and this particular ability.
	/// 
	/// Community Promotion Screen always calculates proper Ability Point Cost for each ability,
	/// which is passed in the Tuple as `iAbilityPointCost`. However, abilities unlocked 
	/// by regular soldiers when they are first promoted to a new rank 
	/// normally do not cost any Ability Points: `(!bAsResistanceHero && bClassAbility && !bUnitHasPurchasedClassPerkAtRank)`
	///
	/// If the above statement evaluates to `true`, the Ability Point Cost written in `iAbilityCost`
	/// will be ignored and the ability will be free to unlock.
	///
	/// ```event
	/// EventID: CPS_OverrideAbilityPointCost,
	/// EventData: [in name AbilityTemplateName,
	///		in int iRank,
	///		in int iRow,
	///		in bool bPowerfulAbility,
	///		in bool bColonelRankAbility,
	///		in bool bClassAbility,
	///		in bool bUnitMeetsAbilityPrerequisites,
	///		in bool bUnitHasPurchasedClassPerkAtRank,
	///		in bool bUnitMeetsRankRequirement,
	///		in bool bUnitCanSpendAP,
	///		in bool bAsResistanceHero,
	///		in int AbilitiesPerRank,
	///		inout int iAbilityPointCost],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	///```	
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_OverrideAbilityPointCost';

	FillTupleFromAbilityMetaInfo(MetaInfo, Tuple);

	Tuple.Data.Add(1);
	Tuple.Data[12].kind = XComLWTVInt;
	Tuple.Data[12].i = iAbilityPointCost;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState);

	UpdateAbilityMetaInfoFromTuple(MetaInfo, Tuple);

	//`LOG(GetFuncName() @ UnitState.GetFullName(),, 'CPS_TEST');
	//`LOG(AbilityMetaInfo_ToString(MetaInfo),, 'CPS_TEST');

	// Ability Point cost should not be applied if this ability is unlocked by a regular soldier for free on their promotion.
	if (!MetaInfo.bAsResistanceHero && MetaInfo.bClassAbility && !MetaInfo.bUnitHasPurchasedClassPerkAtRank)
	{
		return 0;
	}
	return Tuple.Data[12].i; // iAbilityPointCost
}

final function int GetDefaultAbilityPointCostForRank(const int Rank)
{
	// Failsafe in case there are more soldier ranks than there are configured costs for.
	if (Rank >= class'X2StrategyGameRulesetDataStructures'.default.AbilityPointCosts.Length)
	{
		// Then we simply use the final configured member of the array.
		return class'X2StrategyGameRulesetDataStructures'.default.AbilityPointCosts[class'X2StrategyGameRulesetDataStructures'.default.AbilityPointCosts.Length - 1];
	}
	return class'X2StrategyGameRulesetDataStructures'.default.AbilityPointCosts[Rank];
}

function bool GetCustomAbilityCost(const XComGameState_Unit UnitState, const name AbilityName, out int AbilityCost)
{
	local array<CustomClassAbilityCost> CustomCosts;
	local CustomClassAbilityCost CustomCost;

	CustomCosts = class'NPSBDP_UIArmory_PromotionHero'.default.ClassCustomAbilityCost;

	// Look for the class-specific first, so that it takes priority.
	foreach CustomCosts(CustomCost)
	{
		if (CustomCost.ClassName == ClassTemplate.DataName && CustomCost.AbilityName == AbilityName)
		{
			AbilityCost = CustomCost.AbilityCost;
			return true;
		}
	}

	foreach CustomCosts(CustomCost)
	{
		if (CustomCost.ClassName == '' && CustomCost.AbilityName == AbilityName)
		{
			AbilityCost = CustomCost.AbilityCost;
			return true;
		}
	}
	return false;
}

function PreviewAbility(int Rank, int Branch)
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate, PreviousAbilityTemplate;
	local XComGameState_Unit Unit;
	local array<SoldierClassAbilityType> AbilityTree;
	local string AbilityIcon, AbilityName, AbilityDesc, DisabledReason, AbilityCost, CostLabel, APLabel, PrereqAbilityNames;
	local name PrereqAbilityName;
	// Variable for Issue #128
	local string MutuallyExclusiveNames;

	// Variable for Issue #55
	local string SlotName;

	// NPSBDP Patch
	Branch += Position;

	Unit = GetUnit();
	
	// Ability cost is always displayed, even if the rank hasn't been unlocked yet
	CostLabel = m_strCostLabel;
	APLabel = m_strAPLabel;
	AbilityCost = string(GetAbilityPointCost(Rank, Branch));
	if (!CanAffordAbility(Rank, Branch))
	{
		AbilityCost = class'UIUtilities_Text'.static.GetColoredText(AbilityCost, eUIState_Bad);
	}
		
	if (!`GETMCMVAR(SHOW_UNREACHED_PERKS) && Rank >= Unit.GetRank())
	{
		AbilityIcon = class'UIUtilities_Image'.const.LockedAbilityIcon;
		AbilityName = class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedTitle, eUIState_Disabled);
		AbilityDesc = class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedDescription, eUIState_Disabled);

		// Don't display cost information for abilities which have not been unlocked yet
		CostLabel = "";
		AbilityCost = "";
		APLabel = "";
	}
	else
	{		
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		AbilityTree = Unit.GetRankAbilities(Rank);
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[Branch].AbilityName);

		if (AbilityTemplate != none)
		{
			AbilityIcon = AbilityTemplate.IconImage;
			AbilityName = AbilityTemplate.LocFriendlyName != "" ? AbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for " $ AbilityTemplate.DataName);
			AbilityDesc = AbilityTemplate.HasLongDescription() ? AbilityTemplate.GetMyLongDescription(, Unit) : ("Missing 'LocLongDescription' for " $ AbilityTemplate.DataName);

			// Start Issue #7
			CanPurchaseAbilityEx(Rank, Branch, AbilityTemplate.DataName, DisabledReason);
			// End Issue #7

			// Don't display cost information if the ability has already been purchased
			if (Unit.HasSoldierAbility(AbilityTemplate.DataName))
			{
				CostLabel = "";
				AbilityCost = "";
				APLabel = "";
				DisabledReason = ""; // Issue #7
			}
			else if (AbilityTemplate.PrerequisiteAbilities.Length > 0)
			{
				// Look back to the previous rank and check to see if that ability is a prereq for this one
				// If so, display a message warning the player that there is a prereq
				// Start Issue #128
				foreach AbilityTemplate.PrerequisiteAbilities(PrereqAbilityName)
				{
					if (InStr(PrereqAbilityName, class'UIArmory_PromotionHero'.default.MutuallyExclusivePrefix) == 0)
					{
						PreviousAbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(
							name(Mid(PrereqAbilityName, Len(class'UIArmory_PromotionHero'.default.MutuallyExclusivePrefix))));
						if (PreviousAbilityTemplate != none )
						{
							if (MutuallyExclusiveNames != "")
							{
								MutuallyExclusiveNames $= ", ";
							}
							MutuallyExclusiveNames $= PreviousAbilityTemplate.LocFriendlyName;
						}
					}
					else
					{
						PreviousAbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(PrereqAbilityName);
						if (PreviousAbilityTemplate != none && !Unit.HasSoldierAbility(PrereqAbilityName))
						{
							if (PrereqAbilityNames != "")
							{
								PrereqAbilityNames $= ", ";
							}
							PrereqAbilityNames $= PreviousAbilityTemplate.LocFriendlyName;
						}
					}
				}
				PrereqAbilityNames = class'UIUtilities_Text'.static.FormatCommaSeparatedNouns(PrereqAbilityNames);
				MutuallyExclusiveNames = class'UIUtilities_Text'.static.FormatCommaSeparatedNouns(MutuallyExclusiveNames);

				if (MutuallyExclusiveNames != "")
				{
					AbilityDesc = class'UIUtilities_Text'.static.GetColoredText(m_strMutuallyExclusive @ MutuallyExclusiveNames, eUIState_Warning) $ "\n" $ AbilityDesc;
				}

				if (PrereqAbilityNames != "")
				{
					AbilityDesc = class'UIUtilities_Text'.static.GetColoredText(m_strPrereqAbility @ PrereqAbilityNames, eUIState_Warning) $ "\n" $ AbilityDesc;
				}
				// End Issue #128
			}
		}
		else
		{
			AbilityIcon = "";
			AbilityName = string(AbilityTree[Branch].AbilityName);
			AbilityDesc = "Missing template for ability '" $ AbilityTree[Branch].AbilityName $ "'";
			DisabledReason = "";
		}		
	}	

	if (DisabledReason != "")
	{
		AbilityDesc $= "\n" $ class'UIUtilities_Text'.static.GetColoredText(DisabledReason, eUIState_Warning);
	}

	// Issue #55
	if (`GETMCMVAR(SHOW_INVENTORY_SLOT))
	{
		SlotName = class'UIArmory_loadout'.default.m_strInventoryLabels[AbilityTree[Branch].ApplyToWeaponSlot];
		if (SlotName != "")
		{
			AbilityName $= " (" $ Locs(SlotName) $ ")";
		}
	}
	AS_SetDescriptionData(AbilityIcon, AbilityName, AbilityDesc, "", CostLabel, AbilityCost, APLabel);
}

simulated function ConfirmAbilitySelection(int Rank, int Branch)
{
	local XGParamTag LocTag;
	local TDialogueBoxData DialogData;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<SoldierClassAbilityType> AbilityTree;
	local string ConfirmAbilityText;
	local int AbilityPointCost;

	// NPSBDP Patch
	Branch += Position;

	PendingRank = Rank;
	PendingBranch = Branch;

	Movie.Pres.PlayUISound(eSUISound_MenuSelect);

	DialogData.eType = eDialog_Alert;
	DialogData.bMuteAcceptSound = true;
	DialogData.strTitle = m_strConfirmAbilityTitle;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	DialogData.fnCallback = ConfirmAbilityCallbackEx;  // Issue #37

	AbilityTree = GetUnit().GetRankAbilities(Rank);
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[Branch].AbilityName);
	AbilityPointCost = GetAbilityPointCost(Rank, Branch);
	
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = AbilityTemplate.LocFriendlyName;
	LocTag.IntValue0 = AbilityPointCost;
	ConfirmAbilityText = `XEXPAND.ExpandString(m_strConfirmAbilityText);

	// If the unit cannot afford the ability on their own, display a warning about spending Shared AP
	if (AbilityPointCost > GetUnit().AbilityPoints)
	{
		LocTag.IntValue0 = AbilityPointCost - GetUnit().AbilityPoints;

		if((AbilityPointCost - GetUnit().AbilityPoints) == 1)
			ConfirmAbilityText $= "\n\n" $ `XEXPAND.ExpandString(m_strSharedAPWarningSingular);
		else
			ConfirmAbilityText $= "\n\n" $ `XEXPAND.ExpandString(m_strSharedAPWarning);

	}

	DialogData.strText = ConfirmAbilityText;
	Movie.Pres.UIRaiseDialog(DialogData);
}

// This is a copy of `ComfirmAbilityCallback` so that we can inject some
// hooks into it, because some mods will want to add behaviour around when
// the player selects/purchases an ability.
simulated function ConfirmAbilityCallbackEx(Name Action)
{
	local XComGameStateHistory History;
	local bool bSuccess;
	local XComGameState UpdateState;
	local XComGameState_Unit UpdatedUnit;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local int iAbilityPointCost;

	if (Action == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Soldier Promotion");
		UpdateState = History.CreateNewGameState(true, ChangeContainer);

		UpdatedUnit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', GetUnit().ObjectID));
		iAbilityPointCost = GetAbilityPointCost(PendingRank, PendingBranch);
		bSuccess = UpdatedUnit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch, iAbilityPointCost);

		if (bSuccess)
		{
			// Issue #43
			TriggerAbilityPurchased(UpdatedUnit, PendingRank, PendingBranch, iAbilityPointCost, UpdateState);

			`GAMERULES.SubmitGameState(UpdateState);

			Header.PopulateData();
			PopulateData();

			// Issue #53 - Remove ability's tag after it was purchased.
			CPS_UIArmory_PromotionHeroColumn(Columns[PendingRank]).RemoveAbilityTag(PendingBranch);

			// Start Issue #37
			// KDM : After an ability has been selected and accepted, all of the
			// promotion data has to be re-populated and the selected ability's
			// focus is lost. Therefore, we need to give the selected ability its
			// focus back.
			if (`ISCONTROLLERACTIVE)
			{
				Columns[m_iCurrentlySelectedColumn].OnReceiveFocus();
			}
			// End Issue #37
		}
		else
		{
			History.CleanupPendingGameState(UpdateState);
		}

		Movie.Pres.PlayUISound(eSUISound_SoldierPromotion);
	}
	else 	// if we got here it means we were going to upgrade an ability, but then we decided to cancel
	{
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);

		// Start Issue #28
		//List.SetSelectedIndex(previousSelectedIndexOnFocusLost, true); // List is not used by the hero promotion screen.
		//UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(SelectedAbilityIndex);
		// End Issue #28
	}
}

// Issue #43
/// Fires an event when the player has selected/purchased an ability for
/// a given soldier. The soldier unit state is passed as the event source.
/// The unit state can be retrieved and modified using the provided NewGameState
/// if `ELD_Immediate` is used for the listener.
///
/// Note that this listener can not cancel the ability purchase.
///
/// ```event
/// EventID: CPS_AbilityPurchased,
/// EventData: [in int Rank, 
///		in int Row,
///		in int AbilitiesPerRank,
///		in bool bAsResistanceHero,
///		in bool bCanSpendAP,
///		in int iAbilityPointCost],
/// EventSource: XComGameState_Unit (UnitState),
/// NewGameState: yes
/// ```
private function TriggerAbilityPurchased(XComGameState_Unit UnitState, int Rank, int Branch, int iAbilityPointCost, XComGameState NewGameState)
{
	local XComLWTuple Tuple;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_AbilityPurchased';
	Tuple.Data.Add(6);
	Tuple.Data[0].kind = XComLWTVInt;
	Tuple.Data[0].i = Rank;
	Tuple.Data[1].kind = XComLWTVInt;
	Tuple.Data[1].i = Branch;
	Tuple.Data[2].kind = XComLWTVInt;
	Tuple.Data[2].i = AbilitiesPerRank;
	Tuple.Data[3].kind = XComLWTVBool;
	Tuple.Data[3].b = bAsResistanceHero;
	Tuple.Data[4].kind = XComLWTVBool;
	Tuple.Data[4].b = bCanSpendAP;
	Tuple.Data[5].kind = XComLWTVInt;
	Tuple.Data[5].i = iAbilityPointCost;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState, NewGameState);
}
// End Issue #43

//New functions
simulated function string GetPromotionBlueprintTag(StateObjectReference UnitRef)
{
	local int i;
	local XComGameState_Unit UnitState;

	for(i = 0; i < AfterActionScreen.XComHQ.Squad.Length; ++i)
	{
		if(AfterActionScreen.XComHQ.Squad[i].ObjectID == UnitRef.ObjectID)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AfterActionScreen.XComHQ.Squad[i].ObjectID));
			
			if (UnitState.IsGravelyInjured())
			{
				return AfterActionScreen.UIBlueprint_PrefixHero_Wounded $ i;
			}
			else
		
			{
				return AfterActionScreen.UIBlueprint_PrefixHero $ i;
			}						
		}
	}

	return "";
}

function bool CanSpendAP()
{
	if(`GETMCMVAR(DISABLE_TRAINING_CENTER_REQUIREMENT))
		return true;
	
	return `XCOMHQ.HasFacilityByName('RecoveryCenter');
}

function CacheAbilitiesPerRank()
{	
	local int RankIndex;

	AbilitiesPerRank = 0;

	if (GetCustomAbilitiesPerRank())
	{
		return;
	}

	// Start with RankIndex = 1 so we don't count squaddie perks.
	// Main purpose of this function is to figure out the placement of the XCOM perk row
	for (RankIndex = 1; RankIndex < ClassTemplate.GetMaxConfiguredRank(); RankIndex++)
	{
		AbilitiesPerRank = Max(AbilitiesPerRank, ClassTemplate.GetAbilitySlots(RankIndex).Length);
	}
}

function bool GetCustomAbilitiesPerRank()
{
	local int Index;

	Index = class'NPSBDP_UIArmory_PromotionHero'.default.ClassAbilitiesPerRank.Find('ClassName', ClassTemplate.DataName);
	if (Index != INDEX_NONE)
	{
		AbilitiesPerRank = class'NPSBDP_UIArmory_PromotionHero'.default.ClassAbilitiesPerRank[Index].AbilitiesPerRank;
		return true;
	}
	return false;
}

function bool IsUnitResistanceHero(XComGameState_Unit UnitState)
{
	local XComLWTuple Tuple;

	/// Mods can listen to the 'CPS_OverrideIsUnitResistanceHero' event to modify whether the
	/// Community Promotion Screen should treat this unit as a Faction Hero or not.
	/// 
	/// Faction heroes use different ability unlock and ability point cost rules, 
	/// for example they can unlock multiple perks per rank without a Training Center, 
	/// but they have to pay ability points for every unlocked ability.
	///
	///```event
	/// EventID: CPS_OverrideIsUnitResistanceHero,
	/// EventData: [inout bool bAsResistanceHero,
	///		in int AbilitiesPerRank],
	/// EventSource: XComGameState_Unit (UnitState),
	/// NewGameState: none
	///```	
	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CPS_OverrideIsUnitResistanceHero';
	Tuple.Data.Add(2);
	Tuple.Data[0].kind = XComLWTVBool;
	Tuple.Data[0].b = UnitState.IsResistanceHero() || AbilitiesPerRank == 0; // bAsResistanceHero
	Tuple.Data[1].kind = XComLWTVInt;
	Tuple.Data[1].i = AbilitiesPerRank;

	`XEVENTMGR.TriggerEvent(Tuple.Id, Tuple, UnitState);

	return Tuple.Data[0].b;
}

private function FillAbilityMetaInfo(out CPSAbilityMetaInfo MetaInfo, XComGameState_Unit UnitState, const int Rank, const int Branch, const name AbilityName)
{
	MetaInfo.TemplateName = AbilityName;

	// Rank and Row begin their count at 0, with the first perk in the upper left corner of the promotion screen.
	MetaInfo.iRank = Rank;
	MetaInfo.iRow = Branch;

	MetaInfo.bPowerfulAbility = class'X2StrategyGameRulesetDataStructures'.default.PowerfulAbilities.Find(AbilityName) != INDEX_NONE;
	
	// Colonel rank abilities use the "powerful" ability point cost for Faction Heroes, unless they have a Brigadier rank.
	MetaInfo.bColonelRankAbility = Rank == 6;

	// Whether this ability is located within soldier class perk rows (e.g. not in the "XCOM" row or below).
	// 4th row of abilities for "vanilla" Faction Heroes does count as "class abilities", since they use a random deck of perks, not a "true" XCOM row.
	MetaInfo.bClassAbility = Branch < AbilitiesPerRank; 

	MetaInfo.bUnitMeetsAbilityPrerequisites = UnitState.MeetsAbilityPrerequisites(AbilityName);

	// Whether the soldier has a soldier class perk unlocked at this rank already.
	MetaInfo.bUnitHasPurchasedClassPerkAtRank = UnitState.HasPurchasedPerkAtRank(Rank, AbilitiesPerRank);

	// This should not be modified carelessly by event listeners, as it can lead to unexpected results, 
	// like regular soldiers being able to get a free perk on every visible rank off just one promotion. 
	// Even if the rank is high enough, the perks have to be actually visible to the player in order to unlock them, 
	// and perks from unreached ranks are hidden by default.
	MetaInfo.bUnitMeetsRankRequirement = Rank < UnitState.GetRank();

	// Whether Training Center is built, or if the CPS is configured to disregard Training Center requirement.
	MetaInfo.bUnitCanSpendAP = bCanSpendAP;

	MetaInfo.bAsResistanceHero = bAsResistanceHero;
}

private function FillTupleFromAbilityMetaInfo(const CPSAbilityMetaInfo MetaInfo, XComLWTuple Tuple)
{
	Tuple.Data.Add(12);
	Tuple.Data[0].kind = XComLWTVName;
	Tuple.Data[0].n = MetaInfo.TemplateName;
	Tuple.Data[1].kind = XComLWTVInt;
	Tuple.Data[1].i = MetaInfo.iRank;
	Tuple.Data[2].kind = XComLWTVInt;
	Tuple.Data[2].i = MetaInfo.iRow;
	Tuple.Data[3].kind = XComLWTVBool;
	Tuple.Data[3].b = MetaInfo.bPowerfulAbility;
	Tuple.Data[4].kind = XComLWTVBool;
	Tuple.Data[4].b = MetaInfo.bColonelRankAbility;
	Tuple.Data[5].kind = XComLWTVBool;
	Tuple.Data[5].b = MetaInfo.bClassAbility;
	Tuple.Data[6].kind = XComLWTVBool;
	Tuple.Data[6].b = MetaInfo.bUnitMeetsAbilityPrerequisites;
	Tuple.Data[7].kind = XComLWTVBool;
	Tuple.Data[7].b = MetaInfo.bUnitHasPurchasedClassPerkAtRank;
	Tuple.Data[8].kind = XComLWTVBool;
	Tuple.Data[8].b = MetaInfo.bUnitMeetsRankRequirement;
	Tuple.Data[9].kind = XComLWTVBool;
	Tuple.Data[9].b = MetaInfo.bUnitCanSpendAP;
	Tuple.Data[10].kind = XComLWTVBool;
	Tuple.Data[10].b = bAsResistanceHero;
	Tuple.Data[11].kind = XComLWTVInt;
	Tuple.Data[11].i = AbilitiesPerRank;
}

private function UpdateAbilityMetaInfoFromTuple(out CPSAbilityMetaInfo MetaInfo, const XComLWTuple Tuple)
{
	MetaInfo.bPowerfulAbility = Tuple.Data[3].b;
	MetaInfo.bColonelRankAbility = Tuple.Data[4].b;
	MetaInfo.bClassAbility = Tuple.Data[5].b;
	MetaInfo.bUnitMeetsAbilityPrerequisites = Tuple.Data[6].b;
	MetaInfo.bUnitHasPurchasedClassPerkAtRank = Tuple.Data[7].b;
	MetaInfo.bUnitMeetsRankRequirement = Tuple.Data[8].b;
	MetaInfo.bUnitCanSpendAP = Tuple.Data[9].b;
	MetaInfo.bAsResistanceHero = Tuple.Data[10].b;
}

final static function string AbilityMetaInfo_ToString(const CPSAbilityMetaInfo MetaInfo)
{
	return `showvar(MetaInfo.TemplateName) @ `showvar(MetaInfo.iRank) @ `showvar(MetaInfo.iRow) @ `showvar(MetaInfo.bPowerfulAbility) @
			`showvar(MetaInfo.bColonelRankAbility) @ `showvar(MetaInfo.bClassAbility) @ 
			`showvar(MetaInfo.bUnitMeetsAbilityPrerequisites) @ `showvar(MetaInfo.bUnitHasPurchasedClassPerkAtRank) @ 
			`showvar(MetaInfo.bUnitMeetsRankRequirement) @ `showvar(MetaInfo.bUnitCanSpendAP) @ `showvar(MetaInfo.bAsResistanceHero);
}

function ResizeScreenForBrigadierRank()
{
	
	// Fix width and position of elements to make space for the 8th column
	//
	Width = int(MC.GetNum("_width"));
	AdjustXOffset = MC.GetNum("rankColumn6._x") - MC.GetNum("rankColumn5._x");
	SetWidth(Width + AdjustXOffset);

	// Widths
	MC.ChildSetNum("bg",				"_width", MC.GetNum("bg._width") + AdjustXOffset);
	MC.ChildSetNum("topDivider",		"_width", MC.GetNum("topDivider._width") + AdjustXOffset);
	MC.ChildSetNum("bottomDivider",		"_width", MC.GetNum("bottomDivider._width") + AdjustXOffset);
	MC.ChildSetNum("headerLines",		"_width", MC.GetNum("headerLines._width") + AdjustXOffset);
	MC.ChildSetNum("columnGradients",	"_width", MC.GetNum("columnGradients._width") + AdjustXOffset);

	// X Positions
	MC.SetNum("_x", MC.GetNum("_x") + 50);
	MC.ChildSetNum("topDivider",		"_x", MC.GetNum("topDivider._x") - AdjustXOffset);
	MC.ChildSetNum("bottomDivider",		"_x", MC.GetNum("bottomDivider._x") - AdjustXOffset);
	MC.ChildSetNum("headerLines",		"_x", MC.GetNum("headerLines._x") - AdjustXOffset);
	MC.ChildSetNum("columnGradients",	"_x", MC.GetNum("columnGradients._x") - AdjustXOffset);
	MC.ChildSetNum("factionLogoLarge",	"_x", MC.GetNum("factionLogoLarge._x") - AdjustXOffset);
	MC.ChildSetNum("factionLogo",		"_x", MC.GetNum("factionLogo._x") - AdjustXOffset);
	MC.ChildSetNum("classIcon",			"_x", MC.GetNum("classIcon._x") - AdjustXOffset);
	MC.ChildSetNum("rankIcon",			"_x", MC.GetNum("rankIcon._x") - AdjustXOffset);
	MC.ChildSetNum("factionName",		"_x", MC.GetNum("factionName._x") - AdjustXOffset);
	MC.ChildSetNum("abilityLabel",		"_x", MC.GetNum("abilityLabel._x") - AdjustXOffset);
	//MC.ChildSetNum("soldierAPLabel",	"_x", MC.GetNum("soldierAPLabel._x") - AdjustXOffset);
	//MC.ChildSetNum("soldierAPValue",	"_x", MC.GetNum("soldierAPValue._x") - AdjustXOffset);
	//MC.ChildSetNum("teamAPLabel",		"_x", MC.GetNum("teamAPLabel._x") - AdjustXOffset);
	//MC.ChildSetNum("teamAPValue",		"_x", MC.GetNum("teamAPValue._x") - AdjustXOffset);
	//MC.ChildSetNum("combatIntelLabel",	"_x", MC.GetNum("combatIntelLabel._x") - AdjustXOffset);
	//MC.ChildSetNum("combatIntelValue",	"_x", MC.GetNum("combatIntelValue._x") - AdjustXOffset);
	MC.ChildSetNum("unitName",			"_x", MC.GetNum("unitName._x") - AdjustXOffset);
	MC.ChildSetNum("descriptionTitle",	"_x", MC.GetNum("descriptionTitle._x") - AdjustXOffset);
	MC.ChildSetNum("descriptionBody",	"_x", MC.GetNum("descriptionBody._x") - AdjustXOffset);
	MC.ChildSetNum("descriptionDetail",	"_x", MC.GetNum("descriptionDetail._x") - AdjustXOffset);
	MC.ChildSetNum("descriptionIcon",	"_x", MC.GetNum("descriptionIcon._x") - AdjustXOffset);
	MC.ChildSetNum("costLabel",			"_x", MC.GetNum("costLabel._x") - AdjustXOffset);
	MC.ChildSetNum("costValue",			"_x", MC.GetNum("costValue._x") - AdjustXOffset);
	MC.ChildSetNum("apLabel",			"_x", MC.GetNum("apLabel._x") - AdjustXOffset);
	MC.ChildSetNum("abilityPathHeader",	"_x", MC.GetNum("abilityPathHeader._x") - AdjustXOffset);
	MC.ChildSetNum("pathLabel0",		"_x", MC.GetNum("pathLabel0._x") - AdjustXOffset);
	MC.ChildSetNum("pathLabel1",		"_x", MC.GetNum("pathLabel1._x") - AdjustXOffset);
	MC.ChildSetNum("pathLabel2",		"_x", MC.GetNum("pathLabel2._x") - AdjustXOffset);
	MC.ChildSetNum("pathLabel3",		"_x", MC.GetNum("pathLabel3._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn0",		"_x", MC.GetNum("rankColumn0._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn1",		"_x", MC.GetNum("rankColumn1._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn2",		"_x", MC.GetNum("rankColumn2._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn3",		"_x", MC.GetNum("rankColumn3._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn4",		"_x", MC.GetNum("rankColumn4._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn5",		"_x", MC.GetNum("rankColumn5._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn6",		"_x", MC.GetNum("rankColumn6._x") - AdjustXOffset);
	MC.ChildSetNum("rankColumn7",		"_x", MC.GetNum("rankColumn6._x"));
	MC.ChildSetNum("rankColumn7",		"_y", MC.GetNum("rankColumn6._y"));	
}


function AnimatIn()
{
	local int i;

	MC.ChildSetNum("bg", "_alpha", 0);
	AddChildTweenBetween("bg", "_alpha", 0, 100, 0.3f);
	//AddChildTween("bg", "_y", 68, 0.3f , 0, "easeoutquad");

	MC.ChildSetNum("factionLogo", "_alpha", 0);
	AddChildTweenBetween("factionLogo", "_alpha", 0, 100, 0.3f);

	MC.ChildSetNum("rankIcon", "_alpha", 0);
	AddChildTweenBetween("rankIcon", "_alpha", 0, 100, 0.3f);

	MC.ChildSetNum("classIcon", "_alpha", 0);
	AddChildTweenBetween("classIcon", "_alpha", 0, 100, 0.3f);

	MC.ChildSetNum("factionLogoLarge", "_alpha", 0);
	AddChildTweenBetween("factionLogoLarge", "_alpha", 0, 100, 0.3f, 0.5f);

	MC.ChildSetNum("columnGradients", "_alpha", 0);
	AddChildTweenBetween("columnGradients", "_alpha", 0, 100, 0.3f, 0.4f);

	MC.ChildSetNum("factionName", "_alpha", 0);
	AddChildTweenBetween("factionName", "_alpha", 0, 100, 0.2f, 0.2f);
	//AddChildTween("factionName", "_x", 280, 0.2f , 0.2f, "easeoutquad");

	MC.ChildSetNum("unitName", "_alpha", 0);
	AddChildTweenBetween("unitName", "_alpha", 0, 100, 0.2f, 0.2f);
	//AddChildTween("unitName", "_x", 280, 0.2f , 0.2f, "easeoutquad");

	for (i = 0; i < Columns.Length; i++)
	{
		MC.ChildSetNum("rankColumn" $ i, "_alpha", 0);
		AddChildTweenBetween("rankColumn" $ i, "_alpha", 0, 100, 0.2f, 0.3f);
		AddChildTween("rankColumn" $ i, "_y", 200, 0.2f , 0.3f, "easeoutquad");
	}

	MC.ChildSetNum("combatIntelLabel", "_alpha", 0);
	AddChildTweenBetween("combatIntelLabel", "_alpha", 0, 67, 0.2f, 0.2f);

	MC.ChildSetNum("combatIntelValue", "_alpha", 0);
	AddChildTweenBetween("combatIntelValue", "_alpha", 0, 100, 0.2f, 0.3f);

	// Commented out because it cause the elements to disappear
	// Don't know why this happens
	// Left this in for later analysis

	//AddChildTween("combatIntelValue", "_y", 123, 0.2f , 0.2f, "easeoutquad");

	//MC.ChildSetNum("teamAPLabel", "_alpha", 0);
	//AddChildTweenBetween("teamAPLabel", "_alpha", 0, 67, 0.2f, 0.2f);
	
	//MC.ChildSetNum("teamAPValue", "_alpha", 0);
	//AddChildTweenBetween("teamAPValue", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("teamAPValue", "_y", 112, 0.2f , 0.2f, "easeoutquad");
	
	//MC.ChildSetNum("soldierAPLabel", "_alpha", 0);
	//AddChildTweenBetween("soldierAPLabel", "_alpha", 0, 67, 0.2f, 0.2f);

	//MC.ChildSetNum("soldierAPValue", "_alpha", 0);
	//AddChildTweenBetween("soldierAPValue", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("soldierAPValue", "_y", 112, 0.2f , 0.2f, "easeoutquad");

	//MC.ChildSetNum("headerLines", "_alpha", 0);
	//AddChildTweenBetween("headerLines", "_alpha", 0, 100, 0.4f, 0.3f);
	//AddChildTween("headerLines", "_x", 500, 0.4f , 0.3f, "easeoutquad");

	//MC.ChildSetNum("topDivider", "_xscale", 0.1);
	//AddChildTweenBetween("topDivider", "_xscale", 0.1, 100, 0.4f, 0.4f);
	
	//MC.ChildSetNum("bottomDivider", "_xscale", 0.1);
	//AddChildTweenBetween("bottomDivider", "_xscale", 0.1, 100, 0.4f, 0.4f);
	
	//MC.ChildSetNum("abilityLabel", "_alpha", 0);
	//AddChildTweenBetween("abilityLabel", "_alpha", 0, 100, 0.2f, 0.3f);
	
	//MC.ChildSetNum("abilityPathHeader", "_alpha", 0);
	//AddChildTweenBetween("abilityPathHeader", "_alpha", 0, 100, 0.2f, 0.3f);
	
	//MC.ChildSetNum("pathLabel0", "_alpha", 0);
	//AddChildTweenBetween("pathLabel0", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("pathLabel0", "_x", 30, 0.2f , 0.35f, "easeoutquad");
	//
	//MC.ChildSetNum("pathLabel1", "_alpha", 0);
	//AddChildTweenBetween("pathLabel1", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("pathLabel1", "_x", 30, 0.2f , 0.35f, "easeoutquad");
	//
	//MC.ChildSetNum("pathLabel2", "_alpha", 0);
	//AddChildTweenBetween("pathLabel2", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("pathLabel2", "_x", 30, 0.2f , 0.35f, "easeoutquad");
	//
	//MC.ChildSetNum("pathLabel3", "_alpha", 0);
	//AddChildTweenBetween("pathLabel3", "_alpha", 0, 100, 0.2f, 0.3f);
	//AddChildTween("pathLabel3", "_x", 30, 0.2f , 0.35f, "easeoutquad");
	
	//MC.ChildSetNum("descriptionIcon", "_alpha", 0);
	//AddChildTweenBetween("descriptionIcon", "_alpha", 0, 100, 0.2f, 0.6f);

	//MC.ChildSetNum("descriptionTitle", "_alpha", 0);
	//AddChildTweenBetween("descriptionTitle", "_alpha", 0, 100, 0.2f, 0.6f);
	//AddChildTween("descriptionTitle", "_x", 283, 0.2f , 0.6f, "easeoutquad");
		
	//MC.ChildSetNum("descriptionDetail", "_alpha", 0);
	//AddChildTweenBetween("descriptionDetail", "_alpha", 0, 100, 0.2f, 0.65f);
	
	//MC.ChildSetNum("costLabel", "_alpha", 0);
	//AddChildTweenBetween("costLabel", "_alpha", 0, 100, 0.2f, 0.65f);
	//AddChildTween("costLabel", "_x", 975, 0.2f , 0.65f, "easeoutquad");
	
	//MC.ChildSetNum("costValue", "_alpha", 0);
	//AddChildTweenBetween("costValue", "_alpha", 0, 100, 0.2f, 0.65f);
	//AddChildTween("costValue", "_y", 785, 0.2f , 0.65f, "easeoutquad");
	
	//MC.ChildSetNum("apLabel", "_alpha", 0);
	//AddChildTweenBetween("apLabel", "_alpha", 0, 97, 0.2f, 0.7f);
}


simulated function AddChildTween(string ChildPath, String Prop, float Value, float Time, optional float Delay = 0.0, optional String Ease = "linear" )
{
	MC.BeginChildFunctionOp(ChildPath, "addTween"); 

	MC.QueueString(Prop);   
	MC.QueueNumber(Value);  
	
	MC.QueueString("time");  
	MC.QueueNumber(Time);  

	if( Delay != 0.0 )
	{
		MC.QueueString("delay");  
		MC.QueueNumber(Delay);
	}

	if( Ease != "linear" )
	{
		MC.QueueString("ease");  
		MC.QueueString(Ease); 
	}

	MC.EndOp();
}

simulated function AddChildTweenBetween(string ChildPath, String Prop, float StartValue, float EndValue, float Time, optional float Delay = 0.0, optional String Ease = "linear" )
{
	MC.BeginChildFunctionOp(ChildPath, "addTweenBetween");

	MC.QueueString(Prop);
	MC.QueueNumber(StartValue);
	MC.QueueNumber(EndValue);

	MC.QueueString("time");
	MC.QueueNumber(Time);

	if( Delay != 0.0 )
	{
		MC.QueueString("delay");
		MC.QueueNumber(Delay);
	}

	if( Ease != "linear" )
	{
		MC.QueueString("ease");
		MC.QueueString(Ease);
	}

	MC.EndOp();
}

// Start Issue #28
// Replace parent class functions that serve no purpose in CPS, but may get called anyway, generating log errors.
simulated function UpdateClassRowSelection() {}

simulated function Hide()
{
	super(UIScreen).Hide();

	if (NavHelp != none)
	{
		NavHelp.Hide();
	}
}

simulated function OnReceiveFocus()
{
	local XComHQPresentationLayer HQPres;

	super(UIArmory).OnReceiveFocus();

	HQPres = XComHQPresentationLayer(Movie.Pres);

	if(HQPres != none)
	{
		if(bAfterActionPromotion) //If the AfterAction screen is running, let it position the camera
			HQPres.CAMLookAtNamedLocation(AfterActionScreen.GetPromotionBlueprintTag(UnitReference), `HQINTERPTIME);
		else
			HQPres.CAMLookAtNamedLocation(CameraTag, `HQINTERPTIME);
	}

	UpdateNavHelp();

	Columns[m_iCurrentlySelectedColumn].OnReceiveFocus();
}

private simulated function bool OnUnrealCommand_UIArmory_PromotionHero_Override(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	bHandled = true;
	
	bHandled = Columns[m_iCurrentlySelectedColumn].OnUnrealCommand(cmd, arg); // bsg-nlong (1.25.17): Send the input to the column first and see if it can consume it
	if (bHandled) return true;

	switch(cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT:
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT:
		SelectNextColumn();
		bHandled = true;
		break;
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
		SelectPrevColumn();
		bHandled = true;
		break;
	default:
		bHandled = false;
		break;
	}

	return bHandled || OnUnrealCommand_UIArmory_Promotion_Override(cmd, arg);
}

private simulated function bool OnUnrealCommand_UIArmory_Promotion_Override(int cmd, int arg)
{
	//local XComGameStateHistory History;
	local bool bHandled;
	//local name SoldierClassName;
	//local XComGameState_Unit UpdatedUnit;
	//local XComGameState UpdateState;
	//local XComGameStateContext_ChangeContainer ChangeContainer;
	local XComGameState_Unit Unit;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));

	// Only pay attention to presses or repeats; ignoring other input types
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	// Issue #28 - List is not used.
	//if (List.GetSelectedItem().OnUnrealCommand(cmd, arg))
	//{
	//	UpdateNavHelp();
	//	return true;
	//}

	bHandled = true;

	switch( cmd )
	{
		// DEBUG: Press Tab to rank up the soldier
		//`if (`notdefined(FINAL_RELEASE))
		//case class'UIUtilities_Input'.const.FXS_KEY_TAB:
		//	History = `XCOMHISTORY;
		//	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("DEBUG Unit Rank Up");
		//	UpdateState = History.CreateNewGameState(true, ChangeContainer);
		//	UpdatedUnit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', GetUnit().ObjectID));

		//	if (UpdatedUnit.GetRank() == 0)
		//		SoldierClassName = class'UIUtilities_Strategy'.static.GetXComHQ().SelectNextSoldierClass();

		//	UpdatedUnit.RankUpSoldier(UpdateState, SoldierClassName);

		//	`GAMERULES.SubmitGameState(UpdateState);

		//	PopulateData();
		//	break;
		//`endif
		case class'UIUtilities_Input'.const.FXS_MOUSE_5:
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
		case class'UIUtilities_Input'.const.FXS_MOUSE_4:
		case class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT:
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
			// Prevent switching soldiers during AfterAction promotion
			if( UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction')) == none )
				bHandled = false;
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			OnCancel();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_X: // bsg-jrebar (4/21/17): Changed UI flow and button positions per new additions
			MakePosterButton();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_SELECT : // bsg-jrebar (4/21/17): Changed UI flow and button positions per new additions
			//bsg-hlee (05.09.17): If the nav help does not how up do not allow the button to navigate to the facility. Condition taken from UpdateNavHelp when deciding to add the nav help or not.
			if( class'UIUtilities_Strategy'.static.GetXComHQ().HasFacilityByName('RecoveryCenter') && IsAllowedToCycleSoldiers() && !`ScreenStack.IsInStack(class'UIFacility_TrainingCenter')
			&& !`ScreenStack.IsInStack(class'UISquadSelect') && !`ScreenStack.IsInStack(class'UIAfterAction') && Unit.GetSoldierClassTemplate().bAllowAWCAbilities)
				JumpToRecoveryFacility();
		default:
			bHandled = false;
			break;
	}

	//if (List.Navigator.OnUnrealCommand(cmd, arg))
	//{
	//	return true;
	//}
	
	return bHandled || super(UIArmory).OnUnrealCommand(cmd, arg);
}
// End Issue #28