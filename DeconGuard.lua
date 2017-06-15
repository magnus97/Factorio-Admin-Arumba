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
			enabled = true,
			allow_neutral_force = true,
			guard_time = 2,		-- seconds
			ban_time = 15,		-- seconds
			guard_count = 10000,	-- tiles 1x1
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
	return { area = {}, expires = 0 }
end

-- returns the size of a guard
function get_guard_size(pindex)
	local g = global.guard.data[pindex]
  return ((math.ceil(g.area["right_bottom"]["x"]) - math.ceil(g.area["left_top"]["x"])) * ((math.ceil(g.area["right_bottom"]["y"])) - math.ceil(g.area["left_top"]["y"])))
end

-- Debug function needs rewrite not that important to start of with
function dump_guard(event)
	local g = global.guard.data[event.player_index]
	if not g then
		return
	end 
	game.print("Guard dump for " .. game.players[event.player_index] .. " F=" .. g.first .. " L=" .. g.last)
	for i=g.first, g.last do
		game.print(i .. " - " .. g.entities[i].name )
	end
end

-- add new entity to the list
function add_guard(event)	
	if not global.guard.data[event.player_index] then		
		global.guard.data[event.player_index] = init_guard_user()
	end
	local g = global.guard.data[event.player_index]
	g.expires = event.tick + global.guard.config.guard_time * 60 * game.speed	-- set expiry date in the future
	g.area = event.area
	global.guard.data[event.player_index] = g
end

-- expire old entries for given user
function expire_guard(event)
	local pindex = event.player_index
  local tick = event.tick
	if global.guard.data[pindex] == nil then
		return
	end
	
	if get_guard_size(pindex) == 0 then
		return
	end
	
	local g = global.guard.data[pindex]
	
	-- check if it's not easier to delete everything
	if g.expires <= event.tick then
		g.area = {}
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
function enforce_guard(event)
	local pindex = event.player_index
	local deconstructs = get_guard_size(pindex)
	if deconstructs == 0 then
		return
	end
	
	game.print(get_guard_size(pindex))
	
	-- check if it's not over the limit
	if deconstructs < global.guard.config.guard_count then
		return
	end
	
  -- notify players
	game.print("Player:'" .. game.players[pindex].name .. "' tried to deconstruct way too much!")
	game.players[pindex].print("You have tried to deconstruct too much. Your deconstruction planner privileges have been rescinded.")
	
  -- add ban
	global.guard.bans[pindex] = event.tick + global.guard.config.ban_time * 60 * game.speed
	global.guard.stats.bans = global.guard.stats.bans + 1
  
	-- cancel all deconstructions
	local g = global.guard.data[pindex]
	game.players[pindex].surface.cancel_deconstruct_area{area=event.area,force=game.players[pindex].force.name}
	delete_guard(pindex)
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function on_player_deconstructed_area(event)
  -- skip if decon guard is off
  if global.guard.config.enabled == false then
    return true
  end

  -- skip check if player is an admin
	if game.players[event.player_index].admin then
		return true
	end
	
	-- skip check if the user is part of a trusted group
	if global.guard.config.trusted_group ~= nil and game.players[event.player_index].permission_group == global.guard.config.trusted_group then
		return true
	end
	
	-- check if the user is not banned already
	if global.guard.bans[event.player_index] ~= nil and global.guard.bans[event.player_index] > game.tick then
		game.players[event.player_index].print("You have deconstructed way to much earlier. Deconstruction privileges are currently rescinded.");
		game.players[event.player_index].surface.cancel_deconstruct_area{area=event.area,force=game.players[event.player_index].force.name};
		return
	end
		
	-- expire old entries
	expire_guard(event)
	
	-- add new entity
	add_guard(event)
	
	-- enforce, if necessary
	enforce_guard(event)
end

function guard_player_dc(event)
	expire_guard(event)
end

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------

function dcguardon(event) 
  local p = game.players[event.player_index]
	if not p.admin then
		p.print("You must be a server administrator to run this command")
		return
	end 
	global.guard.config.enabled = true
	p.print("Deconstruction Guard Enabled")
end

function dcguardoff(event) 
  local p = game.players[event.player_index]
	if not p.admin then
		p.print("You must be a server administrator to run this command")
		return
	end 
	global.guard.config.enabled = false
	p.print("Deconstruction Guard Disabled")
end

function dcguardstats(event)
	local p = game.players[event.player_index]
	if not p.admin then
		p.print("You must be a server administrator to run this command")
		return
	end 
	p.print("Deconstruction Guard Statistics:")
	p.print("Bans = " .. global.guard.stats.bans)
end

function registercommands()
	commands.remove_command("dcguardon")
	commands.remove_command("dcguardoff")
	commands.remove_command("dcguardstats")
  
	commands.add_command("dcguardon", "Deconstruction Guard Enable", guard_dcguard_cmd)
	commands.add_command("dcguardoff", "Deconstruction Guard Disable", guard_dcguard_cmd)
	commands.add_command("dcguardstats", "Deconstruction Guard Stats", guard_dcguard_cmd)
end

-------------------------------------------------------------------------------
-- Game registration
-------------------------------------------------------------------------------

script.on_event(defines.events.on_player_deconstructed_area, on_player_deconstructed_area)
script.on_event(defines.events.on_player_left_game, guard_player_dc)
script.on_event(defines.events.on_tick, function(event) if(global.guard == nil) then init_guard() end end)
init_guard()
