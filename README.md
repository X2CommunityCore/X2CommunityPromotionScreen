# Community Promotion Screen

## Description

Community Promotion Screen is a mod for XCOM 2 War of the Chosen, an expanded version of the fantastic [New Promotion Screen by Default](https://github.com/Xesyto/New-Promotion-Screen-by-Default) created by Xesyto.

It replaces the standard soldier promotion screen with a modified version of the "Faction Hero" promotion screen that was added in War of the Chosen.

## New Features

* Added [Mod Config Menu](https://steamcommunity.com/sharedfiles/filedetails/?id=667104300) support.
* Ability tagging - while on the promotion screen, you can click locked abilities to tag them. This is mostly useful for planning out soldiers' ability trees or marking important abilities so you don't forget to unlock them later. This feature is disabled by default, and needs to be enabled in Mod Config Menu. "Show perks from unreached ranks" setting must be enabled as well. Basic tagging mode simply marks abilities with an icon. Advanced mode will also display order numbers to indicate the sequence or priority in which you should unlock the abilities.
* Added and documented multiple events for other mods to interact with.

## Improvements

* Vastly improved controller support.
* `ClassCustomAbilityCost` entries can now use an empty `ClassName` to make the `AbilityCost` apply to all soldier classes. Class-specific cost still takes priority.
* Added localization for SPARK ability row titles in all languages, and in a way that will not interfere with mods adding their own localization for them ([#44](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/44)).
* "More info" yellow question mark icon will be shown for all revealed abilities ([#42](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/42)).
* Support mutually exclusive abilities setup on ability templates ([#9](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/pull/9)).
* Bugfix: scrollbar no longer gets misplaced when in windowed mode.
* Bugfix: "promotion available" banner no longer displays if the soldier can't actually unlock any new perks.

## Contributing to the project

Everyone is welcome to contribute to the project via [GitHub](https://github.com/X2CommunityCore/X2CommunityPromotionScreen).

If you encounter a bug or have a suggesten, feel free to open an Issue, or file a Pull Request for one of the open Issues.

## Backwards Compatibility Policy

Can be reivewed [here](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/31).
