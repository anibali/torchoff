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
  {name = 'torchoff_client', type = 'torchoff.Client', opt = true},
  {name = 'graph_x_title', type = 'string', default = 'Epoch'},
  call =
function(self, title, meters, misc_frames, torchoff_client, graph_x_title)
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
    local LogShowoff = require('torchoff.tnt.LogShowoff')

    local notebook = torchoff_client:new_notebook(title)
    self.notebook = notebook

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
            }
          else
            frame = {
              type = 'graph',
              title = group_name,
              x_title = graph_x_title,
              x_data = {},
              y_title = group_name,
              y_data = {},
              series_names = {},
            }
          end

          frame.name = flat_name
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

    for key, frame_opts in pairs(misc_frames) do
      local frame_type = frame_opts
      local autoflush = true
      local title = key
      local bounds = nil

      if type(frame_opts) == 'table' then
        frame_type = frame_opts.type
        if frame_opts.autoflush ~= nil then
          autoflush = frame_opts.autoflush
        end
        title = frame_opts.title or title
        bounds = frame_opts.bounds or bounds
      end

      table.insert(log_keys, key)
      table.insert(frames, {
        type = frame_type,
        title = title,
        autoflush = autoflush,
        bounds = bounds,
        name = key,
      })
    end

    table.insert(frames, {
      type = 'progress',
      title = 'Progress',
      name = 'progress',
      bounds = {x = 0, y = 924, width = 1920, height = 64},
      autoflush = true,
    })

    table.sort(frames, function(a, b)
      if a.bounds == nil and b.bounds ~= nil then
        return true
      end
      if a.bounds ~= nil and b.bounds == nil then
        return false
      end
      return a.name < b.name
    end)

    for i, frame in ipairs(frames) do
      frame.bounds = frame.bounds or get_frame_bounds(i)
    end

    local log_showoff = LogShowoff.new(notebook, frames)
    table.insert(log_set_handlers, log_showoff:create_set_handler())
    table.insert(log_flush_handlers, log_showoff:create_flush_handler())
    self.log_showoff = log_showoff
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

Telemetry.flush_frames = argcheck{
  {name = 'self', type = 'torchoff.tnt.Telemetry'},
  {name = 'frame_names', type = 'table'},
  call =
function(self, frame_names)
  assert(self.log_showoff, 'Telemetry not configured for Showoff logging')

  for i, frame_name in ipairs(frame_names) do
    self.log_showoff:update_frame_by_name(frame_name)
  end
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
