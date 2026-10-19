-- A manual default device lasts only until a device comes or goes.
--
-- The sound panel stores a manual choice as default.configured.audio.sink or
-- default.configured.audio.source. WirePlumber then ranks that device above
-- every other one. Clearing both keys when an audio device node appears or
-- disappears hands the choice back to the priority ranking in
-- modules/audio.nix. Streams are not device nodes, so they never clear it.

log = Log.open_topic ("s-mountainous")

local function interest (event_type, media_class)
  return EventInterest {
    Constraint { "event.type", "=", event_type },
    Constraint { "media.class", "=", media_class },
  }
end

SimpleEventHook {
  name = "mountainous/forget-manual-default",
  interests = {
    interest ("node-added", "Audio/Sink"),
    interest ("node-added", "Audio/Source"),
    interest ("node-removed", "Audio/Sink"),
    interest ("node-removed", "Audio/Source"),
  },
  execute = function (event)
    local om = event:get_source ():call ("get-object-manager", "metadata")
    local metadata = om:lookup { Constraint { "metadata.name", "=", "default" } }
    if not metadata then
      return
    end

    for _, kind in ipairs { "audio.sink", "audio.source" } do
      local key = "default.configured." .. kind
      if metadata:find (0, key) then
        log:info (string.format ("%s: cleared by %s of %s",
            key, event:get_properties () ["event.type"],
            tostring (event:get_subject ().properties ["node.name"])))
        metadata:set (0, key, nil, nil)
      end
    end
  end
}:register ()
