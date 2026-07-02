require 'rails_helper'

RSpec.describe 'Api::V2::BaseballNotes', type: :request do
  let(:user) { create(:user) }
  let(:memo) { [{ 'children' => [{ 'text' => '外角が体の開きで詰まる' }] }].to_json }

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
end
