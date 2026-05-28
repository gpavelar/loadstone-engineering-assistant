class ConversationsController < ApplicationController
  before_action :set_current_user

  def index
    @conversations = @current_user.conversations.order(updated_at: :desc)
    @conversation = @conversations.first || @current_user.conversations.create!(title: nil)
    @conversations = @current_user.conversations.order(updated_at: :desc) unless @conversations.include?(@conversation)
    @messages = @conversation.messages.order(:created_at)
  end

  def show
    @conversations = @current_user.conversations.order(updated_at: :desc)
    @conversation = @current_user.conversations.find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    render :index
  end

  def create
    @conversation = @current_user.conversations.create!(title: nil)
    redirect_to conversation_path(@conversation)
  end

  private

  def set_current_user
    @current_user = User.first
  end
end
