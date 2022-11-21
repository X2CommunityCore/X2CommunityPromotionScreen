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


// auto promote feature. Run at the end of every mission so no soldier gets left behind.
// could have it so it only iterates through all soldiers on a load and then only the squad on the post mission.
static event onPostMission() {
	local StateObjectReference UnitRef;
	local XComGameState_Unit Unit, UpdatedUnit;
	local XComGameStateContext_ChangeContainer Container;
	local XComGameState UpdateState;
	local XComGameState_HeadquartersXCom XCOMHQ;
	local XComGameStateHistory History;
	local array<CPS_UIAbilityTag> AbilityArray;
	local int i, CurrentRank;
	local array<SoldierClassAbilityType> RankAbilities;
	local bool Ability
	`log("=================================");
	`log("onPostMission in Promotion Screen Mod");

	History = `XCOMHISTORY;
	XCOMHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	AbilityArray = class 'CPS_UIArmory_PromotionHeroColumn'.default.AbilityTagIcons;
	Container = class 'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Soldier Promotion");
	UpdateState = History.CreateNewGameState(true, Container);
	`log("length of the variable");
	`log(AbilityArray.Length);
	`log("Checking values that could be used to determine eligibility promotion");
	`log("ObjectIDs of the entire roster");
	for (i = 0; i < XCOMHQ.Crew.Length; i++) {
		// Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XCOMHQ.Crew[i].ObjectID));
		Unit = XComGameState_Unit(UpdateState.ModifyStateObject(class 'XComGameState_Unit', XCOMHQ.Crew[i].ObjectID));
		`log(XCOMHQ.Crew[i].ObjectID);
		if (Unit.IsAlive() && Unit.IsSoldier() && Unit.CanRankUpSoldier()) { // Unit.IsResistanceHero()
		// can a unit be a soldier and a resistance hero at the same time?
			ResearchBranch(Unit);
			`log("This Unit is eligible to Promote, start process");
			CurrentRank = Unit.GetSoldierRank();
			
			// read Unit.HasAvailablePerksToAssign() for how to do the checking
			RankAbilities = Unit.AbilityTree[CurrentRank - 1].Abilities;
			foreach RankAbilities(Ability)
			// need to figure out how to get PendingRank and PendingBranch (what is PendingBranch?)
			// need to check that the ability is unlockable before doing this. What if it isn't unlockable?
			// Problem: If the ability they want is for a higher rank, how do we
			// A. promote them but not buy an ability so they can continue to progress
			// B. go back and buy an ability from a lesser rank once they have acquired that ability
			// Solution to B: iterate backwards through the trees and check with the Unit Values if the current Ability has the number we are looking for.
			// Solution to A:
			// fix this to match solution B
			// If it isn't unlockable, skip buying an ability until it is. If the player wants the first ability unlocked
			// to be from a higher rank, than so be it.
			// Unit.BuySoldierProgressionAbility(UpdateState, CurrentRank + 1, PendingBranch)
		}
	}
	`log("ObjectIDs of the deployed squad returning from mission");
	foreach `XCOMHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		`log(UnitRef.ObjectID);
	}


}


function int GetBranchInt() {



}
// If we can determine the possible values for branch,
// then we may be able to do some math with the ability index numbers
// maybe wishful thinking.
function ResearchBranch(Unit) {
	local SoldierRankAbilities		AbilityTree;
	local SoldierClassAbilityType	AbilityType;
	local int i;
	foreach Unit.AbilityTree(AbilityTree)
	{
		for (i = 0; i < AbilityTree.Abilities.Length; i++)
		{
			`log("==========================================");
			`log("AbilityTree.Abilities[i].AbilityName");
			`log(AbilityTree.Abilities[i].AbilityName);
			`log("The index number");
			`log(i);
		}
	}
}