// This is an Unreal Script
class AutoPromote extends X2DownloadableContentInfo;

struct SoldierTypes {
	var name soldierClass;
	var int squaddie;
	var int corporal;
	var int sergeant;
	var int lieutenant;
	var int captain;
	var int major;
	var int colonel;
};

var config array<SoldierTypes> ClassPresets;

// default.varname to access the config variables
// Send over the unit
static function autoPromote(XComGameState_Unit Unit, XComGameState UpdateState) {
	local name soldierType;
	local int Index, iRank, iBranch;
	soldierType = Unit.GetSoldierClassTemplateName();
	iRank = Unit.GetSoldierRank();
	Index = default.ClassPresets.find('soldierClass', soldierType);
	`log("soldierType, iRank, Index");
	`log(soldierType);
	`log(iRank);
	`log(Index);
	if (Index != INDEX_NONE) {
	// The soldier's class has a preset, autopromote it
		switch(iRank) {
			case 1: 
			iBranch = default.ClassPresets[Index].corporal;
			break;
			case 2:
			iBranch = default.ClassPresets[Index].sergeant;
			break;
			case 3:
			iBranch = default.ClassPresets[Index].lieutenant;
			break;
			case 4:
			iBranch = default.ClassPresets[Index].captain;
			break;
			case 5:
			iBranch = default.ClassPresets[Index].major;
			break;
			case 6:
			iBranch = default.ClassPresets[Index].colonel;
			break;
			default:
			iBranch = default.ClassPresets[Index].squaddie;
			break;
		}
		Unit.BuySoldierProgressionAbility(UpdateState,iRank,iBranch);
		`GAMERULES.SubmitGameState(UpdateState); // maybe needed this line?
	}
	// if it doesn't have a preset, not our problem.
}


static function SCATProgression GetAbilityNameIndexes(XComGameState_Unit Unit, int PlannerIndex) {
	local SoldierRankAbilities		AbilityTree;
	local SoldierClassAbilityType	AbilityType;
	local string AbilityTagPrefix;
	local UnitValue UV;
	local SCATProgression RB; // rank and branch
	
	AbilityTagPrefix= "CPS_AbilityTag_";
	foreach Unit.AbilityTree(AbilityTree)
	{
		foreach AbilityTree.Abilities(AbilityType)
		{
			// iterate through the ability names and find the ability that was marked from the ability planner
			// error: Unexpected '.' folowing ''
			if (Unit.GetUnitValue(name(AbilityTagPrefix $ AbilityType.AbilityName), UV)) {
				if (UV.fValue == float(PlannerIndex)) {
					// remove the Unit Value from the Unit
					Unit.ClearUnitValue(name(AbilityTagPrefix $ AbilityType.AbilityName));
					// get the rank and branch
					RB = Unit.GetSCATProgressionForAbility(AbilityType.AbilityName);
					return RB;
				}
			}
		}
	}
	// if we didn't return anything, we need to. This signifies that no ability is marked on the ability tree
	RB.iBranch = INDEX_NONE;
	RB.iRank = INDEX_NONE;
	return RB;
}