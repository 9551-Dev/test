local graphics_mode = false

local render_distance = 10
local map_size = 250

local acidity = require("acidity")

print("Please enter seed for world generator")
local seed = tonumber(read())

local atlas_width = 4
local function uv_shift(map,atlas_pos)
    local new_uv = {
        {map[1][1]/atlas_width+atlas_pos/atlas_width,map[1][2]},
        {map[2][1]/atlas_width+atlas_pos/atlas_width,map[2][2]},
        {map[3][1]/atlas_width+atlas_pos/atlas_width,map[3][2]}
    }

    return new_uv
end

local connections = {
    top={
        {vertices={{0.5,0.5,-0.5},{-0.5,0.5,0.5},{0.5,0.5,0.5}},uvs=uv_shift({{1,0},{0,1},{1,1}},0),normals={{0,1,0},{0,1,0},{0,1,0}}},
        {vertices={{-0.5,0.5,0.5},{0.5,0.5,-0.5},{-0.5,0.5,-0.5}},uvs=uv_shift({{0,1},{1,0},{0,0}},0),normals={{0,1,0},{0,1,0},{0,1,0}}},
        place_boundary={0,1,0}
    },
    bottom={
        {vertices={{-0.5,-0.5,-0.5},{0.5,-0.5,-0.5},{-0.5,-0.5,0.5}},uvs=uv_shift({{1,1},{0,1},{1,0}},3),normals={{0,1,0},{0,1,0},{0,1,0}}},
        {vertices={{0.5,-0.5,0.5},{-0.5,-0.5,0.5},{0.5,-0.5,-0.5}},uvs=uv_shift({{0,0},{1,0},{0,1}},3),normals={{0,1,0},{0,1,0},{0,1,0}}},
        place_boundary={0,-1,0}
    },
    left={
        {vertices={{-0.5,0.5,0.5},{-0.5,0.5,-0.5},{-0.5,-0.5,0.5}},uvs=uv_shift({{1,1},{0,1},{1,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        {vertices={{-0.5,0.5,-0.5},{-0.5,-0.5,-0.5},{-0.5,-0.5,0.5}},uvs=uv_shift({{0,1},{0,0},{1,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        place_boundary={-1,0,0}
    },
    right={
        {vertices={{0.5,0.5,-0.5},{0.5,0.5,0.5},{0.5,-0.5,-0.5}},uvs=uv_shift({{1,1},{0,1},{1,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        {vertices={{0.5,0.5,0.5},{0.5,-0.5,0.5},{0.5,-0.5,-0.5}},uvs=uv_shift({{0,1},{0,0},{1,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        place_boundary={1,0,0}
    },
    front={
        {vertices={{-0.5,0.5,-0.5},{0.5,0.5,-0.5},{-0.5,-0.5,-0.5}},uvs=uv_shift({{0,1},{1,1},{0,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        {vertices={{0.5,0.5,-0.5},{0.5,-0.5,-0.5},{-0.5,-0.5,-0.5}},uvs=uv_shift({{1,1},{1,0},{0,0}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        place_boundary={0,0,-1}
    },
    back={
        {vertices={{-0.5,-0.5,0.5},{0.5,0.5,0.5},{-0.5,0.5,0.5}},uvs=uv_shift({{0,0},{1,1},{0,1}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        {vertices={{-0.5,-0.5,0.5},{0.5,-0.5,0.5},{0.5,0.5,0.5}},uvs=uv_shift({{0,0},{1,0},{1,1}},2),normals={{0,0,0},{0,0,0},{0,0,0}}},
        place_boundary={0,0,1}
    }
}

math.randomseed(1)
local GRASS,DIRT,STONE,GLASS,WATER,TURTLE,LOG,LEAVES,PLANKS,SBRICKS,BRICKS,SAKURA = {1,0,true,0},{5,0,true,0},{2,0,true,0},{3,1,true,0},{4,2,false,0.1},{6,0,true,0},{7,0,true,0},{8,3,false,0},{9,0,true,0},{10,0,true,0},{11,0,true,0},{12,3,false,0}

local name_lookup = {
    "grass","stone","glass","water","dirt","turtle","oak log","leaves","oak planks","stone bricks","bricks","sakura leaves"
}

local data_lookup = {
    GRASS,
    STONE,
    GLASS,
    WATER,
    DIRT,
    TURTLE,
    LOG,
    LEAVES,
    PLANKS,
    SBRICKS,
    BRICKS,
    SAKURA
}

local AIR = "__STRUCTURE_AIR_BLOCK"

local env = setmetatable({
    GRASS=GRASS,
    DIRT=DIRT,
    STONE=STONE,
    GLASS=GLASS,
    WATER=WATER,
    TURTLE=TURTLE,
    LOG=LOG,
    LEAVES=LEAVES,
    PLANKS=PLANKS,
    SBRICKS=SBRICKS,
    BRICKS=BRICKS,
    SAKURA=SAKURA,
    AIR   =AIR
},{__index=_ENV})

local function load_structure(name)
    return setfenv(require(name),env)()
end

local generated_structures = {
    load_structure("house"),
    load_structure("tower"),
}

local selected = 2

local connection_indices={
    {type="top",offset={0,1,0}},
    {type="bottom",offset={0,-1,0}},
    {type="left",offset={-1,0,0}},
    {type="right",offset={1,0,0}},
    {type="front",offset={0,0,-1}},
    {type="back",offset={0,0,1}},
}

local textures = {}

local cam = c3d.vector.new(10,50,10)

local m = peripheral.wrap("top")

local function construct_mesh(map,w,h,d)
    local view_radius = render_distance
    local cam_x = math.ceil(cam[1])
    local cam_z = math.ceil(cam[3])

    local mesh = c3d.mesh.new()

    local n = 0
    local interactions_map = {}

    local ran = 0
    for x=cam_x-view_radius,cam_x+view_radius do
        for y=2,h-1 do
            for z=cam_z-view_radius,cam_z+view_radius do
                local this = map[x][y][z]
                if this then
                    for k,v in pairs(connection_indices) do
                        local offset = v.offset
                        local struct = connections[v.type]

                        local map_fnd = map[x+offset[1]][y+offset[2]][z+offset[3]]
                        if not map_fnd or map_fnd[2] > this[2] then
                            local v1 = struct[1].vertices
                            local v2 = struct[2].vertices

                            n = n + 1

                            local offst = 0
                            if v.type == "top" then offst = this[4] end
                            mesh:add_triangle({
                                {v1[1][1]+x,v1[1][2]+y-offst,v1[1][3]+z},
                                {v1[2][1]+x,v1[2][2]+y-offst,v1[2][3]+z},
                                {v1[3][1]+x,v1[3][2]+y-offst,v1[3][3]+z}
                            },struct[1].uvs,textures[this[1]],struct[1].normals)

                            mesh:add_triangle({
                                {v2[1][1]+x,v2[1][2]+y-offst,v2[1][3]+z},
                                {v2[2][1]+x,v2[2][2]+y-offst,v2[2][3]+z},
                                {v2[3][1]+x,v2[3][2]+y-offst,v2[3][3]+z}
                            },struct[2].uvs,textures[this[1]],struct[2].normals)
                            ran = ran + 1

                            local place_boundary = struct.place_boundary

                            interactions_map[n] = {x,y,z,x+place_boundary[1],y+place_boundary[2],z+place_boundary[3]}
                        end
                    end
                end
            end
        end
    end

    return mesh,interactions_map
end

if graphics_mode then
    function c3d.resize(w,h)
        c3d.graphics.set_size(w,h)
    end

    function c3d.screen_render(t,w,h,buffer)
        term.drawPixels(1,1,buffer)
    end
end

local mesh
local map

local size = 600
local noise_map

local function generate_map()
    noise_map = acidity.noise_map_complex(seed,200,3,2,1)
end

local interact = {}

local function matmul(a1,a2,a3,a4,b)
    return a1*b[1]+a2*b[5]+a3*b[9]+a4*b[13],
        a1*b[2]+a2*b[6]+a3*b[10]+a4*b[14],
        a1*b[3]+a2*b[7]+a3*b[11]+a4*b[15],
        a1*b[4]+a2*b[8]+a3*b[12]+a4*b[16]
end

local shading = {
    [colors.black]={colors.black,colors.black,colors.black,colors.black,colors.black},
    [colors.blue]={colors.gray,colors.gray,colors.gray,colors.black,colors.black},
    [colors.brown]={colors.lightGray,colors.lightGray,colors.gray,colors.black,colors.black},
    [colors.cyan]={colors.blue,colors.blue,colors.lightGray,colors.gray,colors.black},
    [colors.gray]={colors.gray,colors.gray,colors.black,colors.black,colors.black},
    [colors.green]={colors.lime,colors.green,colors.gray,colors.black,colors.black},
    [colors.lightBlue]={colors.white,colors.lightBlue,colors.blue,colors.gray,colors.black},
    [colors.lightGray]={colors.white,colors.lightGray,colors.gray,colors.gray,colors.black},
    [colors.lime]={colors.lime,colors.lime,colors.green,colors.gray,colors.black},
    [colors.magenta]={colors.pink,colors.magenta,colors.purple,colors.gray,colors.black},
    [colors.orange]={colors.orange,colors.orange,colors.lightGray,colors.gray,colors.black},
    [colors.pink]={colors.white,colors.pink,colors.magenta,colors.purple,colors.black},
    [colors.purple]={colors.magenta,colors.purple,colors.lightGray,colors.gray,colors.black},
    [colors.red]={colors.orange,colors.red,colors.lightGray,colors.gray,colors.black},
    [colors.white]={colors.white,colors.white,colors.lightGray,colors.gray,colors.black},
    [colors.yellow]={colors.white,colors.yellow,colors.lightGray,colors.gray,colors.black}
}

for k,v in pairs(shading) do
    local reversed = {}
    for i=1,#v do
        reversed[#v-i+1] = v[i]
    end
    shading[k] = reversed
end

local function reconstruct_mesh(w,h,d)
    local chunk_mesh
    chunk_mesh,interact = construct_mesh(map,w,h,d)


    mesh = chunk_mesh:make_geometry():push()

    c3d.perspective.set_far_plane(100000)
    c3d.perspective.set_fov(75)

    mesh.disable_culling = false
end

local water_level = 10
local water_depth = 3
local dirt_depth  = 3

local function place_block(x,y,z,type)
    map[x][y][z] = type
end

local function add_structure_at(structure,x,y,z,rotx,rotz)
    for layer=1,#structure do
        local layer_data = structure[layer]
        for row=1,#layer_data do
            local row_data = layer_data[row]
            for collumn=1,#row_data do
                local collumn_data = row_data[collumn]

                local cur_row,cur_col = row,collumn
                if rotx then cur_col = #row_data   - collumn + 1 end
                if rotz then cur_row = #layer_data - row     + 1 end

                local place_x = cur_col+x - 1
                local place_z = cur_row+z - 1
                local place_y = layer  +y - 1

                if collumn_data ~= AIR then
                    place_block(place_x,place_y,place_z,collumn_data)
                else
                    place_block(place_x,place_y,place_z,nil)
                end
            end
        end
    end
end

local function get_structure_footprint(structure)
    local layer_y = structure[1]

    local width  = #layer_y
    local length = #layer_y[1]

    return width,length
end

local function generate_tree(x,y,z)
    local tree_height = math.random(4,7)
    local leaves_offset = math.random(1,3)
    local leaf_layers = math.random(4,5)
    local layer_radius = 4

    local sakura = math.random(1,10) == 1

    for i=1,leaf_layers do
        local layer_y = tree_height-leaves_offset+i+y

        local size = math.ceil((layer_radius-i)/2+0.5)

        for x_offset=-size,size do
            for z_offset=-size,size do
                place_block(x+x_offset,layer_y,z+z_offset,sakura and SAKURA or LEAVES)
            end
        end
    end

    for i=y,y+tree_height do
        place_block(x,i,z,LOG)
    end
end

local function build_mesh()
    if mesh then mesh:remove() end
    map = utils.table.createNDarray(2)
    local w,h,d = size,map_size,size

    local n,m,density = 1,2.8,200

    local structures = {}

    for x=1,w do
        for z=1,d do
            --local height = 2^math.log(noise_map:get_point(x,z)*120-40,2)
            --local height = (3^noise_map:get_point(x,z)*20)*(((math.sin(n*math.pi*x/density)*math.sin(m*math.pi*z/density)-math.sin(m*math.pi*x/density)*math.sin(n*math.pi*z/density))+1))
            --local height = 3^(math.sin(n*math.pi*x/density)*math.sin(m*math.pi*z/density)-math.sin(m*math.pi*x/density)*math.sin(n*math.pi*z/density))*50-20


            local height = (3^(noise_map:get_point(x,z)*1.7)*20-40)*(((math.sin(n*math.pi*x/density)*math.sin(m*math.pi*z/density)-math.sin(m*math.pi*x/density)*math.sin(n*math.pi*z/density))+1)) + 5

            if height > water_level then
                for y=1,height do
                    if y == math.floor(height) then
                        math.randomseed(acidity.get_point_hash(seed,x,z))
                        if math.random() > 0.99 then
                            generate_tree(x,y+1,z)
                        end
                        if math.random() > 0.9995 then
                            local random_structure = math.random(1,#generated_structures)

                            structures[#structures+1] = {
                                x=x,y=y,z=z,
                                data=generated_structures[random_structure],
                                rot_x = math.random() > 0.5,
                                rot_y = math.random() > 0.5
                            }
                        end
                        place_block(x,y,z,GRASS)
                    elseif y < height-dirt_depth then
                        place_block(x,y,z,STONE)
                    elseif y >= height-dirt_depth then
                        place_block(x,y,z,DIRT)
                    end
                end
            else
                local water_count = height+math.min(height-water_level,water_depth)

                for y=1,math.max(height,water_level) do
                    if y < water_count then
                        if y < water_count-dirt_depth then
                            place_block(x,y,z,STONE)
                        else
                            place_block(x,y,z,DIRT)
                        end
                    else
                        if y < 3 then
                            place_block(x,y,z,DIRT)
                        else
                            place_block(x,y,z,WATER)
                        end
                    end
                end
            end
        end
    end

    for i=1,#structures do
        local lowest_height = math.huge

        local structure = structures[i]

        local foot_x,foot_z = get_structure_footprint(structure.data)

        for x=1,foot_x do
            local x_component = map[x+structure.x-1]

            if x_component then for z=1,foot_z do
                for height=map_size,1,-1 do
                    if x_component[height] and x_component[height][z+structure.z-1] then
                        lowest_height = math.min(height,lowest_height)
                        break
                    end
                end
            end end
        end

        add_structure_at(structure.data,structure.x,lowest_height,structure.z,structure.rot_x,structure.rot_y)
    end


    reconstruct_mesh(size,map_size,size)
end

function c3d.wheelmoved(dx,dy)
    size = size + dy
    generate_map()
    build_mesh()
end

local function update_stars(stars,texture)
    local current_time = os.epoch("utc")
    for k,v in pairs(stars) do
        if current_time > v.last_update+v.lifetime then
            v.last_update = current_time
            v.state = not v.state
        end
    end
    for k,v in pairs(stars) do
        texture:set_pixel(v.x,v.y,v.state and colors.white or colors.gray)
    end
end

local stars,star_box_texture

function c3d.load()
    c3d.graphics.set_bg(colors.black)

    if graphics_mode then
        term.setGraphicsMode(1)
        c3d.graphics.autoresize(false)
    end

    local water_transparency_sheet = c3d.graphics.load_texture("water_transparency_sheet.ppm",{mipmap_levels=4})
    local water_skin_sheet         = c3d.graphics.load_texture("water_skin_sheet.ppm",{mipmap_levels=4,transparency=water_transparency_sheet})

    textures[1]  = c3d.graphics.load_texture("grass_skin.ppm",{mipmap_levels=4})
    textures[2]  = c3d.graphics.load_texture("stone_skin.ppm",{mipmap_levels=4})
    textures[3]  = c3d.graphics.load_texture("glass_skin.ppm",{transparency=c3d.graphics.load_texture("glass_skin.ppm",{mipmap_levels=4}),mipmap_levels=4})
    textures[4]  = water_skin_sheet:sprite_sheet({w=64,h=16}):make_animation(1,300)
    textures[5]  = c3d.graphics.load_texture("dirt_skin.ppm",{mipmap_levels=4})
    textures[6]  = c3d.graphics.load_texture("turtle_skin.ppm",{mipmap_levels=4})
    textures[7]  = c3d.graphics.load_texture("log_skin.ppm",{mipmap_levels=4})
    textures[8]  = c3d.graphics.load_texture("leaves_skin.ppm",{mipmap_levels=4,transparency=c3d.graphics.load_texture("leaves_transparency.ppm",{mipmap_levels=5})})
    textures[9]  = c3d.graphics.load_texture("oak_planks_skin.ppm")
    textures[10] = c3d.graphics.load_texture("stone_bricks_skin.ppm")
    textures[11] = c3d.graphics.load_texture("bricks_skin.ppm")
    textures[12] = c3d.graphics.load_texture("sakura_leaves_skin.ppm",{mipmap_levels=4,transparency=c3d.graphics.load_texture("leaves_transparency.ppm",{mipmap_levels=5})})

    generate_map()
    build_mesh()

    stars = {}
    for i=1,2000 do
        stars[i] = {
            x=math.random(1,1000),
            y=math.random(1,1000),
            state=true,
            last_update=os.epoch("utc"),
            lifetime=math.random()*2000
        }
    end
    star_box_texture = c3d.graphics.blank_texture(1000,1000)

    local star_box = c3d.geometry.cube_skinned()

    star_box:add_param("z_layer",-math.huge)
    :add_param("disable_culling",true)
    :add_param("texture",star_box_texture):push():set_vertex_shader(function(...)

        return c3d.shader.vertex.skybox(...)
    end):set_size(10000,10000,10000)
end

local function get_look_vector(yaw,pitch)
    return c3d.vector.new(
        math.sin(yaw)*math.cos(pitch),
        -math.sin(pitch),
        math.cos(yaw)*math.cos(pitch)
    ):normalize()
end

local function get_move_vector(yaw)
    return c3d.vector.new(
        math.sin(yaw),
        0,
        math.cos(yaw)
    ):normalize()
end

function c3d.postrender(term)
    m.clear()
    m.setCursorPos(1,1)
    m.write("allocated tables: "..c3d.sys.get_bus().m_n)
    term.setCursorPos(1,1)
    term.write("Selected: "..name_lookup[selected])
    m.setCursorPos(1,5)
    local i = 0
    for k,v in pairs(c3d.graphics.get_stats()) do
        i = i + 1
        m.setCursorPos(1,i+5)
        m.write(k..": "..tostring(v))
    end
    for k,v in pairs(c3d.graphics.get_stats().pipe) do
        i = i + 1
        m.setCursorPos(1,i+5)
        m.write(k..": "..tostring(v))
    end

    m.setCursorPos(1,2)
    m.setTextColor(colors.blue)
    m.write("Selected: "..name_lookup[selected])
    m.setCursorPos(1,3)
    m.setTextColor(colors.red)
    m.write("Render mode: " .. (graphics_mode and "Graphics. " or "Teletext. ") .. " press G to switch")
    m.setCursorPos(1,4)
    m.setTextColor(colors.green)
    m.write("Render distance: " .. render_distance .. ". Change with O/P")
    m.setCursorPos(1,5)
    m.setTextColor(colors.cyan)
    m.write(("x:%d y:%d z:%d"):format(cam[1],cam[2],cam[3]))
    m.setTextColor(colors.white)
end

local pitch,yaw = 0,45
local pitch_lim = {-89,89}
local no_height_vec = c3d.vector.new(1,0,1)

local acceleration = 0.03
local velocity = c3d.vector.new(0,0,0)

local function update_world_mesh()
    if mesh then mesh:remove() end
    reconstruct_mesh(size,map_size,size)
end

function c3d.init()
    c3d.plugin.load(function()
        local plugin = plug.new("vector-world")

        local bus = plugin:get_bus()
        bus.sys.autorender = false

        function plugin.register_objects()
            local object_registry = c3d.registry.get_object_registry()
            local vector_obj = object_registry:get(OBJECT.vector)

            vector_obj:set_entry(c3d.registry.entry("find_world"),function(this,x,y,z)
                local w_data =  map
                    [math.ceil(this[1]-x-0.5)]
                    [math.ceil(this[2]-y-0.5)]
                    [math.ceil(this[3]-z-0.5)] or
                    map
                    [math.ceil(this[1]-x-0.8)]
                    [math.ceil(this[2]-y-0.5)]
                    [math.ceil(this[3]-z-0.5)] or
                    map
                    [math.ceil(this[1]-x-0.2)]
                    [math.ceil(this[2]-y-0.5)]
                    [math.ceil(this[3]-z-0.5)] or
                    map
                    [math.ceil(this[1]-x-0.5)]
                    [math.ceil(this[2]-y-0.5)]
                    [math.ceil(this[3]-z-0.8)] or
                    map
                    [math.ceil(this[1]-x-0.5)]
                    [math.ceil(this[2]-y-0.5)]
                    [math.ceil(this[3]-z-0.2)]

                if w_data then
                    return w_data[3]
                end
            end)
        end

        function plugin.register_threads()
            local thread_registry = c3d.registry.get_thread_registry()

            thread_registry:set_entry(c3d.registry.entry("fps-logger-thread"),function()
                while true do
                    c3d.log.add(c3d.timer.getFPS())
                    c3d.log.dump()
                    sleep(5)
                end
            end)

            thread_registry:set_entry(c3d.registry.entry("mesh-update-thread"),function()
                while true do
                    update_world_mesh()
                    sleep(1)
                end
            end)

            thread_registry:set_entry(c3d.registry.entry("render_thread"),function()
                while true do
                    c3d.generate_frame()
                end
            end)
        end

        plugin:register()
    end)
end

function c3d.render()
    --[[if mesh then mesh:remove() end
    reconstruct_mesh(size,50,size)]]
    update_stars(stars,star_box_texture)
end

function c3d.update(dt)
    local sens_vector   = c3d.vector.new(10*dt,10*dt,10*dt)

    if c3d.keyboard.is_down("left") then yaw = yaw - 100*dt end
    if c3d.keyboard.is_down("right") then yaw = yaw + 100*dt end
    if c3d.keyboard.is_down("up") then
        local new_pitch = pitch - 100*dt
        if new_pitch > pitch_lim[1] then pitch = new_pitch end
    end
    if c3d.keyboard.is_down("down") then
        local new_pitch = pitch + 100*dt
        if new_pitch < pitch_lim[2] then pitch = new_pitch end
    end

    local move_vector = get_move_vector(math.rad(yaw))

    if c3d.keyboard.is_down("w") then
        local new_cam_pos = cam + move_vector*sens_vector
        local world_pos = new_cam_pos:find_world(0,1,0) or new_cam_pos:find_world(0,0,0)
        if not world_pos then
            cam = new_cam_pos
        end
    end
    if c3d.keyboard.is_down("s") then
        local new_cam_pos = cam - move_vector*sens_vector
        local world_pos = new_cam_pos:find_world(0,1,0) or new_cam_pos:find_world(0,0,0)
        if not world_pos then
            cam = new_cam_pos
        end
    end
    if c3d.keyboard.is_down("d") then
        local look_vector_right = get_move_vector(math.rad(yaw+90))
        local new_cam_pos = cam + look_vector_right*sens_vector*no_height_vec
        local world_pos = new_cam_pos:find_world(0,1,0) or new_cam_pos:find_world(0,0,0)
        if not world_pos then
            cam = new_cam_pos
        end
    end
    if c3d.keyboard.is_down("a") then
        local look_vector_left = get_move_vector(math.rad(yaw-90))
        local new_cam_pos = cam + look_vector_left*sens_vector*no_height_vec
        local world_pos = new_cam_pos:find_world(0,1,0) or new_cam_pos:find_world(0,0,0)
        if not world_pos then
            cam = new_cam_pos
        end
    end

    if c3d.keyboard.is_down("leftShift") or c3d.keyboard.is_down("space") then
        local under = (cam - c3d.vector.new(0,1,0)):find_world(0,0.5,0)
        if under then
            velocity = c3d.vector.new(0,graphics_mode and 0.35 or 0.25,0)
        end
    end

    local new_cam_pos = cam + velocity
    local world_pos = new_cam_pos:find_world(0,1,0) or new_cam_pos:find_world(0,0,0)
    if not world_pos then
        cam = new_cam_pos
    else velocity = c3d.vector.new(0,0,0) end

    velocity = velocity - c3d.vector.new(0,acceleration*dt*20,0)

    local look_vector = get_look_vector(math.rad(yaw),math.rad(pitch))
    local lp = cam+look_vector

    c3d.camera.lookat(cam[1],cam[2]+0.7,cam[3],lp[1],lp[2]+0.7,lp[3],0.01)
end

function c3d.mousepressed(x,y,btn)
    local t = (graphics_mode and c3d.interact.get_triangle_pixel or c3d.interact.get_triangle)(x,y)
    if t then
        local cbp = interact[math.ceil(t.index/2)]
        local mx,my,mz = cbp[1],cbp[2],cbp[3]
        local dvec = c3d.vector.new(mx,my,mz)-cam
        if dvec:get_length() < 8 then
            if btn == 1 then
                map[mx][my][mz] = nil
            else
                if not c3d.keyboard.is_down("t") then
                    map[cbp[4]][cbp[5]][cbp[6]] = data_lookup[selected]
                else
                    generate_tree(cbp[4],cbp[5],cbp[6])
                end
            end
            if mesh then
                mesh:remove()
                mesh = nil
            end
            reconstruct_mesh(size,50,size)
        end
    end
end

function c3d.keypressed(key)
    if key == "space" then
        local bus = c3d.sys.get_bus()
        bus.triangle_debug = not bus.triangle_debug
    end

    if key == "g" then
        graphics_mode = not graphics_mode

        if graphics_mode then
            function c3d.resize(w,h)
                c3d.graphics.set_size(w,h)
            end

            function c3d.screen_render(t,w,h,buffer)
                term.drawPixels(1,1,buffer)
            end

            c3d.graphics.autoresize(false)
            term.setGraphicsMode(1)
        else
            c3d.resize = nil
            c3d.screen_render = nil

            c3d.graphics.autoresize(true)
            term.setGraphicsMode(0)
        end
    end

    if key == "o" then
        render_distance = math.max(render_distance-1,0)

        update_world_mesh()
    elseif key == "p" then
        render_distance = render_distance + 1

        update_world_mesh()
    end
end

function c3d.wheelmoved(dx,dy)
    local new_pos = selected + dy
    if new_pos < 1 then new_pos = #name_lookup end
    if new_pos > #name_lookup then new_pos = 1 end
    selected = new_pos
end
