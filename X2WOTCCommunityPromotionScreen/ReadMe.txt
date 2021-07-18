
[b]Community Promotion Screen[/b] is an expanded and improved version of the [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1124609091]New Promotion Screen By Default[/url][/b]. 

It replaces the standard soldier promotion screen with a modified version of the "Faction Hero" promotion screen that was added in War of the Chosen.

[h1]New Features[/h1]
[list]
[*] Added [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=667104300]Mod Config Menu[/url][/b] support.
[*] Ability tagging - while on the promotion screen, you can click locked abilities to tag them. This is mostly useful for planning out soldiers' ability trees or marking important abilities so you don't forget to unlock them later. This feature is disabled by default, and needs to be enabled in Mod Config Menu. "Show perks from unreached ranks" setting must be enabled as well. Basic tagging mode simply marks abilities with an icon. Advanced mode will also display order numbers to indicate the sequence or priority in which you should unlock the abilities.
[*] Added and documented multiple events for other mods to interact with.
[/list]

[h1]Improvements[/h1]
[list]
[*] Vastly improved controller support.
[*] `ClassCustomAbilityCost` entries can now use an empty `ClassName` to make the `AbilityCost` apply to all soldier classes. Class-specific cost still takes priority.
[*] Added localization for SPARK ability row titles in all languages, and in a way that will not interfere with mods adding their own localization for them.
[*] "More info" yellow question mark icon will be shown for all revealed abilities.
[*] Support mutually exclusive abilities setup on ability templates.
[*] Bugfix: scrollbar no longer gets misplaced when in windowed mode.
[*] Bugfix: "promotion available" banner no longer displays if the soldier can't actually unlock any new perks.
[/list]

[h1]Compatibility[/h1]
[list]
[*] All mods that require [b]New Promotion Screen By Default[/b] can be used with the [b]Community Promotion Screen[/b] instead. Alternative Mod Launcher will warn you about a missing dependency, but it can be safely ignored in this case.
[*] Community Promotion Screen can be used together with [b]New Promotion Screen By Default[/b], but then the [b]New Promotion Screen By Default[/b] will be simply quietly disabled and will not do anything. You will also see an in-game warning popup saying that.
[*] Community Promotion Screen is [b][i]INCOMPATIBLE[/i][/b] with [url=https://steamcommunity.com/sharedfiles/filedetails/?id=1280477867][b]Musashis RPG Overhaul[/b][/url], as RPGO adds its own promotion screen.
[*] [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1130817270]View Locked Skills - Wotc[/url][/b] - Community Promotion Screen already has a "show perks from unreached ranks" MCM setting, but we took some measures so that these mods can coexist without stepping on each other's toes.
[/list]

[h1]Contributing to the project[/h1]

Everyone is welcome to contribute to the project via [GitHub](https://github.com/X2CommunityCore/X2CommunityPromotionScreen).

If you encounter a bug or have a suggesten, feel free to open an Issue, or file a Pull Request for one of the open Issues.

[h1]Credits[/h1]

Thanks to [b]RustyDios[/b] for providing the mod preview image.

Thank you for using the Community Promotion Screen. Our objective is to support all modmakers to be all they can be.

====================================================================================================================

Current version: 1.0
