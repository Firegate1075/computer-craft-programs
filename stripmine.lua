ITEM_TORCH = "minecraft:torch"
ITEM_COBBLE = "minecraft:cobblestone"
ITEM_CHEST = "minecraft:chest"

local blocks_since_torch = 0

function forward()
  while (turtle.forward() == false) do
    turtle.dig()
  end
end

function digUp()
  while (turtle.detectUp()) do
    turtle.digUp()
    sleep(0.4)
  end
end

function placeTorch()
  slot = findItem(ITEM_TORCH)
  if not slot then
    return
  end
  turtle.turnRight()
  turtle.turnRight()
  turtle.select(slot)
  turtle.place()
  turtle.turnRight()
  turtle.turnRight()
  blocks_since_torch = 0
end

function placeChestAndDump()
  slot = findItem(ITEM_CHEST)
  if not slot then
    return
  end
  turtle.turnLeft()
  while not turtle.up() do
    turtle.digUp()
  end
  turtle.dig()
  while not turtle.down() do
    turtle.down()
  end
  turtle.dig()
  turtle.select(slot)
  success = turtle.place()
  if success then
    for slot = 1, 16 do
      info = turtle.getItemDetail(slot)
      if info and not (info.name == ITEM_TORCH or info.name == ITEM_COBBLE or info.name == ITEM_CHEST) then
        turtle.select(slot)
        turtle.drop()
      end
    end
  end
  turtle.select(1)
  turtle.turnRight()
end

function step()
  forward()
  digUp()
  slot = findItem(ITEM_COBBLE)
  if slot then
    turtle.select(slot)
    turtle.placeDown()
  end
  if (blocks_since_torch > 12) then
    placeTorch()
  end
  if turtle.getItemCount(16) ~= 0 then
    condenseInventory()
    if turtle.getItemCount(16) ~= 0 then
      placeChestAndDump()
    end
  end
  blocks_since_torch = blocks_since_torch + 1
end

function findItem(item_string)
  for slot = 1, 16 do
    info = turtle.getItemDetail(slot)
    if info and info.name == item_string then
      return slot
    end
  end
  return nil
end

function condenseInventory()
  for slot_to_fill = 1, 16 do
    for grab_from_slot = (slot_to_fill + 1), 16 do
      if turtle.getItemCount(grab_from_slot) > 0 then
        turtle.select(grab_from_slot)
        turtle.transferTo(slot_to_fill)
      end
    end
  end
end

function cli()
  print("Starting strip mining program")
  while not max_width do
    write("Spiral width=")
    max_width = tonumber(read())
    if not max_width then
      print("Please enter a number!")
    end
  end
end

local spiral_length = 0

function do_spiral()
  while (spiral_length < max_width) do
    for k = 1, spiral_length do
      step()
    end
    turtle.turnRight()
    spiral_length = spiral_length + 2
  end
end

cli()
do_spiral()
