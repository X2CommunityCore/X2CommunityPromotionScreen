class CPS_MCM_Defaults extends object config(X2WOTCCommunityPromotionScreen_DEFAULT);

var config int VERSION_CFG;

var config bool SHOW_INVENTORY_SLOT;
var config int SHOW_UNREACHED_PERKS_MODE; // Issue #69
var config bool DISABLE_TRAINING_CENTER_REQUIREMENT;
var config bool DISABLE_NEWCLASS_POPUPS;
var config bool DISABLE_COMINT_POPUPS;
var config int ABILITY_TREE_PLANNER_MODE;

var config bool SHOW_UNREACHED_PERKS; // Issue #94 - backwards compatibility for Issue #69