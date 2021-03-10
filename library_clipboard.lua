-- JS requests data to put a new entry into the clipboard
jsEvents.listen(
    "COPY_SELECTED_BLUEPRINT",
    function(params)
        local self = currentInstance()
        if self and self.beltEntryId then
           local entry = self.library[self.beltEntryId]
           if entry then
               local data = cjson.encode(entry)
               jsEvents.send(
                    "COPY_SELECTED_BLUEPRINT_DATA",
                    {
                        data = data
                    }
                )
               self.libraryEntryIdInClipboard = entry.entryId
               print('set library entry to', self.libraryEntryIdInClipboard)
           end
        end
    end
)

-- JS may inform us that an entry already exists in the clipboard
jsEvents.listen(
    "SYNC_COPIED_LIBRARY_ENTRY",
    function(params)
        local self = currentInstance()
        if self then
           self.libraryEntryIdInClipboard = params.entryId
           print('set library entry to', self.libraryEntryIdInClipboard)
        end
    end
)
