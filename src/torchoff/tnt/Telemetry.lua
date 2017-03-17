local argcheck = require('argcheck')
local pl = require('pl.import_into')()

local tnt = require('torchnet')
local log_text = require('torchnet.log.view.text')

local Telemetry = torch.class('torchoff.tnt.Telemetry', {})

local cell_width = 480
local cell_height = 308
local cell_rows = 3
local cell_cols = 4

local function get_frame_bounds(index)
  local c = (index - 1) % cell_cols
  local r = math.floor((index - 1) / cell_cols)

  return {
    x = c * cell_width,
    y = r * cell_height,
    width = cell_width,
    height = cell_height
  }
end

local function flatten_meters(meters)
  local flat_meters = {}
  for group_name, group in pairs(meters) do
    for meter_name, meter in pairs(group) do
      local flat_name = string.format('%s.%s', group_name, meter_name)
      flat_meters[flat_name] = meter
    end
  end
  return flat_meters
end

Telemetry.__init = argcheck{
  {name = 'self', type = 'torchoff.tnt.Telemetry'},
  {name = 'title', type = 'string'},
  {name = 'meters', type = 'table'},
  {name = 'misc_frames', type = 'table', default = {}},
  {name = 'torchoff_client', type = 'torchoff.Client', optional = 'true'},
  call =
function(self, title, meters, misc_frames, torchoff_client)
  local log_keys = {'epoch', 'progress'}
  local log_flush_handlers = {}
  local log_set_handlers = {}

  -- Text log

  local log_text_keys = {'epoch'}
  local log_text_format = {'epoch=%3d'}

  local flat_meters = flatten_meters(meters)
  for flat_name, meter in pairs(flat_meters) do
    if torch.type(meter) ~= 'tnt.ConfusionMeter' then
      table.insert(log_text_keys, flat_name)
      table.insert(log_text_format, flat_name .. '=%7.4f')
    end
  end

  table.insert(log_flush_handlers,
    log_text{
      keys = log_text_keys,
      format = log_text_format
    }
  )

  -- Showoff log

  if torchoff_client then
    local log_showoff = require('torchoff.tnt.logshowoff')

    local notebook = torchoff_client:new_notebook(title)

    local frames = {}

    for group_name, group in pairs(meters) do
      local frame = nil

      for meter_name, meter in pairs(group) do
        local flat_name = string.format('%s.%s', group_name, meter_name)

        if frame == nil then
          if torch.type(meter) == 'tnt.ConfusionMeter' then
            frame = {
              type = 'vegalite',
              title = group_name,
              data = flat_name
            }
          else
            frame = {
              type = 'graph',
              title = group_name,
              x_title = 'Epoch',
              x_data = {},
              y_title = group_name,
              y_data = {},
              series_names = {},
            }
          end
        end

        table.insert(log_keys, flat_name)
        if frame.type == 'graph' then
          table.insert(frame.x_data, 'epoch')
          table.insert(frame.y_data, flat_name)
          table.insert(frame.series_names, meter_name)
        end
      end

      table.insert(frames, frame)
    end

    for key, frame_type in pairs(misc_frames) do
      table.insert(log_keys, key)
      table.insert(frames, {
        type = frame_type,
        title = key,
        data = key
      })
    end

    for i, frame in ipairs(frames) do
      frame.bounds = get_frame_bounds(i)
    end

    table.insert(log_flush_handlers,
      log_showoff{
        notebook = notebook,
        frames = frames
      }
    )

    local progress_frame = notebook:new_frame(
      'Progress', {x = 0, y = 924, width = 1920, height = 64})

    table.insert(log_set_handlers, function(log, key, value)
      if key == 'progress' then
        progress_frame:progress(value, 1)
      end
    end)
  end

  local log = tnt.Log{
    keys = log_keys,
    onFlush = log_flush_handlers,
    onSet = log_set_handlers
  }

  self.log = log
  self.meters = meters
  self.epoch = 1
end}

Telemetry.progress = argcheck{
  {name = 'self', type = 'torchoff.tnt.Telemetry'},
  {name = 'cur_val', type = 'number'},
  {name = 'max_val', type = 'number'},
  call =
function(self, cur_val, max_val)
  self:set{progress = cur_val / max_val}
end}

Telemetry.set = argcheck{
  {name = 'self', type = 'torchoff.tnt.Telemetry'},
  {name = 'entries', type = 'table'},
  call =
function(self, entries)
  self.log:set(entries)
end}

Telemetry.finish_epoch = argcheck{
  {name = 'self', type = 'torchoff.tnt.Telemetry'},
  call =
function(self)
  local log = self.log

  local log_values = {
    epoch = self.epoch
  }

  local flat_meters = flatten_meters(self.meters)
  for key, meter in pairs(flat_meters) do
    local value

    if torch.type(meter) ~= 'tnt.TimeMeter' and meter.n == 0 then
      value = 0
    elseif torch.type(meter) == 'tnt.ConfusionMeter' then
      -- Convert confusion matrix to Vega-Lite spec
      local matrix = meter:value()
      local graph_data = {}
      for row = 1, matrix:size(1) do
        for col = 1, matrix:size(2) do
          table.insert(graph_data, {
            target = row,
            prediction = col,
            frequency = string.format('%4.2f', matrix[{row, col}])
          })
        end
      end
      value = {
        data = { values = graph_data },
        mark = 'text',
        encoding = {
          row = { field = 'target', type = 'ordinal' },
          column = { field = 'prediction', type = 'ordinal' },
          color = { field = 'frequency', scale = { domain = {0, 1} }, legend = false },
          text = { field = 'frequency'}
        },
        config = {
          mark = { applyColorToBackground = true },
          scale = { textBandWidth = 45 } -- Cell width
        }
      }
    else
      if torch.type(meter) == 'tnt.ClassErrorMeter' then
        value = meter:value()[1]
      else
        value = meter:value()
      end
    end

    log_values[key] = value
  end

  -- Update log
  log:set(log_values)
  log:flush()

  -- Reset meters
  for group_name, group in pairs(self.meters) do
    for meter_name, meter in pairs(group) do
      meter:reset()
    end
  end

  self.epoch = self.epoch + 1
end}

return Telemetry
