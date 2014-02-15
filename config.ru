require './server'

use Rack::Deflater
run Rack::URLMap.new({
	"/" => Public,
	"/api" => Private
})

