class User
  include DataMapper::Resource
  
  def self.is_searchable!
    is :searchable
  end

  @@full_text_search_fields = [
    :first_name, :last_name, :organization, :email, :title, :address, :address2, :city, :state,
    :postal_code, :country, :office_phone, :mobile_phone, :fax, :www, :notes, :admin_notes
  ]
  
  def self.full_text_search_fields
    @@full_text_search_fields
  end

  CSV_IGNORE = [:id, :password, :www, :graphic_content_visible_by_default, :deleted_at,
                :created_at, :updated_at, :failed_logins, :crypted_password, :salt]

  property :id, Serial
  property :first_name, String, :length => 50
  validates_length_of :first_name, :max => 50, :when => [ :register, :default ]
  property :last_name, String, :length => 50
  validates_length_of :last_name, :max => 50, :when => [ :register, :default ]
  property :organization, String, :length => 80
  validates_length_of :organization, :max => 80, :when => [ :register, :default ]

  property :email, String, :length => 100
  validates_length_of :email, :max => 100, :when => [ :register, :default ]
  
  property :title, String, :length => 255
  validates_length_of :title, :max => 255, :when => [ :register, :default ]

  def self.use_crypted_passwords!
    # validators.contexts[:default].reject! {|v| v.field_name == :password }

    properties = self.properties.reject { |p| p.name == :password }
    @properties[default_repository_name] = DataMapper::PropertySet.new(properties)

    attr_accessor :password

    property :crypted_password, String
    property :salt, String
    before :save, :encrypt_password
  end

  property :force_password_update, Boolean, :default => false

  property :password, String, :auto_validation => false
  attr_accessor :password_confirmation

  property :last_login, DateTime
  property :active, Boolean, :default => true

  property :address, String, :length => 100
  validates_length_of :address, :max => 100, :when => [ :register, :default ]
  property :address2, String, :length => 100
  validates_length_of :address2, :max => 100, :when => [ :register, :default ]
  property :city, String, :length => 100
  validates_length_of :city, :max => 100, :when => [ :register, :default ]
  property :state, String, :length => 50
  validates_length_of :state, :max => 50, :when => [ :register, :default ]
  property :postal_code, String, :length => 20
  validates_length_of :postal_code, :max => 20, :when => [ :register, :default ]
  property :country, String, :length => 100
  validates_length_of :country, :max => 100, :when => [ :register, :default ]
  property :office_phone, String, :length => 30
  validates_length_of :office_phone, :max => 30, :when => [ :register, :default ]
  property :mobile_phone, String, :length => 20
  validates_length_of :mobile_phone, :max => 20, :when => [ :register, :default ]
  property :fax, String, :length => 20
  validates_length_of :fax, :max => 20, :when => [ :register, :default ]
  property :www, String, :length => 200
  validates_length_of :www, :within => 0..200, :when => [ :register, :default ]
  property :graphic_content_visible_by_default, Boolean, :default => false
  property :prefers_attachments, Boolean, :default => false

  property :notes, Text
  property :admin_notes, Text

  property :deleted_at, ParanoidDateTime
  property :created_at, DateTime
  property :updated_at, DateTime

  property :api_key, String, :default => lambda { Digest::MD5.hexdigest(`uuidgen`.chomp) }
  property :auth_key, String, :length => 36, :default => lambda { `uuidgen`.chomp }
  property :reset_password_token, String, :default => lambda { Digest::MD5.hexdigest(`uuidgen`.chomp) }

  has n, :roles, :through => Resource
  
  has n, :permission_sets, :model => "UserPermissionSet"

  def self.use_lockouts!
    property :failed_logins, Integer, :default => 0
    before :update, :reset_failed_logins_on_activation

    def reset_failed_logins_on_activation
      if attribute_dirty?(:active) && active?
        self.failed_logins = 0
      end
    end

    def locked?
      self.failed_logins >= PortAuthority::lockout_attempts
    end
  end

  def self.use_approvals!
    property :awaiting_approval, Boolean, :default => true
    property :activated_at, DateTime
    property :denied_at, DateTime
    property :usage_statement, Text

    def self.awaiting_approval
      sort = PortAuthority::use_logins? ? [:login.asc] : [:email.asc]
      all(:awaiting_approval => true, :order => sort)
    end

    def self.approved
      sort = PortAuthority::use_logins? ? [:login.asc] : [:email.asc]
      all(:awaiting_approval => false, :active => true, :order => sort)
    end

    def approved?
      !self.awaiting_approval?
    end

    def approve!
      self.active = true
      self.awaiting_approval = false
      self.denied_at = nil
      User.update_roles(self, Role.all(:name => PortAuthority.default_user_role).map{|r| [r.id, 1]})
      self.roles.reload
      save! && approved?
    end

    def deny!
      self.permission_sets.each { |set| set.destroy }
      self.awaiting_approval = self.active = false
      self.denied_at = Time.now
      self.save!
    end

  end

  def self.use_logins!
    property :login, String
    validates_length_of :login, :within => 3..100, :when => [ :register, :default ]
    validates_uniqueness_of :login, :when => [ :register, :default ]
    
    self.full_text_search_fields << :login

    def self.login_is_available?(login)
      (3..100).include?(login.size) && (0 == User.count(:login => login))
    end
  end

  validates_length_of :email, :max => 100, :when => [ :register, :default ]
  validates_uniqueness_of :email, :when => [ :register, :default ], :unless => Proc.new { |user| PortAuthority::use_logins? }
  validates_with_block :email, :when => [ :register, :default ] do
    begin
      TMail::Address.parse(self.email) if self.email
      true
    rescue TMail::SyntaxError
      [false, "Invalid email address"]
    end
  end

  validates_presence_of :first_name, :last_name, :when => [ :register, :default ]

  # Password Validations
  validates_presence_of :password, :when => [ :register, :default ], :if => :password_needs_validation_and_dissallow_blank_passwords?
  validates_confirmation_of :password, :when => [ :register, :default ], :if => :password_needs_validation?, :message => "Passwords do not match"

  repository :search do
    property :content, String, :field => "*", :auto_validation => false
    property :email_user,   String, :auto_validation => false, :default => lambda { |r,p| r.email.to_s.split(/@/).first.to_s }
    property :email_server, String, :auto_validation => false, :default => lambda { |r,p| r.email.to_s.split(/@/).last.to_s }
  end

  def name
    [first_name.to_s.strip, last_name.to_s.strip].compact.join(" ")
  end
  alias :to_s :name
  
  def email=(email)
    attribute_set(:email, email.downcase)
  end

  def role_mask_for(name)
    RolePermissionSet.all(:name => name, :role_id => self.roles.map { |r| r.id }).inject(0) { |mask, set| mask | set.mask }
  rescue
    0
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end
  
  def pending_required_fields?
    self.valid?(:default)
  end
  
  def to_s
    PortAuthority::use_logins? ? (login || email) : email
  end

  def reset_password_token!
    self.reset_password_token = Digest::MD5.hexdigest(`uuidgen`.chomp)
  end

  ##
  # Uses pwgen to generate a random pronounceable password
  #
  # http://sourceforge.net/projects/pwgen/, or sfget pwgen
  #
  def self.random_password(size = 8)
    `pwgen -A -0 #{size} 1`.chomp
  end
  
  # def sync_permission_set_with_roles
    # self.permission_sets.destroy!
    # self.roles.each do |role|
      # role.permission_sets.each { |set| set.propagate_permissions! }
    # end
  # end

  # Resets the user's permission sets based on their roles.
  # Note: Custom-defined permissions on the user are not preserved.
  def reset_permission_set_from_roles
    UserPermissionSet.all(:user_id => self.id).each do |existing_permission_set|
      existing_permission_set.destroy
    end

    user_role_ids = self.roles.map { |role| role.id }

    PermissionSet::permissions.keys.each do |permission_name|
      role_permissions = RolePermissionSet.all(:name => permission_name, :role_id => user_role_ids)
      role_mask = role_permissions.inject(0) { |mask, set| mask | set.mask }

      user_permission_set = UserPermissionSet.first_or_create(:name => permission_name, :user_id => self.id)
      # user_mask = user_premission_set.mask

      user_permission_set.mask = role_mask
      user_permission_set.save
    end

    self.permission_sets.reload
  end

  def self.update_roles(user, roles)
    return unless roles.respond_to?(:each)

    roles.each do |id, value|
      role = RoleUser.first(:user_id => user.id, :role_id => id)
      
      case value.to_i
      when 0 then role.destroy unless role.nil?
      when 1 then RoleUser.create(:user_id => user.id, :role_id => id) if role.nil?
      end
    end
  end

  protected

  def encrypt_password
    return if PortAuthority::use_crypted_passwords? != true || password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{self.send(PortAuthority::login_type)}--") if new?
    self.crypted_password = encrypt(password)
  end

  private

  def password_needs_validation?
    if PortAuthority::use_crypted_passwords?
      !password.nil?
    else
      new? || attribute_dirty?(:password)
    end
  end
  
  def password_needs_validation_and_dissallow_blank_passwords?
    password_needs_validation? && !PortAuthority::allow_blank_passwords?
  end

end
