extends "res://tests/suite.gd"
## The Jester collection (CollectionSheet): 150 numbered Jesters, and the words that tell a
## player how to unlock each locked Rare. Game.profile is swapped for a test profile and put
## back afterwards; nothing is saved.


func with_profile(p: Profile, body: Callable) -> void:
	var saved: Profile = Game.profile
	Game.profile = p
	body.call()
	Game.profile = saved


func test_numbered_lists_150_unique_jesters() -> void:
	var ids := CollectionSheet.numbered()
	eq(ids.size(), 150, "Jesters in the collection")
	var unique := {}
	for id in ids:
		unique[id] = true
		var def := ContentDB.get_def(id)
		check(def != null and def.kind == "zanni", "%s is a Jester" % id)
	eq(unique.size(), 150, "different ids")
	var pool := ContentDB.pool("zanni").map(func(d: ContentDef) -> String: return d.id)
	eq(Array(ids), pool, "numbered in the order the content registers them")
	var by_rarity := [0, 0, 0, 0]
	for id in ids:
		by_rarity[clampi(ContentDB.get_def(id).rarity, 0, 3)] += 1
	note("#1 %s ... #150 %s; common %d, uncommon %d, rare %d, legendary %d" % [ids[0], ids[-1], by_rarity[0], by_rarity[1], by_rarity[2], by_rarity[3]])


func test_lock_words_for_a_locked_rare() -> void:
	var p := Profile.new()
	with_profile(p, func() -> void:
		eq(CollectionSheet.lock_words("z_burattinaio"), "Have 5 Jesters at once", "locked Il Burattinaio")
		eq(CollectionSheet.lock_words("z_fenice"), "Lose 5 runs", "locked La Fenice (a lifetime count)")
		eq(CollectionSheet.lock_words("z_zanni"), "", "a common Jester is never locked")
		p.feats["jesters_5"] = true
		eq(CollectionSheet.lock_words("z_burattinaio"), "", "unlocked by its feat"))


func test_found_count_only_counts_jesters() -> void:
	var p := Profile.new()
	p.discovered = { "z_zanni": true, "z_arlecchino": true, "t_matto": true, "s_aries": true }
	with_profile(p, func() -> void:
		eq(CollectionSheet.found_count(), 2, "found Jesters"))


func test_every_rare_has_unlock_words() -> void:
	var ids := CollectionSheet.numbered()
	for id: String in Unlocks.RARE_FEATS:
		var def := ContentDB.get_def(id)
		check(def != null and def.rarity == 2 and ids.has(id), "%s is a Rare in the collection" % id)
		check(CollectionSheet.FEAT_WORDS.has(Unlocks.RARE_FEATS[id]), "%s's rule '%s' has words (it would say 'Keep playing')" % [id, Unlocks.RARE_FEATS[id]])
	for def in ContentDB.pool("zanni"):
		if def.rarity == 2:
			check(Unlocks.RARE_FEATS.has(def.id), "Rare %s has an unlock rule" % def.id)
	eq(Unlocks.RARE_FEATS.size(), 22, "Rare Jesters with a feat")


func test_every_unlock_feat_can_happen() -> void:
	# Each rule names a feat the game records (RunState/content code sets feats["..."]) or a
	# lifetime count Profile._met() knows.
	var source := ""
	for dir in ["res://core", "res://content"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				source += FileAccess.get_file_as_string(dir.path_join(file))
	check(source.length() > 10000, "read the game scripts")
	for rule: String in Unlocks.RARE_FEATS.values():
		if rule.begins_with("lifetime:"):
			var counter := rule.substr(9).split(">=")[0]
			check(counter in ["runs_lost", "signs_used"], "Profile._met() doesn't count '%s'" % counter)
		else:
			check(source.contains("feats[\"%s\"]" % rule), "nothing records the feat '%s'" % rule)
