local gridShader

if GRID_SHADER then
    gridShader = GRID_SHADER
elseif love.graphics then
    gridShader =
    love.graphics.newShader(
        [[
        uniform float gridCellSize;
        uniform float gridSize;
        uniform float dotRadius;
        uniform float axesAlpha;
        uniform vec2 offset;
        uniform vec2 viewOffset;
        uniform bool highlightAxes;

        vec4 effect(vec4 color, Image tex, vec2 texCoords, vec2 screenCoords)
        {
            vec2 f = mod(screenCoords + offset + dotRadius, gridCellSize);
            float l = length(f - dotRadius);
            float s = 1.0 - smoothstep(dotRadius - 1.0, dotRadius + 1.0, l);
            vec2 distToAxis = screenCoords - viewOffset;

            if (gridSize > 0.0 && (abs(distToAxis.x) > gridSize || abs(distToAxis.y) > gridSize)) {
                discard;
            }

            if (highlightAxes && (abs(distToAxis.x) < dotRadius || abs(distToAxis.y) < dotRadius)) {
                return vec4(color.rgb, s * axesAlpha);
            } else {
                return vec4(color.rgb, s * color.a);
            }
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

function drawGrid(gridCellSize, gridSize, viewScale, viewX, viewY, offsetX, offsetY, dotRadius, highlightAxes, axesAlpha)
    if gridCellSize > 0 then
        love.graphics.push("all")

        local windowWidth, windowHeight = CARD_WIDTH, CARD_HEIGHT

        local dpiScale = love.graphics.getDPIScale()
        gridShader:send("gridCellSize", dpiScale * gridCellSize * viewScale)
        gridShader:send("gridSize", dpiScale * gridSize * viewScale)
        gridShader:send("dotRadius", dpiScale * dotRadius)
        gridShader:send(
            "offset",
            {
                dpiScale * (viewX % gridCellSize - offsetX) * viewScale,
                dpiScale * (viewY % gridCellSize - offsetY) * viewScale
            }
        )
        gridShader:send(
            "viewOffset",
            {
                dpiScale * (offsetX - viewX) * viewScale,
                dpiScale * (offsetY - viewY) * viewScale,
            }
        )
        gridShader:send("highlightAxes", highlightAxes)
        gridShader:send("axesAlpha", axesAlpha)
        love.graphics.setShader(gridShader)

        love.graphics.origin()
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        love.graphics.pop()
    end
end


