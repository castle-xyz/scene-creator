local function evalActorRef(actorRef, sourceActorId, game, context)
   local targetActorId
   if actorRef.kind == "self" then
      targetActorId = sourceActorId
   elseif actorRef.kind == "closest" then
      targetActorId = game:closestActorWithTag(sourceActorId, actorRef.tag)
   elseif actorRef.kind == "other" then
      targetActorId = context.otherActorId
   end
   return targetActorId
end

Common:defineExpression(
   "behavior property", {
      returnType = "number",
      description = "the value of a behavior property",
      paramSpecs = {
         behaviorId = {
            label = "behavior",
            method = "dropdown",
            initialValue = nil,
         },
         propertyName = {
            label = "parameter",
            method = "dropdown",
            initialValue = nil,
         },
         actorRef = {
            label = "actor type",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
      },
      eval = function(game, expression, actorId, context)
         if not expression.params.behaviorId or not expression.params.propertyName then
            return 0
         end

         -- behavior's property must allow rules to read it
         local behavior = game.behaviors[expression.params.behaviorId]
         if not behavior.propertySpecs[expression.params.propertyName].rules
         or not behavior.propertySpecs[expression.params.propertyName].rules.get then
            return 0
         end

         -- identify actor whose property to read
         local targetActorId = evalActorRef(expression.params.actorRef, actorId, game, context)

         local component = behavior.components[targetActorId]
         if component then
            if behavior.getters[expression.params.propertyName] then
               return behavior.getters[expression.params.propertyName](behavior, component)
            else
               return component.properties[expression.params.propertyName]
            end
         end
         return 0
      end,
   }
)

Common:defineExpression(
   "counter value", {
      returnType = "number",
      description = "the value of a counter",
      paramSpecs = {
         actorRef = {
            label = "actor type",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
      },
      eval = function(game, expression, actorId, context)
         -- this expression type is just a wrapper for behavior property
         -- with a fixed behavior (Counter) and property (value)
         local behaviorExpression = util.deepCopyTable(expression)
         behaviorExpression.params.behaviorId = game.behaviorsByName.Counter.behaviorId
         behaviorExpression.params.propertyName = "value"
         return Expression.expressions["behavior property"].eval(game, behaviorExpression, actorId, context)
      end,
   }
)

Common:defineExpression(
   "actor distance", {
      returnType = "number",
      description = "the distance between two actors",
      category = "spatial relationships",
      paramSpecs = {
         fromActor= {
            label = "from actor",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
         toActor = {
            label = "to actor",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
      },
      eval = function(game, expression, actorId, context)
         local fromActorId, toActorId = evalActorRef(expression.params.fromActor, actorId, game, context), evalActorRef(expression.params.toActor, actorId, game, context)

         local body = game.behaviorsByName.Body
         local fromBody = body.components[fromActorId]
         local toBody = body.components[toActorId]

         if fromBody and toBody then
            local x1, y1 = body.getters.x(body, fromBody), body.getters.y(body, fromBody)
            local x2, y2 = body.getters.x(body, toBody), body.getters.y(body, toBody)
            local dx, dy = x2 - x1, y2 - y1
            return math.sqrt(dx * dx + dy * dy)
         end
         return 0
      end,
   }
)

Common:defineExpression(
   "actor angle", {
      returnType = "number",
      description = "the angle from one actor to another (degrees)",
      category = "spatial relationships",
      paramSpecs = {
         fromActor= {
            label = "from actor",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
         toActor = {
            label = "to actor",
            method = "actorRef",
            initialValue = { kind = "self" },
         },
      },
      eval = function(game, expression, actorId, context)
         local fromActorId, toActorId = evalActorRef(expression.params.fromActor, actorId, game, context), evalActorRef(expression.params.toActor, actorId, game, context)

         local body = game.behaviorsByName.Body
         local fromBody = body.components[fromActorId]
         local toBody = body.components[toActorId]

         if fromBody and toBody then
            local x1, y1 = body.getters.x(body, fromBody), body.getters.y(body, fromBody)
            local x2, y2 = body.getters.x(body, toBody), body.getters.y(body, toBody)
            return math.deg(math.atan2(y2 - y1, x2 - x1))
         end
         return 0
      end,
   }
)

function Common:closestActorWithTag(actorId, tag)
   local members = self.behaviorsByName.Body:getMembers(actorId)
   local x, y = 0, 0
   if members.body then
      x, y = members.body:getPosition()
   end
   
   local closestActorId, minDistance, actorX, actorY = nil, math.huge, 0, 0
   for otherActorId, actor in pairs(self.actors) do
      if otherActorId ~= actorId
      and ((not tag or tag == '') or self.behaviorsByName.Tags:actorHasTag(otherActorId, tag)) then
         local members = self.behaviorsByName.Body:getMembers(otherActorId)
         if members.body then
            local otherX, otherY = members.body:getPosition()
            if members.layer and members.layer.relativeToCamera then
               local cameraX, cameraY = self:getCameraPosition()
               otherX = otherX + cameraX
               otherY = otherY + cameraY
            end

            local dx, dy = otherX - x, otherY - y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < minDistance then
               minDistance = dist
               closestActorId = otherActorId
               actorX = otherX
               actorY = otherY
            end
         end
      end
   end
   return closestActorId, actorX, actorY
end
