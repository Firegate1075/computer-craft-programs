-- SPDX-FileCopyrightText: 2017 Daniel Ratcliffe
--
-- SPDX-License-Identifier: LicenseRef-CCPL

json = require("json")

local function printUsage()
  local programName = arg[0] or fs.getName(shell.getRunningProgram())
  print("Usages:")
  print(programName .. " host")
  print(programName .. " host <x> <y> <z>")
  print(programName .. " locate")
end

local tArgs = { ... }
if #tArgs < 1 then
  printUsage()
  return
end

local sCommand = tArgs[1]
if sCommand == "locate" then
  -- "gps locate"
  -- Just locate this computer (this will print the results)
  radiogps.locate(2, true)
elseif sCommand == "host" then
  -- "gps host"
  -- Act as a GPS host
  if pocket then
    print("GPS Hosts must be stationary")
    return
  end

  -- Find a radio tower
  local radio = peripheral.find("radio_tower")
  if radio == nil then
    print("No radio tower found. 1 required.")
    return
  end

  -- Determine position
  local x, y, z
  if #tArgs >= 4 then
    -- Position is manually specified
    x = tonumber(tArgs[2])
    y = tonumber(tArgs[3])
    z = tonumber(tArgs[4])
    if x == nil or y == nil or z == nil then
      printUsage()
      return
    end
    print("Position is " .. x .. "," .. y .. "," .. z)
  else
    -- Position is to be determined using locate
    x, y, z = gps.locate(2, true)
    if x == nil then
      print("Run \"radiogps host <x> <y> <z>\" to set position manually")
      return
    end
  end

  -- Open a channel
  print("Setting frequency on radio " .. peripheral.getName(radio))
  radio.setFrequency(radiogps.FREQUENCY_GPS)

  -- Serve requests indefinitely
  local nServed = 0
  while true do
    local event, source_radio, message, distance = os.pullEvent("radio_message")
    if event == "radio_message" then
      -- We received a message from a radio
      if source_radio == peripheral.getName(radio) and message == "PING" and distance then
        -- We received a ping message on the GPS channel, send a response
        radio.broadcast(json.encode({ x, y, z }))

        -- Print the number of requests handled
        nServed = nServed + 1
        if nServed > 1 then
          local _, y = term.getCursorPos()
          term.setCursorPos(1, y - 1)
        end
        print(nServed .. " GPS requests served")
      end
    end
  end
else
  -- "gps somethingelse"
  -- Error
  printUsage()
end
