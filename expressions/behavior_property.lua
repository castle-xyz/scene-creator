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
      eval = function(game, actorId, expression)
         if not expression.params.behaviorId or not expression.params.propertyName then
            return nil
         end

         -- behavior's property must allow rules to read it
         local behavior = game.behaviors[expression.params.behaviorId]
         if not behavior.propertySpecs[expression.params.propertyName].rules
         or not behavior.propertySpecs[expression.params.propertyName].rules.get then
            return nil
         end

         -- identify actor whose property to read
         local targetActorId
         if expression.params.actorRef.kind == "self" then
            targetActorId = actorId
         elseif expression.params.actorRef.kind == "closest" then
            targetActorId = game:closestActorWithTag(actorId, expression.params.actorRef.tag)
         end

         local component = behavior.components[targetActorId]
         if component then
            if behavior.getters[expression.params.propertyName] then
               return behavior.getters[expression.params.propertyName](behavior, component)
            else
               return component.properties[expression.params.propertyName]
            end
         end
         return nil
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
