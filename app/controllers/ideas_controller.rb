class IdeasController < ApplicationController
  before_action :set_current_user
  before_action :set_idea, only: %i[show update destroy archive unarchive]
  before_action :set_idea_lists, only: %i[index show create update]

  def index
    @idea = @active_ideas.first || @archived_ideas.first
  end

  def show
    render :index
  end

  def create
    @idea = @current_user.ideas.new(idea_params)
    if @idea.save
      redirect_to idea_path(@idea)
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @idea.update(idea_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to idea_path(@idea) }
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @idea.destroy!
    redirect_to ideas_path
  end

  def archive
    @idea.archive!
    redirect_to ideas_path
  end

  def unarchive
    @idea.unarchive!
    redirect_to idea_path(@idea)
  end

  private

  def set_current_user
    @current_user = User.first
  end

  def set_idea
    @idea = @current_user.ideas.find(params[:id])
  end

  def set_idea_lists
    @active_ideas = @current_user.ideas.active.includes(:investigations).order(updated_at: :desc)
    @archived_ideas = @current_user.ideas.archived.order(updated_at: :desc)
  end

  def idea_params
    params.require(:idea).permit(:title, :body)
  end
end
