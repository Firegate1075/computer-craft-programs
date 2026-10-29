EVENT_ID_LINK_TX = "link.transmit"
EVENT_ID_LINK_RX = "link.receive"
EVENT_ID_ARP_REQUEST = "arp.request"
EVENT_ID_ARP_REPLY = "arp.reply"

FILE_ARPTABLE = "/etc/arp"
FILE_LOG = "/var/log/arp.log"

PROTOCOL_IDENTIFIER = "ARP"
OPERATION_REQUEST = "REQUEST"
OPERATION_REPLY = "REPLY"


--TODO: move to config
IP_ADDRESS = 10
DO_ARP_SNOOPING = true

local arp_table = {}

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

local function update_arp_table(ip_address, mac_address, interface)
  arp_table[ip_address] = {
    mac = mac_address,
    interface = interface
  }
  arp_file = fs.open(FILE_ARPTABLE, "w")
  arp_file.write(textutils.serializeJSON(arp_table))
  arp_file.close()
end

local function transmit_arp_reply(requesting_ip, requesting_mac, interface)
  local packet = {
    src_address = os.getComputerID(),
    dst_address = requesting_mac,
    payload = {
      protocol = PROTOCOL_IDENTIFIER,
      operation = OPERATION_REPLY,
      sender_ip = IP_ADDRESS,
      sender_mac = os.getComputerID(),
      target_ip = requesting_ip,
      target_mac = requesting_mac
    }
  }
  os.queueEvent(EVENT_ID_LINK_TX, { interface = interface, packet = packet })
end

local function transmit_arp_request(requested_ip, interface)
  local packet = {
    src_address = os.getComputerID(),
    dst_address = 0xFFFF,
    payload = {
      protocol = PROTOCOL_IDENTIFIER,
      operation = OPERATION_REPLY,
      sender_ip = IP_ADDRESS,
      sender_mac = os.getComputerID(),
      target_ip = requested_ip,
    }
  }
  os.queueEvent(EVENT_ID_LINK_TX, { interface = interface, packet = packet })
end

local function handle_event(event_name, ...)
  if event_name == EVENT_ID_ARP_REQUEST then
    local request_data = ...
    local target_ip = request_data["target_ip"]
    local interface = request_data["interface"]
    -- handle arp request: transmit request
    transmit_arp_request(target_ip, interface)
  elseif event_name == EVENT_ID_LINK_RX then
    -- handle link layer received packet
    local link_event_data = ...
    local interface = link_event_data["interface"]
    local packet = link_event_data["packet"]["payload"]

    if not packet["protocol"] or packet["protocol"] ~= PROTOCOL_IDENTIFIER then
      -- not an arp packet -> skip
      return
    end

    if not packet["operation"] then
      log("error: received packet with missing operation field: " .. textutils.serialize(packet))
      return
    end

    if packet["operation"] == OPERATION_REPLY then
      -- process the reply
      update_arp_table(packet["sender_ip"], packet["sender_mac"], interface)
    elseif packet["operation"] == OPERATION_REQUEST then
      -- process the request
      if packet["target_mac"] == os.getComputerID() then
        update_arp_table(packet["sender_ip"], packet["sender_mac"], interface)
        transmit_arp_reply(packet["sender_ip"], packet["sender_mac"], interface)
      elseif DO_ARP_SNOOPING then
        update_arp_table(packet["sender_ip"], packet["sender_mac"], interface)
      end
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
