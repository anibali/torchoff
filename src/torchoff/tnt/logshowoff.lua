local argcheck = require('argcheck')
local base64 = require('base64')

local map = function(collection, func)
  local mapped_collection = {}
  for key, value in pairs(collection) do
    table.insert(mapped_collection, func(value, key))
  end
  return mapped_collection
end

local logshowoff = argcheck{
  noordered = true,
  {name='notebook', type='torchoff.Notebook'},
  {name='frames', type='table'},
  call = function(notebook, frames)
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
        history[frame.data] = {}
      elseif frame.type == 'vegalite' then
        history[frame.data] = {}
      elseif frame.type == 'text' then
        history[frame.data] = {}
      end
      frame.inst = notebook:new_frame(frame.title, frame.bounds)
    end

    return function(log)
      for key, history_for_key in pairs(history) do
        table.insert(history_for_key, log:get(key))
      end

      for i, frame in ipairs(frames) do
        if frame.type == 'graph' then
          frame.inst:graph(
            map(frame.x_data, function(key) return history[key] end),
            map(frame.y_data, function(key) return history[key] end),
            {x_title = frame.x_title, y_title = frame.y_title, series_names = frame.series_names})
        elseif frame.type == 'vega' then
          local frame_data = log:get(frame.data)
          if frame_data ~= nil then
            frame.inst:vega(frame_data)
          end
        elseif frame.type == 'vegalite' then
          local frame_data = log:get(frame.data)
          if frame_data ~= nil then
            frame.inst:vegalite(frame_data)
          end
        elseif frame.type == 'image' then
          local frame_data = log:get(frame.data)
          if frame_data ~= nil then
            local template =
              '<img src=data:image/jpeg;base64,%s>'
            local image_b64 = base64.encode(image.compressJPG(frame_data):char():storage():string())
            frame.inst:html(string.format(template, image_b64))
          end
        elseif frame.type == 'progress' then
          local frame_data = log:get(frame.data)
          if frame_data ~= nil then
            frame.inst:progress(log:get(frame.data), 1)
          end
        elseif frame.type == 'text' then
          local data = history[frame.data]
          if frame.append == false then
            frame.inst:text(data[#data])
          else
            frame.inst:text(table.concat(data, '\n'))
          end
        else
          error('Unrecognised frame type: ' .. frame.type)
        end
      end
    end
  end
}

return logshowoff
