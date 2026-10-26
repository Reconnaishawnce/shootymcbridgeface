class_name Season
extends RefCounted
## The free season track: thirty days, thirty tiers, a reward at every
## one. Quest points move you up it. Nothing to buy. Pure.

const DAYS := 30
const TIERS := 30
const POINTS_PER_TIER := 100
## Locker items the track hands out at every fifth tier. The list turns
## with the season so a later season gives different ones.
const ITEM_POOL := ["cap", "sunny", "candy", "wings", "pip", "crown", "beanie", "berry", "ice", "balloon", "kofi", "viking", "headband", "mint", "wood", "shell", "luna", "halo"]


static func number(day: int) -> int:
	return (maxi(day, 1) - 1) / DAYS + 1


static func day_in_season(day: int) -> int:
	return (maxi(day, 1) - 1) % DAYS + 1


static func tier_for(points: int) -> int:
	return clampi(points / POINTS_PER_TIER, 0, TIERS)


## Points into the current tier, for the bar.
static func tier_progress(points: int) -> int:
	if tier_for(points) >= TIERS:
		return POINTS_PER_TIER
	return points % POINTS_PER_TIER


## What [param tier] (1-based) pays in season [param season].
static func reward(season: int, tier: int) -> Dictionary:
	if tier % 5 == 0:
		var k := (tier / 5 - 1) + (season - 1) * 6
		return {"kind": "item", "id": ITEM_POOL[k % ITEM_POOL.size()]}
	if tier % 3 == 0:
		return {"kind": "stars", "amount": 2 + tier / 10}
	return {"kind": "coins", "amount": 60 + tier * 12}


static func reward_text(r: Dictionary) -> String:
	match str(r.kind):
		"item":
			return "%s (locker)" % Wardrobe.title(str(r.id))
		"stars":
			return "%d stars" % int(r.amount)
	return "%d coins" % int(r.amount)


static func blank(season: int) -> Dictionary:
	return {"season": season, "points": 0, "claimed": 0}


## Add [param points] for season [param season]. Returns the new state
## and the rewards newly reached, in tier order.
static func advance(state: Dictionary, season: int, points: int) -> Dictionary:
	var st := state.duplicate(true)
	if int(st.get("season", -1)) != season:
		st = blank(season)
	st.points = int(st.points) + maxi(points, 0)
	var tier := tier_for(int(st.points))
	var rewards := []
	for t in range(int(st.claimed) + 1, tier + 1):
		var r := reward(season, t)
		r.tier = t
		rewards.append(r)
	st.claimed = maxi(int(st.claimed), tier)
	return {"state": st, "rewards": rewards}
