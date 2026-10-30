EVENT_ID_ARP_REQUEST = "arp.request"
EVENT_ID_ARP_REPLY = "arp.reply"
EVENT_ID_TIMER = "timer"

FILE_ARPTABLE = "/etc/arp"

local arp_table = {}

local function fetch_arp_table()
  local arp_file = fs.open(FILE_ARPTABLE, "r")

  if not arp_file then
    return
  end

  arp_table = textutils.unserializeJSON(arp_file.readAll()) or {}
  arp_file.close()
end


local function lookup(ip_address, interface, timeout)
  timeout = timeout or 1

  fetch_arp_table()

  if not arp_table[ip_address] or arp_table[ip_address]["interface"] ~= interface then
    os.queueEvent(EVENT_ID_ARP_REQUEST, { target_ip = ip_address, interface = interface })
    local arp_timer = os.startTimer(timeout)
    while true do
      local event, p1 = os.pullEvent()
      if event == EVENT_ID_ARP_REPLY and p1["ip"] == ip_address and p1["interface"] == interface then
        return p1["mac"]
      elseif event == EVENT_ID_TIMER and p1 == arp_timer then
        os.cancelTimer(arp_timer)
        error("timeout while resolving mac address")
      end
    end
  end

  return arp_table[ip_address]["mac"]
end

return { lookup = lookup }
