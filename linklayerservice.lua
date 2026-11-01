EVENT_ID_MODEM = "modem_message"
EVENT_ID_RADIO = "radio_message"
EVENT_ID_TX = "link.transmit"
EVENT_ID_RX = "link.receive"

PERIPHERAL_ID_MODEM = "modem"
PERIPHERAL_ID_RADIO = "radio_tower"

FILE_LOG = "/var/log/link.log"

CRC_POLYNOMIAL = 0x04C11DB7

local network_config = require("network_config")

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

local function calculate_packet_crc(serialized_packet)
  local data_string = serialized_packet
  local data = {}
  for index = 1, #data_string do
    data[index] = data_string:byte(index)
  end

  return calculate_CRC(CRC_POLYNOMIAL, data)
end

local function get_link_event_data_from_message(message, peripheral_name, src_address, dst_address)
  -- find interface name for the hardware device
  local src_interface = network_config.get_interface_for_device(peripheral_name)
  if src_interface == nil then
    log("error: no interface found for device " .. peripheral_name)
    return
  end

  local deserialized_message = textutils.unserializeJSON(message)
  if not deserialized_message then
    log("error: could not decode received packet " .. message)
    return
  end

  local packet = textutils.unserializeJSON(deserialized_message["serialized_packet"])
  if not packet then
    log("error: could not decode serialized packet " .. deserialized_message["serialized_packet"])
    return
  end

  local serialized_packet = deserialized_message["serialized_packet"]
  local checksum = deserialized_message["checksum"]
  packet["checksum"] = checksum

  local mac_address = network_config.mac_address(src_interface)
  if not mac_address then
    log("error: no mac address configured for interface" .. src_interface)
    return
  end

  if not packet["dst_address"] or packet["dst_address"] ~= mac_address and packet["dst_address"] ~= 0xFFFF then
    -- packet is not meant for us, drop it
    return
  end

  if src_address and packet["src_address"] and packet["src_address"] ~= src_address then
    log("error: dropping packet with spoofed src_address")
    return
  end
  if dst_address and packet["dst_address"] and packet["dst_address"] ~= dst_address then
    log("error: dropping packet with spoofed dst_address")
    return
  end

  if not packet["checksum"] or packet["checksum"] ~= calculate_packet_crc(serialized_packet) then
    log("error: packet received with incorrect checksum")
    return
  end

  return { interface = src_interface, packet = packet }
end

local function handle_event(event_name, ...)
  if event_name == EVENT_ID_MODEM then
    -- handle received modem message event
    local peripheral_name, dst_address, src_address, message, distance = ...
    local link_event_data = get_link_event_data_from_message(message, peripheral_name, src_address, dst_address)
    os.queueEvent(EVENT_ID_RX, link_event_data)
  elseif event_name == EVENT_ID_RADIO then
    -- handle received radio message event
    local peripheral_name, message, distance = ...
    local link_event_data = get_link_event_data_from_message(message, peripheral_name)
    os.queueEvent(EVENT_ID_RX, link_event_data)
  elseif event_name == EVENT_ID_TX then
    -- handle transmit request
    local link_event_data = ...
    local interface = link_event_data["interface"]
    local packet = link_event_data["packet"]
    if not interface then
      log("error: link.transmit event data missing interface field")
      return
    end
    if not packet then
      log("error: link.transmit event data missing packet field")
      return
    end

    local device_name = network_config.device(interface)
    if not device_name then
      log("error: no device specified for interface " .. interface)
      return
    end

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

    local mac_address = network_config.mac_address(interface)
    if not mac_address then
      log("error: no mac address configured for interface " .. interface)
      return
    end

    if packet["src_address"] ~= mac_address then
      log("error: dropping packet with foreign source address " .. packet["src_address"])
      return
    end

    local serialized_packet = textutils.serializeJSON({
      src_address = packet["src_address"],
      dst_address = packet["dst_address"],
      payload = packet["payload"]
    })

    local message = {
      serialized_packet = serialized_packet,
      checksum = packet["checksum"]
    }

    -- calculate checksum
    message["checksum"] = calculate_packet_crc(serialized_packet)

    if peripheral.hasType(dev, PERIPHERAL_ID_MODEM) then
      dev.transmit(packet["dst_address"], packet["src_address"], textutils.serialiseJSON(message))
    elseif peripheral.hasType(dev, PERIPHERAL_ID_RADIO) then
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
  while true do
    handle_event(os.pullEvent())
  end
end

return { run = run }
