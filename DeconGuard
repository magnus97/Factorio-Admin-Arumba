-------------------------------------------------------------------------------
-- Initialization and config defaults
-------------------------------------------------------------------------------
function init_guard()

	global.guard =
	{
		data = {},
		bans = {},
		config = 
		{
			enabled = true;
			type_whitelist = {"tree", "simple-entity", "fish"},
			allow_neutral_force = true,
			exempt_admins = false,			
			guard_time = 2,		-- seconds
			ban_time = 15,		-- seconds
			guard_count = 5,			
			trusted_group = "trusted",
			
		},
		stats = {
			bans = 0
		}
	}
		
end

-------------------------------------------------------------------------------
-- Guard Functions
-------------------------------------------------------------------------------
function init_guard_user()	
	return { entities = {}, expires = {}, first = 0, last = -1 }
end

-- returns the size of a guard
function get_guard_size(pindex)
	local g = global.guard.data[pindex]
	return g.last - g.first + 1; 
end

-- Debug function
function dump_guard(pindex)
	local g = global.guard.data[pindex]
	if not g then
		return
	end 
	game.print("Guard dump for " .. game.players[pindex] .. " F=" .. g.first .. " L=" .. g.last)
	for i=g.first, g.last do
		game.print(i .. " - " .. g.entities[i].name )
	end
end

-- add new entity to the list
function add_guard(pindex, entity)
	if not global.guard.data[pindex] then		
		global.guard.data[pindex] = init_guard_user()
	end
	local g = global.guard.data[pindex]
	local last = g.last + 1
	g.entities[last] = entity
	g.expires[last] = game.tick + global.guard.config.guard_time * 60 * game.speed	-- set expiry date in the future
	g.last = last
	global.guard.data[pindex] = g
end

-- expire old entries for given user
function expire_guard(pindex)
	if global.guard.data[pindex] == nil then
		return
	end
	
	if get_guard_size(pindex) == 0 then
		return
	end
	
	local g = global.guard.data[pindex]
	
	-- check if it's not easier to delete everything
	if g.expires[g.last] <= game.tick then
		--game.print("Expired everything for " .. game.players(pindex))
		global.guard.data[pindex] = nil
		return
	end
	
	-- expire old items	
	local first = g.first
	while first <= g.last and g.expires[first] <= game.tick do		
		game.print("Expired: " .. g.entities[first].name .. " S=" .. get_guard_size(pindex))
		g.entities[first] = nil
		g.expires[first] = nil
		first = first + 1;
	end
	
	g.first = first
	
	if first > g.last then
		g.last = first - 1
	end
	global.guard.data[pindex] = g
end

-- delete the entire guard for given user
function delete_guard(pindex)
	if global.guard.data[pindex] ~= nil then
		global.guard.data[pindex] = nil
	end
end

-- Cancel deconstruction for stored entities
function enforce_guard(pindex)
	local deconstructs = get_guard_size(pindex)
	if deconstructs == 0 then
		return
	end
	
	
	-- check if it's not over the limit
	if deconstructs < global.guard.config.guard_count then
		return
	end
	
	game.print("Player " .. game.players[pindex].name .. " tried to deconstruct way too much!")
	game.players[pindex].print("You have tried to deconstruct too much. Your deconstruction planner privileges have been rescinded.")
	
	global.guard.bans[pindex] = game.tick + global.guard.config.ban_time * 60 * game.speed;
	global.guard.stats.bans = global.guard.stats.bans + 1
	-- cancel all deconstructions
	local g = global.guard.data[pindex]	
	for i=g.first, g.last do
		--game.print(i .. "Cancelling deconstructon for " .. g.entities[i].name)
		g.entities[i].cancel_deconstruction(game.players[pindex].force.name)
	end
	delete_guard(pindex)
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function guard_deconstruction(event)
	-- skip check if player is an admin
	if global.guard.config.exempt_admins and game.players[event.player_index].admin then
		return true
	end
	
	-- skip check if deconstructing entities of neutral force (trees, rocks..)
	if global.guard.config.allow_neutral_force and event.entity.force ~= nil and event.entity.force.name == "neutral" then
		--game.print("Allowing deconstruction of items belonging to neutral force")
		return true
	end
	
	-- skip check if the user is part of a trusted group
	if global.guard.config.trusted_group ~= nil and game.players[event.player_index].permission_group == global.guard.config.trusted_group then
		return true
	end
	
	-- check if the user is not banned already
	if global.guard.bans[event.player_index] ~= nil and global.guard.bans[event.player_index] > game.tick then
		game.players[event.player_index].print("You have tried to deconstruct too much. Your deconstruction planner privileges have been rescinded.")
		event.entity.cancel_deconstruction(game.players[event.player_index].force.name)
		return
	end 
	
	-- check if entity is not whitelisted
	for k,v in ipairs(global.guard.config.type_whitelist) do
		if v == event.entity.type then
			--game.print("Entity " .. event.entity.type .. " whitelisted from decon guard")
			return true
		end
	end
		
	-- expire old entries
	expire_guard(event.player_index)
	
	-- add new entity
	add_guard(event.player_index, event.entity)
	
	-- enforce, if necessary
	enforce_guard(event.player_index)

	--dump_guard(pindex)
end

function guard_player_dc(event)
	expire_guard(event.player_index)
end

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------

function guard_dcguardon_cmd(x)
	if not game.player.admin then
		game.print("You must be a server administrator to run this command")
		return
	end 
	global.guard.config.enabled = true
	game.print(x)
end

function guard_dcguardoff_cmd()
	if not game.player.admin then
		game.print("You must be a server administrator to run this command")
		return
	end 
	global.guard.config.enabled = false
end

-- Report statistics
function guard_stats_cmd()
if not game.player.admin then
		game.print("You must be a server administrator to run this command")
		return
	end 
	game.player.print("Deconstruction Guard Statistics:")
	game.player.print("Bans = " .. global.guard.stats.bans)
end

-- Register in-game commands
function register_commands()
	commands.remove_command("dcguardstats");
	commands.add_command("dcguardstats", "Deconstruction Guard stats", guard_stats_cmd)
	
	commands.remove_command("dcguardon");
	commands.add_command("dcguardon", "Deconstruction Guard Enable", guard_dcguardon_cmd)	
	
	commands.remove_command("dcguardoff");
	commands.add_command("dcguardoff", "Deconstruction Guard Disable", guard_dcguardoff_cmd)
end


-------------------------------------------------------------------------------
-- Event subscription
-------------------------------------------------------------------------------

script.on_event(defines.events.on_marked_for_deconstruction, guard_deconstruction)
script.on_event(defines.events.on_player_left_game, guard_player_dc)
--script.on_init(init_guard)
init_guard()
register_commands()
