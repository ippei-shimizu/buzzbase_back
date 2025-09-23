# 管理者ユーザーのシードデータ

Rails.logger.info 'Creating admin users...'

# 初期管理者ユーザー
admin_user = Admin::User.find_or_create_by!(email: 'admin_2@example.com') do |admin|
  admin.name = 'Admin User'
  admin.password = 'password123'
end

if admin_user.persisted?
  Rails.logger.info "Admin user created/found: #{admin_user.email}"
else
  Rails.logger.error "Failed to create admin user: #{admin_user.errors.full_messages.join(', ')}"
end

Rails.logger.info 'Admin users seed completed!'
