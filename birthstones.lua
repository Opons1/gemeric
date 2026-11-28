--ALEXANDRITE
--auto sends dug nodes to a configured chest
--peak code
local function maketexture(texture)
	local escaped = texture:gsub("([%^:])", "\\\\%1")
	local parts = {}
	for y = 0, 15 do
		local x = (y % 2) * 2 - 1
		parts[y + 1] = "0," .. y .. "=[combine\\:16x1\\:" .. x .. ",-" .. y .. "=" .. escaped
	end
	return "[combine:16x16:" .. table.concat(parts, ":")
end





local old_handle_node_drops = core.handle_node_drops

local alexandrited = {}

core.handle_node_drops = function(pos, drops, digger)
    if digger and digger:is_player() then
        local wielded = digger:get_wielded_item()

        if alexandrited[wielded:get_name()] then
            return
        end
    end

    return old_handle_node_drops(pos, drops, digger)
end

local function alexandrite(toolname)
    local def = table.copy(core.registered_tools[toolname])

    if not def then
        return
    end
	def.groups = def.groups or {}

    def.groups.not_in_creative_inventory = 1

    def.on_place = function(itemstack, placer, pointed_thing)
        if not placer or not placer:is_player() or pointed_thing.type ~= "node" then
            return itemstack
        end

        local name = placer:get_player_name()
        local pos = pointed_thing.under

        if placer:get_player_control().sneak then

            if core.is_protected(pos, name) then
                core.record_protection_violation(pos, name)
                return itemstack
            end

            local inv = core.get_meta(pos):get_inventory()
            local has_inv

            if inv and inv:get_size("main") > 0 then
                has_inv = true
            end

            if has_inv then
                local meta = itemstack:get_meta()
                meta:set_string("warped_pos", core.pos_to_string(pos))
                core.chat_send_player(name, "Tool linked to chest at " .. core.pos_to_string(pos))
            end

            return itemstack
        end

        if core.registered_tools[toolname].on_place then
            return core.registered_tools[toolname].on_place(itemstack, placer, pointed_thing)
        end

        return itemstack
    end


    def.after_use = function(itemstack, user, node, digparams)
        local meta = itemstack:get_meta()
        local target_pos = core.string_to_pos(meta:get_string("warped_pos"))

        if target_pos and user and user:is_player() then
            local name = user:get_player_name()

            core.load_area(target_pos)

            if core.is_protected(target_pos, name) then
                core.record_protection_violation(target_pos, name)
                return itemstack
            end

            local target_node = core.get_node_or_nil(target_pos)
            local nodedata = target_node and core.registered_nodes[target_node.name]
            local inv = core.get_meta(target_pos):get_inventory()
            local leftover = {}

            if not inv or inv:get_size("main") == 0 then
                return itemstack
            end

            for _, item in ipairs(core.get_node_drops(node, toolname, itemstack)) do
                local stack = ItemStack(item)
                local allow = nodedata and nodedata.allow_metadata_inventory_put

                if not allow or allow(target_pos, "main", 1, stack, user) > 0 then
                    stack = inv:add_item("main", stack)
                end

                if not stack:is_empty() then
                    table.insert(leftover, stack)
                end
            end

            if #leftover > 0 then
                core.handle_node_drops(digparams.pos, leftover, user)
            end
        end

        return itemstack
    end

    local warped_name = toolname .. "_warped"
	def.description = "Warped " .. def.description

	def.inventory_image = maketexture(def.inventory_image)
    core.register_tool(":" .. warped_name, def)
    alexandrited[warped_name] = true
end

alexandrite("default:pick_diamond")

--AMETHYST
local lightduration = 45 -- seconds before the light fades

core.register_node(":birthstones:phantom_light", {
	description = "Arcane Phantom Light",
	drawtype = "allfaces_optional",
	tiles = { "(default_meselamp.png^[colorize:#b266ff:140)^[opacity:80" },
	paramtype = "light",
	light_source = 14,
	sunlight_propagates = true,
	walkable = false,
	pointable = true,
	diggable = false,
	buildable_to = true,
	floodable = true,
	groups = { not_in_creative_inventory = 1 },
	use_texture_alpha = "blend",
	on_construct = function(pos)
		core.get_node_timer(pos):start(lightduration)
	end,

	on_timer = function(pos)
		core.remove_node(pos)
		return false
	end,
})

local function make_arcane_texture(texture)
	return "(" .. texture .. ")^[colorize:#9b30ff:75"
end

local function place_phantom_light(itemstack, user, pointed_thing)
	if not user or not user:is_player() then
		return itemstack
	end

	local light = ItemStack("birthstones:phantom_light")

	if pointed_thing and pointed_thing.type == "node" then
		local _, pos = core.item_place_node(light, user, pointed_thing)
		if pos then
			itemstack:add_wear(65535 / 200)
		end
	else
		local pos = user:get_pos()
		local dir = user:get_look_dir()
		local modifier = vector.rotate()
		local fake_pointed = {
			type = "node",
			under = air_pos,
			above = air_pos,
		}
		local _, pos = core.item_place_node(light, user, fake_pointed)
		if pos then
			itemstack:add_wear(65535 / 200)
		end
	end

	return itemstack
end


local function amethyst(toolname)
	local def = table.copy(core.registered_tools[toolname])
	if not def then
		return
	end

	def = table.copy(def)

    def.light_source = 14
	
	def.groups = def.groups or {}
    def.groups.not_in_creative_inventory = 1

	def.on_place = function(itemstack, placer, pointed_thing)
		return place_phantom_light(itemstack, placer, pointed_thing)
	end

	def.on_secondary_use = function(itemstack, user, pointed_thing)
		return place_phantom_light(itemstack, user, pointed_thing)
	end

	local arcane_name = toolname .. "_arcane"
	def.description = "Arcane " .. def.description
	def.inventory_image = make_arcane_texture(def.inventory_image)

	core.register_tool(":" .. arcane_name, def)
end

core.register_on_mods_loaded(function()
	local defaults = core.tooldef_default
	for name, def in pairs(core.registered_tools) do
		local has_custom_callback =
			def.on_use ~= defaults.on_use or
			def.after_use ~= defaults.after_use or
			def.on_place ~= defaults.on_place or
			def.on_secondary_use ~= defaults.on_secondary_use or
			def.on_drop ~= defaults.on_drop

		if not has_custom_callback then
			alexandrite(name)
			amethyst(name)
		end
	end
end)