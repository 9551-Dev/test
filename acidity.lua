local acidity,raw_map_methods = {},{}

acidity.noise_map_simple   = {}
acidity.noise_map_complex  = {}

local RANDOM,RANDOMSEED,CEIL = math.random,math.randomseed,math.ceil

local default_edge_1 = {x=0,y=0}
local default_edge_2 = {x=1,y=0}
local default_edge_3 = {x=0,y=1}
local default_edge_4 = {x=1,y=1}

local function default_easing_curve(t)
    return 6*t^5-15*t^4+10*t^3
end

local function linear_curve(t)
    return t
end

local function default_output_processor(n)
    return (n+1)/2
end

local function offset_direction(x,y,b,chunk_size)
    return  (x - b.x*chunk_size)/chunk_size,
            (y - b.y*chunk_size)/chunk_size
end

local function dot(a,x,y)
    return a.x * x + a.y * y
end

local function createNDarray(n, tbl)
    tbl = tbl or {}
    if n == 0 then return tbl end
    setmetatable(tbl, {__index = function(t, k)
        local new = createNDarray(n-1)
        t[k] = new
        return new
    end})
    return tbl
end

local function cantor_pair(a,b)
    local hash_a = (a >= 0 and a*2 or a*-2-1)
    local hash_b = (b >= 0 and b*2 or b*-2-1)

    local hash_c = ((hash_a >= hash_b) and hash_a^2+hash_a+hash_b or hash_a+hash_b^2)/2

    return (a < 0 and b < 0 or a >= 0 and b >= 0) and hash_c or -hash_c-1
end

local function calculate_vector_seed(map_seed,x,y)
    return cantor_pair(map_seed,cantor_pair(x,y))
end

local function generate_map_vector(map,x,y)
    local map_vectors = map.vector

    local seed = calculate_vector_seed(map.seed,x,y)

    RANDOMSEED(seed)

    local direction_vector = map_vectors.directions[
        RANDOM(1,map_vectors.ndirections)
    ]

    return direction_vector
end

local function init_map_chunk(map,x,y)
    local chunk_size = map.chunk_size
    local chunk_x = CEIL(x/chunk_size)
    local chunk_y = CEIL(y/chunk_size)

    local vector_grid = map.vector_grid

    vector_grid[chunk_x]  [chunk_y]   = generate_map_vector(map,chunk_x,  chunk_y)
    vector_grid[chunk_x+1][chunk_y]   = generate_map_vector(map,chunk_x+1,chunk_y)
    vector_grid[chunk_x]  [chunk_y+1] = generate_map_vector(map,chunk_x,  chunk_y+1)
    vector_grid[chunk_x+1][chunk_y+1] = generate_map_vector(map,chunk_x+1,chunk_y+1)
end

local function get_chunk_vectors(map,x,y)
    local chunk_size = map.chunk_size
    local chunk_x = CEIL(x/chunk_size)
    local chunk_y = CEIL(y/chunk_size)

    local vector_grid = map.vector_grid

    return vector_grid[chunk_x][chunk_y],
        vector_grid[chunk_x+1] [chunk_y],
        vector_grid[chunk_x]   [chunk_y+1],
        vector_grid[chunk_x+1] [chunk_y+1]
end

local function bilinear_lerp(a,b,c,d,t1,t2)
    local ab = (1-t1)*a + t1*b
    local cd = (1-t1)*c + t1*d

    return (1-t2)*ab + t2*cd
end

local function lerp(a,b,t1)
    return (1-t1)*a + b*t1
end

local function get_point_subfunc(self,x,y)
    init_map_chunk(self,x,y)

    local a,b,c,d = get_chunk_vectors(self,x,y)

    local chunk_size = self.chunk_size

    local chunk_relative_x = (x-1)%chunk_size+1
    local chunk_relative_y = (y-1)%chunk_size+1

    local easing_curve = self.fading_function
    local edges        = self.edges

    local t1 = easing_curve(chunk_relative_x/chunk_size)
    local t2 = easing_curve(chunk_relative_y/chunk_size)

    local direction_a_x,direction_a_y = offset_direction(chunk_relative_x,chunk_relative_y,edges[1],chunk_size)
    local direction_b_x,direction_b_y = offset_direction(chunk_relative_x,chunk_relative_y,edges[2],chunk_size)
    local direction_c_x,direction_c_y = offset_direction(chunk_relative_x,chunk_relative_y,edges[3],chunk_size)
    local direction_d_x,direction_d_y = offset_direction(chunk_relative_x,chunk_relative_y,edges[4],chunk_size)

    local dot1 = dot(a,direction_a_x,direction_a_y)
    local dot2 = dot(b,direction_b_x,direction_b_y)
    local dot3 = dot(c,direction_c_x,direction_c_y)
    local dot4 = dot(d,direction_d_x,direction_d_y)

    return self.output_processor(bilinear_lerp(dot1,dot2,dot3,dot4,t1,t2))
end

function raw_map_methods:get_point(x, y)
    local x_remainder = x % 1
    local y_remainder = y % 1

    local x_floor,x_ceil
    local y_floor,y_ceil
    local interpolate_x,interpolate_y

    if x_remainder ~= 0 then
        x_ceil, x_floor = x+(1-x_remainder),x-x_remainder
        interpolate_x = true
    end

    if y_remainder ~= 0 then
        y_ceil, y_floor = y + (1 - y_remainder), y - y_remainder
        interpolate_y = true
    end

    if interpolate_x and interpolate_y then
        return bilinear_lerp(
            get_point_subfunc(self, x_floor,y_floor),
            get_point_subfunc(self, x_ceil, y_floor),
            get_point_subfunc(self, x_floor,y_ceil),
            get_point_subfunc(self, x_ceil, y_ceil),
            linear_curve(x_remainder),
            linear_curve(y_remainder)
        )
    elseif interpolate_x then
        return lerp(
            get_point_subfunc(self,x_floor,y),
            get_point_subfunc(self,x_ceil, y),
            linear_curve(x_remainder)
        )
    elseif interpolate_y then
        return lerp(
            get_point_subfunc(self,x,y_floor),
            get_point_subfunc(self,x,y_ceil),
            linear_curve(y_remainder)
        )
    else
        return get_point_subfunc(self, x, y)
    end
end


function acidity.create_map_raw(seed,chunk_size,vector_grid,edges,direction_types,fading_function,output_processor)
    return setmetatable({
        chunk_size       = chunk_size,
        seed             = seed,
        vector_grid      = vector_grid,
        edges            = edges,
        vector           = direction_types,
        fading_function  = fading_function,
        output_processor = output_processor

    },{__index=raw_map_methods})
end

setmetatable(acidity.noise_map_simple,{__call=function(methods,seed,frequency,generate_vector_directions,custom_edges,fade,output)
    local directions = generate_vector_directions or 8

    local this = {
        raw_config={
            edges = custom_edges or {
                {x=default_edge_1.x,y=default_edge_1.y},
                {x=default_edge_2.x,y=default_edge_2.y},
                {x=default_edge_3.x,y=default_edge_3.y},
                {x=default_edge_4.x,y=default_edge_4.y}
            },
            frequency        = frequency,
            seed             = seed,
            directions       = directions,
            fade_processor   = fade,
            output_processor = output
        }
    }

    local function generate_grid()
        local generated_vectors = {}
        local n = 0

        for dir=0,math.pi*2,(math.pi*2)/directions do
            n = n + 1
            generated_vectors[n] = {
                x=math.cos(dir),
                y=math.sin(dir)
            }
        end

        local vector_directions = {
            ndirections = this.raw_config.directions,
            directions  = generated_vectors
        }

        local fade_processor   = this.raw_config.fade_processor   or default_easing_curve
        local output_processor = this.raw_config.output_processor or default_output_processor

        this.raw = acidity.create_map_raw(
            this.raw_config.seed,
            this.raw_config.frequency,
            createNDarray(1),
            this.raw_config.edges,
            vector_directions,
            fade_processor,
            output_processor
        )
    end

    generate_grid()
    this.regenerate = generate_grid

    return setmetatable(this,{__index=methods,__tostring=function() return "simple_noise_map" end})
end})

setmetatable(acidity.noise_map_complex,{__call=function(methods,seed,frequency,octaves,lacunarity,persistance,generate_vector_directions,custom_edges,fade,output)
    local directions = generate_vector_directions or 8

    local this = {
        octaves     = octaves,
        lacunarity  = lacunarity,
        persistance = persistance,
        raw_config={
            edges = custom_edges or {
                {x=default_edge_1.x,y=default_edge_1.y},
                {x=default_edge_2.x,y=default_edge_2.y},
                {x=default_edge_3.x,y=default_edge_3.y},
                {x=default_edge_4.x,y=default_edge_4.y}
            },
            frequency        = frequency,
            seed             = seed,
            directions       = directions,
            fade_processor   = fade,
            output_processor = output
        }
    }

    local function generate_octaves()
        local generated_vectors = {}

        local n = 0
        for dir=0,math.pi*2,(math.pi*2)/this.raw_config.directions do
            n = n + 1
            generated_vectors[n] = {
                x=math.cos(dir),
                y=math.sin(dir)
            }
        end

        local edges = this.raw_config.edges

        local vector_directions = {
            ndirections = this.raw_config.directions,
            directions  = generated_vectors
        }

        local fade_processor   = this.raw_config.fade_processor   or default_easing_curve
        local output_processor = this.raw_config.output_processor or default_output_processor

        local octaves_out = {}

        for i=1,this.octaves do
            local octave_id = i-1
            local octave_amplitude =      this.persistance                            ^ octave_id
            local octave_frequency = CEIL(this.raw_config.frequency/(this.lacunarity  ^ octave_id))

            octaves_out[i] = {
                raw = acidity.create_map_raw(
                    this.raw_config.seed,octave_frequency,createNDarray(1),edges,vector_directions,fade_processor,output_processor
                ),
                frequency = octave_frequency,
                amplitude = octave_amplitude
            }
        end

        this.generated_octaves = octaves_out
    end

    generate_octaves()

    this.regenerate = generate_octaves

    return setmetatable(this,{__index=methods,__tostring=function() return "complex_noise_map" end})
end})

function acidity.noise_map_simple:get_point(x,y)
    return self.raw:get_point(x,y)
end
function acidity.noise_map_complex:get_point(x,y)
    local total = 0

    local octaves    = self.octaves
    local noise_maps = self.generated_octaves

    local total_amplitude = 0

    for i=1,octaves do
        local octave = noise_maps[i]

        local amplitude = octave.amplitude

        total = total + (octave.raw:get_point(x,y) * amplitude)

        total_amplitude = total_amplitude + amplitude
    end

    return total/total_amplitude
end

function acidity.noise_map_simple:rebuild()
    self:regenerate()
end
function acidity.noise_map_complex:rebuild()
    self:regenerate()
end

acidity.init_map_chunk = init_map_chunk
acidity.get_point_hash = calculate_vector_seed
acidity.cantor_pair    = cantor_pair

return acidity