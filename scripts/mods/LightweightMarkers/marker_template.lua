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
    -- Heretical idols, which vanilla never marks: Markers Improved AIO's idol frame (equal ring and
    -- background, icon at half their size, "Tarnished" ring), at our point-of-interest size.
    idol = {
        background = "content/ui/materials/hud/interactions/frames/point_of_interest_back",
        ring = "content/ui/materials/hud/interactions/frames/point_of_interest_top",
        ring_color = { 255, 130, 115, 102 },
        ring_size = 144 * HANDOVER_SCALE,
        background_size = 144 * HANDOVER_SCALE,
        icon_size = 72 * HANDOVER_SCALE,
    },
}
local RING_SIZE = FRAMES.standard.ring_size
local ICON_SIZE = FRAMES.standard.icon_size
local LABEL_FONT_SIZE = 15
local COUNT_FONT_SIZE = 18
local BACKGROUND_ALPHA = 200
-- Charge counts sit right above the ring: from its top to the centre of the count's text box.
local COUNT_LIFT = 14
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
    -- Taggable like vanilla's interaction marker: the tagging HUD picks the nearest marker of a
    -- smart-tag template under the crosshair (its `size` box), in line of sight unless the marker
    -- checks none, within max_distance, and only for units with a smart tag extension that can be
    -- tagged (hud_element_smart_tagging.lua, _is_marker_valid_for_tagging, _find_world_marker_target).
    template.using_smart_tag_system = true
    template.size = { RING_SIZE, RING_SIZE }
    template.get_smart_tag_id = function(marker)
        return Managers.state.extension:system("smart_tag_system"):unit_tag_id(marker.unit)
    end
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
                    color = { BACKGROUND_ALPHA, 49, 56, 49 },
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
                    size = { 64, 24 },
                    offset = { 0, -RING_SIZE * 0.5 - COUNT_LIFT, 4 },
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

        local ring_color = frame.ring_color

        if ring_color then
            local color = style.ring.color

            color[1], color[2], color[3], color[4] = ring_color[1], ring_color[2], ring_color[3], ring_color[4]
        end

        local icon_color = style.icon.color
        local color = kind.color

        icon_color[1], icon_color[2], icon_color[3], icon_color[4] = color[1], color[2], color[3], color[4]

        local label = style.label

        label.font_size = LABEL_FONT_SIZE * config.marker_scale
        label.offset[2] = ring_size * 0.5

        local count = style.count
        local count_lift = COUNT_LIFT * config.marker_scale

        count.font_size = COUNT_FONT_SIZE * config.marker_scale
        count.offset[2] = -(ring_size * 0.5 + count_lift)
        marker.lsm_count_lift = count_lift
        marker.lsm_keep_count = kind.charges ~= nil

        content.icon = marker.data.icon
        content.label = nil
        content.count = nil
        content.line_of_sight_progress = check_line_of_sight and 0 or 1
        marker.lsm_ring_size = ring_size
        marker.lsm_icon_alpha = color[1]

        self.position_offset = kind.offset
        self.size[1], self.size[2] = ring_size, ring_size
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
    -- its line-of-sight alpha (set by its own update_function) times its distance fade; and its widget.
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

        return alpha, widget
    end

    -- Other mods can rewrite our widget's styles after on_enter (a player's crash: a background
    -- without a colour), so a pass that lost its colour table keeps its look instead of erroring.
    local function set_pass_alpha(pass_style, alpha)
        local color = pass_style and pass_style.color

        if color then
            color[1] = alpha
        end
    end

    -- Runs after the HUD decided `draw` for this frame and before drawing
    -- (hud_element_world_markers.lua, _calculate_markers).
    template.update_function = function(element, _, widget, marker, self, dt)
        if not marker.draw then
            return
        end

        local content = widget.content
        local check_line_of_sight = marker.lsm_check_line_of_sight
        local vanilla, vanilla_widget = vanilla_alpha(element, marker.unit)
        local yielded = vanilla >= FULL_YIELD
        local keep_count = marker.lsm_keep_count and content.count ~= nil

        if yielded then
            -- Vanilla's marker shows the item (in line of sight, or tagged), so ours takes no
            -- raycasts until vanilla's stops showing, and is hidden unless it keeps its count (a
            -- deployed crate).
            if check_line_of_sight then
                self.check_line_of_sight = false
                marker.raycast_result = false
                content.line_of_sight_progress = 1
            end

            if not keep_count then
                marker.draw = false

                return
            end
        end

        local line_of_sight = 1

        if check_line_of_sight and not yielded then
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

        local alpha = line_of_sight * marker.lsm_dim

        if keep_count then
            -- The count stays while vanilla's marker takes over: only the ring, its background and
            -- the icon fade, and the count sits above the larger of the two rings.
            local style = widget.style
            local own = 1 - vanilla
            local top = marker.lsm_ring_size
            local vanilla_style = vanilla > 0 and vanilla_widget and vanilla_widget.style
            local vanilla_ring = vanilla_style and vanilla_style.ring

            set_pass_alpha(style.background, BACKGROUND_ALPHA * own)
            set_pass_alpha(style.ring, 255 * own)
            set_pass_alpha(style.icon, marker.lsm_icon_alpha * own)

            if vanilla_ring then
                top = math_max(top, vanilla_ring.size[2])
            end

            style.count.offset[2] = -(top * 0.5 + marker.lsm_count_lift)
        else
            alpha = alpha * (1 - vanilla)
        end

        if alpha <= MIN_ALPHA then
            -- Hidden markers are not drawn at all.
            marker.draw = false

            return
        end

        widget.alpha_multiplier = alpha

        if config.show_distance and not yielded then
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
