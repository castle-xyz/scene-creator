Common:defineExpression(
   "+", {
      returnType = "number",
      category = "operators",
      description = "add",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs + rhs
      end,
   }
)

Common:defineExpression(
   "*", {
      returnType = "number",
      category = "operators",
      description = "multiply",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs * rhs
      end,
   }
)

Common:defineExpression(
   "-", {
      returnType = "number",
      category = "operators",
      description = "subtract",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs - rhs
      end,
   }
)

Common:defineExpression(
   "/", {
      returnType = "number",
      category = "operators",
      description = "divide",
      paramSpecs = {
         lhs = {
            label = "Numerator",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Denominator",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         if rhs == 0 then
            return 0
         end
         return lhs / rhs
      end,
   }
)

Common:defineExpression(
   "%", {
      returnType = "number",
      category = "operators",
      description = "modulo",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         if rhs == 0 then
            return 0
         end
         return lhs % rhs
      end,
   }
)

Common:defineExpression(
   "^", {
      returnType = "number",
      category = "operators",
      description = "power",
      paramSpecs = {
         lhs = {
            label = "Base",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Exponent",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs ^ rhs
      end,
   }
)
