-- compute the dotted decimal representation of an IPv4 address
local function ip2string(ip_address)
  restult = ""
  result = result .. tostring(bit32.rshift(bit32.band(ip_address, 0xFF000000), 24))
  result = result .. tostring(bit32.rshift(bit32.band(ip_address, 0x00FF0000), 16))
  result = result .. tostring(bit32.rshift(bit32.band(ip_address, 0x0000FF00), 8))
  result = result .. tostring(bit32.band(ip_address, 0x000000FF))
  return result
end

local function string2ip(ip_string)
  local octet_strings = {}
  index = 1
  for part in string.gmatch(ip_string, "%.") do -- split the string at the dots
    octet_strings[index] = part
    index = index + 1
  end

  return bit32.lshift(tonumber(octet_strings[1]), 24) + bit32.lshift(tonumber(octet_strings[2]), 16) +
      bit32.lshift(tonumber(octet_strings[3]), 8) + tonumber(octet_strings[4])
end

local function subnet2cidr(net_address, bit_mask)
  local prefix_length = 0
  -- count the number of set msbs
  for index = 31, 0, -1 do
    if bit32.band(bit32.rshift(bit_mask, index), 1) then
      prefix_length = 32 - index
    else
      break
    end
  end
  return ip2string(net_address) .. "/" .. tostring(prefix_length)
end

local function cidr2subnet(cidr_representation)
  local parts = {}
  local index = 1
  for part in string.gmatch(cidr_representation, "/") do
    parts[index] = part
    index = index + 1
  end

  local prefix_length = tonumber(parts[2])
  local subnet_mask = bit32.bnot(bit32.lshift(1, 32 - prefix_length) - 1)

  return string2ip(parts[1]), subnet_mask
end

return {
  ip2string = ip2string,
  string2ip = string2ip,
  subnet2cidr = subnet2cidr,
  cidr2subnet = cidr2subnet
}
