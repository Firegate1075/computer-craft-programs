local ip_util = require("ip_util")
local network_config = require("nerwork_config")
local forwarding = require("forwarding")


local function print_usage()
  local program_name = arg[0] or fs.getName(shell.getRunningProgram())
  print("Useage: " .. program_name .. " OBJECT")
  print("where   OBJECT := { address | route }")
end

local args = { ... }
if #args < 1 then
  print_usage()
end


function cli()
  local command = args[1]
  if command == "address" or command == "a" then
    local index = 1
    for interface, interface_config in pairs(network_config.interfaces()) do
      local mac_address = network_config.mac_address(interface)

      print(index .. ": " .. interface .. ": " .. "mtu " .. network_config.mtu(interface))
      print("    link/ether " ..
        string.format("%x", bit32.rshift(mac_address, 8)) .. ":" .. string.format("%x", bit32.band(mac_address, 0xFF)))
      print("    inet " .. network_config.ip_cidr_string(interface))

      index = index + 1
    end
  elseif command == "route" or command == "r" then
    for target_net, route in pairs(forwarding.routes()) do
      target_net_address, _ = ip_util.cidr2subnet(target_net)
      write(target_net .. " ")
      if not forwarding.has_direct_delivery(target_net_address) then
        write(" via " .. ip_util.ip2string(forwarding.next_hop(target_net_address)))
      end
      print(" dev " .. forwarding.interface(target_net_address))
    end
  end
end

cli()
