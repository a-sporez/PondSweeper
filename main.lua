local love = require 'love'

-- Load necessary images and initialize critter quads
function love.load()
    images = {}

    -- Load numeric and state images
    for imageIndex, image in ipairs( {
        1, 2, 3, 4, 5, 6, 7, 8,
        'uncovered', 'covered_highlighted', 'covered',
        'labu', 'question',
    } ) do
        images[image] = love.graphics.newImage( 'images/'..image..'.png' )
    end

    -- Load the critter sprite sheet
    images.critter = love.graphics.newImage('images/critter-Sheet.png')

    -- Sprite sheet setup: Define quads for each critter
    critterQuads = {}
    local critterWidth = 18 -- Width of a single critter sprite
    local critterHeight = 18 -- Height of a single critter sprite
    local critterSheetWidth = images.critter:getWidth()
    local critterSheetHeight = images.critter:getHeight()

    for y = 0, (critterSheetHeight / critterHeight) - 1 do
        for x = 0, (critterSheetWidth / critterWidth) - 1 do
            table.insert(critterQuads, love.graphics.newQuad(
                x * critterWidth, y * critterHeight,
                critterWidth, critterHeight,
                critterSheetWidth, critterSheetHeight
            ))
        end
    end

    cellSize = 18 -- Size of each grid cell in pixels

    gridXCount = 19 -- Number of cells horizontally
    gridYCount = 14 -- Number of cells vertically

    -- Function to calculate the number of surrounding critters for a cell
    function getSurroundingCritterCount(x, y)
        local surroundingCritterCount = 0

        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dy == 0 and dx == 0)
                and grid[y + dy]
                and grid[y + dy][x + dx]
                and grid[y + dy][x + dx].critter
                then
                    surroundingCritterCount = surroundingCritterCount + 1
                end
            end
        end

        return surroundingCritterCount
    end

    -- Resets the game state and initializes the grid
    function reset()
        grid = {}

        for y = 1, gridYCount do
            grid[y] = {}
            for x = 1, gridXCount do
                grid[y][x] = {
                    critter = false, -- Whether this cell contains a critter
                    critterQuad = nil, -- The specific sprite for this critter
                    state = 'covered', -- Cell state: 'covered', 'uncovered', 'labu', 'question'
                }
            end
        end

        gameOver = false
        firstClick = true
    end

    reset() -- Initialize the game
end

-- Updates the selected cell based on mouse position
function love.update()
    selectedX = math.floor(love.mouse.getX() / cellSize) + 1
    selectedY = math.floor(love.mouse.getY() / cellSize) + 1

    -- Clamp selection to grid boundaries
    if selectedX > gridXCount then
        selectedX = gridXCount
    end

    if selectedY > gridYCount then
        selectedY = gridYCount
    end
end

-- Handles mouse click events for gameplay
function love.mousereleased(mouseX, mouseY, button)
    if not gameOver then
        if button == 1 and grid[selectedY][selectedX].state ~= 'labu' then
            if firstClick then
                firstClick = false

                -- Generate random positions for critters
                local possibleCritterPositions = {}

                for y = 1, gridYCount do
                    for x = 1, gridXCount do
                        if not (x == selectedX and y == selectedY) then
                            table.insert(possibleCritterPositions, {x = x, y = y})
                        end
                    end
                end

                -- Place critters randomly on the grid
                for critterIndex = 1, 40 do
                    local position = table.remove(
                        possibleCritterPositions,
                        love.math.random(#possibleCritterPositions)
                    )

                    grid[position.y][position.x].critter = true
                    grid[position.y][position.x].critterQuad = critterQuads[love.math.random(#critterQuads)]
                end
            end

            if grid[selectedY][selectedX].critter then
                grid[selectedY][selectedX].state = 'uncovered'
                gameOver = true -- Game ends when clicking on a critter
            else
                -- Flood-fill algorithm to uncover empty cells
                local stack = {
                    {
                        x = selectedX,
                        y = selectedY,
                    }
                }

                while #stack > 0 do
                    local current = table.remove(stack)
                    local x = current.x
                    local y = current.y

                    grid[y][x].state = 'uncovered'

                    if getSurroundingCritterCount(x, y) == 0 then
                        for dy = -1, 1 do
                            for dx = -1, 1 do
                                if not (dx == 0 and dy == 0)
                                and grid[y + dy]
                                and grid[y + dy][x + dx]
                                and (
                                    grid[y + dy][x + dx].state == 'covered'
                                    or grid[y + dy][x + dx].state == 'question'
                                ) then
                                    table.insert(stack, {
                                        x = x + dx,
                                        y = y + dy,
                                    })
                                end
                            end
                        end
                    end
                end

                -- Check if all non-critter cells are uncovered
                local complete = true

                for y = 1, gridYCount do
                    for x = 1, gridXCount do
                        if grid[y][x].state ~= 'uncovered'
                        and not grid[y][x].critter then
                            complete = false
                        end
                    end
                end

                if complete then
                    gameOver = true
                end
            end

        elseif button == 2 then
            -- Toggle cell state between 'labu', 'question', and 'covered'
            if grid[selectedY][selectedX].state == 'covered' then
                grid[selectedY][selectedX].state = 'labu'

            elseif grid[selectedY][selectedX].state == 'labu' then
                grid[selectedY][selectedX].state = 'question'

            elseif grid[selectedY][selectedX].state == 'question' then
                grid[selectedY][selectedX].state = 'covered'
            end
        end
    else
        reset() -- Reset game after game over
    end
end

-- Draw the game grid and other visual elements
function love.draw()
    for y = 1, gridYCount do
        for x = 1, gridXCount do
            local function drawCell(image, x, y)
                love.graphics.draw(
                    image,
                    (x - 1) * cellSize, (y - 1) * cellSize
                )
            end

            if grid[y][x].state == 'uncovered' then
                drawCell(images.uncovered, x, y)
            else
                -- Highlight the selected cell
                if x == selectedX and y == selectedY and not gameOver then
                    if love.mouse.isDown(1) then
                        if grid[y][x].state == 'labu' then
                            drawCell(images.covered, x, y)
                        else
                            drawCell(images.uncovered, x, y)
                        end
                    else
                        drawCell(images.covered_highlighted, x, y)
                    end
                else
                    drawCell(images.covered, x, y)
                end
            end

            -- Draw critters if the game is over
            if grid[y][x].critter and gameOver then
                love.graphics.draw(
                    images.critter,
                    grid[y][x].critterQuad,
                    (x - 1) * cellSize, (y - 1) * cellSize
                )
            elseif getSurroundingCritterCount(x, y) > 0 and grid[y][x].state == 'uncovered' then
                drawCell(images[getSurroundingCritterCount(x, y)], x, y)
            end

            -- Draw labus and question marks
            if grid[y][x].state == 'labu' then
                drawCell(images.labu, x, y)
            elseif grid[y][x].state == 'question' then
                drawCell(images.question, x, y)
            end
        end
    end
end