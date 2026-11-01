FILE_NETWORKS = "/etc/networks"

local ip_util = require("ip_util")


-- maps "if-name": "peripheral-name"
local config = {}

local function read_config_from_file()
  local config_file = fs.open(FILE_NETWORKS, "r")
  if not config_file then
    return {}
  end
  config = textutils.unserializeJSON(config_file.readAll())
  config_file.close()
end

local function save_config_to_file()
  local config_file = fs.open(FILE_NETWORKS, "w")
  config_file.write(textutils.serializeJSON(config))
  config_file.close()
end


local function interfaces()
  read_config_from_file()
  return config["interfaces"] or {}
end

local function arp_snooping()
  read_config_from_file()
  if not config["options"] then
    return true
  end
  return config["options"]["arp_snooping"] or true
end

local function generate_default_config()
  config = {
    interfaces = {},
    options = {
      arp_snooping = true
    }
  }

  save_config_to_file()
end

local function get_interface_for_device(device_name)
  read_config_from_file()
  local src_interface = nil
  for interface, interface_config in pairs(interfaces()) do
    if interface_config["device"] and device_name == interface_config["device"] then
      src_interface = interface
      break
    end
  end
  return src_interface
end

local function mac_address(interface)
  read_config_from_file()
  if not config["interfaces"] or not config["interfaces"][interface] then
    return nil
  end

  return config["interfaces"][interface]["mac_address"]
end

local function device(interface)
  read_config_from_file()
  if not config["interfaces"] or not config["interfaces"][interface] then
    return nil
  end

  return config["interfaces"][interface]["device"]
end

local function ip_address(interface)
  read_config_from_file()
  if not conifg["interfaces"] or not config["interfaces"][interface] or not config["interfaces"][interface]["ip_address"] then
    return nil
  end

  local interface_address, _ = ip_util.cidr2subnet(config["interfaces"][interface]["ip_address"])
  return interface_address
end

return {
  interfaces = interfaces,
  arp_snooping = arp_snooping,
  generate_default_config = generate_default_config,
  get_interface_for_device = get_interface_for_device,
  mac_address = mac_address,
  ip_address = ip_address,
  device = device
}
