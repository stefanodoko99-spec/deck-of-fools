class_name Monetization
extends RefCounted
## Which money features this build has:
## - "off": coins, the daily gift and the coin shop only. No ads and no real-money
##   store. This is the published web game until the store and ads are connected.
## - "test": everything, with stand-in providers that charge nothing and show a
##   placeholder instead of an ad (dev gallery, debug runs, and builds exported with
##   the custom feature "store_test"). For trying the flow end to end.
## - "live": the real ad network and store, for builds exported with the custom
##   feature "store_live" once the providers are connected (docs/MONETIZATION.md).


static func mode() -> String:
	if OS.has_feature("store_live"):
		return "live"
	if OS.has_feature("store_test") or OS.has_feature("preview") or OS.is_debug_build():
		return "test"
	return "off"
