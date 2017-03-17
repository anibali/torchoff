# Torchoff

Torchoff is a [Showoff](https://github.com/anibali/showoff) client for Torch.

## Usage

### torchoff.tnt.Telemetry

```lua
local torchoff = require('torchoff')
local Telemetry = require('torchoff.tnt.Telemetry')
local tnt = require('torchnet')

local client = torchoff.Client.new('localhost', 3000)

local meters = {
  loss = {
    train = tnt.AverageValueMeter()
  }
}

local tele = Telemetry.new{
  title = string.format('Training a model'),
  meters = meters,
  torchoff_client = client,
}

local n_epochs = 10
for epoch = 1, n_epochs do
  local loss = torch.uniform(1, 2)
  meters.loss.train:add(loss)

  tele:progress(epoch, n_epochs)
  tele:finish_epoch()
end
```

## Requirements

The basic requirements are:

* cjson
* httpclient
* argcheck
* penlight
* lbase64

And, if using `torchoff.tnt`, the following are also required:

* torch
* torchnet
