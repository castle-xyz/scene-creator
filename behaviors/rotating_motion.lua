local RotatingMotionBehavior = defineCoreBehavior {
    name = "RotatingMotion",
    displayName = "Fixed Motion",
    dependencies = {
        "Body"
    },
    propertySpecs = {
       vx = {
          method = 'numberInput',
          label = 'Velocity X',
          rules = {
             set = true,
             get = true,
          },
       },
       vy = {
          method = 'numberInput',
          label = 'Velocity Y',
          rules = {
             set = true,
             get = true,
          },
       },
       rotationsPerSecond = {
          method = 'numberInput',
          label = 'Rotations per second',
          rules = {
             set = true,
             get = true,
          },
       },
    },
}

-- Body type

function RotatingMotionBehavior.handlers:bodyTypeComponent(component)
    return "kinematic"
end

-- Component management

function RotatingMotionBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rotationsPerSecond = bp.rotationsPerSecond or 0
    component.properties.vx = bp.vx or 0
    component.properties.vy = bp.vy or 0
end

function RotatingMotionBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

function RotatingMotionBehavior.handlers:blueprintComponent(component, bp)
    bp.rotationsPerSecond = component.properties.rotationsPerSecond
    bp.vx = component.properties.vx
    bp.vy = component.properties.vy
end

-- Perform

function RotatingMotionBehavior.handlers:perform(dt)
    for actorId, component in pairs(self.components) do
        if not component.disabled then
            local bodyId, body = self.dependencies.Body:getBody(actorId)

            -- Physics bodies are automatically synced by the server, so just set locally
            body:setLinearVelocity(component.properties.vx, component.properties.vy)
            body:setAngularVelocity(2 * math.pi * component.properties.rotationsPerSecond)
        end
    end
end

-- Responses

RotatingMotionBehavior.responses["move toward actor"] = {
   description = "Move toward another actor (fixed motion)",
   category = "motion",
   paramSpecs = {
      tag = {
         method = "textInput",
         label = "Tag",
      },
      speed = {
         method = "numberInput",
         label = "Speed",
         initialValue = 0,
      },
   },
   run = function(self, actorId, params, context)
      local members = self.game.behaviorsByName.Body:getMembers(actorId)
      local x, y = 0, 0
      if members.body then
         x, y = members.body:getPosition()
      end
      
      local closestActorId, actorX, actorY = self.game:closestActorWithTag(actorId, params.tag)
      if members.body and closestActorId ~= nil then
         local angle = math.atan2(actorY - y, actorX - x)
         local component = self.components[actorId]
         local speed = self.game:evalExpression(actorId, params.speed)
         component.properties.vx = speed * math.cos(angle)
         component.properties.vy = speed * math.sin(angle)
      end
   end
}
