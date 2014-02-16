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
		Neo.execute_query("create (user:User {login: '#{login}', password: '#{password}', email: '#{email}'})")
		status 201
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
		book = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {bookid: '#{id}'}) optional match (b)-[:CONTAINS|FOLLOWS*]-(c:Chapter) return b.title as booktitle, c.chid as chapterid, c.title as chaptertitle")
		if book["data"].length == 0
			halt 404
		end
		{
			"title" => book["data"][0][0],
			"chapters" => book["data"].reject { |ch| ch[1].nil? }.map { |ch| {
				"id" => ch[1],
				"title" => ch[2]
			} }
		}.to_json
	end
	
	get "/books/:id/:chap" do |id, chap|
		login = env['REMOTE_USER']
		puts "match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {bookid: '#{id}'})-[:CONTAINS|FOLLOWS*]-(c:Chapter {chid: '#{chap}'}) return c.text as text"
		chapter = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {bookid: '#{id}'})-[:CONTAINS|FOLLOWS*]-(c:Chapter {chid: '#{chap}'}) return c.text as text")
		if chapter["data"].length == 0
			halt 404
		end
		chapter["data"][0][0]
	end
	
	post "/books" do
		login = env['REMOTE_USER']
		entity = JSON.load(request.body.gets)
		id = SecureRandom.hex(3)
		entity["bookid"] = id
		Neo.execute_query("match (u:User {login: '#{login}'}) create (b:Book {data}), (u)-[:WROTE]->(b)", {"data"=>entity})
		status 201
		id.to_json
	end
	
	put "/books/:id" do |id|
		login = env['REMOTE_USER']
		exists = Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {id: '#{id}'}) return count(b)")["data"][0][0]
		if (exists == 0)
			halt 404
		end
		entity = JSON.load(request.body.gets)
		entity["bookid"] = id
		Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {bookid: '#{id}'}) set b={data}", {"data"=>entity})
		status 204
	end
	
	put "/books/:id/:chap" do |id, chap|
		login = env['REMOTE_USER']
		entity = request.body.gets
		Neo.execute_query("match (u:User {login: '#{login}'})-[:WROTE]->(b:Book {bookid: '#{id}'})-[:CONTAINS|FOLLOWS*]-(c:Chapter {chid: '#{chap}'}) set c.text={text}", {"text"=>entity})
		status 204
	end

end

