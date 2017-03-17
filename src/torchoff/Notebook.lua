local argcheck = require('argcheck')

local Frame = require('torchoff.Frame')

local Notebook, Parent = torch.class('torchoff.Notebook', require('torchoff.env'))

Notebook.__init = argcheck{
  {name = 'self', type = 'torchoff.Notebook'},
  {name = 'client', type = 'torchoff.Client'},
  {name = 'id', type = 'number'},
call = function(self, client, id)
  self.client = client
  self.id = id
end}

-- Delete all frames in the notebook
Notebook.clear = argcheck{
  {name = 'self', type = 'torchoff.Notebook'},
call = function(self)
  self.client:request('delete', '/notebooks/' .. self.id .. '/frames')
end}

Notebook.get_frame = argcheck{
  {name = 'self', type = 'torchoff.Notebook'},
  {name = 'id', type = 'number'},
call = function(self, id)
  return Frame.new(self.client, id)
end}

Notebook.new_frame = argcheck{
  {name = 'self', type = 'torchoff.Notebook'},
  {name = 'title', type = 'string', default = 'Untitled frame'},
  {name = 'bounds', type = 'table', opt = true},
call = function(self, title, bounds)
  local request_data = {
    data = {
      type = 'frames',
      attributes = { title = title },
      relationships = {
        notebook = { id = tostring(self.id) }
      }
    }
  }

  if bounds then
    request_data.data.attributes.x = bounds.x
    request_data.data.attributes.y = bounds.y
    request_data.data.attributes.width = bounds.width
    request_data.data.attributes.height = bounds.height
  end

  local res_body = self.client:request('post', '/frames', request_data)
  local frame_id = tonumber(res_body.data.id)

  return Frame.new(self.client, frame_id)
end}

return Notebook
