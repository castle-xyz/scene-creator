Expression = {
   expressions = {},
   BaseExpression = {
      expressionType = 'base',
      returnType = 'nil',
      params = nil,
   },
}

function Expression.eval(maybeExpression)
   local typ = type(maybeExpression)
   if typ == "table" and Expression.expressions[maybeExpression.expressionType] then
      return Expression.expressions[maybeExpression.expressionType].eval(maybeExpression)
   end

   -- not an expression, so treat as a primitive
   return maybeExpression
end

Expression.expressions['number'] = {
   returnType = 'number',
   description = 'a constant number',
   paramSpecs = {
      value = {
         description = 'Value',
         method = 'numberInput',
         initialValue = 0,
         expression = false,
      },
   },
   eval = function(expression)
      return expression.params.value
   end
}

Expression.expressions['random'] = {
   returnType = 'number',
   description = 'a random number',
   paramSpecs = {
      min = {
         description = 'Minimum value',
         method = 'numberInput',
         initialValue = 0,
         expression = false, -- TODO: allow expression
      },
      max = {
         description = 'Maximum value',
         method = 'numberInput',
         initialValue = 1,
         expression = false, -- TODO: allow expression
      },
   },
   eval = function(expression)
      local min, max = Expression.eval(expression.params.min), Expression.eval(expression.params.max)
      return min + math.random() * (max - min)
   end
}
