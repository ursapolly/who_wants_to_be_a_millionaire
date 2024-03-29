require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  context 'Anon' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include('Вам необходимо войти в систему или зарегистрироваться')
    end

    it 'forbid #create' do
      post :create
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include('Вам необходимо войти в систему или зарегистрироваться')
    end

    it 'forbid #answer' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include('Вам необходимо войти в систему или зарегистрироваться')
    end

    it 'forbid #take_money' do
      game_w_questions.update_attribute(:current_level, 2)
      put :take_money, id: game_w_questions.id
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include('Вам необходимо войти в систему или зарегистрироваться')
    end
  end

  context 'Logged in user' do
    before(:each) do
      sign_in user
    end

    it 'creates game' do
      generate_questions(15)
      post :create
      game = assigns(:game)
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      expect(response.status).to eq 200
      expect(response).to render_template('show')
    end

    it '#show game of another user' do
      another_game = FactoryGirl.create(:game_with_questions)
      get :show, id: another_game.id
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be
    end

    it 'answer correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)
      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy
    end

    it 'answer incorrect' do
      put :answer, id: game_w_questions.id, letter: 'a'
      game = assigns(:game)
      expect(game.is_failed).to be_truthy
      expect(response).to redirect_to(user_path(user))
      expect(flash[:alert]).to include('Игра закончена')
      expect(game.finished?).to be_truthy
    end

    it 'take money' do
      game_w_questions.update_attribute(:current_level, 2)
      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)
      user.reload
      expect(user.balance).to eq(200)
      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    it 'goto uncompleted game' do
      expect(game_w_questions.finished?).to be_falsey
      expect { post :create }.to change(Game, :count).by(0)
      game = assigns(:game)
      expect(game).to be_nil
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    it 'uses audience help' do
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses fifty_fifty help' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be_falsey
      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      expect(response.status).to eq 302
      game = assigns(:game)
      expect(game.fifty_fifty_used).to be_truthy
      expect(game.current_game_question.help_hash[:fifty_fifty]).to be
      expect(response).to redirect_to(game_path(game))
      expect(flash[:info]).to include('Вы использовали подсказку')
    end
  end
end
