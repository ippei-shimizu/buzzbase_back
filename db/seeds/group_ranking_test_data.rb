# グループランキング検証用シードデータ
# 既存の全Userを10人ずつのグループに分割し、各Userが最低1つのグループに所属する状態を作成

Rails.logger.debug 'Creating group ranking test data...'

users = User.all.to_a
total_users = users.count

if total_users.zero?
  Rails.logger.debug 'No users found. Please create users first.'
  exit
end

Rails.logger.debug { "Found #{total_users} users" }

# 10人ずつグループに分割
group_size = 10
groups_count = (total_users.to_f / group_size).ceil

Rails.logger.debug { "Creating #{groups_count} groups with up to #{group_size} members each..." }

groups_count.times do |i|
  group_number = i + 1
  start_index = i * group_size
  end_index = [start_index + group_size - 1, total_users - 1].min
  group_users = users[start_index..end_index]

  next if group_users.empty?

  # グループ作成
  group = Group.create!(
    name: "ランキングテストグループ#{group_number}"
  )

  Rails.logger.debug { "Created group: #{group.name} with #{group_users.count} members" }

  # グループの作成者（最初のユーザー）
  creator = group_users.first

  # 各ユーザーをグループに追加
  group_users.each do |user|
    # GroupUserレコード作成（作成者との関連付け）
    GroupUser.create!(
      user: creator,
      group:
    )

    # GroupInvitationレコード作成（accepted状態）
    GroupInvitation.create!(
      user:,
      group:,
      state: 'accepted',
      sent_at: Time.current
    )
  end

  Rails.logger.debug { "  - Added #{group_users.count} members to #{group.name}" }
end

Rails.logger.debug 'Group ranking test data creation completed!'
Rails.logger.debug { "Created #{groups_count} groups with a total of #{total_users} members" }
