function love.draw()
    love.graphics.clear(1, 0.98, 0.98)

    love.graphics.setColor(0, 0, 0)
    love.graphics.print('hello, world!', 20, 20)

    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.circle('fill', 100, 200, 80)
end
