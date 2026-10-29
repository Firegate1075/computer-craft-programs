EVENT_ID_MODEM = "modem_message"
EVENT_ID_RADIO = "radio_message"
EVENT_ID_TX = "link.transmit"
EVENT_ID_RX = "link.receive"

PERIPHERAL_ID_MODEM = "modem"
PERIPHERAL_ID_RADIO = "radio_tower"

FILE_INTERFACES = "/etc/interfaces"
FILE_LOG = "/var/log/link.log"

CRC_POLYNOMIAL = 0x04C11DB7

-- maps "if-name": "peripheral-name"
local config_interfaces = {}

local function process_config()
  local file_interface = fs.open(FILE_INTERFACES, "r")
  config_interfaces = textutils.unserializeJSON(file_interface.readAll())
  file_interface.close()
end

local function initialize_log()
  local log_file = fs.open(FILE_LOG, "w")
  log_file.writeLine(os.date("%F %T") .. " - link layer service started")
  log_file.close()
end

local function log(message)
  local log_file = fs.open(FILE_LOG, "a")
  log_file.writeLine(os.date("%F %T") .. " - " .. message)
  log_file.close()
end

-- see https://ccf.squiddev.cc/topic/9867-cyclic-redundancy-checks-aka-crc.html
-- https://pastebin.com/GWmNGwMV
local function calculate_CRC(gen_poly, data)
  local remainder = 0
  for i = 1, #data do
    remainder = bit.bxor(remainder, bit.blshift(data[i], 24))
    for _ = 1, 8 do
      if (bit.band(remainder, 0x80000000) > 0) then
        remainder = bit.bxor(bit.blshift(remainder, 1), gen_poly)
      else
        remainder = bit.blshift(remainder, 1)
      end
    end
  end
  return remainder
end

local function calculate_packet_crc(packet)
  local crc_packet = {
    src_address = packet["src_address"],
    dst_address = packet["dst_address"],
    payload = packet["payload"],
  }
  local data_string = textutils.serialize(crc_packet)
  local data = {}
  for index = 1, #data_string do
    data[index] = data_string:byte(index)
  end

  return calculate_CRC(CRC_POLYNOMIAL, data)
end

local function handle_event(event_name, ...)
  if event_name == EVENT_ID_MODEM then
    -- handle received modem message event
    local peripheral_name, dst_address, src_address, message, distance = ...

    if dst_address ~= os.getComputerID() and dst_address ~= 0xFFFF then
      -- packet is not meant for us, drop it
      return
    end

    -- find interface name for the hardware device
    local src_interface = nil
    for interface, device in pairs(config_interfaces) do
      if peripheral_name == device then
        src_interface = interface
        break
      end
    end

    if src_interface == nil then
      log("error: no interface found for device " .. peripheral_name)
      return
    end

    deserialized_message = textutils.unserializeJSON(message)

    local packet = {
      src_address = src_address,
      dst_address = dst_address,
      payload = deserialized_message["payload"],
      checksum = deserialized_message["checksum"]
    }
    if packet["checksum"] ~= calculate_packet_crc(packet) then
      log("error: packet received with incorrect checksum")
      return
    end

    local link_event_data = { interface = src_interface, packet = packet }
    os.queueEvent(EVENT_ID_RX, link_event_data)
  elseif event_name == EVENT_ID_RADIO then
    -- handle received radio message event
    local peripheral_name, message, distance = ...

    -- find interface name for the hardware device
    local src_interface = nil
    for interface, device in pairs(config_interfaces) do
      if peripheral_name == device then
        src_interface = interface
        break
      end
    end

    if src_interface == nil then
      log("error: no interface found for device " .. peripheral_name)
      return
    end

    deserialized_message = textutils.unserializeJSON(message)

    local packet = {
      src_address = deserialized_message["src_address"],
      dst_address = deserialized_message["dst_address"],
      payload = deserialized_message["payload"],
      checksum = deserialized_message["checksum"]
    }
    if packet["dst_address"] ~= os.getComputerID() and packet["dst_address"] ~= 0xFFFF then
      -- packet is not meant for us, drop it
      return
    end
    if packet["checksum"] ~= calculate_packet_crc(packet) then
      log("error: packet received with incorrect checksum")
      return
    end

    local link_event_data = { interface = src_interface, packet = packet }
    os.queueEvent(EVENT_ID_RX, link_event_data)
  elseif event_name == EVENT_ID_TX then
    -- handle transmit request
    local link_event_data = ...
    local interface = link_event_data["interface"]
    local packet = link_event_data["packet"]

    local device_name = config_interfaces[interface]
    local dev = peripheral.wrap(device_name)
    if not dev then
      log("error: peripheral " .. device_name .. " not found")
      return
    end

    if not packet["src_address"] then
      log("error: missing source MAC address for modem packet " .. textutils.serialize(packet))
      return
    end
    if not packet["dst_address"] then
      log("error: missing destination MAC address for modem packet " .. textutils.serialize(packet))
      return
    end

    if packet["src_address"] ~= os.getComputerID() then
      log("error: dropping packet with foreign source address " .. packet["src_address"])
      return
    end

    message = {
      payload = packet["payload"],
      checksum = packet["checksum"]
    }

    -- calculate checksum
    message["checksum"] = calculate_packet_crc(packet)

    if peripheral.hasType(dev, PERIPHERAL_ID_MODEM) then
      dev.transmit(packet["dst_address"], packet["src_address"], textutils.serialiseJSON(message))
    elseif peripheral.hasType(dev, PERIPHERAL_ID_RADIO) then
      -- radio does not have native addressing, so we add it into the layer 2 message
      message["src_address"] = packet["src_address"]
      message["dst_address"] = packet["dst_address"]

      dev.broadcast(textutils.serializeJSON(message))
    else
      log("error: device " ..
        device_name .. " for interface " .. interface .. " has unsupported type " .. peripheral.getType(dev))
      return
    end
  end
end

local function run()
  initialize_log()
  process_config()
  while true do
    handle_event(os.pullEvent())
  end
end

return { run = run }
