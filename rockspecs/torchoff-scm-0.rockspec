package = 'torchoff'
version = 'scm-0'

source = {
  url = 'https://github.com/anibali/torchoff/archive/master.zip',
  dir = 'torchoff-master'
}

description = {
  summary = 'A Showoff client for Torch',
  homepage = 'https://github.com/anibali/torchoff',
  license = 'MIT <http://opensource.org/licenses/MIT>'
}

dependencies = {
  'torch >= 7.0'
}

build = {
  type = 'builtin',
  modules = {
    ['torchoff'] = 'src/torchoff.lua',
    ['torchoff.Client'] = 'src/torchoff/Client.lua',
    ['torchoff.Frame'] = 'src/torchoff/Frame.lua',
    ['torchoff.Notebook'] = 'src/torchoff/Notebook.lua',
    ['torchoff.env'] = 'src/torchoff/env.lua',
    ['torchoff.tnt.Telemetry'] = 'src/torchoff/tnt/Telemetry.lua',
    ['torchoff.tnt.logshowoff'] = 'src/torchoff/tnt/logshowoff.lua'
  }
}
