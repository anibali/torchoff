local argcheck = require('argcheck')
local base64 = require('base64')
local image = require('image')

local LogShowoff, Parent = torch.class('LogShowoff', {})

local function map(collection, func)
  local mapped_collection = {}
  for key, value in pairs(collection) do
    table.insert(mapped_collection, func(value, key))
  end
  return mapped_collection
end

LogShowoff.__init = argcheck{
  {name = 'self', type = 'LogShowoff'},
  {name = 'notebook', type = 'torchoff.Notebook'},
  {name = 'frames', type = 'table'},
call = function(self, notebook, frames, log)
  local history = {}

  for i, frame in ipairs(frames) do
    if frame.type == 'graph' then
      for j, key in ipairs(frame.x_data) do
        history[key] = {}
      end
      for j, key in ipairs(frame.y_data) do
        history[key] = {}
      end
    elseif frame.type == 'vega' then
      history[frame.name] = {}
    elseif frame.type == 'vegalite' then
      history[frame.name] = {}
    elseif frame.type == 'text' then
      history[frame.name] = {}
    end
    frame.inst = notebook:new_frame(frame.title, frame.bounds)
  end

  self.notebook = notebook
  self.frames = frames
  self.history = history
end}

function LogShowoff:update_frame(frame, value)
  local history = self.history
  local log = self.log

  local value = value or log:get(frame.name)

  if frame.type == 'graph' then
    frame.inst:graph(
      map(frame.x_data, function(key) return history[key] end),
      map(frame.y_data, function(key) return history[key] end),
      {x_title = frame.x_title, y_title = frame.y_title, series_names = frame.series_names})
  elseif frame.type == 'vega' then
    if value ~= nil then
      frame.inst:vega(value)
    end
  elseif frame.type == 'vegalite' then
    if value ~= nil then
      frame.inst:vegalite(value)
    end
  elseif frame.type == 'image' then
    if value ~= nil then
      local template =
        '<img src=data:image/jpeg;base64,%s>'
      local image_b64 = base64.encode(image.compressJPG(value, 90):char():storage():string())
      frame.inst:html(string.format(template, image_b64))
    end
  elseif frame.type == 'progress' then
    if value ~= nil then
      frame.inst:progress(value, 1)
    end
  elseif frame.type == 'text' then
    if frame.append == false then
      frame.inst:text(value)
    else
      frame.inst:text(table.concat(history[frame.name], '\n'))
    end
  elseif frame.type == 'html' then
    if value ~= nil then
      frame.inst:html(value)
    end
  else
    error('Unrecognised frame type: ' .. frame.type)
  end
end

LogShowoff.update_frame_by_name = argcheck{
  {name = 'self', type = 'LogShowoff'},
  {name = 'frame_name', type = 'string'},
call = function(self, frame_name)
  for i, frame in ipairs(self.frames) do
    if frame.name == frame_name then
      self:update_frame(frame)
    end
  end
end}

LogShowoff.create_set_handler = argcheck{
  {name = 'self', type = 'LogShowoff'},
call = function(self)
  local history = self.history

  return function(log, key, value)
    self.log = log

    if history[key] then
      table.insert(history[key], value)
    end

    for i, frame in ipairs(self.frames) do
      if frame.autoflush and frame.name == key then
        self:update_frame(frame, value)
      end
    end
  end
end}

LogShowoff.create_flush_handler = argcheck{
  {name = 'self', type = 'LogShowoff'},
call = function(self)
  return function(log)
    self.log = log

    for i, frame in ipairs(self.frames) do
      if not frame.autoflush then
        self:update_frame(frame)
      end
    end
  end
end}

return LogShowoff
