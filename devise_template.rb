# frozen_string_literal: true

require 'fileutils'

def add_gems
  gem 'devise'
  gem 'simple_form'
end

def setup_simple_form
  generate 'simple_form:install --bootstrap'
end

def setup_users
  generate 'devise:install'
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000}",
              env: 'development'
  generate :devise, 'User', 'username:string:uniq', 'admin:boolean'
  in_root do
    migration = Dir.glob('db/migrate/*').max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ':admin, default: false'
  end
  rails_command 'db:migrate'
  generate 'devise:views'

  inject_into_file 'app/controllers/application_controller.rb', before: 'end' do
    "\n before_action :configure_permitted_parameters, if: :devise_controller?
		\n
		  protected
		\n
    def configure_permitted_parameters
        \nadded_attrs = [:username, :email, :password, :password_confirmation, :remember_me]
      \ndevise_parameter_sanitizer.permit :sign_up, keys: added_attrs
          \ndevise_parameter_sanitizer.permit :account_update, keys: added_attrs
      \nend\n"
  end

  inject_into_file 'app/models/user.rb', before: 'end' do
    "\n  validates :username, presence: true, uniqueness: { case_sensitive: false }
    validate :validate_username
    attr_writer :login
    def login
      @login || username || email
    end

    def validate_username
      errors.add(:username, :invalid) if User.where(email: username).exists?
    end

    def self.find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:login)
        where(conditions.to_h).where(['lower(username) = :value OR lower(email) = :value', { value: login.downcase }]).first
      elsif conditions.key?(:username) || conditions.key?(:email)
        where(conditions.to_h).first
      end
    end\n"
  end

  inject_into_file 'config/initializers/devise.rb', after: '# config.authentication_keys = [:email]' do
    "\nconfig.authentication_keys = [ :login ]\n\n"
  end

  find_and_replace_in_file('app/views/devise/sessions/new.html.erb', 'email', 'login')

  inject_into_file 'app/views/devise/registrations/new.html.erb', before: '<%= f.input :email' do
    "\n<%= f.input :username %>"
  end

  inject_into_file 'app/views/devise/registrations/edit.html.erb', before: '<%= f.input :email' do
    "\n<%= f.input :username %>"
  end
end

def find_and_replace_in_file(file_name, old_content, new_content)
  text = File.read(file_name)
  new_contents = text.gsub(old_content, new_content)
  File.open(file_name, 'w') { |file| file.write new_contents }
end

def source_paths
  [__dir__]
end

def add_bootstrap
  bootstrap_stylesheets = 'app/assets/stylesheets/vendor/bootstrap/bootstrap.scss.tt'
  bootstrap_javascript = 'app/javascript/vendor/bootstrap/index.js'

  FileUtils.touch(bootstrap_stylesheets)
  FileUtils.touch(bootstrap_javascript)

  insert_into_file 'app/assets/stylesheets/application.scss', after: /\/\/ Dependencies\n/ do
    <<~SCSS
      @import 'vendor/bootstrap/bootstrap';
    SCSS
  end

  insert_into_file 'package.json', after: /"i18n-js":.+\n/ do
    <<~JSON
      "bootstrap": "4.5.2",
      "bootstrap.native": "3.0.13",
    JSON
  end

  insert_into_file 'app/javascript/packs/application.js', before: %r{import 'translations/translations'.+\n} do
    <<~JAVASCRIPT
      import 'vendor/bootstrap';
    JAVASCRIPT
  end

  import_into_file bootstrap_javascript do
    <<~INDEXJS
      import bootstrap from 'bootstrap.native/dist/bootstrap-native';

      export const Alert = bootstrap.Alert;
      export const Button = bootstrap.Button;
      export const Carousel = bootstrap.Carousel;
      export const Collapse = bootstrap.Collapse;
      export const Dropdown = bootstrap.Dropdown;
      export const Modal = bootstrap.Modal;
      export const Popover = bootstrap.Popover;
      export const ScrollSpy = bootstrap.ScrollSpy;
      export const Tab = bootstrap.Tab;
      export const Toast = bootstrap.Toast;
      export const Tooltip = bootstrap.Tooltip;
    INDEXJS
  end

  import_into_file bootstrap_stylesheets do
    <<~STYLESHEET
      // By default every component is imported
      // But DO NOT import the whole framework but instead
      // pick what the project requires
      // and comment out the rest.
      
      @import 'bootstrap/scss/functions';
      @import 'bootstrap/scss/variables';
      @import 'bootstrap/scss/mixins';
      @import 'bootstrap/scss/root';
      @import 'bootstrap/scss/reboot';
      @import 'bootstrap/scss/type';
      @import 'bootstrap/scss/utilities';
      @import 'bootstrap/scss/images';
      @import 'bootstrap/scss/grid';
      @import 'bootstrap/scss/forms';
      @import 'bootstrap/scss/buttons';
      @import 'bootstrap/scss/tables';
      @import 'bootstrap/scss/code';
      @import 'bootstrap/scss/transitions';
      @import 'bootstrap/scss/dropdown';
      @import 'bootstrap/scss/button-group';
      @import 'bootstrap/scss/input-group';
      @import 'bootstrap/scss/custom-forms';
      @import 'bootstrap/scss/nav';
      @import 'bootstrap/scss/navbar';
      @import 'bootstrap/scss/card';
      @import 'bootstrap/scss/breadcrumb';
      @import 'bootstrap/scss/pagination';
      @import 'bootstrap/scss/badge';
      @import 'bootstrap/scss/jumbotron';
      @import 'bootstrap/scss/alert';
      @import 'bootstrap/scss/progress';
      @import 'bootstrap/scss/media';
      @import 'bootstrap/scss/list-group';
      @import 'bootstrap/scss/close';
      @import 'bootstrap/scss/toasts';
      @import 'bootstrap/scss/modal';
      @import 'bootstrap/scss/tooltip';
      @import 'bootstrap/scss/popover';
      @import 'bootstrap/scss/carousel';
      @import 'bootstrap/scss/spinners';
      @import 'bootstrap/scss/print';
    STYLESHEET
  end

end

def add_bootstrap_navbar
  navbar = 'app/views/layouts/_navbar.html.erb'
  FileUtils.touch(navbar)
  inject_into_file 'app/views/layouts/application.html.erb', before: '<%= yield %>' do
    "\n<%= render 'layouts/navbar' %>\n"
  end
  append_to_file navbar do
    '<nav class="navbar navbar-expand-lg navbar-light bg-light">
    <%= link_to Rails.application.class.parent_name, root_path, class:"navbar-brand"%>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
    </button>

    <div class="collapse navbar-collapse" id="navbarSupportedContent">
        <ul class="navbar-nav mr-auto">
            <li class="nav-item active">
                <%= link_to "Home", root_path, class:"nav-link" %>
            </li>
        </ul>
        <ul class="navbar-nav ml-auto">
            <% if current_user %>
            <li class="nav-item dropdown">
                <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                    <%= current_user.username %>
                </a>
                <div class="dropdown-menu dropdown-menu-right" aria-labelledby="navbarDropdown">
                    <%= link_to "Account Settings", edit_user_registration_path, class:"dropdown-item" %>
                    <div class="dropdown-divider"></div>
                    <%= link_to "Logout", destroy_user_session_path, method: :delete, class:"dropdown-item" %>
                </div>
            </li>
            <% else %>
            <li class="nav-item">
                <%= link_to "Create An Account", new_user_registration_path, class:"nav-link" %>
            </li>
            <li class="nav-item">
                <%= link_to "Login", new_user_session_path, class:"nav-link" %>
            </li>
            <% end %>
        </ul>
    </div>
		</nav>'
  end
end

source_paths

add_gems

def demo_rails_commands
  generate(:controller, 'pages home')
  route "root to: 'pages#home'"
  rails_command 'db:migrate'
end

after_bundle do
  setup_simple_form
  setup_users

  demo_rails_commands

  add_bootstrap
  add_bootstrap_navbar
end