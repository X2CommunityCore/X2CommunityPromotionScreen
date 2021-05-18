class X2DownloadableContentInfo_NewPromotionScreenbyDefault extends X2DownloadableContentInfo;

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

exec function PSSetXoffsetBG(int AdjustXOffset)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	
	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));
	UI.MC.ChildSetNum("bg", "_x", AdjustXOffset);
}

exec function PSSetWidth(int Width)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	
	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));
	UI.MC.SetNum("_width", Width);
}

exec function PSSetXOffset(int AdjustXOffset)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	
	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));
	UI.MC.SetNum("_x", UI.MC.GetNum("_x") + AdjustXOffset);
}

exec function PSSetColumnWidth(int Offset = 200, int Width = 120)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	local int i;

	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));
	for (i = 0; i < UI.Columns.Length; i++)
	{
		if (i == 5 || i ==6)
			UI.Columns[i].MC.SetNum("_width", Width);
		//UI.Columns[i].SetX(Offset + (i * Width));
		
	}
}

exec function PSScrollBarSetPos(int X, int Y, int Anchor = -1)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));

	UI.Scrollbar.SetX(X);
	UI.Scrollbar.SetY(Y);

	if (Anchor > -1)
	{
		UI.Scrollbar.SetAnchor(Anchor);
	}
}

exec function PSScrollBarSetSize(int Width = 0, int Height = 0)
{
	local NPSBDP_UIArmory_PromotionHero UI;
	UI = NPSBDP_UIArmory_PromotionHero(`SCREENSTACK.GetFirstInstanceOf(class'NPSBDP_UIArmory_PromotionHero'));

	if (Width > 0)
	{
		UI.Scrollbar.SetWidth(Width);
	}

	if (Height > 0)
	{
		UI.Scrollbar.SetHeight(Height);
	}
}