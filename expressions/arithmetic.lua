Common:defineExpression(
   "+", {
      returnType = "number",
      category = "operators",
      description = "the sum of two values",
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
      description = "the product of two values",
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
         return lhs * rhs
      end,
   }
)

Common:defineExpression(
   "-", {
      returnType = "number",
      category = "operators",
      description = "the difference between two values",
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
      description = "the quotient of two values",
      paramSpecs = {
         lhs = {
            label = "Numerator",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Denominator",
            method = "numberInput",
            initialValue = 0,
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
      description = "one value modulo another",
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
      description = "one value to the power of another",
      paramSpecs = {
         lhs = {
            label = "Base",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Exponent",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs ^ rhs
      end,
   }
)
