local gridShader

if GRID_SHADER then
    gridShader = GRID_SHADER
elseif love.graphics then
    gridShader =
        love.graphics.newShader(
        [[
        uniform float gridSize;
        uniform float dotRadius;
        uniform vec2 offset;
        vec4 effect(vec4 color, Image tex, vec2 texCoords, vec2 screenCoords)
        {
            vec2 f = mod(screenCoords + offset + dotRadius, gridSize);
            float l = length(f - dotRadius);
            float s = 1.0 - smoothstep(dotRadius - 1.0, dotRadius + 1.0, l);
            return vec4(color.rgb, s * color.a);
        }
    ]],
        [[
        vec4 position(mat4 transformProjection, vec4 vertexPosition)
        {
            return transformProjection * vertexPosition;
        }
    ]]
    )
end

function drawGrid(gridSize, viewScale, viewX, viewY, offsetX, offsetY)
    if gridSize > 0 then
        love.graphics.push("all")

        local windowWidth, windowHeight = love.graphics.getDimensions()

        local dpiScale = love.graphics.getDPIScale()
        gridShader:send("gridSize", dpiScale * gridSize * viewScale)
        gridShader:send("dotRadius", dpiScale * 2)
        gridShader:send(
            "offset",
            {
                dpiScale * (viewX % gridSize - offsetX) * viewScale,
                dpiScale * (viewY % gridSize - offsetY) * viewScale
            }
        )
        love.graphics.setShader(gridShader)

        love.graphics.origin()
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        love.graphics.pop()
    end
end


