FILE_FORWARDING_TABLE = "/etc/route"

local ip_util = require("ip_util")

local forwarding_table = {}

local function read_forwarding_table_from_file()
  local table_file = fs.open(FILE_FORWARDING_TABLE, "r")
  if not table_file then
    return {}
  end
  forwarding_table = textutils.unserializeJSON(table_file.readAll())
  table_file.close()
end


local function get_longest_prefix_match(dst_address)
  read_forwarding_table_from_file()

  local longest_match_key = nil
  local longest_match_subnet_mask = -1

  for target_net, route in pairs(forwarding_table) do
    local target_net_address, target_net_subnet_mask = ip_util.cidr2subnet(target_net)
    local matching = bit32.band(dst_address, target_net_subnet_mask) == target_net_address
    if matching and target_net_subnet_mask > longest_match_subnet_mask then
      longest_match_key = target_net
      longest_match_subnet_mask = target_net_subnet_mask
    end
  end

  return longest_match_key
end

local function routes()
  read_forwarding_table_from_file()
  return forwarding_table
end

local function has_direct_delivery(dst_address)
  local route = get_longest_prefix_match(dst_address)
  return not forwarding_table[route]["gateway"] or forwarding_table[route]["gateway"] == false
end

local function interface(dst_address)
  local route = get_longest_prefix_match(dst_address)
  return forwarding_table[route]["interface"]
end

local function next_hop(dst_address)
  local route = get_longest_prefix_match(dst_address)
  return ip_util.string2ip(forwarding_table[route]["next_hop"])
end

return {
  routes = routes,
  has_direct_delivery = has_direct_delivery,
  interface = interface,
  next_hop = next_hop
}
