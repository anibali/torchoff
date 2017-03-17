local argcheck = require('argcheck')

local cjson = require('cjson')
local httpclient = require('httpclient')

local Notebook = require('torchoff.Notebook')

local Client, Parent = torch.class('torchoff.Client', require('torchoff.env'))

Client.__init = argcheck{
  {name = 'self', type = 'torchoff.Client'},
  {name = 'host', type = 'string'},
  {name = 'port', type = 'number'},
call = function(self, host, port)
  local hc = httpclient.new()

  -- httpclient is a bad citizen, it overwrites _G._
  -- This is a monkey-patch to correct that behaviour.
  local hc_client_request = hc.client.request
  hc.client.request = function(...)
    local old_ = _G._
    local res = hc_client_request(...)
    _G._ = old_
    return res
  end

  self.hc = hc
  self.base_url = string.format('http://%s:%d/api/v2', host, port)
end}

Client.request = argcheck{
  {name = 'self', type = 'torchoff.Client'},
  {name = 'method', type = 'string'},
  {name = 'path', type = 'string'},
  {name = 'request_data', type = 'table', opt = true},
call = function(self, method, path, request_data)
  local args = {self.hc, self.base_url .. path}
  if method == 'post' or method == 'put' or method == 'patch' then
    table.insert(args, cjson.encode(request_data))
  end
  table.insert(args, {content_type = 'application/json', ['x-no-compression'] = 'true'})

  local res = self.hc[method](unpack(args))

  if not res.body or #res.body == 0 then
    return nil, res
  end

  return cjson.decode(res.body), res
end}

Client.get_notebook = argcheck{
  {name = 'self', type = 'torchoff.Client'},
  {name = 'notebook_id', type = 'number'},
call = function(self, notebook_id)
  return Notebook.new(self, notebook_id)
end}

Client.new_notebook = argcheck{
  {name = 'self', type = 'torchoff.Client'},
  {name = 'title', type = 'string', default = 'Untitled notebook'},
call = function(self, title)
  local request_data = {
    data = {
      type = 'notebooks',
      attributes = { title = title }
    }
  }

  local res_body = self:request('post', '/notebooks', request_data)
  local notebook_id = tonumber(res_body.data.id)

  return Notebook.new(self, notebook_id)
end}

return Client
