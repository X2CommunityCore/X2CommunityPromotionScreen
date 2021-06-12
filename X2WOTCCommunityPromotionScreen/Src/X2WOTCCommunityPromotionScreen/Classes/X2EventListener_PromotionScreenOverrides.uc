//---------------------------------------------------------------------------------------
//  FILE:    X2EventListener_PromotionScreenOverrides.uc
//  AUTHOR:  Peter Ledbrook
//  PURPOSE: Provides the event listeners that replace the standard (vanilla)
//           promotion screens with the Community Promotion Screen.
//---------------------------------------------------------------------------------------
class X2EventListener_PromotionScreenOverrides extends X2EventListener config(PromotionUIMod);

// Issue #44
// The SPARK ability tree titles to use if no other mod has set
// them (since the base game doesn't provide any itself).
var localized array<string> SparkAbilityTreeTitles;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateListeners());

	return Templates;
}

static function CHEventListenerTemplate CreateListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'X2WOTCCPS_PromotionScreenListeners');

	// Set priority below default, so that if a mod wants to use a custom promotion screen under specific circumstances, 
	// they can do so even with default priority.
	Template.AddCHEvent('OverridePromotionBlueprintTagPrefix', OverridePromotionBlueprintTagPrefix, ELD_Immediate, 40);
	Template.AddCHEvent('OverridePromotionUIClass', OverridePromotionUIClass, ELD_Immediate, 40);
	Template.AddCHEvent('OverrideLocalizedAbilityTreeTitle', FixSparkAbilityTitles, ELD_Immediate, 30);
	Template.RegisterInStrategy = true;

	return Template;
}

static function EventListenerReturn OverridePromotionBlueprintTagPrefix(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitState;
	local UIAfterAction AfterActionScreen;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
	{
		return ELR_NoInterrupt;
	}

	UnitState = XComGameState_Unit(Tuple.Data[0].o);
	if (UnitState == none)
	{
		return ELR_NoInterrupt;
	}

	AfterActionScreen = UIAfterAction(EventSource);
	if (AfterActionScreen == none)
	{
		return ELR_NoInterrupt;
	}

	// CPS will change the soldier's position on the promotion screen, unless they are a psi operative.
	if (!UnitState.IsPsiOperative())
	{
		Tuple.Data[1].s = UnitState.IsGravelyInjured() ?
				AfterActionScreen.UIBlueprint_PrefixHero_Wounded :
				AfterActionScreen.UIBlueprint_PrefixHero;
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OverridePromotionUIClass(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local CHLPromotionScreenType ScreenType;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
	{
		return ELR_NoInterrupt;
	}

	ScreenType = CHLPromotionScreenType(Tuple.Data[0].i);

	// CPS will always replace standard and hero promotion screens.
	if (ScreenType == eCHLPST_Hero || ScreenType == eCHLPST_Standard)
	{
		Tuple.Data[1].o = class'X2WOTCCommunityPromotionScreen.CPS_UIArmory_PromotionHero';
	}

	return ELR_NoInterrupt;
}

// Issue #44: Add ability tree titles for SPARKs if there aren't any set up yet
static function EventListenerReturn FixSparkAbilityTitles(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name InEventID,
	Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComLWTuple Tuple;
	local int Row, i;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	Row = Tuple.Data[0].i;

	if (UnitState.GetSoldierClassTemplateName() == 'Spark' &&
		UnitState.GetSoldierClassTemplate().AbilityTreeTitles.Length == 0)
	{
		Tuple.Data[1].s = default.SparkAbilityTreeTitles[Row];
	}

	return ELR_NoInterrupt;
}
