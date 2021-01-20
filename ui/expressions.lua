function Client:uiExpressions()
   local expressions = {}
   for name, spec in pairs(Expression.expressions) do
      expressions[name] = {
         description = spec.description,
         returnType = spec.returnType,
         category = spec.category and spec.category or 'values',
         paramSpecs = spec.paramSpecs,
      }
   end
   ui.data(
      {
         expressions = expressions,
      }
   )
end
