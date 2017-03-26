package.path = package.path .. ';./src/?.lua'

local torchoff = require('torchoff')
local Telemetry = require('torchoff.tnt.Telemetry')
local tnt = require('torchnet')

assert(#arg == 2, 'Usage: example.lua <showoff_host> <showoff_port>')
local host = arg[1]
local port = tonumber(arg[2])

-- Create a client for communicating with the Showoff server.
local client = torchoff.Client.new(host, port)

-- Create a table of Torchnet meters. This table should be two levels deep
-- so that meters can be grouped into graphs.
local meters = {
  loss = {
    train = tnt.AverageValueMeter(),
    val = tnt.AverageValueMeter(),
  }
}

local tele = Telemetry.new{
  -- The title of the Showoff notebook to be created.
  title = string.format('Telemetry example'),
  -- Miscellaneous extra frames. When `autoflush` is true, the frame is
  -- immediately updated when its value is set, otherwise it is only updated when
  -- `finish_epoch()` is called.
  misc_frames = {
    text_box = {type = 'text', autoflush = true},
  },
  -- The Torchnet meters
  meters = meters,
  -- The Showoff client
  torchoff_client = client,
  -- Title of the x-axis for meter graphs. Default is "Epoch".
  graph_x_title = 'Step'
}

tele:set{
  text_box = 'Hello there!',
}

local n_epochs = 5
for epoch = 1, n_epochs do
  meters.loss.train:add(torch.uniform(1, 2))
  meters.loss.val:add(torch.uniform(0.5, 1.5))

  tele:progress(epoch, n_epochs)
  tele:finish_epoch()
end
