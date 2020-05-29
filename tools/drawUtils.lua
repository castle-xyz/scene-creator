DEFAULT_PALETTE = {
    "a6c439",
    "586b2e",
    "a8a8a8",
    "6d6d6d",
    "1a4253",
    "24233d",
    "e3d0b9",
    "f17f3b",
    "9b6524",
    "be4d68",
    "59284f",
    "4f2d34",
    "71823c",
    "708db7",
    "31314c",
    "d1bfa3",
    -- pico 8 colors
    "000000",
    "1D2B53",
    "7E2553",
    "008751",
    "AB5236",
    "5F574F",
    "C2C3C7",
    "FFF1E8",
    "FF004D",
    "FFA300",
    "FFEC27",
    "00E436",
    "29ADFF",
    "83769C",
    "FF77A8",
    "FFCCAA"
}

function uiPalette(r, g, b, props)
    props = props or {}
    local onChange = props.onChange
    local palette = props.palette or DEFAULT_PALETTE

    ui.button(
        "     ",
        {
            backgroundColor = "#" .. rgbToHexString(r, g, b),
            borderWidth = 6,
            popoverAllowed = true,
            popoverStyle = {width = 200},
            popover = function(closePopover)
                local i = 1
                while palette[i] do
                    ui.box(
                        "row-" .. i,
                        {
                            flexDirection = "row",
                            justifyContent = "space-between"
                        },
                        function()
                            for j = 1, 4 do
                                local hexString = palette[i]
                                if not hexString then
                                    break
                                end
                                i = i + 1
                                ui.button(
                                    "     ",
                                    {
                                        flex = 1,
                                        aspectRatio = 1,
                                        backgroundColor = "#" .. hexString,
                                        onClick = function()
                                            closePopover()
                                            r, g, b = hexStringToRgb(hexString)
                                            if onChange then
                                                onChange(r, g, b)
                                            end
                                        end
                                    }
                                )
                            end
                        end
                    )
                end
            end
        }
    )

    return r, g, b
end

-- https://gist.github.com/marceloCodget/3862929
function rgbToHexString(r, g, b)
    local rgb = {r * 255, g * 255, b * 255}
	local hexadecimal = ''

	for key, value in pairs(rgb) do
		local hex = ''

		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return hexadecimal
end

function hexStringToRgb(str)
    local rgb255 = tonumber(str, 16)
    rgb255 = rgb255 % 0x1000000

    local b255 = rgb255 % 0x100
    local g255 = ((rgb255 - b255) % 0x10000) / 0x100
    local r255 = (rgb255 - g255 - b255) / 0x10000

    return r255 / 255, g255 / 255, b255 / 255, 1
end
