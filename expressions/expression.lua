Expression = {
   expressions = {},
   BaseExpression = {
      expressionType = "base",
      returnType = "nil",
      params = nil,
   },
}

function Common:evalExpression(maybeExpression, actorId, context, paramSpec)
   local result
   local typ = type(maybeExpression)
   if typ == "table" and Expression.expressions[maybeExpression.expressionType] then
      result = Expression.expressions[maybeExpression.expressionType].eval(self, maybeExpression, actorId, context)
   else
      -- not an expression, so treat as a primitive
      result = maybeExpression
   end

   -- if provided, validate result according to spec
   if paramSpec ~= nil then
      if paramSpec.props ~= nil then
         if paramSpec.props.min ~= nil and result < paramSpec.props.min then
            result = paramSpec.props.min
         end
         if paramSpec.props.max ~= nil and result > paramSpec.props.max then
            result = paramSpec.props.max
         end
         if paramSpec.props.discrete ~= nil then
            result = math.floor(result)
         end
      end
   end

   return result
end

function Common:defineExpression(expressionType, expression)
   Expression.expressions[expressionType] = util.deepCopyTable(expression)
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
   eval = function(game, expression, actorId, context)
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
         order = 1,
      },
      max = {
         label = "Maximum value",
         method = "numberInput",
         initialValue = 1,
         expression = false, -- TODO: allow expression
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

Expression.expressions["variable"] = {
   returnType = "number",
   description = "the value of a variable",
   paramSpecs = {
      variableId = {
         label = "Variable name",
         method = "dropdown",
         initialValue = "(none)",
         props = { showVariablesItems = true },
      },
   },
   eval = function(game, expression, actorId, context)
      return game:variableIdToValue(expression.params.variableId)
   end
}
