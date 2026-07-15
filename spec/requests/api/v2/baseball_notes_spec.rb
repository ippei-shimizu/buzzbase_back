require 'rails_helper'

RSpec.describe 'Api::V2::BaseballNotes', type: :request do
  let(:user) { create(:user) }
  let(:memo) { [{ 'children' => [{ 'text' => '外角が体の開きで詰まる' }] }].to_json }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/baseball_notes' do
    context '未認証' do
      it '401' do
        get '/api/v2/baseball_notes'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '練習に紐付くノートを practice_log_id で絞り込める' do
      log = create(:practice_log, user:)
      create(:baseball_note, user:, practice_log: log, memo:, date: Date.current)
      create(:baseball_note, user:, memo:, date: Date.current)
      get '/api/v2/baseball_notes', params: { practice_log_id: log.id }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(1)
      expect(response.parsed_body.first['memo_preview']).to include('外角')
    end
  end

  describe 'POST /api/v2/baseball_notes' do
    it '練習に紐付けて作成できる' do
      log = create(:practice_log, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: '気づき', date: Date.current, memo:, practice_log_id: log.id } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['practice_log_id']).to eq(log.id)
    end

    it '他ユーザーの練習には紐付けられない（IDOR防止）' do
      other_log = create(:practice_log, user: create(:user))
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, practice_log_id: other_log.id } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it '練習記録（日次セッション）に紐付けて作成できる' do
      session = create(:practice_session, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: '気づき', date: Date.current, memo:, practice_session_id: session.id } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['practice_session_id']).to eq(session.id)
    end

    it '他ユーザーの練習記録には紐付けられない（IDOR防止）' do
      other_session = create(:practice_session, user: create(:user))
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, practice_session_id: other_session.id } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v2/baseball_notes（振り返りテンプレ）' do
    it 'テンプレと問い→回答を保存して返す' do
      template = create(:reflection_template, :preset)
      answers = [{ question: 'うまくいったこと', answer: '外角を捌けた' }, { question: '次やること', answer: '引きつけ' }]
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      reflection_template_id: template.id, reflection_answers: answers } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['reflection_template_id']).to eq(template.id)
      expect(response.parsed_body['reflection_answers'].first['answer']).to eq('外角を捌けた')
    end

    it '他ユーザーの自作テンプレには紐付けられない（IDOR防止）' do
      others = create(:reflection_template, user: create(:user))
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, reflection_template_id: others.id } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v2/baseball_notes（タグ）' do
    it '無料ユーザーはタグ付与できない（403）' do
      mine = create(:note_tag, user:, name: '自主練')
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, tag_ids: [mine.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーはプリセット・自作タグを付与して作成し tags を返す' do
      make_pro(user)
      preset = create(:note_tag, :preset, name: '打撃')
      mine = create(:note_tag, user:, name: '自主練')
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, tag_ids: [preset.id, mine.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      names = response.parsed_body['tags'].pluck('name')
      expect(names).to contain_exactly('打撃', '自主練')
    end

    it 'Proユーザーでも他ユーザーのタグは付与できない（IDOR防止）' do
      make_pro(user)
      others = create(:note_tag, user: create(:user), name: '他人')
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, tag_ids: [others.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーは同じタグIDが重複しても500にならず1件だけ付与される' do
      make_pro(user)
      mine = create(:note_tag, user:, name: '自主練')
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, tag_ids: [mine.id, mine.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['tags'].pluck('name')).to eq(['自主練'])
    end
  end

  describe 'PATCH /api/v2/baseball_notes/:id（タグ）' do
    it 'Proユーザーはタグを差し替えられる' do
      make_pro(user)
      note = create(:baseball_note, user:, memo:, date: Date.current)
      old_tag = create(:note_tag, user:, name: '旧')
      note.note_tag_ids = [old_tag.id]
      new_tag = create(:note_tag, user:, name: '新')
      patch "/api/v2/baseball_notes/#{note.id}",
            params: { baseball_note: { tag_ids: [new_tag.id] } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['tags'].pluck('name')).to eq(['新'])
    end

    it 'tag_ids キー省略時は既存タグを維持する（無料ユーザーのタグUI非表示による意図しない全消去を防止）' do
      note = create(:baseball_note, user:, memo:, date: Date.current)
      tag = create(:note_tag, :preset, name: '打撃')
      note.note_tag_ids = [tag.id]
      patch "/api/v2/baseball_notes/#{note.id}",
            params: { baseball_note: { title: '更新後タイトル' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['tags'].pluck('name')).to eq(['打撃'])
    end
  end

  describe 'POST /api/v2/baseball_notes（試合記録の紐付け）' do
    it '1件だけなら無料ユーザーでも紐付けられる' do
      game_result = create(:game_result, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, game_result_ids: [game_result.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['game_result_ids']).to eq([game_result.id])
    end

    it '無料ユーザーが2件以上紐付けようとすると403' do
      game_results = create_list(:game_result, 2, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      game_result_ids: game_results.map(&:id) } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーは複数の試合記録を紐付けられる' do
      make_pro(user)
      game_results = create_list(:game_result, 2, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      game_result_ids: game_results.map(&:id) } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['game_result_ids']).to match_array(game_results.map(&:id))
    end

    it '他ユーザーの試合には紐付けられない（IDOR防止）' do
      other_game_result = create(:game_result, user: create(:user))
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      game_result_ids: [other_game_result.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v2/baseball_notes/:id（試合記録の紐付け）' do
    it 'Proユーザーは紐付けを差し替えられる' do
      make_pro(user)
      note = create(:baseball_note, user:, memo:, date: Date.current)
      old_game_result = create(:game_result, user:)
      note.game_result_ids = [old_game_result.id]
      new_game_result = create(:game_result, user:)
      patch "/api/v2/baseball_notes/#{note.id}",
            params: { baseball_note: { game_result_ids: [new_game_result.id] } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['game_result_ids']).to eq([new_game_result.id])
    end
  end

  describe 'GET /api/v2/baseball_notes（練習記録で絞り込み）' do
    it 'practice_session_id で絞り込める' do
      session = create(:practice_session, user:)
      create(:baseball_note, user:, practice_session: session, memo:, date: Date.current)
      create(:baseball_note, user:, memo:, date: Date.current)
      get '/api/v2/baseball_notes', params: { practice_session_id: session.id }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe 'POST /api/v2/baseball_notes（課題の紐付け）' do
    it '1件だけなら無料ユーザーでも紐付けられる' do
      theme = create(:improvement_theme, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:, improvement_theme_ids: [theme.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['improvement_theme_ids']).to eq([theme.id])
    end

    it '無料ユーザーが2件以上紐付けようとすると403' do
      themes = create_list(:improvement_theme, 2, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      improvement_theme_ids: themes.map(&:id) } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーは複数の課題を紐付けられる' do
      make_pro(user)
      themes = create_list(:improvement_theme, 2, user:)
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      improvement_theme_ids: themes.map(&:id) } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['improvement_theme_ids']).to match_array(themes.map(&:id))
    end

    it '他ユーザーの課題には紐付けられない（IDOR防止）' do
      other_theme = create(:improvement_theme, user: create(:user))
      post '/api/v2/baseball_notes',
           params: { baseball_note: { title: 'x', date: Date.current, memo:,
                                      improvement_theme_ids: [other_theme.id] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v2/baseball_notes/:id（課題の紐付け）' do
    it 'Proユーザーは紐付けを差し替えられる' do
      make_pro(user)
      note = create(:baseball_note, user:, memo:, date: Date.current)
      old_theme = create(:improvement_theme, user:)
      note.improvement_theme_ids = [old_theme.id]
      new_theme = create(:improvement_theme, user:)
      patch "/api/v2/baseball_notes/#{note.id}",
            params: { baseball_note: { improvement_theme_ids: [new_theme.id] } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['improvement_theme_ids']).to eq([new_theme.id])
    end
  end
end
