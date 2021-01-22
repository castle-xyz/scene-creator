Common:defineExpression(
   "random", {
      returnType = "number",
      description = "a random number in a range",
      order = 1,
      category = "randomness",
      paramSpecs = {
         min = {
            label = "Minimum value",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         max = {
            label = "Maximum value",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
         discrete = {
            label = "Only choose whole numbers",
            method = "toggle",
            initialValue = false,
            order = 3,
         },
      },
      eval = function(game, expression, actorId, context)
         local min, max = game:evalExpression(expression.params.min, actorId, context), game:evalExpression(expression.params.max, actorId, context)
         local result = min + math.random() * (max - min)
         if expression.params.discrete == true then
            result = math.floor(result + 0.5)
         end
         return result
      end
   }
)

Common:defineExpression(
   "perlin", {
      returnType = "number",
      description = "Perlin noise in 2 dimensions",
      category = "randomness",
      paramSpecs = {
         x = {
            label = "X",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         y = {
            label = "Y",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local x, y = game:evalExpression(expression.params.x, actorId, context), game:evalExpression(expression.params.y, actorId, context)
         return love.math.noise(x, y)
      end
   }
)

Common:defineExpression(
   "gauss", {
      returnType = "number",
      description = "a random number with a Gaussian distribution",
      category = "randomness",
      paramSpecs = {
         mean = {
            label = "Mean",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         sigma = {
            label = "Standard deviation",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local mean, sigma = game:evalExpression(expression.params.mean, actorId, context), game:evalExpression(expression.params.sigma, actorId, context)
         return love.math.randomNormal(sigma, mean)
      end
   }
)
