-- Honour node.disabled on Bluetooth nodes.
--
-- WirePlumber 0.5.17 skips node creation when node.disabled is set, but only
-- in the ALSA, V4L2 and libcamera monitors. Its BlueZ monitor reads
-- device.disabled and ignores node.disabled, so a monitor.bluez.rules entry
-- cannot remove a single node of a Bluetooth device.
--
-- The upstream hook order for one node is:
--   monitor/bluez/name-node      applies monitor.bluez.rules
--   monitor/bluez/create-offload-node
--   monitor/bluez/create-set-node
--   monitor/bluez/create-node    creates the node
--
-- This hook runs between the first two. It reads the properties that the rules
-- produced and stops the event before any creating hook runs.

log = Log.open_topic ("s-monitors-bluez")

SimpleEventHook {
  name = "monitor/bluez/skip-disabled-node",
  after = "monitor/bluez/name-node",
  before = "monitor/bluez/create-offload-node",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "create-bluez-device-node" },
    },
  },
  execute = function (event)
    local properties = event:get_data ("node-properties")
    if properties == nil then
      return
    end

    local disabled = properties["node.disabled"]
    if disabled == "true" or disabled == "1" then
      log:notice ("Bluez node " .. tostring (properties["node.name"]) ..
          " disabled by configuration")
      event:stop_processing ()
    end
  end
}:register ()
