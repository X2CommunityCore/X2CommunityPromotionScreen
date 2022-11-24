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
	local XComGameState_Unit Unit;
	local XComGameStateContext_ChangeContainer Container;
	local XComGameState UpdateState;
	local XComGameState_HeadquartersXCom XCOMHQ;
	local XComGameStateHistory History;
	local int i, PlannerIndex, PendingRank, PendingBranch;
	local SCATProgression Value;
	`log("=================================");
	`log("onPostMission in Promotion Screen Mod");
	// we only want to autopromote if the ability planner tree is active.
	if (!`GETMCMVAR(AUTO_PROMOTE)) {
		`log("Player has no interest in autopromoting of any kind. halt execution.");
		return;
	}
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
		if (Unit.IsAlive() && Unit.IsSoldier() && Unit.CanRankUpSoldier()) {
			Value = class 'AutoPromote'.static.GetAbilityNameIndexes(Unit, PlannerIndex);
			PendingRank = Value.iRank;
			PendingBranch = Value.iBranch;
			if (PendingRank == INDEX_NONE || PendingBranch == INDEX_NONE) {
			// add our config array manipulation around here
			// if they have no abilities marked, default to the config files.
			// figure out how to add it as an option to the MCM.
			`log("they haven't marked any abilities on the planner, and told us they want to automate promoting units so lets execute");
			class 'AutoPromote'.static.autoPromote(Unit, UpdateState);
			continue;
			}
			`log("This Unit is eligible to Promote, start process");

			// If it isn't unlockable, skip buying an ability until it is. If the player wants the first ability unlocked
			// to be from a higher rank, than so be it.
			if (Unit.GetSoldierRank() < PendingRank) {
				`log("The Unit is not the same rank as the pending rank.");
				`log(Unit.GetSoldierRank());
				`log(PendingRank);
				continue;
			}
			// buy the ability
			// still need to confirm if the soldier will continue to promote even if no ability is purchased.
			Unit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch);
			
			// Check if the soldier is eligible to purchase the next ability marked from the ability planner.
			while(true) {
				PlannerIndex++;
				Value = class 'AutoPromote'.static.GetAbilityNameIndexes(Unit, PlannerIndex);
				if (Value.iRank == INDEX_NONE || Value.iBranch == INDEX_NONE) {
					`log("Unit is not eligible to purchase next ability on the planner, move on");
					break;
				}
				if (Unit.GetSoldierRank() < Value.iRank) {
					`log("The Unit is not the same rank as the pending rank.");
					`log(Unit.GetSoldierRank());
					`log(PendingRank);
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


