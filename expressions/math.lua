Common:defineExpression(
   "abs", {
      returnType = "number",
      category = "functions",
      order = 1,
      description = "absolute value",
      paramSpecs = {
         number = {
            label = "Number",
            method = "numberInput",
            initialValue = 0,
         },
      },
      eval = function(game, expression, actorId, context)
         local x = game:evalExpression(expression.params.number, actorId, context)
         return math.abs(x)
      end,
   }
)

Common:defineExpression(
   "floor", {
      returnType = "number",
      category = "functions",
      order = 2,
      description = "round down",
      paramSpecs = {
         number = {
            label = "Number",
            method = "numberInput",
            initialValue = 0,
         },
      },
      eval = function(game, expression, actorId, context)
         local x = game:evalExpression(expression.params.number, actorId, context)
         return math.floor(x)
      end,
   }
)

Common:defineExpression(
   "mix", {
      returnType = "number",
      category = "functions",
      description = "mix two values",
      paramSpecs = {
         lhs = {
            label = "First input",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Second input",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
         mix = {
            label = "Mix",
            method = "numberInput",
            initialValue = 0.5,
            props = { min = 0, max = 1, step = 0.1 },
            order = 3,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         local mix = game:evalExpression(expression.params.mix, actorId, context)
         return lhs * (1 - mix) + rhs * mix
      end,
   }
)

Common:defineExpression(
   "clamp", {
      returnType = "number",
      category = "functions",
      description = "clamp a value between two bounds",
      paramSpecs = {
         number = {
            label = "Value to clamp",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         min = {
            label = "Minimum value",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
         max = {
            label = "Maximum value",
            method = "numberInput",
            initialValue = 1,
            order = 3,
         },
      },
      eval = function(game, expression, actorId, context)
         local min, max = game:evalExpression(expression.params.min, actorId, context), game:evalExpression(expression.params.max, actorId, context)
         local x = game:evalExpression(expression.params.number, actorId, context)
         if x < min then x = min end
         if x > max then x = max end
         return x
      end,
   }
)

-- TODO: flexible number of inputs for min, max, choose

Common:defineExpression(
   "min", {
      returnType = "number",
      category = "choices",
      order = 3,
      description = "minimum",
      paramSpecs = {
         lhs = {
            label = "First input",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Second input",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return math.min(lhs, rhs)
      end,
   }
)

Common:defineExpression(
   "max", {
      returnType = "number",
      category = "choices",
      order = 4,
      description = "maximum",
      paramSpecs = {
         lhs = {
            label = "First input",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Second input",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return math.max(lhs, rhs)
      end,
   }
)

Common:defineExpression(
   "choose", {
      returnType = "number",
      category = "choices",
      order = 1,
      description = "choose",
      paramSpecs = {
         lhs = {
            label = "First outcome",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Second outcome",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         if math.random() < 0.5 then return lhs else return rhs end
      end,
   }
)

Common:defineExpression(
   "weighted choose", {
      returnType = "number",
      category = "choices",
      order = 2,
      description = "weighted choose",
      paramSpecs = {
         lhs = {
            label = "First outcome",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Second outcome",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
         lhw = {
            label = "Weight of first outcome",
            method = "numberInput",
            initialValue = 0.5,
            props = { min = 0, step = 0.1 },
            order = 3,
         },
         rhw = {
            label = "Weight of second outcome",
            method = "numberInput",
            initialValue = 0.5,
            props = { min = 0, step = 0.1 },
            order = 4,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         local lhw, rhw = game:evalExpression(expression.params.lhw, actorId, context), game:evalExpression(expression.params.rhw, actorId, context)
         if lhw < 0 then lhw = 0 end
         if rhw < 0 then rhw = 0 end
         if rhw == 0 then return lhs end
         if lhw == 0 then return rhs end
         lhw = lhw / (lhw + rhw)
         if math.random() < lhw then return lhs else return rhs end
      end,
   }
)
