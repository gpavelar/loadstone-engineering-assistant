class InvestigationsController < ApplicationController
  before_action :set_current_user
  before_action :set_idea

  def create
    raw_mode = investigation_params[:mode]
    mode = Skills::InvestigationModes.valid?(raw_mode) ? raw_mode.presence : nil

    inv = @idea.investigations.create!(
      status: "queued",
      prompt: investigation_params[:prompt].presence,
      mode: mode
    )
    Turbo::StreamsChannel.broadcast_prepend_to(
      "idea_#{@idea.id}",
      target: "investigations_#{@idea.id}",
      partial: "investigations/summary",
      locals: { investigation: inv }
    )
    RunInvestigationJob.perform_later(inv.id)
    redirect_to idea_path(@idea)
  end

  def show
    @investigation = @idea.investigations.find(params[:id])
    render partial: "investigations/full", locals: { investigation: @investigation }
  end

  def distil
    @investigation = @idea.investigations.find(params[:id])

    unless @investigation.done?
      return redirect_to idea_path(@idea),
                         alert: "Can only distil completed investigations."
    end

    result = Skills::DistilInvestigation.new(@investigation).call

    if result.success?
      @idea.append_to_body!(result.section)
      @investigation.update!(distilled_at: Time.current)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to idea_path(@idea) }
      end
    else
      redirect_to idea_path(@idea), alert: "Distillation failed: #{result.error}"
    end
  end

  private

  def set_current_user
    @current_user = User.first
  end

  def set_idea
    @idea = @current_user.ideas.find(params[:idea_id])
  end

  def investigation_params
    params.fetch(:investigation, {}).permit(:prompt, :mode)
  end
end
