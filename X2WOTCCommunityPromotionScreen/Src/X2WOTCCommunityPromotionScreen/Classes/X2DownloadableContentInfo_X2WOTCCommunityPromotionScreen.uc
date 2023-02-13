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

	// Issue #85
	Neuter_VariousOptions_UISL();
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

// Start Issue #85
static final function Neuter_VariousOptions_UISL()
{
	local UIScreenListener CDO;

    CDO = UIScreenListener(class'XComEngine'.static.GetClassDefaultObjectByName(name("VariousOptions.AdvancedAbilityButton")));
    if (CDO != none)
    {
        CDO.ScreenClass = class'UIScreen_Dummy';
    }
}
// End Issue #85

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
		if (`GETMCMVAR(SHOW_UNREACHED_PERKS_MODE) > 0)
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
