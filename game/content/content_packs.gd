class_name ContentPacks
extends RefCounted





static func register_all() -> void:
	ContentDB.reset()
	SignCards.register()
	ZanniBatch01.register()
	DeckMods.register()
	TarocchiCards.register()
	ZanniBatch03.register()
	ZanniBatch04.register()
	ZanniBatch05.register()
	ZanniBatch06.register()
	ZanniBatch07.register()
	ZanniBatch08.register()
	OmenCards.register()
	WarrantCards.register()
	PackDefs.register()
	PatronCards.register()
	FavorCards.register()
	DeckCards.register()
	StakeCards.register()
	ChallengeCards.register()
