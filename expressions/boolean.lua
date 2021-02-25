-- TODO: we'd like to implement actual boolean expressions
-- but for now we just have a helper method to resolve the existing comparison operators
COMPARISON_OPERATORS = {
   "equal",
   "not equal",
   "less than",
   "less or equal",
   "greater than",
   "greater or equal",
}

function Common:compare(comparison, lhs, rhs)
   if comparison == "equal" and lhs == rhs then
      return true
   end
   if comparison == "not equal" and lhs ~= rhs then
      return true
   end
   if comparison == "less or equal" and lhs <= rhs then
      return true
   end
   if comparison == "greater or equal" and lhs >= rhs then
      return true
   end
   if comparison == "less than" and lhs < rhs then
      return true
   end
   if comparison == "greater than" and lhs > rhs then
      return true
   end
   return false
end
