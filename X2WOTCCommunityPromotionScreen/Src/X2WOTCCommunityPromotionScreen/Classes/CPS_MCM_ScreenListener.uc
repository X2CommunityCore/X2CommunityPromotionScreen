class CPS_MCM_ScreenListener extends UIScreenListener;

event OnInit (UIScreen Screen)
{
	local CPS_MCM_Screen MCMScreen;

	if (ScreenClass == none)
	{
		if (MCM_API(Screen) != none)
		{
			ScreenClass = Screen.Class;
		}
		else
		{
			return;
		}
	}

	MCMScreen = new class'CPS_MCM_Screen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
