Common:defineExpression(
   "abs", {
      returnType = "number",
      category = "arithmetic",
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
   "log", {
      returnType = "number",
      category = "arithmetic",
      description = "logarithm",
      paramSpecs = {
         base = {
            label = "Base",
            method = "numberInput",
            initialValue = 2,
         },
         number = {
            label = "Number",
            method = "numberInput",
            initialValue = 1,
         },
      },
      eval = function(game, expression, actorId, context)
         local base, x = game:evalExpression(expression.params.base, actorId, context), game:evalExpression(expression.params.number, actorId, context)
         return math.log(x) / math.log(base)
      end,
   }
)

-- TODO: flexible number of inputs for min, max, choose

Common:defineExpression(
   "min", {
      returnType = "number",
      category = "choices",
      description = "minimum",
      paramSpecs = {
         lhs = {
            label = "First input",
            method = "numberInput",
            initialValue = 0,
         },
         rhs = {
            label = "Second input",
            method = "numberInput",
            initialValue = 1,
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
      description = "maximum",
      paramSpecs = {
         lhs = {
            label = "First input",
            method = "numberInput",
            initialValue = 0,
         },
         rhs = {
            label = "Second input",
            method = "numberInput",
            initialValue = 1,
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
      description = "choose",
      paramSpecs = {
         lhs = {
            label = "First outcome",
            method = "numberInput",
            initialValue = 0,
         },
         rhs = {
            label = "Second outcome",
            method = "numberInput",
            initialValue = 1,
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
      description = "weighted choose",
      paramSpecs = {
         lhs = {
            label = "First outcome",
            method = "numberInput",
            initialValue = 0,
         },
         rhs = {
            label = "Second outcome",
            method = "numberInput",
            initialValue = 1,
         },
         lhw = {
            label = "Weight of first outcome",
            method = "numberInput",
            initialValue = 0.5,
         },
         rhw = {
            label = "Weight of second outcome",
            method = "numberInput",
            initialValue = 0.5,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         local lhw, rhw = game:evalExpression(expression.params.lhw, actorId, context), game:evalExpression(expression.params.rhw, actorId, context)
         if rhw == 0 then return lhs end
         if lhw == 0 then return rhs end
         lhw = lhw / (lhw + rhw)
         if math.random() < lhw then return lhs else return rhs end
      end,
   }
)
