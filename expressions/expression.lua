Expression = {
   expressions = {},
   BaseExpression = {
      expressionType = "base",
      returnType = "nil",
      params = nil,
   },
}

function Common:evalExpression(maybeExpression)
   local typ = type(maybeExpression)
   if typ == "table" and Expression.expressions[maybeExpression.expressionType] then
      return Expression.expressions[maybeExpression.expressionType].eval(self, maybeExpression)
   end

   -- not an expression, so treat as a primitive
   return maybeExpression
end

Expression.expressions["number"] = {
   returnType = "number",
   description = "a constant number",
   paramSpecs = {
      value = {
         label = "Value",
         method = "numberInput",
         initialValue = 0,
         expression = false,
      },
   },
   eval = function(game, expression)
      return expression.params.value
   end
}

Expression.expressions["random"] = {
   returnType = "number",
   description = "a random number",
   paramSpecs = {
      min = {
         label = "Minimum value",
         method = "numberInput",
         initialValue = 0,
         expression = false, -- TODO: allow expression
      },
      max = {
         label = "Maximum value",
         method = "numberInput",
         initialValue = 1,
         expression = false, -- TODO: allow expression
      },
   },
   eval = function(game, expression)
      local min, max = game:evalExpression(expression.params.min), game:evalExpression(expression.params.max)
      return min + math.random() * (max - min)
   end
}

Expression.expressions["variable"] = {
   returnType = "number",
   description = "the value of a variable",
   paramSpecs = {
      variableId = {
         label = "variable",
         method = "dropdown",
         initialValue = "(none)",
         props = { showVariablesItems = true },
      },
   },
   eval = function(game, expression)
      return game:variableIdToValue(expression.params.variableId)
   end
}
