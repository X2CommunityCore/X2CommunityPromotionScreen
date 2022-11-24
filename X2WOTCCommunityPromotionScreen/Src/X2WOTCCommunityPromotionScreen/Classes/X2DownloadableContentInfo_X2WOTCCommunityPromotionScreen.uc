class X2DownloadableContentInfo_X2WOTCCommunityPromotionScreen extends X2DownloadableContentInfo;

`include(X2WOTCCommunityPromotionScreen\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static event OnPostTemplatesCreated()
{
	// Issue #25
	FixTemplarMomentumBug();
}

// Start Issue #25
static private function FixTemplarMomentumBug()
{
	local X2SoldierClassTemplateManager	Mgr;
	local X2SoldierClassTemplate		Template;	
	local SoldierClassAbilitySlot		EmptySlot;
	local SoldierClassAbilitySlot		MomentumSlot;
	local array<X2DataTemplate>			DataTemplates;
	local X2DataTemplate				DataTemplate;

	Mgr = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	Mgr.FindDataTemplateAllDifficulties('Templar', DataTemplates);
	MomentumSlot.AbilityType.AbilityName = 'Momentum';

	foreach DataTemplates(DataTemplate)
	{
		Template = X2SoldierClassTemplate(DataTemplate);

		// Requires unprotecting X2SoldierClassTemplate.SoldierRanks
		if (Template.SoldierRanks.Length != 0 &&
			Template.SoldierRanks[0].AbilitySlots.Length > 4 &&
			Template.SoldierRanks[0].AbilitySlots[3] == EmptySlot &&
			Template.SoldierRanks[0].AbilitySlots[4] == MomentumSlot)
		{
			Template.SoldierRanks[0].AbilitySlots[3] = MomentumSlot;
			Template.SoldierRanks[0].AbilitySlots.Remove(4, 1);

		}

		// Patching SoldierRanks in template instance *should* be enough, 
		// but let's patch 'default' SoldierRanks as well just to be super duper safe.
		if (Template.default.SoldierRanks.Length != 0 && 
			Template.default.SoldierRanks[0].AbilitySlots.Length > 4 &&
			Template.default.SoldierRanks[0].AbilitySlots[3] == EmptySlot &&
			Template.default.SoldierRanks[0].AbilitySlots[4] == MomentumSlot)
		{
			Template.default.SoldierRanks[0].AbilitySlots[3] = MomentumSlot;
			Template.default.SoldierRanks[0].AbilitySlots.Remove(4, 1);
		}
	}
}
// End Issue #25

static function OnPreCreateTemplates()
{
    // Issue #26
	Neuter_NPSBD_UISL();

	// Issue #62
	Update_ViewLockedSkills_UISL();
}

// Start Issue #26
static final function Neuter_NPSBD_UISL()
{
	local UIScreenListener CDO;

    CDO = UIScreenListener(class'XComEngine'.static.GetClassDefaultObject(class'NewPromotionScreenbyDefault.NewPromotionScreenByDefault_PromotionScreenListener'));
    if (CDO != none)
    {
        CDO.ScreenClass = class'UIScreen_Dummy';
    }
}
// End Issue #26

// Start Issue #62
/// This handles CPS' compatibility with View Locked Skills - Wotc
/// https://steamcommunity.com/sharedfiles/filedetails/?id=1130817270
/// When CPS is configured to show perks from unreached ranks via MCM, 
/// View Locked Skills' UISL is neutered.
/// The UISL is un-neutered if Show Unreached Perks is disabled.
/// This allows both mods to coexist without stepping on each other's toes too much,
/// even though View Locked Skills is mostly redundant with CPS.
static final function Update_ViewLockedSkills_UISL()
{
	local UIScreenListener CDO;

	CDO = UIScreenListener(class'XComEngine'.static.GetClassDefaultObjectByName('Main_ViewLockedSkillsWotc'));
	if (CDO != none)
	{	
		if (`GETMCMVAR(SHOW_UNREACHED_PERKS))
		{
			CDO.ScreenClass = class'UIScreen_Dummy';
		}
		else if (CDO.ScreenClass == class'UIScreen_Dummy')
		{
			CDO.ScreenClass = none;
		}
	}
}
// End Issue #62

// move the auto promoting of soldiers who did not go on the current mission here.
static event OnLoadedSavedGameToStrategy() {}

// auto promote feature. This only promotes the soldiers that went on the mission. Other soldiers will be promoted on a load of a save.
/* Almost forgot, still need to add our spin on it and have a config preset that does the auto promoting sequentially
   if the player indicates that they want all troops to be autopromoted, even if there is no ability planner markings.
   How do we handle mod classes that aren't from the standard game?
*/
static event onPostMission() {
	local StateObjectReference UnitRef;
	local XComGameState_Unit Unit, UpdatedUnit;
	local XComGameStateContext_ChangeContainer Container;
	local XComGameState UpdateState;
	local XComGameState_HeadquartersXCom XCOMHQ;
	local XComGameStateHistory History;
	local int i, PlannerIndex, PendingRank, PendingBranch; // keep naming consistent
	local array<SoldierClassAbilityType> RankAbilities;
	local bool Ability;
	local SCATProgression Value;
	`log("=================================");
	`log("onPostMission in Promotion Screen Mod");
	PlannerIndex = 1;
	History = `XCOMHISTORY;
	XCOMHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	Container = class 'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Soldier Promotion");
	UpdateState = History.CreateNewGameState(true, Container);
	`log("Checking values that could be used to determine eligibility promotion");
	`log("ObjectIDs of the entire roster");
	for (i = 0; i < XCOMHQ.Crew.Length; i++) {
		// Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XCOMHQ.Crew[i].ObjectID));
		Unit = XComGameState_Unit(UpdateState.ModifyStateObject(class 'XComGameState_Unit', XCOMHQ.Crew[i].ObjectID));
		PlannerIndex = 1;
		`log(XCOMHQ.Crew[i].ObjectID);
		// still need to confirm if a unit can be a soldier and a resistance hero
		if (Unit.IsAlive() && Unit.IsSoldier() || Unit.IsResistanceHero() && Unit.CanRankUpSoldier()) {
			Value = GetAbilityName(Unit, PlannerIndex);
			PendingRank = Value.iRank;
			PendingBranch = Value.iBranch;
			if (PendingRank == INDEX_NONE || PendingBranch == INDEX_NONE && `GETMCMVAR(AUTO_PROMOTE)) {
			// add our config array manipulation around here
			// if they have no abilities marked, default to the config files.
			// figure out how to add it as an option to the MCM.
			`log("they haven't marked any abilities on the planner");
			}
			`log("This Unit is eligible to Promote, start process");

			// If it isn't unlockable, skip buying an ability until it is. If the player wants the first ability unlocked
			// to be from a higher rank, than so be it.
			if (Unit.GetCurrentRank() + 1 < PendingRank) {
				`log("The Unit is not the same rank as the pending rank. Remember, we added 1 to the value resolved from GetCurrentRank()");
				`log("This means that the unit is not ready to buy this ability");
				`log(Unit.GetCurrentRank());
				`log(PendingRank)
				continue;
			}
			// buy the ability
			// still need to confirm if the soldier will continue to promote even if no ability is purchased.
			Unit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch);
			
			// Check if the soldier is eligible to purchase the next ability marked from the ability planner.
			while(true) {
				PlannerIndex++;
				Value = GetAbilityName(Unit, PlannerIndex);
				if (Value.iRank == INDEX_NONE || Value.iBranch == INDEX_NONE) {
					`log("Unit is not eligible to purchase next ability on the planner, move on");
					break;
				}
				if (Unit.GetCurrentRank() + 1 < Value.iRank) {
					`log("The Unit is not the same rank as the pending rank. Remember, we added 1 to the value resolved from GetCurrentRank()");
					`log("This means that the unit is not ready to buy this ability");
					`log(Unit.GetCurrentRank());
					`log(PendingRank)
					break;
				}
				PendingRank = Value.iRank;
				PendingBranch = Value.iBranch;
				Unit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch);
			}
		}
	}
	`log("ObjectIDs of the deployed squad returning from mission");
	foreach `XCOMHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		`log(UnitRef.ObjectID);
	}


}

// this function name is misleading. It gets the ability name to then return the rank and branch from the ability tree.
function SCATProgression GetAbilityName(Unit, PlannerIndex) {
	local SoldierRankAbilities		AbilityTree;
	local SoldierClassAbilityType	AbilityType;
	local int i;
	local string AbilityTagPrefix ;
	local UnitValue UV;
	local SCATProgression RB; // rank and branch
	
	AbilityTagPrefix= "CPS_AbilityTag_";
	foreach Unit.AbilityTree(AbilityTree)
	{
		foreach AbilityTree.Abilities(AbilityType)
		{
			// iterate through the ability names and find the ability that was marked from the ability planner
			if (Unit.GetUnitValue(name(AbilityTagPrefix $ AbilityType.AbilityName), UV).fValue == float(PlannerIndex)) {
				// get the rank and branch
				RB = Unit.GetSCATProgressionForAbility(AbilityType.AbilityName);
				return RB;
			}
		}
	}
	// if we didn't return anything, we need to. This signifies that the ability is not marked on the ability tree
	RB.iBranch = INDEX_NONE;
	RB.iRank = INDEX_NONE;
	return RB;
}
