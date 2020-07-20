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
    if opts.isOrigin then
        if self.dependencies.Body:getShapeType(component.actorId) ~= "circle" then
            local physics = self.dependencies.Body:getPhysics()
            local width, height = self.dependencies.Body:getSize(component.actorId)
            local newRadius = 0.5 * (width and height and math.max(width, height) or UNIT)
            self.dependencies.Body:setShapes(component.actorId, {physics:newCircleShape(newRadius)})
        end
    end
end

function CircleShapeBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin and not opts.removeActor then
        self.dependencies.Body:resetShapes(component.actorId)
    end
end

function CircleShapeBehavior.setters:radius(component, value)
   value = math.max(0.5 * MIN_BODY_SIZE, math.min(value, 0.5 * MAX_BODY_SIZE))
   local actorId = component.actorId
   local physics = self.dependencies.Body:getPhysics()
   self.dependencies.Body:setShapes(actorId, {physics:newCircleShape(value)})
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
