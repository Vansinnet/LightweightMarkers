-- World-marker template for every marked item. Visuals are set once in on_enter; update_function
-- runs every frame for each live marker and only works out its alpha and distance text.
local UIWidget = require("scripts/managers/ui/ui_widget")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

-- Vanilla's interaction marker at the 15 m hand-over distance, where its distance scale is 0.4:
-- "pickup"/"default" visuals ring and background 96, icon 48; "point_of_interest" ring 144,
-- background 128, icon 72; same textures and colours as below
-- (world_marker_template_interaction.lua, template sizes, template_visual_definitions, update_function).
local HANDOVER_SCALE = 0.4
local FRAMES = {
    standard = {
        background = "content/ui/materials/hud/interactions/frames/mission_back",
        ring = "content/ui/materials/hud/interactions/frames/mission_top",
        ring_size = 96 * HANDOVER_SCALE,
        background_size = 96 * HANDOVER_SCALE,
        icon_size = 48 * HANDOVER_SCALE,
    },
    point_of_interest = {
        background = "content/ui/materials/hud/interactions/frames/pickup_back",
        ring = "content/ui/materials/hud/interactions/frames/pickup_top",
        ring_size = 144 * HANDOVER_SCALE,
        background_size = 128 * HANDOVER_SCALE,
        icon_size = 72 * HANDOVER_SCALE,
    },
}
local RING_SIZE = FRAMES.standard.ring_size
local ICON_SIZE = FRAMES.standard.icon_size
local LABEL_FONT_SIZE = 15
local COUNT_FONT_SIZE = 18
-- Health station charges sit to the upper right of the ring.
local COUNT_GAP = 6
local LINE_OF_SIGHT_SPEED = 8
local EDGE_FADE = 5
local MIN_ALPHA = 0.01
-- At or above this alpha vanilla's marker for the same unit shows the item and ours is hidden.
local FULL_YIELD = 0.99
-- The HUD raycasts the markers that waited longest first (10 every 5th frame, shared by every
-- marker). Ours age at half speed, so vanilla markers keep priority when the queue is long.
local RAYCAST_AGE_DISCOUNT = 0.5
local MAX_DISTANCE_TEXT = 260

local DISTANCE_TEXT = {}

for metres = 0, MAX_DISTANCE_TEXT do
    DISTANCE_TEXT[metres] = metres .. " m"
end

return function(ctx)
    local config = ctx.config
    local state = ctx.state
    local marker_by_unit = ctx.marker_by_unit

    local template = {}

    template.name = ctx.template_name
    template.unit_node = "ui_interaction_marker"
    template.position_offset = { 0, 0, 0.8 }
    template.max_distance = 40
    template.check_line_of_sight = true
    template.screen_clamp = false
    template.fade_settings = {
        default_fade = 1,
        fade_from = 0,
        fade_to = 1,
        distance_max = 40,
        distance_min = 40 - EDGE_FADE,
        easing_function = math.easeCubic,
    }

    -- One definition for every marker: UIWidget.init clones its content, style and passes
    -- (scripts/managers/ui/ui_widget.lua).
    local definitions = {}

    local function create_definition(scenegraph_id)
        return UIWidget.create_definition({
            {
                pass_type = "texture",
                style_id = "background",
                value_id = "background",
                value = FRAMES.standard.background,
                style = {
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    size = { RING_SIZE, RING_SIZE },
                    offset = { 0, 0, 1 },
                    color = { 200, 49, 56, 49 },
                },
            },
            {
                pass_type = "texture",
                style_id = "ring",
                value_id = "ring",
                value = FRAMES.standard.ring,
                style = {
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    size = { RING_SIZE, RING_SIZE },
                    offset = { 0, 0, 2 },
                    color = { 255, 226, 199, 126 },
                },
            },
            {
                pass_type = "texture",
                style_id = "icon",
                value_id = "icon",
                value = "content/ui/materials/hud/interactions/icons/default",
                style = {
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    size = { ICON_SIZE, ICON_SIZE },
                    offset = { 0, 0, 3 },
                    color = { 255, 255, 255, 255 },
                },
            },
            {
                pass_type = "text",
                style_id = "label",
                value_id = "label",
                value = "",
                style = {
                    font_type = "proxima_nova_bold",
                    font_size = LABEL_FONT_SIZE,
                    drop_shadow = true,
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    text_horizontal_alignment = "center",
                    text_vertical_alignment = "top",
                    size = { 120, 24 },
                    offset = { 0, RING_SIZE * 0.5, 4 },
                    text_color = { 255, 216, 237, 190 },
                },
                visibility_function = function(content)
                    return content.label ~= nil
                end,
            },
            {
                pass_type = "text",
                style_id = "count",
                value_id = "count",
                value = "",
                style = {
                    font_type = "proxima_nova_bold",
                    font_size = COUNT_FONT_SIZE,
                    drop_shadow = true,
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    text_horizontal_alignment = "center",
                    text_vertical_alignment = "center",
                    size = { 40, 24 },
                    offset = { RING_SIZE * 0.5 + COUNT_GAP, -RING_SIZE * 0.25, 4 },
                    text_color = { 255, 255, 255, 255 },
                },
                visibility_function = function(content)
                    return content.count ~= nil
                end,
            },
        }, scenegraph_id)
    end

    template.create_widget_defintion = function(_, scenegraph_id)
        local definition = definitions[scenegraph_id]

        if not definition then
            definition = create_definition(scenegraph_id)
            definitions[scenegraph_id] = definition
        end

        return definition
    end

    local function scale_pass(style, base_size, scale)
        local size = style.size

        size[1] = base_size * scale
        size[2] = base_size * scale
    end

    -- `self` is this marker's own deep copy of the template (hud_element_world_markers.lua,
    -- event_add_world_marker_unit), so per-marker settings go there.
    template.on_enter = function(widget, marker, self)
        local kind = marker.data.kind
        local scale = config.marker_scale * kind.size
        local style = widget.style
        local content = widget.content
        local max_distance = config.max_distance
        local check_line_of_sight = not config.see_through_walls

        local frame = FRAMES[kind.frame] or FRAMES.standard
        local ring_size = frame.ring_size * scale

        content.background = frame.background
        content.ring = frame.ring
        scale_pass(style.background, frame.background_size, scale)
        scale_pass(style.ring, frame.ring_size, scale)
        scale_pass(style.icon, frame.icon_size, scale)

        local icon_color = style.icon.color
        local color = kind.color

        icon_color[1], icon_color[2], icon_color[3], icon_color[4] = color[1], color[2], color[3], color[4]

        local label = style.label

        label.font_size = LABEL_FONT_SIZE * config.marker_scale
        label.offset[2] = ring_size * 0.5

        local count = style.count

        count.font_size = COUNT_FONT_SIZE * config.marker_scale
        count.offset[1] = ring_size * 0.5 + COUNT_GAP * config.marker_scale
        count.offset[2] = -ring_size * 0.25

        content.icon = marker.data.icon
        content.label = nil
        content.count = nil
        content.line_of_sight_progress = check_line_of_sight and 0 or 1

        self.position_offset = kind.offset
        self.max_distance = max_distance
        self.check_line_of_sight = check_line_of_sight
        marker.lsm_check_line_of_sight = check_line_of_sight
        self.fade_settings.distance_max = max_distance
        self.fade_settings.distance_min = max_distance - math_min(EDGE_FADE, max_distance * 0.25)

        marker.lsm_dim = 1
        marker.lsm_metres = nil
        marker.lsm_element = state.element
        marker_by_unit[marker.unit] = marker
    end

    -- Alpha of vanilla's interaction marker for the same unit, as _draw_markers will draw it:
    -- its line-of-sight alpha (set by its own update_function) times its distance fade.
    local function vanilla_alpha(element, unit)
        local interaction_units = state.interaction_units
        local entry = interaction_units and interaction_units[unit]
        local id = entry and entry.marker_id
        local vanilla = id and element._markers_by_id[id]

        if not vanilla or not vanilla.draw then
            return 0
        end

        local widget = vanilla.widget

        if widget.visible == false then
            return 0
        end

        local alpha = widget.alpha_multiplier or 0
        local fade_settings = vanilla.template.fade_settings

        if fade_settings and not vanilla.block_fade_settings and alpha > 0 then
            alpha = alpha * element:_get_fade(fade_settings, vanilla.distance)
        end

        return alpha
    end

    -- Runs after the HUD decided `draw` for this frame and before drawing
    -- (hud_element_world_markers.lua, _calculate_markers).
    template.update_function = function(element, _, widget, marker, self, dt)
        if not marker.draw then
            return
        end

        local content = widget.content
        local check_line_of_sight = marker.lsm_check_line_of_sight
        local vanilla = vanilla_alpha(element, marker.unit)

        if vanilla >= FULL_YIELD then
            -- Vanilla's marker shows the item (in line of sight, or tagged), so ours stays hidden
            -- and takes no raycasts until vanilla's stops showing.
            if check_line_of_sight then
                self.check_line_of_sight = false
                marker.raycast_result = false
                content.line_of_sight_progress = 1
            end

            marker.draw = false

            return
        end

        local line_of_sight = 1

        if check_line_of_sight then
            self.check_line_of_sight = true

            local raycast_frame_count = marker.raycast_frame_count

            if raycast_frame_count then
                marker.raycast_frame_count = raycast_frame_count - RAYCAST_AGE_DISCOUNT
            end

            line_of_sight = content.line_of_sight_progress

            if marker.raycast_initialized then
                if marker.raycast_result then
                    line_of_sight = math_max(line_of_sight - dt * LINE_OF_SIGHT_SPEED, 0)
                else
                    line_of_sight = math_min(line_of_sight + dt * LINE_OF_SIGHT_SPEED, 1)
                end

                content.line_of_sight_progress = line_of_sight
            end
        end

        local alpha = line_of_sight * marker.lsm_dim * (1 - vanilla)

        if alpha <= MIN_ALPHA then
            -- Hidden markers are not drawn at all.
            marker.draw = false

            return
        end

        widget.alpha_multiplier = alpha

        if config.show_distance then
            local metres = math_floor(marker.distance)

            if metres ~= marker.lsm_metres then
                marker.lsm_metres = metres
                content.label = DISTANCE_TEXT[metres] or DISTANCE_TEXT[MAX_DISTANCE_TEXT]
            end
        elseif content.label then
            content.label = nil
            marker.lsm_metres = nil
        end
    end

    template.on_exit = function(widget, marker)
        local unit = marker.unit

        if marker_by_unit[unit] == marker then
            marker_by_unit[unit] = nil
        end

        -- The element keeps every marker widget by name for its lifetime; release ours.
        local element = marker.lsm_element

        if element and widget and element:has_widget(widget.name) then
            element:_unregister_widget_name(widget.name)
        end
    end

    return template
end
