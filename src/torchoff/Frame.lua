local argcheck = require('argcheck')

local Frame, Parent = torch.class('torchoff.Frame', require('torchoff.env'))

Frame.__init = argcheck{
  {name = 'self', type = 'torchoff.Frame'},
  {name = 'client', type = 'torchoff.Client'},
  {name = 'id', type = 'number'},
call = function(self, client, id)
  self.client = client
  self.id = id
end}

Frame.set_title = argcheck{
  {name = 'self', type = 'torchoff.Frame'},
  {name = 'title', type = 'string'},
call = function(self, title)
  local request_data = {
    data = {
      id = self.id,
      type = 'frames',
      attributes = { title = title },
    }
  }

  self.client:request('patch', '/frames/' .. self.id, request_data)
end}

function Frame:set_content(content_type, body)
  local request_data = {
    data = {
      id = self.id,
      type = 'frames',
      attributes = {
        type = content_type,
        content = { body = body }
      },
    }
  }

  self.client:request('patch', '/frames/' .. self.id, request_data)
end

function Frame:vega(spec)
  self:set_content('vega', spec)
end

function Frame:vegalite(spec)
  self:set_content('vegalite', spec)
end

function Frame:text(message)
  self:set_content('text', message)
end

function Frame:html(html)
  self:set_content('html', html)
end

function Frame:progress(current_value, max_value)
  local percentage = 100 * current_value / max_value
  if percentage > 100 then percentage = 100 end
  local html = string.format([[<div class="progress">
  <div class="progress-bar" role="progressbar" aria-valuenow="%0.2f" aria-valuemin="0" aria-valuemax="100" style="width: %0.2f%%; min-width: 40px;">
    %0.2f%%
  </div>
</div>]], percentage, percentage, percentage)

  self:set_content('html', html)
end

local html_colours = {
  'steelblue',
  'tomato',
  'yellowgreen',
  'blueviolet',
  'sienna',
  'slategrey',
  'olive',
  'crimson'
}

function Frame:graph(xss, yss, opts)
  opts = opts or {}

  if type(xss[1]) ~= 'table' then
    local xs = xss
    xss = {}
    for i = 1, #yss do
      table.insert(xss, xs)
    end
  end

  local series_names = opts.series_names
  if series_names == nil then
    series_names = {}
    for i = 1, #xss do
      series_names[i] = tostring(i)
    end
  end

  local min_x = math.huge
  local max_x = -math.huge
  local min_y = math.huge
  local max_y = -math.huge
  local tables = {}
  local marks = {}
  for i=1,#xss do
    table.insert(marks, {
      type = 'line',
      from = {data = 'table' .. i},
      properties = {
        enter = {
          x = {scale = 'x', field = 'x'},
          y = {scale = 'y', field = 'y'},
          stroke = {scale = 'c', value = series_names[i]}
        }
      }
    })
    local points = {}
    for j=1,#xss[i] do
      local x = xss[i][j]
      local y = yss[i][j]
      if x < min_x then min_x = x end
      if x > max_x then max_x = x end
      if y < min_y then min_y = y end
      if y > max_y then max_y = y end
      table.insert(points, {x=x, y=y})
    end
    table.insert(tables, points)
  end

  local data = {}
  for i=1,#tables do
    table.insert(data, {
      name = 'table' .. i,
      values = tables[i]
    })
  end

  local spec = {
    width = 370,
    height = 250,
    data = data,
    scales = {
      {
        name = 'x',
        type = 'linear',
        range = 'width',
        domainMin = min_x,
        domainMax = max_x,
        nice = true,
        zero = false
      }, {
        name = 'y',
        type = 'linear',
        range = 'height',
        domainMin = opts.y_min or min_y,
        domainMax = opts.y_max or max_y,
        nice = true,
        zero = false
      }, {
        name = 'c',
        type = 'ordinal',
        range = 'category10',
        domain = series_names
      }
    },
    axes = {
      {type = 'x', scale = 'x', title = opts.x_title},
      {type = 'y', scale = 'y', title = opts.y_title, grid = true}
    },
    marks = marks
  }

  if opts.series_names then
    spec.legends = {
      {fill = 'c'}
    }
  end

  self:vega(spec)
end

return Frame
