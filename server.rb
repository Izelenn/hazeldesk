require 'sinatra/base'
require 'securerandom'
require 'neography'
require 'json'

Neo = Neography::Rest.new("http://localhost:7474")

class Public < Sinatra::Base

	get "/" do
		redirect "/index.html"
	end
	
	post "/user" do
		entity = JSON.load(request.body.gets)
		login = entity["login"]
		password = entity["password"]
		email = entity["email"]
		valid = login and password and email
		if valid.nil?
			halt 400
		end
		puts "test"
		exists = Neo.execute_query("match (user:User) where user.login='#{login}' return count(user)")["data"][0][0]
		puts exists
		if (exists > 0)
			halt 409
			break
		end
		Neo.execute_query("create (user:User {login: '#{login}', id: '#{login}', password: '#{password}', email: '#{email}'})")
		halt 201
	end

end

class Private < Sinatra::Base
	
	use Rack::Auth::Basic, "HazelDesk" do |username, password|
		auth = Neo.execute_query("match (user:User) where user.login='#{username}' and user.password='#{password}' return count(user)")["data"][0][0]
		if (auth > 0) then true else false end
	end
	
	after do
		content_type :json
	end
	
	get "/books" do
		login = env['REMOTE_USER']
		books = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book) return b")
		list = books["data"].map{ |book| book[0]["data"] }
		if list.length == 0
			halt 204
		end
		list.to_json
	end
	
	get "/books/:id" do |id|
		login = env['REMOTE_USER']
		book = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {id: '#{id}'}) return b")
		if book["data"].length == 0
			halt 404
		end
		book["data"][0][0]["data"].to_json
	end
	
	post "/books" do
		login = env['REMOTE_USER']
		entity = JSON.load(request.body.gets)
		id = SecureRandom.hex(3)
		entity["id"] = id
		Neo.execute_query("match (u:User {login: '#{login}'}) create (b:Book {data}), (u)-[:WROTE]->(b)", {"data"=>entity})
		id
	end
	
	put "/books/:id" do |id|
		login = env['REMOTE_USER']
		exists = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {id: '#{id}'}) return count(b)")["data"][0][0]
		if (exists == 0)
			halt 404
		end
		entity = JSON.load(request.body.gets)
		entity["id"] = id
		Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {id: '#{id}'}) set b={data}", {"data"=>entity})
		halt 204
	end

end

