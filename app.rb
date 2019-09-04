require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'pony'
require 'sqlite3'

def get_db
  db = SQLite3::Database.new('./db/barbershop.db')
  db.results_as_hash = true
  return db
end

configure do
  db = get_db
  db.execute"CREATE TABLE IF NOT EXISTS
    `Users`
      (
	      `id`	INTEGER PRIMARY KEY AUTOINCREMENT,
        `Name`	TEXT,
        `Phone`	TEXT,
        `Datestamp`	TEXT,
        `Barber`	TEXT,
        `Color`	TEXT
      )"
  enable :sessions
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Привет, гость'
  end
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Sorry, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  erb 'Can you handle a <a href="/secure/place">secret</a>?'
end

get '/login/form' do
  erb :login_form
end

get '/admin' do
  erb :admin
end

post '/admin' do
  @username = params[:username]
  @password = params[:password]

  if @username == 'admin' && @password == 'admin'
    @users_file = File.open('./public/users.txt', 'r')
    erb :user_list
  end
end

get '/book' do # visit
  erb :book
end

post '/book' do
  @user_name = params[:user_name]
  @phone = params[:phone]
  @date_time = params[:date_time]
  @barber = params[:barber]
  @color = params[:color]

  error_list = {
    user_name: 'Введите имя',
    phone: 'Введите телефон',
    date_time: 'Не правильная дата'
  }

  @error = error_list.select { |key, _| params[key] == '' }.values.join(', ')

  if @error != ''
    return erb :book
  end

  db = get_db
  db.execute 'insert into Users (Name, Phone, Datestamp, Barber, Color) values (?, ?, ?, ?, ?)', [@user_name, @phone, @date_time, @barber, @color]

  erb "Уважаемый #{@user_name}, Вы зарегистрировались на #{@date_time} к мастеру: #{@barber}. Вы выбрали #{@color} цвет. Спасибо"
end

post '/login/attempt' do
  if params[:username] == 'ilja' && params[:password] == '123456'
    session[:identity] = "Привет, #{params[:username]}"
    where_user_came_from = session[:previous_url] || '/'
    redirect to where_user_came_from
  else
    @error = 'Извините, Вы ввели не правильный логин или пароль! Попробуйте ещё раз.'
    halt erb(:login_form)
  end
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/secure/place' do
  erb 'This is a secret place that only <%=session[:identity]%> has access to!'
end

get '/about' do
  @error = 'Something wrong!'
  erb :about
end

get '/contacts' do
  erb :contacts
end

post '/contacts' do
  @email = params[:email]
  @text = params[:text]

  error_list = {
    email: 'Введите email',
    text: 'Введите сообщение, не менее 10 символов'
  }

  @error = error_list.select { |key, _| params[key] == '' }.values.join(', ')

  return erb :contacts if @error != ''

  @error = nil

  Pony.mail(
    from: 'ruby.school@yandex.ru',
    to: "#{params[:email]}",
    subject: 'Some Subject',
    body: "#{params[:text]}",
    via: :smtp,
    via_options: {
      address: 'smtp.yandex.ru',
      port: '25' ,
      user_name: 'ruby.school@yandex.ru',
      password: 'ruby_school',
      authentication: :plain
    }
  )

  f = File.open('./public/contacts.txt', 'a')
  f.write("#{@email}\n")
  f.close

  erb "С Вашего электронного адреса: #{@email} отправленно письмо. Спасибо."
end

get '/showusers' do
  db = get_db
  @results = db.execute 'select * from Users order by id desc'
  erb :showusers
end
