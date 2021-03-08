-- TODO: merge with other library code after belt lands.

function Common.receivers:pasteLibraryEntry(time, entry)
   if entry == nil or entry.entryId == nil then return end
   
   if self.library[entry.entryId] ~= nil then
      local oldEntry = self.library[entry.entryId]
      -- blueprint exists:
      -- override entryId in library, override all existing instances
      self:command('update blueprint from clipboard', {
          params = { 'entry', 'oldEntry' },
      }, function(params, live)
          self:send('updateLibraryEntry', self.clientId, entry.entryId, entry, {
              updateActors = true,
              -- skipActorId = actorId,
          })
      end, function()
          self:send('updateLibraryEntry', self.clientId, entry.entryId, oldEntry, {
              updateActors = true,
              -- skipActorId = actorId,
          })
      end)
   else
      -- entry does not exist on this card yet, add to library
      -- use same entryId so that this can be pasted again later and we know how to override
      self:command(
         'add blueprint from clipboard',
         { params = { 'entry' } },
         function(params, live)
            self:send('addLibraryEntry', entry.entryId, entry)

            -- TODO: after belt lands, adding an actor may not be the default behavior
            self:_addBlueprintToScene(entry.entryId)
         end,
         function()
            -- TODO: seems to break belt
            -- self:send('removeLibraryEntry', entry.entryId)
         end
      )
   end
end
