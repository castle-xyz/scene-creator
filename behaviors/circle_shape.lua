local CircleShapeBehavior = defineCoreBehavior {
    name = "CircleShape",
    displayName = "circle",
    dependencies = {
        "Body"
    },
    propertySpecs = {
      radius = {
         method = 'numberInput',
         label = 'radius',
         props = { min = 0.5 * MIN_BODY_SIZE, max = 0.5 * MAX_BODY_SIZE, decimalDigits = 1 },
      },
   },
}

-- Component management

function CircleShapeBehavior.handlers:addComponent(component, bp, opts)
    if self.game.actors[component.actorId].components[self.game.behaviorsByName.Drawing2.behaviorId] then
        return
    end

    if opts.isOrigin then
        self.dependencies.Body:setShapes(component.actorId, {{
            shapeType = "circle",
            x = 0.0,
            y = 0.0,
            radius = 0.5,
        }})
    end
end

function CircleShapeBehavior.handlers:disableComponent(component, opts)
    if self.game.actors[component.actorId].components[self.game.behaviorsByName.Drawing2.behaviorId] then
        return
    end

    if opts.isOrigin and not opts.removeActor then
        self.dependencies.Body:resetShapes(component.actorId)
    end
end

function CircleShapeBehavior.setters:radius(component, value)
   value = math.max(0.5 * MIN_BODY_SIZE, math.min(value, 0.5 * MAX_BODY_SIZE))
   local actorId = component.actorId
   self.dependencies.Body:setShapes(actorId, {{
        shapeType = "circle",
        x = 0.0,
        y = 0.0,
        radius = value,
    }})
end

function CircleShapeBehavior.getters:radius(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   if members.firstFixture then
      local shape = members.firstFixture:getShape()
      if shape:getType() == "circle" then
         return shape:getRadius()
      end
   end
   return 0
end
