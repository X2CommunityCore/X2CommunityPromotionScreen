# Community Promotion Screen

## Description

This is the code repository for the XCOM 2 Community Promotion Screen mod, which is an expanded version of the fantastic [New Promotion Screen by Default](https://github.com/Xesyto/New-Promotion-Screen-by-Default) created by Xesyto.

## Improvements

* Added [Mod Config Menu](https://steamcommunity.com/sharedfiles/filedetails/?id=667104300) support.
* Vastly improved controller support.
* Added and documented multiple events for other mods to interact with.
* `ClassCustomAbilityCost` entries can now use empty `ClassName` to make the `AbilityCost` apply to all soldier classes. Class-specific cost still takes priority.
* Added localization for SPARK ability row titles in all languages, and in a way that will not interfere with mods adding their own localization for them ([#44](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/44)).
* "More info" yellow question mark icon will be shown for all revealed abilities ([#42](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/42)).
* Support mutually exclusive abilities setup on ability templates ([#9](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/pull/9)).
* Bigfix: scrollbar no longer gets misplaced when in windowed mode.
* Bugfix: "promotion available" banner no longer displays if the soldier can't actually unlock any new perks.

## Backwards Compatibility Policy

Can be reivewed [here](https://github.com/X2CommunityCore/X2CommunityPromotionScreen/issues/31).
